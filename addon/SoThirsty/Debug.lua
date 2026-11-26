-- /sot debug: prints what the client tells the addon, to settle the open questions in
-- spec Section 16. Read-only: nothing here works around a hidden value.
-- (The probes that answered Q17-Q24 are gone; their answers are recorded in the spec.)
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

local function flag(label, ok, err)
  line(label, ok and "ok" or ("no: " .. tostring(err)))
end

local function header(unit)
  DEFAULT_CHAT_FRAME:AddMessage(("|cff4fc3f7[%s]|r %s"):format(unit, show(UnitName(unit))))
end

local function describeUnit(unit)
  if not UnitExists(unit) then return end
  header(unit)
  line("GUID", UnitGUID(unit))
  line("role (UnitGroupRolesAssigned)", UnitGroupRolesAssigned(unit))
  line("dead / connected", UnitIsDeadOrGhost(unit), UnitIsConnected(unit))
  line("in combat (UnitAffectingCombat)", UnitAffectingCombat(unit))
  local _, class = UnitClass(unit)
  line("class", class)
end

function ns.Debug()
  ns.Print(L.DEBUG_HEADER)
  local version, build, buildDate, toc = GetBuildInfo()
  line("client", version, build, buildDate, toc)
  line("WOW_PROJECT_ID", WOW_PROJECT_ID)
  line("curves available / build error", ns.Curves.Available(), ns.Curves.error)
  line("IsInGroup / IsInRaid", IsInGroup(), IsInRaid())
  line("IsInInstance", IsInInstance())
  line("chat channel picked", ns.ChatChannel())
  line("zone ok / group in combat", (ns.ZoneOk()), ns.Combat.Is())
  line("leader", UnitIsGroupLeader("player"))
  line("healers tracked", ns.Roster.Count())
  local s = ns.Settings()
  line("indicators on (bar, pips, flask, banner, glow)", s.bar.enabled, s.pips.enabled, s.flask.enabled,
    s.banner.enabled, s.vignette.enabled)
  for _, unit in ipairs(ns.Roster.GroupUnits() or { "player" }) do describeUnit(unit) end
end

-- /sot debug drink: each healer's buffs and whether one counts as drinking (spec 16 Q11).
function ns.DebugDrink()
  ns.Print(L.DEBUG_DRINK_HEADER)
  ns.Roster.Scan()
  if ns.Roster.Count() == 0 then return ns.Print(L.DEBUG_DRINK_NONE) end
  for _, h in pairs(ns.Roster.healers) do
    header(h.unit)
    for i, a in ipairs(ns.Drink.List(h.unit)) do line("buff " .. i, a.name, a.spellId) end
    line("drink buff match (true / false / nil = hidden)", ns.Drink.AuraMatch(h.unit))
  end
end

-- /sot debug frames: the unit frame and power bar found for each group member (Q8, Q25).
function ns.DebugFrames()
  ns.Print(L.DEBUG_FRAMES_HEADER)
  local report, candidates = ns.Frames.Report()
  line("unit frames the addon knows about", candidates)
  for _, entry in ipairs(report) do
    line(entry.unit .. (entry.healer and " (healer)" or ""), entry.frame or "no frame found",
      entry.frame and (entry.powerBar or "no power bar showing: bottom strip is used") or nil)
  end
end

-- /sot debug looks: the three things the new indicators rely on that weren't proven yet.
--   Q25 is the unit frame's own power bar reachable (the mana bar color sits on it)?
--   Q26 does a vertical bar filled with an icon take the hidden mana fraction (the flask)?
--   Q27 can text be colored and faded from hidden values (banner and flask names)?
function ns.DebugLooks()
  ns.Print(L.DEBUG_LOOKS_HEADER)
  local Curves = ns.Curves
  line("curves available / build error", Curves.Available(), Curves.error)
  local report = ns.Frames.Report()
  local liquid = CreateFrame("StatusBar")
  liquid:SetStatusBarTexture(ns.Theme.ICONS.flask)
  flag("Q26 vertical bar", pcall(liquid.SetOrientation, liquid, "VERTICAL"))
  liquid:SetMinMaxValues(0, 1)
  local text = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:Hide()
  for _, entry in ipairs(report) do
    local unit = entry.unit
    header(unit)
    line("Q25 frame / power bar", entry.frame or "none", entry.powerBar or "none showing")
    local ok, fraction, r, g, b, alpha, low, p1 = Curves.All(unit)
    line("all curves", ok and "ok" or "failed")
    if ok then
      flag("Q26 flask fill SetValue", pcall(liquid.SetValue, liquid, fraction))
      local fill = liquid:GetStatusBarTexture()
      if fill then flag("Q26 flask fill SetAlpha", pcall(fill.SetAlpha, fill, alpha)) end
      flag("Q27 text SetTextColor", pcall(text.SetTextColor, text, r, g, b))
      flag("Q27 text SetAlpha", pcall(text.SetAlpha, text, low))
      flag("pip SetAlpha", pcall(text.SetAlpha, text, p1))
    end
    line("drink buff match (true / false / nil = hidden)", ns.Drink.AuraMatch(unit))
  end
  ns.Print(L.DEBUG_LOOKS_FOOT)
end

-- /sot debug icons: shows the game art the addon borrows. A blank or green square means
-- the client doesn't have it (spec 16 Q16).
local iconWindow
function ns.DebugIcons()
  if not iconWindow then
    iconWindow = ns.CreateWindow("SoThirstyIcons", 420, 260, L.ADDON)
    local c = iconWindow.content
    local list = {}
    for _, name in ipairs(ns.Theme.ICON_ORDER) do list[#list + 1] = { name, ns.Theme.ICONS[name] } end
    list[#list + 1] = { "bar", ns.Theme.BAR }
    for i, entry in ipairs(list) do
      local t = c:CreateTexture(nil, "ARTWORK")
      t:SetSize(40, 40)
      t:SetPoint("TOPLEFT", 24 + (i - 1) * 72, -24)
      t:SetTexture(entry[2])
      local label = ns.Text(c, "muted", 11)
      label:SetPoint("TOP", t, "BOTTOM", 0, -4)
      label:SetText(entry[1])
    end
    local note = ns.Text(c, "body", 12)
    note:SetPoint("TOPLEFT", 16, -100)
    note:SetPoint("RIGHT", -16, 0)
    note:SetWordWrap(true)
    note:SetText(L.DEBUG_ICONS_NOTE)
  end
  iconWindow:Show()
end
