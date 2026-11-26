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
local lastDelay
C_Timer = {
  After = function(_, fn) timers[#timers + 1] = { fn = fn } end,
  NewTimer = function(seconds, fn)
    lastDelay = seconds
    local t = { fn = fn }
    function t:Cancel() self.cancelled = true end
    timers[#timers + 1] = t
    return t
  end,
}
local function runTimers()
  local batch = timers
  timers = {}
  for _, t in ipairs(batch) do
    if not t.cancelled then t.fn() end
  end
end

-- A party: me (a tank) and two others. Edit `units` to change the group.
local units, combat, grouped, raid, zone
local function reset()
  units = {
    player = { guid = "Player-1", name = "Tanky", role = "TANK", class = "WARRIOR" },
    party1 = { guid = "Player-2", name = "Sherl", role = "HEALER", class = "PRIEST" },
    party2 = { guid = "Player-3", name = "Brann", role = "DAMAGER", class = "MAGE" },
  }
  combat, grouped, raid, zone = false, true, false, "party"
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
function UnitAffectingCombat(unit) return combat or (u(unit) ~= nil and u(unit).combat == true) end
function UnitAura(unit, i)
  if i == 1 and u(unit).drink then return "Drink" end
end
function UnitIsGroupLeader() return true end
function InCombatLockdown() return combat end
function IsInGroup() return grouped end
function IsInRaid() return raid end
function IsInInstance() return zone ~= "none", zone end

local clock, sent = 1000, {}
function GetTime() return clock end
function SendChatMessage(msg, channel) sent[#sent + 1] = channel .. ": " .. msg end

loadAddon("Locales/enUS.lua")
loadAddon("Core.lua")
loadAddon("Theme.lua")
loadAddon("Levels.lua")
loadAddon("Roster.lua")
loadAddon("Drink.lua")
loadAddon("Combat.lua")
loadAddon("Button.lua")
fire("ADDON_LOADED", "SoThirsty")

local Levels = ns.Levels
local rosterFrame, combatFrame = frames[2], frames[3]

-- ---------------------------------------------------------------- harness

local passed, failed = 0, 0
local function check(name, ok, detail)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL  " .. name .. (detail and ("\n      " .. tostring(detail)) or ""))
  end
end
local function eq(name, got, want)
  check(name, got == want, ("got %s, want %s"):format(tostring(got), tostring(want)))
end
local function near(name, got, want)
  local ok = type(got) == "number" and math.abs(got - want) < 1e-6
  check(name, ok, ("got %s, want %s"):format(tostring(got), tostring(want)))
end

-- A config like the defaults, with easy colors: yellow, orange, red.
local function cfg(a, b, c)
  return {
    levels = {
      { pct = a or 50, color = { 1, 1, 0 } },
      { pct = b or 30, color = { 1, 0.5, 0 } },
      { pct = c or 10, color = { 1, 0, 0 } },
    },
  }
end

-- ---------------------------------------------------------------- Levels (spec 6.3)

do
  local function v(a, b, c)
    return select(2, Levels.Validate({ { pct = a }, { pct = b }, { pct = c } })) or "ok"
  end
  eq("Validate 50/30/10", v(50, 30, 10), "ok")
  eq("Validate 30/50/10: order", v(30, 50, 10), "ORDER")
  eq("Validate equal levels: order", v(50, 50, 10), "ORDER")
  eq("Validate 0: range", v(50, 30, 0), "RANGE")
  eq("Validate 100: range", v(100, 30, 10), "RANGE")
  eq("Validate 12.5: range", v(50, 12.5, 10), "RANGE")
end

do
  local c = cfg()
  local p = Levels.ColorPoints(c)
  eq("ColorPoints: linear", p.type, "linear")
  eq("  five points", #p.points, 5)
  near("  x1 = 0", p.points[1][1], 0)
  near("  x2 = 0.1", p.points[2][1], 0.1)
  near("  x3 = 0.3", p.points[3][1], 0.3)
  near("  x4 = 0.5", p.points[4][1], 0.5)
  near("  red at 0 (green part)", p.points[1][3], 0)
  near("  red at level 3", p.points[2][3], 0)
  near("  orange at level 2", p.points[3][3], 0.5)
  near("  yellow at level 1", p.points[4][3], 1)
  check("  water blue just above level 1", p.points[5][1] > 0.5 and p.points[5][1] < 0.51)
  near("  and it's the fine color", p.points[5][4], Levels.FINE[3])
  local classy = Levels.ColorPoints(c, { 0.2, 0.4, 0.6 })
  check("ColorPoints with a class color ends in it", #classy.points == 5 and classy.points[5][2] == 0.2 and classy.points[5][4] == 0.6)
  near("  and keeps the level colors below", classy.points[4][3], 1)
  near("ColorAt 20% is a red/orange blend", select(2, Levels.ColorAt(20, c)), 0.25)
  near("ColorAt 80% is water blue", select(3, Levels.ColorAt(80, c)), Levels.FINE[3])
end

do
  local c = cfg()
  local p = Levels.AlphaPoints(c)
  eq("AlphaPoints: linear", p.type, "linear")
  near("  full at 0", p.points[1][2], 1)
  near("  full at level 3", p.points[2][2], 1)
  near("  level 3 x", p.points[2][1], 0.1)
  near("  faint just under level 1", p.points[3][2], Levels.FAINT)
  check("  just under", p.points[3][1] < 0.5 and p.points[3][1] > 0.49)
  near("  zero at level 1", p.points[4][2], 0)
  near("  level 1 x", p.points[4][1], 0.5)
  near("AlphaAt 5%", Levels.AlphaAt(5, c), 1)
  near("AlphaAt 30% is halfway", Levels.AlphaAt(30, c), (1 + Levels.FAINT) / 2)
  near("AlphaAt 50%", Levels.AlphaAt(50, c), 0)
  near("AlphaAt 80%", Levels.AlphaAt(80, c), 0)
end

do
  local c = cfg(60, 40, 20)
  local low = Levels.LowPoints(c)
  eq("LowPoints: step", low.type, "step")
  near("  on from 0", low.points[1][2], 1)
  near("  off at level 1 (60%)", low.points[2][1], 0.6)
  near("  to zero", low.points[2][2], 0)
  for i, want in ipairs({ 0.6, 0.4, 0.2 }) do
    local pip = Levels.PipPoints(c, i)
    eq("PipPoints " .. i .. ": step", pip.type, "step")
    near("  on from 0", pip.points[1][2], 1)
    near("  off at its level", pip.points[2][1], want)
    near("  to zero", pip.points[2][2], 0)
  end
  eq("PipsLit 70%", Levels.PipsLit(70, c), 0)
  eq("PipsLit 60% (at level 1: not yet)", Levels.PipsLit(60, c), 0)
  eq("PipsLit 59%", Levels.PipsLit(59, c), 1)
  eq("PipsLit 39%", Levels.PipsLit(39, c), 2)
  eq("PipsLit 5%", Levels.PipsLit(5, c), 3)
end

do
  local c = cfg()
  local fraction, r, g, _, alpha, low, p1, p2, p3 = Levels.Plain(25, c)
  near("Plain 25%: fraction", fraction, 0.25)
  check("  a red/orange blend", r == 1 and math.abs(g - 0.375) < 1e-6)
  check("  partly faded in", alpha > Levels.FAINT and alpha < 1)
  check("  low, two pips", low == 1 and p1 == 1 and p2 == 1 and p3 == 0)
  fraction, _, _, _, alpha, low, p1, p2, p3 = Levels.Plain(90, c)
  near("Plain 90%: fraction", fraction, 0.9)
  check("  invisible, not low, no pips", alpha == 0 and low == 0 and p1 == 0 and p2 == 0 and p3 == 0)
end

do
  local function known(t)
    local k = { enabled = true, zoneOk = true, inCombat = false, dead = false, offline = false, drinking = false }
    for key, value in pairs(t or {}) do k[key] = value end
    return k
  end
  local a, drinking = Levels.Holder(known())
  check("Holder: showing", a == 1 and not drinking)
  a, drinking = Levels.Holder(known({ drinking = true }))
  check("Holder: drinking dims", math.abs(a - Levels.DRINK_DIM) < 1e-6 and drinking)
  eq("Holder: combat hides", (Levels.Holder(known({ inCombat = true }))), 0)
  a, drinking = Levels.Holder(known({ inCombat = true, drinking = true }))
  check("Holder: combat beats drinking", a == 0 and not drinking)
  a, drinking = Levels.Holder(known({ dead = true, drinking = true }))
  check("Holder: dead beats drinking", a == 0 and not drinking)
  eq("Holder: offline hides", (Levels.Holder(known({ offline = true }))), 0)
  eq("Holder: off hides", (Levels.Holder(known({ enabled = false }))), 0)
  eq("Holder: wrong zone hides", (Levels.Holder(known({ zoneOk = false }))), 0)

  eq("CanNudge: normal", Levels.CanNudge(known(), false), true)
  eq("CanNudge: drinking", Levels.CanNudge(known({ drinking = true }), false), false)
  eq("CanNudge: wiped", Levels.CanNudge(known(), true), false)
  eq("CanNudge: combat", Levels.CanNudge(known({ inCombat = true }), false), false)
  eq("CanNudge: dead", Levels.CanNudge(known({ dead = true }), false), false)
  eq("CanNudge: off", Levels.CanNudge(known({ enabled = false }), false), false)
end

do
  eq("Wiped: 3 of 5 dead", Levels.Wiped(3, 5), true)
  eq("Wiped: 2 of 5 dead", Levels.Wiped(2, 5), false)
  eq("Wiped: 1 of 2 dead (needs two)", Levels.Wiped(1, 2), false)
  eq("Wiped: 2 of 2 dead", Levels.Wiped(2, 2), true)
end

do
  local log = {}
  eq("ButtonAllowed: first click", Levels.ButtonAllowed(100, log), true)
  log[1] = 100
  eq("  second inside 15 s: cooldown", select(2, Levels.ButtonAllowed(110, log)), "COOLDOWN")
  eq("  after 15 s: ok", Levels.ButtonAllowed(116, log), true)
  log[2], log[3] = 131, 170
  eq("  fourth inside 5 min: cap", select(2, Levels.ButtonAllowed(210, log)), "CAP")
  eq("  once the first ages out: ok", Levels.ButtonAllowed(401, log), true)
  eq("Message fills tokens", Levels.Message("{name} ({class}) is dry", "Sherl", "PRIEST"), "Sherl (PRIEST) is dry")
end

do
  -- Settings from any older version: keep what still exists, drop the rest.
  local old = {
    enabled = false, roleHint = false, combatScope = "me",
    levels = { { enabled = true, pct = 60, color = { 1, 1, 1, 1 }, out = {} }, { pct = 40 }, { pct = 20 } },
    ready = { pct = 95 }, look = { ghost = 40, palette = "water", style = "tint", alpha = 45 },
    frames = { enabled = true, readyTick = true }, meter = { enabled = true }, nudge = true, sound = { enabled = true },
    button = { show = "always", party = false, thirstyMsg = "hi", point = { "CENTER", "CENTER", 1, 2 } },
    zones = { dungeon = true, raid = false, world = true }, minimap = { hide = true, angle = 90 },
  }
  local new = Levels.Migrate(old)
  check("Migrate keeps levels", new.levels[1].pct == 60 and new.levels[3].pct == 20 and new.levels[1].color[1] == 1)
  check("  and drops their old fields", new.levels[1].out == nil and new.levels[1].enabled == nil)
  check("  keeps on/off, role hint, combat scope", new.enabled == false and new.roleHint == false and new.combatScope == "me")
  eq("  keeps the palette", new.palette, "water")
  check("  keeps the drink button", new.button.show == "always" and new.button.party == false and new.button.thirstyMsg == "hi")
  check("  as a copy", new.button ~= old.button and new.button.point ~= old.button.point and new.button.point[3] == 1)
  check("  keeps zones and the minimap button", new.zones.raid == false and new.minimap.hide == true and new.minimap.angle == 90)
  check("  drops looks, motion, meter, sounds, ready",
    new.look == nil and new.frames == nil and new.meter == nil and new.nudge == nil and new.sound == nil and new.ready == nil)
  local bad = Levels.Migrate({ levels = { { pct = 30 }, { pct = 50 }, { pct = 10 } } })
  check("Migrate drops an invalid level order", bad.levels[1] == nil)
end

-- ---------------------------------------------------------------- settings

do
  local s = SoThirstyDB.settings
  eq("defaults: version 4", SoThirstyDB.version, 4)
  check("defaults: 50/30/10", s.levels[1].pct == 50 and s.levels[2].pct == 30 and s.levels[3].pct == 10)
  check("defaults validate", Levels.Validate(s.levels))
  check("defaults: bar, pips, flask and banner on; screen glow off",
    s.bar.enabled and s.pips.enabled and s.flask.enabled and s.banner.enabled and not s.vignette.enabled)
  eq("defaults: banner 5 s after a fight", s.banner.delay, 5)
  check("defaults: the flask always shows, at full opacity", s.flask.whenLow == false and s.flask.alpha == 100)
  check("defaults: the screen glow uses the level colors", s.vignette.custom == false and #s.vignette.color == 4)
  eq("ZoneOk in a dungeon", (ns.ZoneOk()), true)
  zone = "pvp"
  local ok, pvp = ns.ZoneOk()
  check("ZoneOk: battlegrounds are always off", ok == false and pvp == true)
  zone = "raid"
  s.zones.raid = false
  eq("ZoneOk: raids switched off", (ns.ZoneOk()), false)
  s.zones.raid = true
  zone = "party"
end

-- ---------------------------------------------------------------- Roster (spec 5)

local function healerNames()
  local names = {}
  for _, h in pairs(ns.Roster.healers) do names[#names + 1] = h.name end
  table.sort(names)
  return table.concat(names, ",")
end

eq("startup: the healer is tracked", healerNames(), "Sherl")
check("  unit events are on", rosterFrame.events.UNIT_POWER_UPDATE and rosterFrame.events.UNIT_AURA)

units.party2.role = "HEALER"
fire("ROLE_CHANGED_INFORM")
eq("a second healer via Set Role", healerNames(), "Brann,Sherl")
units.party2.role = "DAMAGER"
fire("GROUP_ROSTER_UPDATE")
eq("role cleared: dropped", healerNames(), "Sherl")

units.party1.role = SECRET
fire("GROUP_ROSTER_UPDATE")
eq("a secret role read is skipped", healerNames(), "")
check("  unit events go off with no healer", not rosterFrame.events.UNIT_POWER_UPDATE)
units.party1.role = "HEALER"
fire("GROUP_ROSTER_UPDATE")

do
  local h = ns.Roster.ByUnit("party1")
  local k = ns.Roster.Known(h)
  check("Known: alive, online, watching", k.enabled and k.zoneOk and not k.dead and not k.offline and not k.drinking)
  units.party1.dead = true
  eq("Known: dead", ns.Roster.Known(h).dead, true)
  units.party1.dead, units.party1.offline = nil, true
  eq("Known: offline", ns.Roster.Known(h).offline, true)
  units.party1.offline = nil
  SoThirstyDB.settings.enabled = false
  eq("Known: switched off", ns.Roster.Known(h).enabled, false)
  SoThirstyDB.settings.enabled = true
end

do
  -- Units shift; the GUID keeps its record.
  local before = ns.Roster.ByUnit("party1")
  units.party3, units.party1 = units.party1, nil
  fire("GROUP_ROSTER_UPDATE")
  local after = ns.Roster.ByUnit("party3")
  check("a healer who moves unit keeps their record", after == before and after.unit == "party3")
  units.party1, units.party3 = units.party3, nil
  fire("GROUP_ROSTER_UPDATE")
end

do
  -- Mana and buff events are coalesced into one refresh per healer.
  local updates = {}
  local realUpdate = ns.UpdateHealer
  ns.UpdateHealer = function(h) updates[#updates + 1] = h.name .. (h.drinking and ":drinking" or "") end
  runTimers()
  fire("UNIT_POWER_UPDATE", "party1", "MANA")
  fire("UNIT_POWER_UPDATE", "party1", "MANA")
  fire("UNIT_POWER_UPDATE", "party2", "MANA") -- not a healer
  fire("UNIT_POWER_UPDATE", "party1", "ENERGY")
  eq("power updates wait for the 0.5 s timer", #timers, 1)
  runTimers()
  eq("  one refresh", table.concat(updates, " "), "Sherl")

  updates = {}
  units.party1.drink = true
  fire("UNIT_AURA", "party1")
  runTimers()
  eq("a drink buff marks the healer as drinking", table.concat(updates, " "), "Sherl:drinking")
  updates = {}
  units.party1.drink = nil
  fire("UNIT_AURA", "party1")
  runTimers()
  eq("  and it clears when the buff goes", table.concat(updates, " "), "Sherl")
  ns.UpdateHealer = realUpdate
end

do
  grouped = false
  fire("GROUP_ROSTER_UPDATE")
  eq("solo: nothing tracked", healerNames(), "")
  check("  unit events off", not rosterFrame.events.UNIT_POWER_UPDATE)
  grouped = true
  fire("GROUP_ROSTER_UPDATE")
end

do
  zone = "pvp"
  fire("ZONE_CHANGED_NEW_AREA")
  check("battleground: unit events off", not rosterFrame.events.UNIT_POWER_UPDATE)
  zone = "party"
  fire("ZONE_CHANGED_NEW_AREA")
  check("  back on in a dungeon", rosterFrame.events.UNIT_POWER_UPDATE)
end

do
  raid = true
  units = {
    raid1 = { guid = "Player-1", name = "Tanky", role = "TANK", class = "WARRIOR" },
    raid2 = { guid = "Player-2", name = "Sherl", role = "HEALER", class = "PRIEST" },
  }
  units.player = units.raid1
  fire("GROUP_ROSTER_UPDATE")
  eq("raid: the healer is tracked by raid unit", (ns.Roster.ByUnit("raid2") or {}).name, "Sherl")
  reset()
  fire("GROUP_ROSTER_UPDATE")
end

-- ---------------------------------------------------------------- Combat and the banner (spec 7)

-- The banner is UI; here it just records who Combat asked it to show.
local nudged = {}
ns.Banner = {
  Refresh = function() end, Hide = function() end,
  Show = function(list)
    for _, h in ipairs(list) do nudged[#nudged + 1] = h.name end
  end,
}
local function fight()
  combat = true
  fire("PLAYER_REGEN_DISABLED")
  combat = false
  fire("PLAYER_REGEN_ENABLED")
end

do
  runTimers()
  check("UNIT_FLAGS is watched with a healer in the group", combatFrame.events.UNIT_FLAGS)
  combat = true
  fire("PLAYER_REGEN_DISABLED")
  eq("combat starts", ns.Combat.Is(), true)
  eq("  the healer's known state says so", ns.Roster.Known(ns.Roster.ByUnit("party1")).inCombat, true)
  combat = false
  lastDelay = nil
  fire("PLAYER_REGEN_ENABLED")
  eq("combat ends", ns.Combat.Is(), false)
  eq("  the nudge is 5 s away", lastDelay, 5)
  eq("  nothing yet", #nudged, 0)
  runTimers()
  eq("  then one nudge", table.concat(nudged, " "), "Sherl")
end

do
  nudged = {}
  fight()
  combat = true
  fire("PLAYER_REGEN_DISABLED") -- chain pull before the timer
  runTimers()
  eq("a new fight cancels the nudge", #nudged, 0)
  combat = false
  fire("PLAYER_REGEN_ENABLED")
  runTimers()
  eq("  and the last fight's end nudges once", #nudged, 1)
end

do
  nudged = {}
  units.party1.drink = true
  fight()
  runTimers()
  eq("a drinking healer gets no nudge", #nudged, 0)
  units.party1.drink = nil

  units.player.dead, units.party2.dead = true, true
  fight()
  eq("two of three dead is a wipe", ns.Combat.Wiped(), true)
  runTimers()
  eq("  no nudge after a wipe", #nudged, 0)
  units.player.dead, units.party2.dead = nil, nil

  units.party1.dead = true
  fight()
  runTimers()
  eq("a dead healer gets no nudge", #nudged, 0)
  units.party1.dead = nil

  SoThirstyDB.settings.banner.enabled = false
  lastDelay = nil
  fight()
  eq("banner switched off: no timer", lastDelay, nil)
  SoThirstyDB.settings.banner.enabled = true
  SoThirstyDB.settings.banner.delay = 8
  fight()
  eq("the banner delay setting is used", lastDelay, 8)
  SoThirstyDB.settings.banner.delay = 5
  runTimers()
end

do
  runTimers()
  units.party2.combat = true
  fire("UNIT_FLAGS", "party2")
  runTimers()
  eq("someone else fighting counts as combat", ns.Combat.Is(), true)
  units.party2.combat = nil
  runTimers()
  eq("  and it clears when they're done", ns.Combat.Is(), false)
  runTimers()

  SoThirstyDB.settings.combatScope = "me"
  ns.Roster.Refresh()
  check("combat scope \"me\": UNIT_FLAGS not watched", not combatFrame.events.UNIT_FLAGS)
  units.party2.combat = true
  ns.Combat.Check()
  eq("  and others' fights don't count", ns.Combat.Is(), false)
  units.party2.combat = nil
  SoThirstyDB.settings.combatScope = "group"
  ns.Roster.Refresh()
  runTimers()
end

-- ---------------------------------------------------------------- the drink button (spec 8.2)

do
  local Button = ns.Button
  sent, printed = {}, {}
  eq("a click posts one line", Button.Say("thirsty"), true)
  eq("  to party chat, with the tag", sent[1], "PARTY: [Thirsty] Tanky needs a drink - hold the pull")
  eq("a second click inside 15 s is refused", Button.Say("thirsty"), false)
  eq("  nothing more sent", #sent, 1)
  check("  and it says why", (printed[#printed] or ""):find("15 seconds") ~= nil)
  clock = clock + 31
  eq("after the cooldown: ready line", Button.Say("ready"), true)
  eq("  the ready text", sent[2], "PARTY: [Thirsty] Tanky is good to go")
  clock = clock + 31
  eq("third line", Button.Say("thirsty"), true)
  clock = clock + 31
  eq("fourth inside 5 minutes hits the cap", Button.Say("thirsty"), false)
  eq("  three sent in all", #sent, 3)
  clock = clock + 300
  eq("after 5 minutes it works again", Button.Say("thirsty"), true)

  clock = clock + 400
  combat = true
  fire("PLAYER_REGEN_DISABLED")
  eq("never in combat", Button.Say("thirsty"), false)
  combat = false
  fire("PLAYER_REGEN_ENABLED")
  runTimers()

  zone = "pvp"
  eq("never in a battleground", Button.Say("thirsty"), false)
  zone = "party"

  SoThirstyDB.settings.button.party = false
  eq("party chat unchecked: refused", Button.Say("thirsty"), false)
  SoThirstyDB.settings.button.party = true

  grouped = false
  eq("solo: refused", Button.Say("thirsty"), false)
  grouped = true

  raid = true
  sent = {}
  eq("in a raid", Button.Say("thirsty"), true)
  check("  it goes to raid chat", (sent[1] or ""):find("^RAID: ") ~= nil, sent[1])
  raid = false

  SoThirstyDB.settings.button.prefix = false
  SoThirstyDB.settings.button.thirstyMsg = "{name} is parched"
  eq("a custom line, no tag", Button.Line("thirsty"), "Tanky is parched")
  SoThirstyDB.settings.button.prefix = true
  SoThirstyDB.settings.button.thirstyMsg = nil
end

-- ---------------------------------------------------------------- slash commands

do
  printed = {}
  local s = SoThirstyDB.settings
  ns.RunCommand("levels 60 40 20")
  local lv = s.levels
  check("/sot levels 60 40 20", lv[1].pct == 60 and lv[2].pct == 40 and lv[3].pct == 20)
  ns.RunCommand("levels 30 50 10")
  check("/sot levels 30 50 10 is rejected", lv[1].pct == 60 and printed[#printed]:find("lower than"))
  ns.RunCommand("levels 50 30 0")
  check("/sot levels with a 0 is rejected", lv[1].pct == 60 and printed[#printed]:find("1 to 99"))
  ns.RunCommand("levels 50 30 10")
  ns.RunCommand("off")
  check("/sot off", s.enabled == false and not rosterFrame.events.UNIT_POWER_UPDATE)
  ns.RunCommand("on")
  check("/sot on", s.enabled == true and rosterFrame.events.UNIT_POWER_UPDATE)
  printed = {}
  ns.RunCommand("status")
  check("/sot status lists the healer", (printed[2] or ""):find("Sherl") ~= nil, printed[2])
  printed = {}
  ns.RunCommand("")
  check("/sot with no options window prints status", (printed[2] or ""):find("Sherl") ~= nil, printed[2])

  for command, key in pairs({ bar = "bar", pips = "pips", flask = "flask", banner = "banner", glow = "vignette" }) do
    local before = s[key].enabled
    ns.RunCommand(command)
    eq("/sot " .. command .. " flips the indicator", s[key].enabled, not before)
    ns.RunCommand(command)
    eq("  and back", s[key].enabled, before)
  end

  ns.RunCommand("move")
  eq("/sot move starts placing", ns.unlocked, true)
  ns.RunCommand("lock")
  eq("/sot lock ends it", ns.unlocked, false)
  ns.RunCommand("ghost 40")
  eq("/sot ghost 40", s.ghost, 40)
  ns.RunCommand("ghost 200")
  eq("/sot ghost 200 is rejected", s.ghost, 40)
  ns.RunCommand("bogus")
  check("an unknown command says so", printed[#printed]:find("Unknown command") ~= nil)
  check("Theme.ApplyPalette water", ns.Theme.ApplyPalette(s, "water") and s.palette == "water")
  eq("  level 3 turns violet", s.levels[3].color[3], 0.97)
  eq("Theme.ApplyPalette with a bad name does nothing", ns.Theme.ApplyPalette(s, "nope"), false)
end

-- ---------------------------------------------------------------- Save / Revert helpers

do
  local s = SoThirstyDB.settings
  local copy = ns.DeepCopy(s)
  check("DeepCopy makes new tables", copy ~= s and copy.levels ~= s.levels and copy.levels[1].color ~= s.levels[1].color)
  eq("DeepEqual: a copy matches", ns.DeepEqual(copy, s), true)
  copy.levels[2].color[2] = 0.123
  eq("DeepEqual: a nested change is seen", ns.DeepEqual(copy, s), false)
  copy = ns.DeepCopy(s)
  copy.button.thirstyMsg = "x"
  eq("DeepEqual: an added key is seen", ns.DeepEqual(copy, s), false)
  eq("  from either side", ns.DeepEqual(s, copy), false)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
