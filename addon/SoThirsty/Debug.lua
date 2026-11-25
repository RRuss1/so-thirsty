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
