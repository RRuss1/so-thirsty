-- Group combat state and the after-fight nudge (spec Section 7). The glow hides in combat;
-- nudgeDelay seconds after a fight it brightens once, then settles.
local _, ns = ...

local Combat = {}
ns.Combat = Combat

local inCombat, wiped = false, false
local nudgeTimer
local checkQueued = false

function Combat.Is() return inCombat end
function Combat.Wiped() return wiped end

-- Am I, or (combatScope "group") is anyone in the group, fighting? A secret read counts as
-- fighting: that's the safe answer.
local function read()
  if InCombatLockdown() then return true end
  local me = UnitAffectingCombat("player")
  if ns.IsSecret(me) or me then return true end
  if ns.Settings().combatScope ~= "group" then return false end
  local units = ns.Roster.GroupUnits()
  if not units then return false end
  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      local c = UnitAffectingCombat(unit)
      if ns.IsSecret(c) or c then return true end
    end
  end
  return false
end

local function deadCount()
  local dead, total = 0, 0
  local units = ns.Roster.GroupUnits()
  if not units then return 0, 0 end
  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      total = total + 1
      local d = UnitIsDeadOrGhost(unit)
      if not ns.IsSecret(d) and d then dead = dead + 1 end
    end
  end
  return dead, total
end

-- Brightens every healer who may be nudged. A healer above level 1 has an invisible glow,
-- so nothing shows for them; the addon doesn't need to know who is low.
function Combat.Nudge()
  nudgeTimer = nil
  if inCombat or not ns.Frames then return end
  for _, h in pairs(ns.Roster.healers) do
    if ns.Levels.CanNudge(ns.Roster.Known(h), wiped) then ns.Frames.Nudge(h) end
  end
end

local function set(now)
  if now == inCombat then return end
  inCombat = now
  if nudgeTimer then
    nudgeTimer:Cancel()
    nudgeTimer = nil
  end
  local s = ns.Settings()
  if now then
    wiped = false
  else
    wiped = s.quietAfterWipe and ns.Levels.Wiped(deadCount()) or false
    if s.enabled and s.nudge and ns.Roster.Count() > 0 then
      nudgeTimer = C_Timer.NewTimer(s.nudgeDelay, Combat.Nudge)
    end
  end
  if s.debugEvents then ns.Print(("|cff888888combat|r %s wiped=%s"):format(tostring(now), tostring(wiped))) end
  ns.Roster.RefreshDrinking()
  ns.UpdateAll()
end

-- Re-reads combat. While I'm out of combat but someone else is still fighting, look again
-- every second until it clears (UNIT_FLAGS can't be relied on; spec 16 Q5).
local function check()
  checkQueued = false
  local now = read()
  set(now)
  if now and not InCombatLockdown() and not checkQueued then
    checkQueued = true
    C_Timer.After(1, check)
  end
end
Combat.Check = check

local frame = CreateFrame("Frame")
local flagsOn = false

-- UNIT_FLAGS is only needed with healers to show and the group scope on.
function Combat.Refresh()
  local s = ns.Settings()
  local want = s.enabled and s.combatScope == "group" and ns.Roster.Count() > 0
  if want ~= flagsOn then
    if want then frame:RegisterEvent("UNIT_FLAGS") else frame:UnregisterEvent("UNIT_FLAGS") end
    flagsOn = want
  end
  set(read())
end

frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    set(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    check()
  elseif not checkQueued then
    -- UNIT_FLAGS: coalesce to one check per half second.
    checkQueued = true
    C_Timer.After(0.5, check)
  end
end)

function Combat.Start()
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
end
