-- Pure logic (spec 6.2): curve points, visibility decisions, drink-button caps.
-- No WoW API in this file. Numbers, booleans and tables in; plain values out.
-- The addon never knows a healer's mana: Curves.lua hands these points to the game, and
-- the game applies them to the hidden value.
local _, ns = ...

local Levels = {}
ns.Levels = Levels

Levels.COOLDOWN = 30     -- seconds between drink-button lines
Levels.CAP = 3           -- lines per CAP_WINDOW
Levels.CAP_WINDOW = 300
local EPS = 0.001        -- how close two curve points sit to make a hard edge

local function blend(a, b, t)
  return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- Thresholds strictly descending, 1-99; Ready (optional) above level 1.
function Levels.Validate(levels, ready)
  for _, lv in ipairs(levels) do
    local p = lv.pct
    if type(p) ~= "number" or p < 1 or p > 99 or p ~= math.floor(p) then return false, "RANGE" end
  end
  local last = 100
  for _, lv in ipairs(levels) do
    if lv.pct >= last then return false, "ORDER" end
    last = lv.pct
  end
  if ready then
    local r = ready.pct
    if type(r) ~= "number" or r < 1 or r > 100 then return false, "RANGE" end
    if r <= levels[1].pct then return false, "READY" end
  end
  return true
end

-- The smooth thirst color at a mana percent (0-100): level 3's color at and below level 3,
-- blending up through level 2 to level 1's color.
function Levels.ColorAt(pct, cfg)
  local lv = cfg.levels
  local p1, p2, p3 = lv[1].pct, lv[2].pct, lv[3].pct
  local c1, c2, c3 = lv[1].color, lv[2].color, lv[3].color
  if pct <= p3 then return c3[1], c3[2], c3[3] end
  if pct <= p2 then return blend(c3, c2, (pct - p3) / (p2 - p3)) end
  if pct <= p1 then return blend(c2, c1, (pct - p2) / (p1 - p2)) end
  return c1[1], c1[2], c1[3]
end

-- The color actually shown at a percent: in "steps" mode each 10% band is one flat color.
function Levels.ColorShown(pct, cfg)
  if cfg.look.bands == "steps" then
    return Levels.ColorAt(math.floor(pct / 10) * 10 + 5, cfg)
  end
  return Levels.ColorAt(pct, cfg)
end

-- The glow's own opacity (0-1) at a percent: 0 at and above level 1.
function Levels.AlphaAt(pct, cfg)
  local lv, look = cfg.levels, cfg.look
  local p1, p3 = lv[1].pct, lv[3].pct
  local full = look.alpha / 100
  if pct >= p1 then return 0 end
  if not look.strength or pct <= p3 then return full end
  local faint = full * look.faint / 100
  return full + (faint - full) * (pct - p3) / (p1 - p3)
end

-- Color curve points on the 0-1 scale: { type, points = { { x, r, g, b }, ... } }.
-- `fine` (optional) is the color above level 1, for the thirst meter.
function Levels.ColorPoints(cfg, fine)
  local lv = cfg.levels
  local p1 = lv[1].pct
  local points = {}
  local kind
  if cfg.look.bands == "steps" then
    kind = "step"
    for band = 0, p1 - 1, 10 do
      points[#points + 1] = { band / 100, Levels.ColorAt(band + 5, cfg) }
    end
    if fine then points[#points + 1] = { p1 / 100, fine[1], fine[2], fine[3] } end
  else
    kind = "linear"
    points[1] = { 0, Levels.ColorAt(0, cfg) }
    for i = 3, 1, -1 do
      local c = lv[i].color
      points[#points + 1] = { lv[i].pct / 100, c[1], c[2], c[3] }
    end
    if fine then points[#points + 1] = { p1 / 100 + EPS, fine[1], fine[2], fine[3] } end
  end
  return { type = kind, points = points }
end

-- Strength curve: { type, points = { { x, alpha }, ... } }.
function Levels.AlphaPoints(cfg)
  local lv, look = cfg.levels, cfg.look
  local p1, p3 = lv[1].pct / 100, lv[3].pct / 100
  local full = look.alpha / 100
  if not look.strength then
    return { type = "step", points = { { 0, full }, { p1, 0 } } }
  end
  local faint = full * look.faint / 100
  return { type = "linear", points = { { 0, full }, { p3, full }, { p1 - EPS, faint }, { p1, 0 } } }
end

-- 1 below level 3, 0 at and above.
function Levels.PulsePoints(cfg)
  return { type = "step", points = { { 0, 1 }, { cfg.levels[3].pct / 100, 0 } } }
end

-- 0 below Ready, 1 at and above.
function Levels.ReadyPoints(cfg)
  return { type = "step", points = { { 0, 0 }, { cfg.ready.pct / 100, 1 } } }
end

-- The known-state half of visibility for one healer. Returns alpha (0-1), grey, drinking.
-- known = { enabled, zoneOk, inCombat, dead, offline, drinking }
function Levels.Holder(known, cfg)
  local look = cfg.look
  if not known.enabled or not known.zoneOk then return 0, false, false end
  if known.dead or known.offline then return 0, true, false end
  if known.inCombat then return look.combat == "faint" and 0.15 or 0, false, false end
  if known.drinking then return look.drinkDim / 100, false, true end
  return look.rest / 100, false, false
end

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

-- Design v1 settings -> the parts v2 keeps (spec 12.1). Defaults fill in the rest.
function Levels.Migrate(old)
  local new = { enabled = old.enabled, roleHint = old.roleHint, levels = {}, look = {} }
  if type(old.levels) == "table" then
    for i = 1, 3 do
      local lv = old.levels[i]
      if type(lv) == "table" and type(lv.pct) == "number" then new.levels[i] = { pct = lv.pct, color = lv.color } end
    end
    if not (new.levels[1] and new.levels[2] and new.levels[3] and Levels.Validate(new.levels)) then new.levels = {} end
  end
  if type(old.ready) == "table" and type(old.ready.pct) == "number" then
    new.ready = { pct = old.ready.pct, color = old.ready.color }
    local first = new.levels[1] and new.levels[1].pct or 50 -- 50 is the default level 1
    if new.ready.pct <= first or new.ready.pct > 100 then new.ready = nil end
  end
  if type(old.look) == "table" then
    new.look.ghost = old.look.ghost
    new.look.palette = old.look.palette
  end
  return new
end
