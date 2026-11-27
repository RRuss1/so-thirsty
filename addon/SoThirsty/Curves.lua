-- Turns Levels' point lists into the game's curve objects, and asks the game to run a
-- healer's hidden mana through them (spec Section 2, 16 Q18-Q19). The results are secret:
-- they may only be handed to SetVertexColor / SetAlpha / SetValue. Never compared, never
-- stored, never used in math. Every getter returns an `ok` flag first: test only that.
local _, ns = ...

local Curves = {}
ns.Curves = Curves

local built = {}  -- color, alpha, low, pip1, pip2, pip3
local unitPct = _G.UnitPowerPercent
local createColor = _G.CreateColor

local function manaType()
  return Enum and Enum.PowerType and Enum.PowerType.Mana or 0
end

function Curves.Available()
  return C_CurveUtil ~= nil and C_CurveUtil.CreateCurve ~= nil and C_CurveUtil.CreateColorCurve ~= nil
    and unitPct ~= nil and createColor ~= nil and Enum.LuaCurveType ~= nil
end

local function build(spec, isColor)
  local curve = isColor and C_CurveUtil.CreateColorCurve() or C_CurveUtil.CreateCurve()
  curve:SetType(spec.type == "step" and Enum.LuaCurveType.Step or Enum.LuaCurveType.Linear)
  local function add(x, p)
    if isColor then
      curve:AddPoint(x, createColor(p[2], p[3], p[4], 1))
    else
      curve:AddPoint(x, p[2])
    end
  end
  for _, p in ipairs(spec.points) do add(p[1], p) end
  -- Hold the last value up to full mana, so nothing depends on how the game treats
  -- inputs past a curve's last point.
  local last = spec.points[#spec.points]
  if last[1] < 1 then add(1, last) end
  return curve
end

-- Rebuilds every curve from the settings. Called at load and when a level or color changes.
function Curves.Rebuild()
  for k in pairs(built) do built[k] = nil end
  if Curves.ForgetClasses then Curves.ForgetClasses() end
  Curves.error = nil
  if not Curves.Available() then return end
  local cfg = ns.Settings()
  local Levels = ns.Levels
  local ok, err = pcall(function()
    built.color = build(Levels.ColorPoints(cfg), true)
    built.alpha = build(Levels.AlphaPoints(cfg), false)
    built.low = build(Levels.LowPoints(cfg), false)
    for i = 1, 3 do built["pip" .. i] = build(Levels.PipPoints(cfg, i), false) end
  end)
  if not ok then
    for k in pairs(built) do built[k] = nil end
    Curves.error = tostring(err)
  end
end

local function colorOf(unit, curve)
  local color = unitPct(unit, manaType(), false, curve)
  return color:GetRGB()
end

-- Returns ok, then secret r, g, b: the thirst color for a unit's mana.
function Curves.Color(unit)
  local curve = built.color
  if not curve then return false end
  return pcall(colorOf, unit, curve)
end

-- Returns ok, then a secret number. which: "alpha" | "low" | "pip1" | "pip2" | "pip3".
function Curves.Value(unit, which)
  local curve = built[which]
  if not curve then return false end
  return pcall(unitPct, unit, manaType(), false, curve)
end

-- Returns ok, then the unit's mana as a secret 0-1 fraction, for a status bar.
function Curves.Fraction(unit)
  local scale = _G.CurveConstants and _G.CurveConstants.ZeroToOne
  if not unitPct or not scale then return false end
  return pcall(unitPct, unit, manaType(), false, scale)
end

-- Returns ok, then the unit's mana as a secret 0-100 number, only ever for the game to
-- print (the banner's "mana is at x%", spec 16 Q28). The addon never learns it.
function Curves.Percent(unit)
  local scale = _G.CurveConstants and _G.CurveConstants.ScaleTo100
  if not unitPct or not scale then return false end
  return pcall(unitPct, unit, manaType(), false, scale)
end

-- Everything an indicator needs for one unit, in the same order as Levels.Plain:
-- ok, fraction, r, g, b, alpha, low, pip1, pip2, pip3. All secret except ok.
function Curves.All(unit)
  local okF, fraction = Curves.Fraction(unit)
  local okC, r, g, b = Curves.Color(unit)
  local okA, alpha = Curves.Value(unit, "alpha")
  local okL, low = Curves.Value(unit, "low")
  local ok1, p1 = Curves.Value(unit, "pip1")
  local ok2, p2 = Curves.Value(unit, "pip2")
  local ok3, p3 = Curves.Value(unit, "pip3")
  if not (okF and okC and okA and okL and ok1 and ok2 and ok3) then return false end
  return true, fraction, r, g, b, alpha, low, p1, p2, p3
end

-- The same color curve, but ending in a class color above level 1 (the flask edge: class
-- color while the healer is fine, level colors as they run dry). One curve per class,
-- built on first use and dropped by Rebuild. Returns ok, then secret r, g, b.
local byClass = {}
function Curves.ClassColor(unit, class, color)
  if not built.color then return false end
  local curve = byClass[class]
  if not curve then
    local ok, made = pcall(build, ns.Levels.ColorPoints(ns.Settings(), { color.r, color.g, color.b }), true)
    if not ok then return false end
    curve = made
    byClass[class] = curve
  end
  return pcall(colorOf, unit, curve)
end

function Curves.ForgetClasses()
  for k in pairs(byClass) do byClass[k] = nil end
end
