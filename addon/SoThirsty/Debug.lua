-- /sot debug: prints what the client tells the addon, to settle the open questions in
-- spec Section 16 (roles, mana and combat flags as secret values, chat channel, auras).
local _, ns = ...
local L = ns.L

local function show(v)
  if ns.IsSecret(v) then return "|cffff6060<secret>|r" end
  if v == nil then return "nil" end
  return tostring(v)
end

local function line(label, ...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = show((select(i, ...))) end
  DEFAULT_CHAT_FRAME:AddMessage(("  |cff4fc3f7%s|r %s"):format(label, table.concat(parts, " | ")))
end

local function manaType()
  return Enum and Enum.PowerType and Enum.PowerType.Mana
end

local function describeUnit(unit)
  if not UnitExists(unit) then return end
  DEFAULT_CHAT_FRAME:AddMessage(("|cff4fc3f7[%s]|r %s"):format(unit, show(UnitName(unit))))
  line("GUID", UnitGUID(unit))
  line("role (UnitGroupRolesAssigned)", UnitGroupRolesAssigned(unit))
  local mt = manaType() or 0
  line("mana raw / max", UnitPower(unit, mt), UnitPowerMax(unit, mt))
  line("primary power type / raw", UnitPowerType(unit), UnitPower(unit))
  line("dead / connected", UnitIsDeadOrGhost(unit), UnitIsConnected(unit))
  line("in combat (UnitAffectingCombat)", UnitAffectingCombat(unit))
  line("in range (UnitInRange)", UnitInRange and UnitInRange(unit))
  local _, class = UnitClass(unit)
  line("class", class)
end

function ns.Debug()
  ns.Print(L.DEBUG_HEADER)
  local version, build, buildDate, toc = GetBuildInfo()
  line("client", version, build, buildDate, toc)
  line("WOW_PROJECT_ID", WOW_PROJECT_ID)
  line("issecretvalue API", issecretvalue ~= nil)
  line("C_UnitAuras.GetAuraDataByIndex", C_UnitAuras ~= nil and C_UnitAuras.GetAuraDataByIndex ~= nil)
  line("Enum.PowerType.Mana", manaType())
  line("IsInGroup / IsInRaid", IsInGroup(), IsInRaid())
  local instanceCat = LE_PARTY_CATEGORY_INSTANCE
  line("instance group (LE_PARTY_CATEGORY_INSTANCE)", instanceCat, instanceCat and IsInGroup(instanceCat))
  line("IsInInstance", IsInInstance())
  line("chat channel picked", ns.ChatChannel())
  line("InCombatLockdown / player in combat", InCombatLockdown(), UnitAffectingCombat("player"))
  line("leader", UnitIsGroupLeader("player"))
  line("healers tracked", ns.Roster.Count())
  local units = ns.Roster.GroupUnits()
  if not units then return describeUnit("player") end
  for _, unit in ipairs(units) do describeUnit(unit) end
end

-- /sot debug drink: each healer's buffs and the drink verdict now, then the mana change
-- 10 seconds later (spec 16 Q11, Q12).
function ns.DebugDrink()
  ns.Print(L.DEBUG_DRINK_HEADER)
  ns.Roster.Scan()
  if ns.Roster.Count() == 0 then return ns.Print(L.DEBUG_DRINK_NONE) end
  local start = {}
  for guid, h in pairs(ns.Roster.healers) do
    DEFAULT_CHAT_FRAME:AddMessage(("|cff4fc3f7[%s]|r %s"):format(h.unit, show(h.name)))
    for i, a in ipairs(ns.Drink.List(h.unit)) do line("buff " .. i, a.name, a.spellId) end
    line("drink buff match", ns.Drink.AuraMatch(h.unit))
    local pct, why = ns.Roster.Read(h)
    line("mana % now", pct or why)
    start[guid] = pct
  end
  C_Timer.After(10, function()
    ns.Print("debug drink, 10 seconds later:")
    for guid, h in pairs(ns.Roster.healers) do
      local pct, why = ns.Roster.Read(h)
      local before = start[guid]
      local rise = (pct and before) and (pct - before) or nil
      local drinking = ns.Levels.IsDrinking(ns.Drink.AuraMatch(h.unit), before, pct, ns.Settings())
      line(show(h.name), "now " .. tostring(pct or why), "change " .. tostring(rise), "counts as drinking: " .. tostring(drinking))
    end
  end)
end

-- /sot debug mana: tries every official way to read mana, since plain UnitPower came back
-- secret even out of combat (spec 16 Q2, Q17). Read-only: it never works around a secret.
local function try(label, fn, ...)
  if not fn then return line(label, "missing") end
  local ok, a, b = pcall(fn, ...)
  if not ok then return line(label, "error: " .. tostring(a)) end
  line(label, a, b)
end

-- Global names that hint at secret-value helpers (issecretvalue, canaccessvalue, C_Secrets...).
local function secretGlobals()
  local found = {}
  for k in pairs(_G) do
    if type(k) == "string" and (k:find("[Ss]ecret") or k:find("Restrict") or k:find("Curve")) then
      found[#found + 1] = k
    end
  end
  table.sort(found)
  return found
end

local function probeUnit(unit, mt)
  if not UnitExists(unit) then return end
  DEFAULT_CHAT_FRAME:AddMessage(("|cff4fc3f7[%s]|r %s"):format(unit, show(UnitName(unit))))
  try("UnitPower(u)", UnitPower, unit)
  try("UnitPower(u, mana)", UnitPower, unit, mt)
  try("UnitPower(u, mana, true)", UnitPower, unit, mt, true)
  try("UnitPowerMax(u, mana)", UnitPowerMax, unit, mt)
  try("UnitPowerPercent(u, mana)", _G.UnitPowerPercent, unit, mt)
  try("UnitHealth / Max (compare)", function() return UnitHealth(unit), UnitHealthMax(unit) end)
  local secrets = _G.C_Secrets
  if type(secrets) == "table" then
    for name, fn in pairs(secrets) do
      if type(fn) == "function" and name:find("Power") then try("C_Secrets." .. name, fn, unit, mt) end
    end
  end
end

-- Can a status bar take a secret mana value? If yes, a mana display can still work even
-- when the addon can't read the number itself.
local function probeBar(mt)
  local bar = CreateFrame("StatusBar")
  local okMax = pcall(bar.SetMinMaxValues, bar, 0, 1)
  local okSet, err = pcall(bar.SetValue, bar, UnitPower("player", mt))
  line("StatusBar accepts secret mana", okMax and okSet or ("no: " .. tostring(err)))
  if okSet then line("StatusBar:GetValue()", bar:GetValue()) end
end

function ns.DebugMana()
  ns.Print(L.DEBUG_MANA_HEADER)
  local mt = manaType() or 0
  line("InCombatLockdown / instance", InCombatLockdown(), (IsInInstance()))
  local names = secretGlobals()
  line("secret-related globals", #names > 0 and table.concat(names, ", ") or "none")
  local units = ns.Roster.GroupUnits() or { "player" }
  for _, unit in ipairs(units) do probeUnit(unit, mt) end
  probeBar(mt)
end

-- /sot debug curve: mana is always secret (spec 16 Q17), so can a curve turn it into a color
-- or an alpha that our own textures accept, without the addon ever learning the number?
-- This is the sanctioned Midnight path (spec 16 Q18). Every call is guarded.
local function keys(t)
  if type(t) ~= "table" then return "missing" end
  local out = {}
  for k, v in pairs(t) do
    local tv = type(v)
    out[#out + 1] = tostring(k) .. ((tv ~= "function" and tv ~= "table") and ("=" .. tostring(v)) or "")
  end
  table.sort(out)
  return #out > 0 and table.concat(out, ", ") or "empty"
end

local function methods(obj)
  local ok, mt = pcall(getmetatable, obj)
  if not ok or type(mt) ~= "table" then return "hidden" end
  return keys(type(mt.__index) == "table" and mt.__index or mt)
end

local function curveResult(label, mt, curve)
  local ok, v = pcall(_G.UnitPowerPercent, "player", mt, false, curve)
  if not ok then return line(label, "error: " .. tostring(v)) end
  line(label, v, "secret: " .. tostring(ns.IsSecret(v)))
  return v
end

local function probeCurve(cu, mt, tex)
  local ok, curve = pcall(cu.CreateCurve)
  line("C_CurveUtil.CreateCurve", ok and "ok" or ("error: " .. tostring(curve)))
  if not ok or not curve then return end
  line("curve methods", methods(curve))
  local step = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
  if step then try("curve:SetType(Step)", curve.SetType, curve, step) end
  -- 1 (show) below 50% mana, 0 (hide) at or above; tried on both 0-1 and 0-100 scales.
  try("curve:AddPoint(0, 1)", curve.AddPoint, curve, 0, 1)
  try("curve:AddPoint(0.5, 0)", curve.AddPoint, curve, 0.5, 0)
  try("curve:AddPoint(50, 0)", curve.AddPoint, curve, 50, 0)
  local okP, pct = pcall(_G.UnitPowerPercent, "player", mt)
  if okP then try("curve:Evaluate(mana %)", curve.Evaluate, curve, pct) end
  local a = curveResult("UnitPowerPercent(player, mana, false, curve)", mt, curve)
  if a ~= nil then line("Texture:SetAlpha(curve result)", (pcall(tex.SetAlpha, tex, a))) end
end

local function probeColorCurve(cu, mt, tex)
  if not cu.CreateColorCurve then return line("C_CurveUtil.CreateColorCurve", "missing") end
  local ok, cc = pcall(cu.CreateColorCurve)
  line("C_CurveUtil.CreateColorCurve", ok and "ok" or ("error: " .. tostring(cc)))
  if not ok or not cc or not _G.CreateColor then return end
  line("color curve methods", methods(cc))
  try("colorCurve:AddPoint(0, red)", cc.AddPoint, cc, 0, _G.CreateColor(1, 0.25, 0.25, 1))
  try("colorCurve:AddPoint(0.5, blue)", cc.AddPoint, cc, 0.5, _G.CreateColor(0.31, 0.76, 0.97, 1))
  local col = curveResult("UnitPowerPercent(player, mana, false, colorCurve)", mt, cc)
  if col == nil then return end
  local okR, r, g, b = pcall(function() return col:GetRGB() end)
  line("color:GetRGB()", okR and r or ("error: " .. tostring(r)))
  if okR then line("Texture:SetVertexColor(secret rgb)", (pcall(tex.SetVertexColor, tex, r, g, b))) end
end

function ns.DebugCurve()
  ns.Print(L.DEBUG_CURVE_HEADER)
  local mt = manaType() or 0
  local cu = _G.C_CurveUtil
  line("C_CurveUtil", keys(cu))
  line("CurveConstants", keys(_G.CurveConstants))
  line("Enum.LuaCurveType", keys(Enum and Enum.LuaCurveType))
  local tex = UIParent:CreateTexture()
  line("Texture has SetAlphaFromBoolean / SetVertexColorFromBoolean",
    tex.SetAlphaFromBoolean ~= nil, tex.SetVertexColorFromBoolean ~= nil)
  if type(cu) ~= "table" then return end
  probeCurve(cu, mt, tex)
  probeColorCurve(cu, mt, tex)
  tex:Hide()
end

-- /sot debug swatch: a live preview of your own mana through curves (spec 16 Q19). The addon
-- never sees the number; the game evaluates the curves. Spend mana and watch:
--   color square: green at full, yellow at half, red at empty (moves only on a 0-1 scale)
--   fade square:  appears below 90% mana (only on a 0-1 scale)
local swatch

local function colorCurve(points)
  local c = C_CurveUtil.CreateColorCurve()
  c:SetType(Enum.LuaCurveType.Linear)
  for _, p in ipairs(points) do c:AddPoint(p[1], _G.CreateColor(p[2], p[3], p[4], 1)) end
  return c
end

local function stepCurve(points)
  local c = C_CurveUtil.CreateCurve()
  c:SetType(Enum.LuaCurveType.Step)
  for _, p in ipairs(points) do c:AddPoint(p[1], p[2]) end
  return c
end

local function square(parent, x)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(1, 1, 1, 1)
  t:SetSize(56, 56)
  t:SetPoint("TOPLEFT", x, -20)
  return t
end

local function buildSwatch()
  local f = ns.CreateWindow("SoThirstySwatch", 360, 260, L.ADDON)
  local c = f.content
  local mt = manaType() or 0
  local colors = colorCurve({ { 0, 1, 0.25, 0.25 }, { 0.5, 1, 0.85, 0.2 }, { 1, 0.4, 0.9, 0.3 } })
  local fade = stepCurve({ { 0, 1 }, { 0.9, 0 } })
  local colorSq, fadeSq = square(c, 24), square(c, 104)
  local bar = CreateFrame("StatusBar", nil, c)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.31, 0.76, 0.97)
  bar:SetSize(150, 14)
  bar:SetPoint("TOPLEFT", 184, -40)
  local help = ns.Text(c, "body", 12)
  help:SetPoint("TOPLEFT", 16, -92)
  help:SetPoint("RIGHT", -16, 0)
  help:SetWordWrap(true)
  help:SetText(L.SWATCH_HELP)

  local function refresh()
    local okC, col = pcall(_G.UnitPowerPercent, "player", mt, false, colors)
    if okC and col then colorSq:SetVertexColor(col:GetRGB()) end
    local okF, a = pcall(_G.UnitPowerPercent, "player", mt, false, fade)
    if okF and a ~= nil then fadeSq:SetAlpha(a) end
    bar:SetMinMaxValues(0, UnitPowerMax("player", mt))
    bar:SetValue(UnitPower("player", mt))
  end

  f:SetScript("OnEvent", refresh)
  f:HookScript("OnShow", function(self)
    self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    refresh()
  end)
  f:HookScript("OnHide", function(self) self:UnregisterAllEvents() end)
  return f
end

function ns.DebugSwatch()
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and _G.UnitPowerPercent) then
    return ns.Print(L.SWATCH_MISSING)
  end
  swatch = swatch or buildSwatch()
  swatch:Hide()
  swatch:Show()
end

-- /sot debug window: opens a sample window, to check the look and that the game textures it
-- borrows exist on Forever (spec 16 Q16).
local sample
function ns.DebugWindow()
  if not sample then
    sample = ns.CreateWindow("SoThirstySample", 520, 300, L.ADDON)
    local c = sample.content
    local head = ns.Text(c, "section", 14)
    head:SetPoint("TOPLEFT", 24, -18)
    head:SetText(L.SAMPLE_HEAD)
    local body = ns.Text(c, "body", 13)
    body:SetPoint("TOPLEFT", 16, -46)
    body:SetPoint("RIGHT", -16, 0)
    body:SetWordWrap(true)
    body:SetText(L.SAMPLE_BODY)
    local muted = ns.Text(c, "muted", 12)
    muted:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -10)
    muted:SetPoint("RIGHT", -16, 0)
    muted:SetText(L.SAMPLE_MUTED)
    local box = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
    box:SetPoint("BOTTOMLEFT", 12, 44)
    box:SetChecked(true)
    local label = ns.Text(c, "body", 13)
    label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    label:SetText(L.SAMPLE_CHECK)
    local close = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    close:SetSize(120, 24)
    close:SetPoint("BOTTOMRIGHT", -12, 12)
    close:SetText(CLOSE or "Close")
    close:SetScript("OnClick", function() sample:Hide() end)
  end
  sample:Show()
end
