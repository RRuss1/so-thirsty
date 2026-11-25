-- Turns Levels' point lists into the game's curve objects, and asks the game to run a
-- healer's hidden mana through them (spec Section 2, 16 Q18-Q19). The results are secret:
-- they may only be handed to SetVertexColor / SetAlpha / SetValue. Never compared, never
-- stored, never used in math.
local _, ns = ...

local Curves = {}
ns.Curves = Curves

local built = {}  -- color, meter, alpha, pulse, ready
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
  for _, p in ipairs(spec.points) do
    if isColor then
      curve:AddPoint(p[1], createColor(p[2], p[3], p[4], 1))
    else
      curve:AddPoint(p[1], p[2])
    end
  end
  return curve
end

-- Rebuilds every curve from the settings. Called at load and when a setting changes.
function Curves.Rebuild()
  for k in pairs(built) do built[k] = nil end
  Curves.error = nil
  if not Curves.Available() then return end
  local cfg = ns.Settings()
  local Levels = ns.Levels
  local ok, err = pcall(function()
    built.color = build(Levels.ColorPoints(cfg), true)
    built.meter = build(Levels.ColorPoints(cfg, ns.COLORS and ns.COLORS.water or { 0.31, 0.76, 0.97 }), true)
    built.alpha = build(Levels.AlphaPoints(cfg), false)
    built.pulse = build(Levels.PulsePoints(cfg), false)
    built.ready = build(Levels.ReadyPoints(cfg), false)
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

-- The thirst color for a unit's mana. Returns ok, then secret r, g, b. Test only `ok`.
-- which: "color" (frames) or "meter" (water blue above level 1).
function Curves.Color(unit, which)
  local curve = built[which or "color"]
  if not curve then return false end
  return pcall(colorOf, unit, curve)
end

-- Returns ok, then a secret number for a unit's mana. which: "alpha" | "pulse" | "ready".
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
