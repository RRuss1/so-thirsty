-- Pure logic (spec 6.2): curve points, visibility decisions, drink-button caps.
-- No WoW API in this file. Numbers, booleans and tables in; plain values out.
-- The addon never knows a healer's mana: Curves.lua hands these points to the game, and
-- the game applies them to the hidden value.
local _, ns = ...

local Levels = {}
ns.Levels = Levels

Levels.COOLDOWN = 15     -- seconds between drink-button lines
Levels.CAP = 3           -- lines per CAP_WINDOW
Levels.CAP_WINDOW = 300
Levels.DRINK_DIM = 0.35  -- a drinking healer's indicators dim to this
Levels.FAINT = 0.35      -- how visible the fading indicators are just under level 1
Levels.FINE = { 0.31, 0.76, 0.97 } -- water blue: the color above level 1
local EPS = 0.001        -- how close two curve points sit to make a hard edge

local function blend(a, b, t)
  return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- Thresholds strictly descending, whole numbers from 1 to 99.
function Levels.Validate(levels)
  for _, lv in ipairs(levels) do
    local p = lv.pct
    if type(p) ~= "number" or p < 1 or p > 99 or p ~= math.floor(p) then return false, "RANGE" end
  end
  local last = 100
  for _, lv in ipairs(levels) do
    if lv.pct >= last then return false, "ORDER" end
    last = lv.pct
  end
  return true
end

-- The thirst color at a mana percent (0-100): level 3's color at and below level 3,
-- blending up through level 2 to level 1's color; water blue above level 1.
function Levels.ColorAt(pct, cfg)
  local lv = cfg.levels
  local p1, p2, p3 = lv[1].pct, lv[2].pct, lv[3].pct
  local c1, c2, c3 = lv[1].color, lv[2].color, lv[3].color
  if pct <= p3 then return c3[1], c3[2], c3[3] end
  if pct <= p2 then return blend(c3, c2, (pct - p3) / (p2 - p3)) end
  if pct <= p1 then return blend(c2, c1, (pct - p2) / (p1 - p2)) end
  return Levels.FINE[1], Levels.FINE[2], Levels.FINE[3]
end

-- How visible the fading indicators (flask, screen glow) are at a percent: 0 at and above
-- level 1, FAINT just under it, rising to 1 at level 3 and below.
function Levels.AlphaAt(pct, cfg)
  local p1, p3 = cfg.levels[1].pct, cfg.levels[3].pct
  if pct >= p1 then return 0 end
  if pct <= p3 then return 1 end
  return 1 + (Levels.FAINT - 1) * (pct - p3) / (p1 - p3)
end

-- How many pips are lit at a percent (0-3).
function Levels.PipsLit(pct, cfg)
  local lit = 0
  for i = 1, 3 do
    if pct < cfg.levels[i].pct then lit = i end
  end
  return lit
end

-- Everything an indicator needs for a plain (not secret) percent: the previews use this.
-- Returns fraction, r, g, b, alpha, low, pip1, pip2, pip3.
function Levels.Plain(pct, cfg)
  local r, g, b = Levels.ColorAt(pct, cfg)
  local lit = Levels.PipsLit(pct, cfg)
  return pct / 100, r, g, b, Levels.AlphaAt(pct, cfg), lit >= 1 and 1 or 0,
    lit >= 1 and 1 or 0, lit >= 2 and 1 or 0, lit >= 3 and 1 or 0
end

-- Curve points are on the 0-1 scale: { type = "linear" | "step", points = { ... } }.

-- Color: { x, r, g, b }. Level colors below level 1, water blue just above it.
function Levels.ColorPoints(cfg)
  local lv = cfg.levels
  local points = { { 0, Levels.ColorAt(0, cfg) } }
  for i = 3, 1, -1 do
    local c = lv[i].color
    points[#points + 1] = { lv[i].pct / 100, c[1], c[2], c[3] }
  end
  points[#points + 1] = { lv[1].pct / 100 + EPS, Levels.FINE[1], Levels.FINE[2], Levels.FINE[3] }
  return { type = "linear", points = points }
end

-- Fade: { x, alpha }. Matches AlphaAt.
function Levels.AlphaPoints(cfg)
  local p1, p3 = cfg.levels[1].pct / 100, cfg.levels[3].pct / 100
  return { type = "linear", points = { { 0, 1 }, { p3, 1 }, { p1 - EPS, Levels.FAINT }, { p1, 0 } } }
end

-- 1 below level 1, 0 at and above: solid on/off for the bar color and the banner text.
function Levels.LowPoints(cfg)
  return { type = "step", points = { { 0, 1 }, { cfg.levels[1].pct / 100, 0 } } }
end

-- Pip i: 1 below level i, 0 at and above.
function Levels.PipPoints(cfg, i)
  return { type = "step", points = { { 0, 1 }, { cfg.levels[i].pct / 100, 0 } } }
end

-- The known-state half of visibility for one healer. Returns alpha (0-1) and drinking.
-- known = { enabled, zoneOk, inCombat, dead, offline, drinking }
function Levels.Holder(known)
  if not known.enabled or not known.zoneOk then return 0, false end
  if known.dead or known.offline or known.inCombat then return 0, false end
  if known.drinking then return Levels.DRINK_DIM, true end
  return 1, false
end

-- May this healer appear on the after-fight banner?
function Levels.CanNudge(known, wiped)
  if wiped or not known.enabled or not known.zoneOk then return false end
  if known.inCombat or known.dead or known.offline or known.drinking then return false end
  return true
end

-- A wipe: at least half the group (and at least two players) dead when combat ends.
function Levels.Wiped(dead, total)
  return dead >= 2 and dead * 2 >= total
end

-- May the drink button post a line now? `log` lists this session's send times.
function Levels.ButtonAllowed(now, log)
  local recent, last = 0, nil
  for _, t in ipairs(log) do
    if now - t < Levels.CAP_WINDOW then recent = recent + 1 end
    if not last or t > last then last = t end
  end
  if last and now - last < Levels.COOLDOWN then return false, "COOLDOWN" end
  if recent >= Levels.CAP then return false, "CAP" end
  return true
end

-- Fills {name} and {class} in a chat line.
function Levels.Message(template, name, class)
  local fill = { name = name or "", class = class or "" }
  return (template:gsub("{(%a+)}", function(token) return fill[token] end))
end

local function copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = copy(v) end
  return out
end

-- Older settings (v1-v3) -> the parts v4 keeps (spec 12.1). Defaults fill in the rest.
-- Kept: on/off, levels and colors, palette, the drink button, zones, combat scope, role
-- hint, minimap button. Dropped: every old look, motion, meter and sound setting.
function Levels.Migrate(old)
  local new = { enabled = old.enabled, roleHint = old.roleHint, combatScope = old.combatScope, levels = {} }
  if type(old.levels) == "table" then
    for i = 1, 3 do
      local lv = old.levels[i]
      if type(lv) == "table" and type(lv.pct) == "number" then new.levels[i] = { pct = lv.pct, color = copy(lv.color) } end
    end
    if not (new.levels[1] and new.levels[2] and new.levels[3] and Levels.Validate(new.levels)) then new.levels = {} end
  end
  if type(old.look) == "table" then new.palette = old.look.palette end
  for _, key in ipairs({ "button", "zones", "minimap" }) do
    if type(old[key]) == "table" then new[key] = copy(old[key]) end
  end
  return new
end
