-- Who's in the group, who's a healer, and their mana (spec Section 5).
-- Every addon user tracks every healer, so one copy of the addon covers the whole group.
local _, ns = ...
local L = ns.L
local Levels = ns.Levels

local Roster = {}
ns.Roster = Roster

-- Tracked healers by GUID: { guid, unit, name, class, state, pct, why }. State survives
-- roster shuffles (units can change; GUIDs don't).
local healers = {}
local byUnit = {}  -- current unit token -> healer
local count = 0
Roster.healers = healers

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local function manaType()
  return Enum and Enum.PowerType and Enum.PowerType.Mana or 0
end

-- The unit tokens to scan, or nil when solo.
function Roster.GroupUnits()
  if IsInRaid() then return RAID_UNITS end
  if IsInGroup() then return PARTY_UNITS end
  return nil
end

function Roster.Count() return count end
function Roster.ByUnit(unit) return byUnit[unit] end

-- The group is in combat if I am, or (combatScope "group") anyone is. Combat.lua (Phase 3)
-- replaces this with the event-driven version.
function Roster.InCombat()
  if ns.GroupInCombat then return ns.GroupInCombat() end
  return InCombatLockdown() or UnitAffectingCombat("player") == true
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
        local h = healers[guid] or { guid = guid, state = Levels.NewState() }
        healers[guid] = h
        h.unit = unit
        h.name = UnitName(unit)
        local _, class = UnitClass(unit)
        h.class = nil
        if not ns.IsSecret(class) then h.class = class end
        byUnit[unit] = h
        -- In a raid my own power events come as "player" as well as "raidN".
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

-- A healer's mana percent, or nil and why not ("dead" | "offline" | "secret").
function Roster.Read(h)
  local unit = h.unit
  local dead, online = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
  if ns.IsSecret(dead) or ns.IsSecret(online) then return nil, "secret" end
  if dead then return nil, "dead" end
  if not online then return nil, "offline" end
  local mana, max = UnitPower(unit, manaType()), UnitPowerMax(unit, manaType())
  local pct = Levels.Pct(mana, max)
  if not pct then return nil, "secret" end
  return pct
end

-- Reads one healer and runs the state machine. Results go to ns.OnLevelEvent (Phase 3).
function Roster.Evaluate(h, inCombat)
  local pct, why = Roster.Read(h)
  h.pct, h.why = pct, why
  if not pct then return end
  local result = Levels.Update(h.state, pct, inCombat, ns.Settings())
  if result and ns.OnLevelEvent then ns.OnLevelEvent(h, result) end
end

function Roster.EvaluateAll()
  local inCombat = Roster.InCombat()
  for _, h in pairs(healers) do Roster.Evaluate(h, inCombat) end
end

-- ---------------------------------------------------------------- events

-- UNIT_POWER_UPDATE is coalesced: at most one evaluation per healer every 0.5 s (spec 13).
local dirty = {}
local flushQueued = false
local function flush()
  flushQueued = false
  local inCombat = Roster.InCombat()
  for guid in pairs(dirty) do
    dirty[guid] = nil
    local h = healers[guid]
    if h then Roster.Evaluate(h, inCombat) end
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
local powerOn, flagsOn = false, false

-- Registers or drops the power (and debug) events to match the current state.
function Roster.Refresh()
  local s = ns.Settings()
  Roster.Scan()
  local wantPower = s.enabled and count > 0
  if wantPower ~= powerOn then
    if wantPower then frame:RegisterEvent("UNIT_POWER_UPDATE") else frame:UnregisterEvent("UNIT_POWER_UPDATE") end
    powerOn = wantPower
  end
  -- UNIT_FLAGS is only watched for /sot debug events until Combat.lua needs it (spec 16 Q5).
  local wantFlags = s.debugEvents and Roster.GroupUnits() ~= nil
  if wantFlags ~= flagsOn then
    if wantFlags then frame:RegisterEvent("UNIT_FLAGS") else frame:UnregisterEvent("UNIT_FLAGS") end
    flagsOn = wantFlags
  end
  if wantPower then Roster.EvaluateAll() end
end

local ROSTER_EVENTS = {
  "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM", "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

frame:SetScript("OnEvent", function(_, event, unit, powerType)
  local s = ns.Settings()
  if s.debugEvents and event ~= "UNIT_POWER_UPDATE" then
    ns.Print(("|cff888888event|r %s %s %s"):format(event, tostring(unit), tostring(powerType)))
    if event == "UNIT_FLAGS" and unit then
      local c = UnitAffectingCombat(unit)
      ns.Print(("  UnitAffectingCombat(%s) = %s"):format(unit, ns.IsSecret(c) and "<secret>" or tostring(c)))
    end
  end
  if event == "UNIT_POWER_UPDATE" then
    if powerType ~= "MANA" then return end
    local h = byUnit[unit]
    if not h then return end
    dirty[h.guid] = true
    if not flushQueued then
      flushQueued = true
      C_Timer.After(0.5, flush)
    end
  elseif event == "UNIT_FLAGS" or event == "PLAYER_REGEN_DISABLED" then
    return -- debug print only (above), until Combat.lua
  elseif event == "PLAYER_REGEN_ENABLED" then
    if powerOn then Roster.EvaluateAll() end
  else
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

local function displayName(h)
  if not h.name or ns.IsSecret(h.name) then return h.unit end
  local color = h.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[h.class]
  if color and color.colorStr then return ("|c%s%s|r"):format(color.colorStr, h.name) end
  return h.name
end

-- One line per tracked healer (used by /sot status and the compartment tooltip).
function ns.StatusLines()
  local lines = {}
  if not SoThirstyDB or not ns.Settings().enabled then return lines end
  local cfg = ns.Settings()
  for _, h in pairs(healers) do
    local pct, why = Roster.Read(h)
    local mana, level, drink = L.STATUS_UNKNOWN, "", ""
    if pct then
      mana = L.STATUS_MANA:format(pct)
      local current = Levels.Current(pct, cfg)
      if current > 0 then level = L.STATUS_LEVEL:format(current, cfg.levels[current].pct) end
      if ns.Drink.AuraMatch(h.unit) == true then drink = L.STATUS_DRINKING end
    elseif why == "dead" then
      mana = L.STATUS_DEAD
    elseif why == "offline" then
      mana = L.STATUS_OFFLINE
    end
    lines[#lines + 1] = L.STATUS_LINE:format(displayName(h), mana, level, drink)
  end
  table.sort(lines)
  return lines
end

function ns.PrintStatus()
  if not ns.Settings().enabled then return ns.Print(L.STATUS_OFF) end
  if not Roster.GroupUnits() then return ns.Print(L.STATUS_SOLO) end
  Roster.Scan()
  if count == 0 then return ns.Print(L.STATUS_NONE) end
  ns.Print(L.STATUS_HEADER:format(count))
  for _, line in ipairs(ns.StatusLines()) do DEFAULT_CHAT_FRAME:AddMessage(line) end
  if Roster.InCombat() then DEFAULT_CHAT_FRAME:AddMessage("  " .. L.STATUS_COMBAT) end
end
