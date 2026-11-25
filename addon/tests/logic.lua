-- Tests for SoThirsty's logic against a stubbed WoW API (spec 6.3).
--   lua5.1 addon/tests/logic.lua      (or luajit)
-- Exits non-zero on failure.

local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local root = here .. "/../.."
local ns = {}

local function loadAddon(path)
  local f = assert(loadfile(root .. "/addon/SoThirsty/" .. path))
  return f("SoThirsty", ns)
end

-- ---------------------------------------------------------------- stubbed WoW API

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
function issecretvalue(v) return v == SECRET end

local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) printed[#printed + 1] = msg end }
SlashCmdList = {}
RAID_CLASS_COLORS = {}
Enum = { PowerType = { Mana = 0 } }

-- Frames: remember each one's event handler and registered events so tests can fire events.
local frames = {}
function CreateFrame()
  local f = { events = {} }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:SetScript(_, fn) self.handler = fn end
  frames[#frames + 1] = f
  return f
end
local function fire(event, ...)
  for _, f in ipairs(frames) do
    if f.handler and f.events[event] then f.handler(f, event, ...) end
  end
end

local timers = {}
C_Timer = {
  After = function(_, fn) timers[#timers + 1] = fn end,
  NewTimer = function() return { Cancel = function() end } end,
}
local function runTimers()
  local batch = timers
  timers = {}
  for _, fn in ipairs(batch) do fn() end
end

-- A party: me (a tank) and four others. Edit `units` to change the group.
local units, combat, grouped, raid
local function reset()
  units = {
    player = { guid = "Player-1", name = "Tanky", role = "TANK", class = "WARRIOR", mana = 0, max = 0 },
    party1 = { guid = "Player-2", name = "Sherl", role = "HEALER", class = "PRIEST", mana = 1000, max = 1000 },
    party2 = { guid = "Player-3", name = "Brann", role = "DAMAGER", class = "MAGE", mana = 500, max = 1000 },
  }
  combat, grouped, raid = false, true, false
end
reset()
local function u(unit) return units[unit] end
function UnitExists(unit) return u(unit) ~= nil end
function UnitGUID(unit) return u(unit) and u(unit).guid end
function UnitName(unit) return u(unit) and u(unit).name end
function UnitClass(unit) return u(unit).class, u(unit).class end
function UnitIsUnit(a, b) return u(a) ~= nil and u(a) == u(b) end
function UnitGroupRolesAssigned(unit) return u(unit) and u(unit).role or "NONE" end
function UnitIsDeadOrGhost(unit) return u(unit).dead == true end
function UnitIsConnected(unit) return u(unit).offline ~= true end
function UnitPower(unit) return u(unit).mana end
function UnitPowerMax(unit) return u(unit).max end
function UnitAffectingCombat() return combat end
function UnitIsGroupLeader() return true end
function InCombatLockdown() return combat end
function IsInGroup() return grouped end
function IsInRaid() return raid end
function IsInInstance() return true, "party" end

loadAddon("Locales/enUS.lua")
loadAddon("Core.lua")
loadAddon("Levels.lua")
loadAddon("Roster.lua")
loadAddon("Drink.lua")
fire("ADDON_LOADED", "SoThirsty")

local Levels = ns.Levels

-- ---------------------------------------------------------------- harness

local passed, failed = 0, 0
local function check(name, ok, detail)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL  " .. name .. (detail and ("\n      " .. detail) or ""))
  end
end
local function eq(name, got, want)
  check(name, got == want, ("got %s, want %s"):format(tostring(got), tostring(want)))
end

-- A fresh config like the defaults: 50/30/10, Ready 90, margin 5, drink rise 10.
local function cfg(a, b, c)
  return {
    levels = { { enabled = true, pct = a or 50 }, { enabled = true, pct = b or 30 }, { enabled = true, pct = c or 10 } },
    ready = { enabled = true, pct = 90 },
    rearmMargin = 5,
    drinkRise = 10,
  }
end

-- Runs mana updates out of combat, then settles; returns the level announced (or nil).
local function settleAt(state, pct, c, drinking)
  Levels.Update(state, pct, false, c)
  local d = Levels.Settle(state, pct, drinking or false, c)
  return d and d.level
end

-- ---------------------------------------------------------------- Levels (spec 6.3)

do
  local c, s = cfg(), Levels.NewState()
  eq("100 -> 49: L1", settleAt(s, 49, c), 1)
  eq("  48: nothing more", settleAt(s, 48, c), nil)
  eq("  47: nothing more", settleAt(s, 47, c), nil)
end

do
  local c, s = cfg(), Levels.NewState()
  Levels.Update(s, 100, false, c)
  eq("100 -> 29 in one step: only L2", settleAt(s, 29, c), 2)
end

do
  local c, s = cfg(), Levels.NewState()
  Levels.Update(s, 60, true, c)
  eq("60 -> 8 in combat: no decision mid-fight", Levels.Update(s, 8, true, c), nil)
  eq("  settle at 8: L3", (Levels.Settle(s, 8, false, c) or {}).level, 3)
  eq("  and only once", Levels.Settle(s, 8, false, c), nil)
end

do
  local c, s = cfg(), Levels.NewState()
  Levels.Update(s, 25, true, c)
  eq("60 -> 25 in combat, drinks to 40 by settle: L1, not L2", (Levels.Settle(s, 40, false, c) or {}).level, 1)
end

do
  local c, s = cfg(), Levels.NewState()
  eq("29: L2", settleAt(s, 29, c), 2)
  eq("  31 (inside the re-arm margin): nothing", settleAt(s, 31, c), nil)
  eq("  29 again: no second L2", settleAt(s, 29, c), nil)
end

do
  local c, s = cfg(), Levels.NewState()
  eq("29: L2", settleAt(s, 29, c), 2)
  eq("  36 (past the margin): nothing", settleAt(s, 36, c), nil)
  eq("  29 again: L2 fires again", settleAt(s, 29, c), 2)
end

do
  local c, s = cfg(), Levels.NewState()
  Levels.Update(s, 25, false, c)
  eq("settle while drinking: nothing", Levels.Settle(s, 25, true, c), nil)
  eq("  announced unchanged", s.announced, 0)
  eq("  next settle, not drinking, still 25: L2", (Levels.Settle(s, 25, false, c) or {}).level, 2)
end

do
  local c, s = cfg(), Levels.NewState()
  eq("two settles with no change: first L2", settleAt(s, 25, c), 2)
  eq("  second nil", Levels.Settle(s, 25, false, c), nil)
end

do
  local c, s = cfg(), Levels.NewState()
  settleAt(s, 9, c)
  eq("9 -> 92 out of combat: Ready", Levels.Update(s, 92, false, c), Levels.READY)
  eq("  then nothing", Levels.Update(s, 93, false, c), nil)
  eq("  Ready waits for the end of combat", (function()
    local s2 = Levels.NewState()
    settleAt(s2, 9, c)
    return Levels.Update(s2, 95, true, c)
  end)(), nil)
end

do
  local c, s = cfg(), Levels.NewState()
  c.ready.enabled = false
  settleAt(s, 9, c)
  eq("Ready disabled: never fires", Levels.Update(s, 95, false, c), nil)
end

do
  local c, s = cfg(), Levels.NewState()
  c.levels[1].enabled = false
  eq("L1 off: a drop to 45 does nothing", settleAt(s, 45, c), nil)
  eq("  but 29 still gives L2", settleAt(s, 29, c), 2)
end

do
  local c, s = cfg(60, 40, 20), Levels.NewState()
  eq("60/40/20: 55 -> L1", settleAt(s, 55, c), 1)
  eq("  35 -> L2", settleAt(s, 35, c), 2)
  eq("  19 -> L3", settleAt(s, 19, c), 3)
  eq("  10 -> nothing", settleAt(s, 10, c), nil)
end

do
  check("Validate 50/30/10", Levels.Validate(cfg().levels))
  local ok, why = Levels.Validate(cfg(30, 50, 10).levels)
  check("Validate rejects 30/50/10", not ok)
  eq("  because of the order", why, "ORDER")
  eq("Validate rejects 0", select(2, Levels.Validate(cfg(50, 30, 0).levels)), "RANGE")
  eq("Validate rejects 100", select(2, Levels.Validate(cfg(100, 30, 10).levels)), "RANGE")
  local c = cfg(30, 50, 10)
  c.levels[1].enabled = false
  check("Validate ignores a disabled level", Levels.Validate(c.levels))
  eq("Validate rejects equal levels", select(2, Levels.Validate(cfg(50, 50, 10).levels)), "ORDER")
end

do
  local c, s = cfg(), Levels.NewState()
  settleAt(s, 29, c)
  eq("secret pct: Update nil", Levels.Update(s, SECRET, false, c), nil)
  eq("  Settle nil", Levels.Settle(s, SECRET, false, c), nil)
  eq("  state unchanged", s.lastPct, 29)
  eq("  announced unchanged", s.announced, 2)
end

do
  local c, s = cfg(), Levels.NewState()
  eq("Update out of combat arms on a new level", Levels.Update(s, 45, false, c), Levels.ARM)
  eq("  never in combat", Levels.Update(s, 25, true, c), nil)
  Levels.Settle(s, 25, false, c)
  eq("  not again for the same level", Levels.Update(s, 24, false, c), nil)
end

do
  local c = cfg()
  eq("IsDrinking: aura true", Levels.IsDrinking(true, 20, 20, c), true)
  eq("IsDrinking: aura unknown, rise 12", Levels.IsDrinking(nil, 20, 32, c), true)
  eq("IsDrinking: aura unknown, rise 3", Levels.IsDrinking(nil, 20, 23, c), false)
  eq("IsDrinking: no aura, secret pcts", Levels.IsDrinking(false, SECRET, SECRET, c), false)
end

do
  eq("Pct 437/1000", Levels.Pct(437, 1000), 43)
  eq("Pct max 0", Levels.Pct(0, 0), nil)
  eq("Pct secret", Levels.Pct(SECRET, 1000), nil)
end

-- ---------------------------------------------------------------- Roster (spec 5)

local function healerNames()
  local names = {}
  for _, h in pairs(ns.Roster.healers) do names[#names + 1] = h.name end
  table.sort(names)
  return table.concat(names, ",")
end

eq("startup: the healer is tracked", healerNames(), "Sherl")
check("  power events are on", frames[#frames].events.UNIT_POWER_UPDATE)

units.party2.role = "HEALER"
fire("ROLE_CHANGED_INFORM")
eq("a second healer via Set Role", healerNames(), "Brann,Sherl")
units.party2.role = "DAMAGER"
fire("GROUP_ROSTER_UPDATE")
eq("role cleared: dropped", healerNames(), "Sherl")

units.party1.role = SECRET
fire("GROUP_ROSTER_UPDATE")
eq("a secret role read is skipped", healerNames(), "")
check("  power events go off with no healer", not frames[#frames].events.UNIT_POWER_UPDATE)
units.party1.role = "HEALER"
fire("GROUP_ROSTER_UPDATE")

do
  local h = ns.Roster.ByUnit("party1")
  units.party1.mana = 450
  eq("Read: 45%", ns.Roster.Read(h), 45)
  units.party1.mana = SECRET
  local pct, why = ns.Roster.Read(h)
  check("Read: secret mana is nil", pct == nil and why == "secret")
  units.party1.mana, units.party1.dead = 450, true
  eq("Read: dead", select(2, ns.Roster.Read(h)), "dead")
  units.party1.dead, units.party1.offline = nil, true
  eq("Read: offline", select(2, ns.Roster.Read(h)), "offline")
  units.party1.offline = nil
end

do
  -- Units shift; the GUID keeps its state.
  local before = ns.Roster.ByUnit("party1")
  before.state.announced = 2
  units.party1.mana = 250 -- 25%: still level 2, so the rescan's mana read doesn't re-arm it
  units.party3, units.party1 = units.party1, nil
  fire("GROUP_ROSTER_UPDATE")
  local after = ns.Roster.ByUnit("party3")
  check("a healer who moves unit keeps their state", after == before and after.state.announced == 2)
  units.party1, units.party3 = units.party3, nil
  fire("GROUP_ROSTER_UPDATE")
  after.state.announced = 0
end

do
  -- Mana updates are coalesced, then run through Levels.Update.
  local events = {}
  ns.OnLevelEvent = function(h, result) events[#events + 1] = h.name .. ":" .. result.kind end
  runTimers()
  units.party1.mana = 400
  fire("UNIT_POWER_UPDATE", "party1", "MANA")
  fire("UNIT_POWER_UPDATE", "party1", "MANA")
  fire("UNIT_POWER_UPDATE", "party2", "MANA") -- not a healer
  fire("UNIT_POWER_UPDATE", "party1", "ENERGY")
  eq("power updates wait for the 0.5 s timer", #timers, 1)
  runTimers()
  eq("  one evaluation, one arm", table.concat(events, " "), "Sherl:arm")
  ns.OnLevelEvent = nil
end

do
  grouped = false
  fire("GROUP_ROSTER_UPDATE")
  eq("solo: nothing tracked", healerNames(), "")
  check("  power events off", not frames[#frames].events.UNIT_POWER_UPDATE)
  grouped = true
  fire("GROUP_ROSTER_UPDATE")
end

do
  raid = true
  units = {
    raid1 = { guid = "Player-1", name = "Tanky", role = "TANK", class = "WARRIOR", mana = 0, max = 0 },
    raid2 = { guid = "Player-2", name = "Sherl", role = "HEALER", class = "PRIEST", mana = 1000, max = 1000 },
  }
  units.player = units.raid1
  fire("GROUP_ROSTER_UPDATE")
  eq("raid: the healer is tracked by raid unit", (ns.Roster.ByUnit("raid2") or {}).name, "Sherl")
  reset()
  fire("GROUP_ROSTER_UPDATE")
end

-- ---------------------------------------------------------------- slash commands

do
  printed = {}
  ns.RunCommand("levels 60 40 20")
  local lv = SoThirstyDB.settings.levels
  check("/sot levels 60 40 20", lv[1].pct == 60 and lv[2].pct == 40 and lv[3].pct == 20)
  ns.RunCommand("levels 30 50 10")
  check("/sot levels 30 50 10 is rejected", lv[1].pct == 60 and printed[#printed]:find("lower than"))
  ns.RunCommand("levels 50 30 10")
  ns.RunCommand("off")
  check("/sot off", SoThirstyDB.settings.enabled == false and not frames[#frames].events.UNIT_POWER_UPDATE)
  ns.RunCommand("on")
  check("/sot on", SoThirstyDB.settings.enabled == true and frames[#frames].events.UNIT_POWER_UPDATE)
  printed = {}
  ns.RunCommand("status")
  check("/sot status lists the healer", (printed[2] or ""):find("Sherl") ~= nil, printed[2])
  ns.RunCommand("ghost 40")
  eq("/sot ghost 40", SoThirstyDB.settings.look.ghost, 40)
  ns.RunCommand("ghost 200")
  eq("/sot ghost 200 is rejected", SoThirstyDB.settings.look.ghost, 40)
  ns.RunCommand("ghost 0")
  eq("/sot ghost 0 turns it off", SoThirstyDB.settings.look.ghost, 0)
  ns.RunCommand("bogus")
  check("an unknown command says so", printed[#printed]:find("Unknown command") ~= nil)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
