-- Who's in the group, who's a healer, and what the addon is allowed to know about them
-- (spec Section 5). Mana is never read as a number: it's always secret on Forever.
local _, ns = ...
local L = ns.L

local Roster = {}
ns.Roster = Roster

-- Tracked healers by GUID: { guid, unit, name, class, drinking }. Units can change when the
-- roster shuffles; GUIDs don't.
local healers = {}
local byUnit = {}  -- current unit token -> healer
local count = 0
Roster.healers = healers

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

-- The unit tokens to scan, or nil when solo.
function Roster.GroupUnits()
  if IsInRaid() then return RAID_UNITS end
  if IsInGroup() then return PARTY_UNITS end
  return nil
end

function Roster.Count() return count end
function Roster.ByUnit(unit) return byUnit[unit] end

function Roster.InCombat()
  return ns.Combat.Is()
end

-- ---------------------------------------------------------------- scanning

function Roster.Scan()
  for unit in pairs(byUnit) do byUnit[unit] = nil end
  local seen = {}
  local units = Roster.GroupUnits()
  if units then
    for _, unit in ipairs(units) do
      -- Check for secret values before any test or comparison on them.
      local role, guid
      if UnitExists(unit) then role = UnitGroupRolesAssigned(unit) end
      if not ns.IsSecret(role) and role == "HEALER" then guid = UnitGUID(unit) end
      if not ns.IsSecret(guid) and guid then
        local h = healers[guid] or { guid = guid, drinking = false }
        healers[guid] = h
        h.unit = unit
        h.name = UnitName(unit)
        local _, class = UnitClass(unit)
        h.class = nil
        if not ns.IsSecret(class) then h.class = class end
        byUnit[unit] = h
        -- In a raid my own events come as "player" as well as "raidN".
        if unit ~= "player" and UnitIsUnit(unit, "player") then byUnit.player = h end
        seen[guid] = true
      end
    end
  end
  count = 0
  for guid in pairs(healers) do
    if seen[guid] then count = count + 1 else healers[guid] = nil end
  end
end

-- What the addon knows about one healer, for Levels.Holder / Levels.CanNudge. The table is
-- reused; read it before the next call.
local known = {}
function Roster.Known(h)
  local s = ns.Settings()
  local dead, online = UnitIsDeadOrGhost(h.unit), UnitIsConnected(h.unit)
  known.enabled = s.enabled == true
  known.zoneOk = ns.ZoneOk() and true or false
  known.inCombat = ns.Combat.Is()
  known.dead = not ns.IsSecret(dead) and dead == true
  known.offline = not ns.IsSecret(online) and online == false
  known.drinking = h.drinking == true
  return known
end

-- Re-reads the drink buff for every healer. Nobody drinks in combat.
function Roster.RefreshDrinking()
  local inCombat = ns.Combat.Is()
  for _, h in pairs(healers) do
    h.drinking = not inCombat and ns.Drink.AuraMatch(h.unit) == true
  end
end

-- ---------------------------------------------------------------- events

-- Mana and buff events are coalesced: at most one refresh per healer every 0.5 s (spec 13).
local dirty, auraDirty = {}, {}
local flushQueued = false
local function flush()
  flushQueued = false
  local inCombat = ns.Combat.Is()
  for guid in pairs(dirty) do
    dirty[guid] = nil
    local h = healers[guid]
    if h then
      if auraDirty[guid] then h.drinking = not inCombat and ns.Drink.AuraMatch(h.unit) == true end
      ns.UpdateHealer(h)
    end
    auraDirty[guid] = nil
  end
end

local function markDirty(h, aura)
  dirty[h.guid] = true
  if aura then auraDirty[h.guid] = true end
  if not flushQueued then
    flushQueued = true
    C_Timer.After(0.5, flush)
  end
end

-- Role hint (spec 5): once per group, only to the leader, only inside a dungeon or raid.
local hinted = false
local function checkRoleHint()
  if not IsInGroup() then hinted = false return end
  local s = ns.Settings()
  if hinted or not s.roleHint or not s.enabled or count > 0 then return end
  local _, kind = IsInInstance()
  if kind ~= "party" and kind ~= "raid" then return end
  if not UnitIsGroupLeader("player") then return end
  hinted = true
  ns.Print(L.ROLE_HINT)
end

local frame = CreateFrame("Frame")
local unitEventsOn = false
local UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_AURA", "UNIT_CONNECTION" }

-- Rescans, then registers or drops the unit events to match the current state.
function Roster.Refresh()
  local s = ns.Settings()
  Roster.Scan()
  local want = s.enabled and count > 0 and (ns.ZoneOk() and true or false)
  if want ~= unitEventsOn then
    for _, event in ipairs(UNIT_EVENTS) do
      if want then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
    end
    unitEventsOn = want
  end
  ns.Combat.Refresh()
  Roster.RefreshDrinking()
  ns.UpdateAll()
end

local ROSTER_EVENTS = {
  "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM", "PLAYER_ENTERING_WORLD",
  "ZONE_CHANGED_NEW_AREA",
}

frame:SetScript("OnEvent", function(_, event, unit, powerType)
  if event == "UNIT_POWER_UPDATE" then
    if powerType ~= "MANA" then return end
    local h = byUnit[unit]
    if h then markDirty(h, false) end
  elseif event == "UNIT_AURA" then
    local h = byUnit[unit]
    if h and not ns.Combat.Is() then markDirty(h, true) end
  elseif event == "UNIT_CONNECTION" then
    local h = byUnit[unit]
    if h then markDirty(h, false) end
  else
    if ns.Settings().debugEvents then ns.Print(("|cff888888event|r %s %s"):format(event, tostring(unit))) end
    Roster.Refresh()
    C_Timer.After(5, checkRoleHint) -- roles often arrive a moment after the group forms
  end
end)

-- Called once from Core.lua after SavedVariables load.
function Roster.Start()
  for _, event in ipairs(ROSTER_EVENTS) do frame:RegisterEvent(event) end
  Roster.Refresh()
end

-- ---------------------------------------------------------------- status

function Roster.DisplayName(h)
  if not h.name or ns.IsSecret(h.name) then return h.unit end
  local color = h.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[h.class]
  if color and color.colorStr then return ("|c%s%s|r"):format(color.colorStr, h.name) end
  return h.name
end

-- One line per tracked healer (used by /sot status and the compartment tooltip). No mana
-- numbers: the game hides them.
function ns.StatusLines()
  local lines = {}
  if not SoThirstyDB or not ns.Settings().enabled then return lines end
  for _, h in pairs(healers) do
    local k = Roster.Known(h)
    local state = k.dead and L.STATUS_DEAD or k.offline and L.STATUS_OFFLINE or k.drinking and L.STATUS_DRINKING
      or L.STATUS_WATCHING
    lines[#lines + 1] = L.STATUS_LINE:format(Roster.DisplayName(h), state)
  end
  table.sort(lines)
  return lines
end

function ns.PrintStatus()
  if not ns.Settings().enabled then return ns.Print(L.STATUS_OFF) end
  if not Roster.GroupUnits() then return ns.Print(L.STATUS_SOLO) end
  Roster.Scan()
  if count == 0 then return ns.Print(L.STATUS_NONE) end
  Roster.RefreshDrinking()
  ns.Print(L.STATUS_HEADER:format(count))
  for _, line in ipairs(ns.StatusLines()) do DEFAULT_CHAT_FRAME:AddMessage(line) end
  if not ns.ZoneOk() then DEFAULT_CHAT_FRAME:AddMessage("  " .. L.STATUS_ZONE) end
  if ns.Combat.Is() then DEFAULT_CHAT_FRAME:AddMessage("  " .. L.STATUS_COMBAT) end
end
