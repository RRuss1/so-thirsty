-- The Options window (spec 12.2): tabs of settings on the left, a live preview on the right.
-- Built from the game's own templates (spec 9.7). Every color uses the game's color picker.
local _, ns = ...
local L = ns.L
local Theme, Levels, Frames = ns.Theme, ns.Levels, ns.Frames

local ROW_H, LEFT_W = 26, 392
local window
local refreshers = {}
local preview = { pct = 40, drinking = false }

local function S() return ns.Settings() end
local function changed() ns.Apply() end

-- ---------------------------------------------------------------- small controls

local function button(parent, text, width, fn)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", fn)
  return b
end

local function label(parent, text, y)
  local t = ns.Text(parent, "body", 12)
  t:SetPoint("TOPLEFT", 12, y - 6)
  t:SetText(text)
  return t
end

-- [-] value [+], right edge at x. Returns its refresh function.
local function stepper(parent, x, y, get, set, min, max, step, suffix)
  local plus = button(parent, "+", 24, nil)
  plus:SetPoint("TOPRIGHT", parent, "TOPLEFT", x, y - 2)
  local value = ns.Text(parent, "body", 12)
  value:SetWidth(46)
  value:SetJustifyH("CENTER")
  value:SetPoint("RIGHT", plus, "LEFT", -2, 0)
  local minus = button(parent, "-", 24, nil)
  minus:SetPoint("RIGHT", value, "LEFT", -2, 0)
  local function bump(delta)
    local v = math.max(min, math.min(max, get() + delta))
    if v == get() then return end
    set(v)
    changed()
  end
  plus:SetScript("OnClick", function() bump(step) end)
  minus:SetScript("OnClick", function() bump(-step) end)
  return function() value:SetText(get() .. (suffix or "")) end
end

-- Opens the game's color picker on a { r, g, b, a } table.
local function pickColor(color, onChange)
  local r, g, b, a = color[1], color[2], color[3], color[4] or 1
  local function set(nr, ng, nb)
    color[1], color[2], color[3] = nr, ng, nb
    onChange()
  end
  local info = {
    r = r, g = g, b = b, opacity = a, hasOpacity = false,
    swatchFunc = function() set(ColorPickerFrame:GetColorRGB()) end,
    cancelFunc = function() set(r, g, b) end,
  }
  if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info) end
end

-- A color swatch plus a small reset button, right edge at x.
local function swatch(parent, x, y, getColor, getDefault, onChange)
  local reset = button(parent, L.OPT_RESET, 50, nil)
  reset:SetPoint("TOPRIGHT", parent, "TOPLEFT", x, y - 2)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(28, 18)
  b:SetPoint("RIGHT", reset, "LEFT", -4, 0)
  local edge = b:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints()
  edge:SetColorTexture(0.75, 0.55, 0.2, 1)
  local fill = b:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", -1, 1)
  local function apply()
    if onChange then onChange() end
    changed()
  end
  b:SetScript("OnClick", function() pickColor(getColor(), apply) end)
  reset:SetScript("OnClick", function()
    local c, d = getColor(), getDefault()
    c[1], c[2], c[3], c[4] = d[1], d[2], d[3], d[4]
    apply()
  end)
  return function()
    local c = getColor()
    fill:SetColorTexture(c[1], c[2], c[3], 1)
  end
end

-- ---------------------------------------------------------------- row kinds
-- Each builder returns a refresh function (or nil) and the row's height.

local build = {}

function build.head(parent, row, y)
  local t = ns.Text(parent, "section", 13)
  t:SetPoint("TOPLEFT", 22, y - 8)
  t:SetText(row[2])
  return nil, ROW_H + 4
end

function build.note(parent, row, y)
  local t = ns.Text(parent, "muted", 11)
  t:SetPoint("TOPLEFT", 12, y - 4)
  t:SetWidth(LEFT_W - 16)
  t:SetWordWrap(true)
  local text = row[2]
  if type(text) == "function" then return function() t:SetText(text()) end, row[3] or 34 end
  t:SetText(text)
  return nil, row[3] or 34
end

-- { "check", label, get, set }
function build.check(parent, row, y)
  local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  box:SetSize(24, 24)
  box:SetPoint("TOPLEFT", 8, y)
  local t = ns.Text(parent, "body", 12)
  t:SetPoint("LEFT", box, "RIGHT", 2, 0)
  t:SetText(row[2])
  box:SetScript("OnClick", function(self)
    row[4](self:GetChecked() and true or false)
    changed()
  end)
  return function() box:SetChecked(row[3]() and true or false) end, ROW_H
end

-- { "step", label, get, set, min, max, step, suffix }
function build.step(parent, row, y)
  label(parent, row[2], y)
  return stepper(parent, LEFT_W, y, row[3], row[4], row[5], row[6], row[7], row[8]), ROW_H
end

-- { "cycle", label, get, set, values, labels }: left-click next, right-click back.
function build.cycle(parent, row, y)
  label(parent, row[2], y)
  local values, labels = row[5], row[6]
  local b = button(parent, "", 150, nil)
  b:SetPoint("TOPRIGHT", parent, "TOPLEFT", LEFT_W, y - 2)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(_, mouse)
    local at = 0
    for i, v in ipairs(values) do
      if v == row[3]() then at = i end
    end
    local step = mouse == "RightButton" and -1 or 1
    row[4](values[(at - 1 + step) % #values + 1])
    changed()
  end)
  return function()
    local v = row[3]()
    b:SetText(labels and labels[v] or tostring(v))
  end, ROW_H
end

-- { "color", label, getColor, getDefault }
function build.color(parent, row, y)
  label(parent, row[2], y)
  return swatch(parent, LEFT_W, y, row[3], row[4]), ROW_H
end

-- { "level", label, index } where index is 1-3 or "ready": threshold stepper + color.
local function setThreshold(index, value)
  local s = S()
  local list, ready = {}, { pct = s.ready.pct }
  for i = 1, 3 do list[i] = { pct = s.levels[i].pct } end
  if index == "ready" then ready.pct = value else list[index].pct = value end
  local ok, why = Levels.Validate(list, ready)
  if not ok then return ns.Print(why == "READY" and L.OPT_BAD_READY or L.LEVELS_BAD_ORDER) end
  if index == "ready" then s.ready.pct = value else s.levels[index].pct = value end
end

function build.level(parent, row, y)
  label(parent, row[2], y)
  local index = row[3]
  local function entry() return index == "ready" and S().ready or S().levels[index] end
  local function default()
    local d = ns.DB_DEFAULTS.settings
    return index == "ready" and d.ready.color or d.levels[index].color
  end
  local refreshColor = swatch(parent, LEFT_W, y, function() return entry().color end, default,
    function() S().look.palette = "custom" end)
  local refreshStep = stepper(parent, LEFT_W - 96, y, function() return entry().pct end,
    function(v) setThreshold(index, v) end, 10, index == "ready" and 100 or 90, 10, "%")
  return function()
    refreshColor()
    refreshStep()
  end, ROW_H
end

-- { "edit", label, get, set }: an empty box means "use the default line".
function build.edit(parent, row, y)
  label(parent, row[2], y)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(LEFT_W - 96, 20)
  box:SetPoint("TOPRIGHT", parent, "TOPLEFT", LEFT_W, y - 3)
  box:SetAutoFocus(false)
  box:SetMaxLetters(120)
  local function commit(self)
    local text = self:GetText()
    row[4](text ~= "" and text or nil)
    self:ClearFocus()
    changed()
  end
  box:SetScript("OnEnterPressed", commit)
  box:SetScript("OnEscapePressed", function(self)
    self:SetText(row[3]() or "")
    self:ClearFocus()
  end)
  return function()
    if not box:HasFocus() then box:SetText(row[3]() or "") end
  end, ROW_H
end

-- { "buttons", { label, fn }, ... }: a row of buttons.
function build.buttons(parent, row, y)
  local x = 12
  for i = 2, #row do
    local b = button(parent, row[i][1], row[i][3] or 110, function()
      row[i][2]()
      changed()
    end)
    b:SetPoint("TOPLEFT", x, y - 2)
    x = x + (row[i][3] or 110) + 6
  end
  return nil, ROW_H + 2
end

-- ---------------------------------------------------------------- the tabs

local function field(path, key)
  return function() return path()[key] end, function(v) path()[key] = v end
end
local function look() return S().look end
local function framesCfg() return S().frames end
local function buttonCfg() return S().button end
local function zones() return S().zones end
local function meterCfg() return S().meter end

local function check(text, path, key) return { "check", text, field(path, key) } end
local function step(text, path, key, min, max, by, suffix)
  local get, set = field(path, key)
  return { "step", text, get, set, min, max, by, suffix }
end
local function cycle(text, path, key, values, labels)
  local get, set = field(path, key)
  return { "cycle", text, get, set, values, labels }
end

local function resetAll()
  SoThirstyDB.settings = ns.applyDefaults({}, ns.DB_DEFAULTS.settings)
  ns.Print(L.OPT_RESET_DONE)
end

local function toggleUnlock()
  ns.unlocked = not ns.unlocked
  ns.Print(ns.unlocked and L.MOVE_ON or L.MOVE_OFF)
end

local function tabList()
  local feel = { "buttons" }
  for _, name in ipairs(Theme.FEEL_ORDER) do
    feel[#feel + 1] = { L["FEEL_" .. name], function() Theme.ApplyFeel(S(), name) end }
  end
  return {
    { L.TAB_LEVELS, {
      { "head", L.OPT_LEVELS },
      { "level", L.OPT_LEVEL1, 1 },
      { "level", L.OPT_LEVEL2, 2 },
      { "level", L.OPT_LEVEL3, 3 },
      { "level", L.OPT_READY, "ready" },
      { "note", L.OPT_LEVELS_NOTE, 44 },
      cycle(L.OPT_BANDS, look, "bands", { "smooth", "steps" }, L.BANDS),
      { "cycle", L.OPT_PALETTE, function() return look().palette end,
        function(v) Theme.ApplyPalette(S(), v) end, Theme.PALETTE_ORDER, L.PALETTES },
      { "head", L.OPT_FEEL },
      feel,
      { "note", L.OPT_FEEL_NOTE, 44 },
    } },
    { L.TAB_LOOK, {
      { "head", L.OPT_GLOW },
      cycle(L.OPT_STYLE, look, "style", Theme.STYLES, L.STYLES),
      step(L.OPT_THICKNESS, look, "thickness", 1, 4, 1, " px"),
      step(L.OPT_ALPHA, look, "alpha", 20, 100, 10, "%"),
      check(L.OPT_STRENGTH, look, "strength"),
      step(L.OPT_FAINT, look, "faint", 10, 100, 5, "%"),
      step(L.OPT_REST, look, "rest", 30, 100, 10, "%"),
      cycle(L.OPT_COMBAT, look, "combat", { "hide", "faint" }, L.COMBAT_LOOK),
      { "head", L.OPT_DRINKING },
      step(L.OPT_DRINK_DIM, look, "drinkDim", 10, 100, 5, "%"),
      check(L.OPT_DROP, framesCfg, "drop"),
      cycle(L.OPT_ICON, look, "icon", Theme.ICON_ORDER, L.ICONS),
      { "head", L.OPT_OTHER },
      { "color", L.OPT_GREY, function() return look().greyColor end,
        function() return ns.DB_DEFAULTS.settings.look.greyColor end },
      step(L.OPT_GHOST, look, "ghost", 0, 100, 5, "%"),
    } },
    { L.TAB_MOTION, {
      { "head", L.OPT_NUDGE_HEAD },
      check(L.OPT_NUDGE, S, "nudge"),
      cycle(L.OPT_NUDGE_DELAY, S, "nudgeDelay", { 3, 5, 8, 10 }, L.SECONDS),
      step(L.OPT_NUDGE_HOLD, S, "nudgeHold", 2, 5, 1, " s"),
      check(L.OPT_WIPE, S, "quietAfterWipe"),
      { "head", L.OPT_PULSE_HEAD },
      check(L.OPT_PULSE, look, "pulse"),
      cycle(L.OPT_PULSE_SPEED, look, "pulseSpeed", Theme.PULSE_ORDER, L.SPEEDS),
      { "head", L.OPT_EXTRAS },
      check(L.OPT_READY_TICK, framesCfg, "readyTick"),
      check(L.OPT_RANGE_FADE, framesCfg, "rangeFade"),
      { "note", L.OPT_MOTION_NOTE, 44 },
    } },
    { L.TAB_BUTTON, {
      { "head", L.OPT_BUTTON_HEAD },
      cycle(L.OPT_BUTTON_SHOW, buttonCfg, "show", { "healer", "always", "never" }, L.BUTTON_SHOW),
      { "note", L.OPT_BUTTON_NOTE, 44 },
      { "head", L.OPT_CHANNELS },
      check(L.CHANNEL_party, buttonCfg, "party"),
      check(L.CHANNEL_raid, buttonCfg, "raid"),
      check(L.CHANNEL_instance, buttonCfg, "instance"),
      check(L.OPT_PREFIX, buttonCfg, "prefix"),
      { "head", L.OPT_LINES },
      { "edit", L.OPT_LINE_THIRSTY, function() return buttonCfg().thirstyMsg end,
        function(v) buttonCfg().thirstyMsg = v end },
      { "edit", L.OPT_LINE_READY, function() return buttonCfg().readyMsg end,
        function(v) buttonCfg().readyMsg = v end },
      { "note", function() return L.OPT_LINE_PREVIEW:format(ns.Button.Line("thirsty")) end, 40 },
      { "buttons", { L.OPT_UNLOCK, toggleUnlock, 170 } },
    } },
    { L.TAB_GENERAL, {
      { "head", L.OPT_GENERAL },
      check(L.OPT_ENABLED, S, "enabled"),
      check(L.OPT_ROLE_HINT, S, "roleHint"),
      cycle(L.OPT_COMBAT_SCOPE, S, "combatScope", { "group", "me" }, L.COMBAT_SCOPE),
      { "head", L.OPT_ZONES },
      check(L.OPT_ZONE_DUNGEON, zones, "dungeon"),
      check(L.OPT_ZONE_RAID, zones, "raid"),
      check(L.OPT_ZONE_WORLD, zones, "world"),
      { "head", L.OPT_METER },
      check(L.OPT_METER_ON, meterCfg, "enabled"),
      step(L.OPT_METER_SCALE, meterCfg, "scale", 50, 200, 10, "%"),
      { "buttons", { L.OPT_UNLOCK, toggleUnlock, 170 }, { L.OPT_RESET_ALL, resetAll, 110 } },
    } },
  }
end

-- ---------------------------------------------------------------- preview

local previewKnown = { enabled = true, zoneOk = true, inCombat = false, dead = false, offline = false }

local function paintPreview()
  if not preview.holder then return end
  local cfg = S()
  local pct = preview.pct
  Frames.Style(preview.holder)
  previewKnown.drinking = preview.drinking
  Frames.SetKnown(preview.holder, Levels.Holder(previewKnown, cfg))
  local r, g, b = Levels.ColorShown(pct, cfg)
  Frames.Paint(preview.holder, r, g, b, Levels.AlphaAt(pct, cfg), pct < cfg.levels[3].pct and 1 or 0,
    pct >= cfg.ready.pct and 1 or 0)
  preview.bar:SetValue(pct / 100)
  preview.text:SetText(pct .. "%")
  preview.state:SetText(preview.drinking and L.PREVIEW_DRINKING or "")
end

local function buildPreview(parent)
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetPoint("TOPLEFT", LEFT_W + 14, -40)
  panel:SetPoint("BOTTOMRIGHT", -8, 8)
  ns.Edge(panel, "BORDER", ns.COLORS.goldEdge, 0)

  local head = ns.Text(panel, "section", 13)
  head:SetPoint("TOPLEFT", 22, -10)
  head:SetText(L.PREVIEW)

  -- A stand-in unit frame.
  local unit = CreateFrame("Frame", nil, panel)
  unit:SetSize(150, 42)
  unit:SetPoint("TOP", 0, -56)
  local bg = unit:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.08, 0.08, 0.1, 1)
  local name = unit:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  name:SetPoint("TOPLEFT", 6, -6)
  name:SetText(L.PREVIEW_NAME)
  preview.state = unit:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  preview.state:SetPoint("TOPRIGHT", -6, -6)
  preview.state:SetTextColor(0.31, 0.76, 0.97)
  local bar = CreateFrame("StatusBar", nil, unit)
  bar:SetPoint("BOTTOMLEFT", 4, 4)
  bar:SetPoint("BOTTOMRIGHT", -4, 4)
  bar:SetHeight(10)
  bar:SetStatusBarTexture(Theme.BAR)
  bar:SetStatusBarColor(0.2, 0.4, 0.95)
  bar:SetMinMaxValues(0, 1)
  preview.bar = bar
  preview.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  preview.text:SetPoint("CENTER")

  local holder = CreateFrame("Frame", nil, unit)
  holder:SetAllPoints()
  holder:SetFrameLevel(unit:GetFrameLevel() + 5)
  Frames.Build(holder)
  preview.holder = holder

  local manaLabel = ns.Text(panel, "body", 12)
  manaLabel:SetPoint("TOPLEFT", 12, -136)
  manaLabel:SetText(L.PREVIEW_MANA)
  refreshers[#refreshers + 1] = stepper(panel, 196, -130, function() return preview.pct end,
    function(v) preview.pct = v end, 0, 100, 10, "%")

  local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  box:SetSize(24, 24)
  box:SetPoint("TOPLEFT", 8, -160)
  local boxText = ns.Text(panel, "body", 12)
  boxText:SetPoint("LEFT", box, "RIGHT", 2, 0)
  boxText:SetText(L.PREVIEW_DRINK)
  box:SetScript("OnClick", function(self)
    preview.drinking = self:GetChecked() and true or false
    paintPreview()
  end)
  preview.box = box

  local play = button(panel, L.PREVIEW_PLAY, 150, function() ns.PlayPreview() end)
  play:SetPoint("TOP", 0, -196)
  local nudge = button(panel, L.PREVIEW_NUDGE, 150, function() Frames.PlayNudge(preview.holder) end)
  nudge:SetPoint("TOP", play, "BOTTOM", 0, -6)

  local note = ns.Text(panel, "muted", 11)
  note:SetPoint("TOPLEFT", 12, -260)
  note:SetPoint("RIGHT", -10, 0)
  note:SetWordWrap(true)
  note:SetText(L.PREVIEW_NOTE)
end

-- Plays a fake healer through the bands: 100% down to 0%, a drink, then full. Nothing is
-- posted anywhere (spec 9.3).
function ns.PlayPreview()
  if not window or not window:IsShown() then ns.ToggleOptions(true) end
  if preview.ticker then preview.ticker:Cancel() end
  local tick = 0
  preview.ticker = C_Timer.NewTicker(0.3, function()
    tick = tick + 1
    if tick <= 21 then
      preview.pct, preview.drinking = 100 - (tick - 1) * 5, false
    elseif tick <= 27 then
      preview.pct, preview.drinking = (tick - 21) * 15, true
    else
      preview.pct, preview.drinking = 100, false
    end
    preview.box:SetChecked(preview.drinking)
    paintPreview()
    if tick == 13 then Frames.PlayNudge(preview.holder) end
  end, 28)
end

-- ---------------------------------------------------------------- the window

local function buildWindow()
  window = ns.CreateWindow("SoThirstyOptions", 700, 580, L.ADDON)
  local c = window.content
  local tabs, tabButtons = {}, {}

  local function show(index)
    for i, tab in ipairs(tabs) do
      tab:SetShown(i == index)
      if i == index then tabButtons[i]:LockHighlight() else tabButtons[i]:UnlockHighlight() end
    end
  end

  for i, def in ipairs(tabList()) do
    local b = button(c, def[1], 76, function() show(i) end)
    b:SetPoint("TOPLEFT", 8 + (i - 1) * 78, -8)
    tabButtons[i] = b
    local tab = CreateFrame("Frame", nil, c)
    tab:SetPoint("TOPLEFT", 0, -34)
    tab:SetPoint("BOTTOMLEFT", 0, 0)
    tab:SetWidth(LEFT_W + 8)
    tabs[i] = tab
    local y = 0
    for _, row in ipairs(def[2]) do
      local refresh, height = build[row[1]](tab, row, y)
      if refresh then refreshers[#refreshers + 1] = refresh end
      y = y - height
    end
  end

  buildPreview(c)
  local debug = button(c, L.OPT_DEBUG, 100, function() ns.Debug() end)
  debug:SetPoint("BOTTOMRIGHT", -16, 16)
  show(1)
  window:Hide()
end

-- Re-reads every control from the settings (after any change).
function ns.RefreshOptions()
  if not window then return end
  for _, refresh in ipairs(refreshers) do refresh() end
  paintPreview()
end

function ns.ToggleOptions(forceOpen)
  if not window then buildWindow() end
  if forceOpen or not window:IsShown() then
    ns.RefreshOptions()
    window:Show()
  else
    window:Hide()
  end
end

-- A small entry under Esc > Options > AddOns that opens the window.
function ns.RegisterOptions()
  local settings = _G.Settings
  if not (settings and settings.RegisterCanvasLayoutCategory and settings.RegisterAddOnCategory) then return end
  local panel = CreateFrame("Frame")
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L.ADDON)
  local open = button(panel, L.OPT_OPEN, 220, function() ns.ToggleOptions(true) end)
  open:SetPoint("TOPLEFT", 16, -50)
  settings.RegisterAddOnCategory(settings.RegisterCanvasLayoutCategory(panel, L.ADDON))
end
