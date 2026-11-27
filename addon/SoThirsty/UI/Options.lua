-- The Options window (spec 12.2). Big and sparse on purpose, so the art behind it shows:
-- a short list of tabs down the left (one per indicator), one short column of controls per
-- tab. Previews happen on screen, on the real indicators, with the window tucked away. Built from the game's own templates (spec 9.7);
-- every color uses the game's color picker.
local _, ns = ...
local L = ns.L
local Theme, Levels, Frames = ns.Theme, ns.Levels, ns.Frames

local WIDTH, HEIGHT = 900, 660
local TAB_W = 150            -- the tab list's width
local COL_X, COL_W = 190, 400 -- where a tab's column starts, and how wide it is
local ROW_H = 32
local window
local refreshers = {}
local SAMPLE_PCT = 25        -- the mana the samples rest at: low enough that everything shows
local preview = { pct = SAMPLE_PCT, drinking = false }
local currentTab = "general"
local onScreen = false       -- the window is tucked away and the real indicators show samples
local toggleScreen           -- defined below (it needs Save / Undo)

local function S() return ns.Settings() end
local function changed() ns.Apply() end

-- ---------------------------------------------------------------- small controls

local function button(parent, text, width, fn)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 24)
  b:SetText(text)
  b:SetScript("OnClick", fn)
  return b
end

local function label(parent, text, y)
  local t = ns.Text(parent, "body", 13)
  t:SetPoint("TOPLEFT", 4, y - 7)
  t:SetText(text)
  return t
end

-- [-] value [+], right edge at x. Returns its refresh function.
local function stepper(parent, x, y, get, set, min, max, step, suffix)
  local plus = button(parent, "+", 26, nil)
  plus:SetPoint("TOPRIGHT", parent, "TOPLEFT", x, y - 2)
  local value = ns.Text(parent, "body", 13)
  value:SetWidth(52)
  value:SetJustifyH("CENTER")
  value:SetPoint("RIGHT", plus, "LEFT", -2, 0)
  local minus = button(parent, "-", 26, nil)
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
  local r, g, b = color[1], color[2], color[3]
  local function set(nr, ng, nb)
    color[1], color[2], color[3] = nr, ng, nb
    onChange()
  end
  local info = {
    r = r, g = g, b = b, hasOpacity = false,
    swatchFunc = function() set(ColorPickerFrame:GetColorRGB()) end,
    cancelFunc = function() set(r, g, b) end,
  }
  if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info) end
end

-- A color swatch plus a small reset button, right edge at x.
local function swatch(parent, x, y, getColor, getDefault, onChange)
  local reset = button(parent, L.OPT_RESET, 56, nil)
  reset:SetPoint("TOPRIGHT", parent, "TOPLEFT", x, y - 2)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(32, 20)
  b:SetPoint("RIGHT", reset, "LEFT", -6, 0)
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
  local t = ns.Text(parent, "heading", 18)
  t:SetPoint("TOPLEFT", 4, y)
  t:SetText(row[2])
  return nil, ROW_H + 6
end

function build.note(parent, row, y)
  local t = ns.Text(parent, "muted", 12)
  t:SetPoint("TOPLEFT", 4, y - 6)
  t:SetWidth(COL_W - 8)
  t:SetWordWrap(true)
  local text = row[2]
  if type(text) == "function" then return function() t:SetText(text()) end, row[3] or 44 end
  t:SetText(text)
  return nil, row[3] or 44
end

-- { "check", label, get, set }
function build.check(parent, row, y)
  local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  box:SetSize(26, 26)
  box:SetPoint("TOPLEFT", 0, y - 1)
  local t = ns.Text(parent, "body", 13)
  t:SetPoint("LEFT", box, "RIGHT", 4, 0)
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
  return stepper(parent, COL_W, y, row[3], row[4], row[5], row[6], row[7], row[8]), ROW_H
end

-- { "cycle", label, get, set, values, labels }: left-click next, right-click back.
function build.cycle(parent, row, y)
  label(parent, row[2], y)
  local values, labels = row[5], row[6]
  local b = button(parent, "", 170, nil)
  b:SetPoint("TOPRIGHT", parent, "TOPLEFT", COL_W, y - 2)
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
  return swatch(parent, COL_W, y, row[3], row[4]), ROW_H
end

-- { "level", label, index }: where the level starts (steps of 10) and its color.
local function setThreshold(index, value)
  local s = S()
  local list = {}
  for i = 1, 3 do list[i] = { pct = s.levels[i].pct } end
  list[index].pct = value
  if not Levels.Validate(list) then return ns.Print(L.LEVELS_BAD_ORDER) end
  s.levels[index].pct = value
end

function build.level(parent, row, y)
  label(parent, row[2], y)
  local index = row[3]
  local function entry() return S().levels[index] end
  local refreshColor = swatch(parent, COL_W, y, function() return entry().color end,
    function() return ns.DB_DEFAULTS.settings.levels[index].color end,
    function() S().palette = "custom" end)
  local refreshStep = stepper(parent, COL_W - 108, y, function() return entry().pct end,
    function(v) setThreshold(index, v) end, 10, 90, 10, "%")
  return function()
    refreshColor()
    refreshStep()
  end, ROW_H
end

-- { "edit", label, get, set }: an empty box means "use the default line".
function build.edit(parent, row, y)
  label(parent, row[2], y)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(COL_W - 120, 22)
  box:SetPoint("TOPRIGHT", parent, "TOPLEFT", COL_W, y - 3)
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

-- { "buttons", { label, fn, width }, ... }: a row of buttons.
function build.buttons(parent, row, y)
  local x = 2
  for i = 2, #row do
    local width = row[i][3] or 150
    local b = button(parent, row[i][1], width, function()
      row[i][2]()
      changed()
    end)
    b:SetPoint("TOPLEFT", x, y - 4)
    x = x + width + 8
  end
  return nil, ROW_H + 4
end

-- ---------------------------------------------------------------- the tabs

local function field(path, key)
  return function() return path()[key] end, function(v) path()[key] = v end
end
local function group(name) return function() return S()[name] end end
local barCfg, pipsCfg, flaskCfg = group("bar"), group("pips"), group("flask")
local bannerCfg, glowCfg, buttonCfg, zones = group("banner"), group("vignette"), group("button"), group("zones")

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

local placeRow = { "buttons", { L.OPT_PLACE, function() toggleScreen() end, 210 } }

-- { key, tab title, rows }
local function tabList()
  return {
    { "general", L.TAB_GENERAL, {
      { "head", L.TAB_GENERAL },
      check(L.OPT_ENABLED, S, "enabled"),
      check(L.OPT_ZONE_DUNGEON, zones, "dungeon"),
      check(L.OPT_ZONE_RAID, zones, "raid"),
      check(L.OPT_ZONE_WORLD, zones, "world"),
      cycle(L.OPT_COMBAT_SCOPE, S, "combatScope", { "group", "me" }, L.COMBAT_SCOPE),
      check(L.OPT_ROLE_HINT, S, "roleHint"),
      { "check", L.OPT_MINIMAP, function() return not S().minimap.hide end,
        function(v)
          S().minimap.hide = not v
          ns.SetupMinimap()
        end },
      step(L.OPT_GHOST, S, "ghost", 0, 100, 5, "%"),
      { "buttons", { L.OPT_RESET_ALL, resetAll, 120 }, { L.OPT_DEBUG, function() ns.Debug() end, 120 } },
    } },
    { "levels", L.TAB_LEVELS, {
      { "head", L.TAB_LEVELS },
      { "level", L.OPT_LEVEL1, 1 },
      { "level", L.OPT_LEVEL2, 2 },
      { "level", L.OPT_LEVEL3, 3 },
      { "cycle", L.OPT_PALETTE, function() return S().palette end,
        function(v) Theme.ApplyPalette(S(), v) end, Theme.PALETTE_ORDER, L.PALETTES },
      { "note", L.NOTE_LEVELS, 60 },
    } },
    { "bar", L.TAB_BAR, {
      { "head", L.TAB_BAR },
      check(L.OPT_ON, barCfg, "enabled"),
      step(L.OPT_OPACITY, barCfg, "alpha", 40, 100, 10, "%"),
      { "note", L.NOTE_BAR, 60 },
    } },
    { "pips", L.TAB_PIPS, {
      { "head", L.TAB_PIPS },
      check(L.OPT_ON, pipsCfg, "enabled"),
      cycle(L.OPT_SIZE, pipsCfg, "size", Theme.PIP_ORDER, L.SIZES),
      cycle(L.OPT_CORNER, pipsCfg, "corner", Theme.CORNER_ORDER, L.CORNERS),
      { "note", L.NOTE_PIPS, 60 },
    } },
    { "flask", L.TAB_FLASK, {
      { "head", L.TAB_FLASK },
      check(L.OPT_ON, flaskCfg, "enabled"),
      check(L.OPT_FLASK_WHEN_LOW, flaskCfg, "whenLow"),
      step(L.OPT_OPACITY, flaskCfg, "alpha", 20, 100, 10, "%"),
      step(L.OPT_SIZE, flaskCfg, "scale", 60, 200, 10, "%"),
      check(L.OPT_FLASK_NAMES, flaskCfg, "names"),
      cycle(L.OPT_FLASK_LAYOUT, flaskCfg, "layout", { "row", "column" }, L.FLASK_LAYOUT),
      cycle(L.OPT_FLASK_TOGETHER, flaskCfg, "together", { true, false }, L.FLASK_TOGETHER),
      placeRow,
      { "note", L.NOTE_FLASK, 60 },
    } },
    { "banner", L.TAB_BANNER, {
      { "head", L.TAB_BANNER },
      check(L.OPT_ON, bannerCfg, "enabled"),
      cycle(L.OPT_BANNER_DELAY, bannerCfg, "delay", { 3, 5, 8, 10 }, L.SECONDS),
      step(L.OPT_BANNER_HOLD, bannerCfg, "hold", 3, 8, 1, " s"),
      step(L.OPT_SIZE, bannerCfg, "scale", 60, 200, 10, "%"),
      cycle(L.OPT_BANNER_NAME, bannerCfg, "surname", { true, false }, L.BANNER_NAME),
      placeRow,
      { "note", L.NOTE_BANNER, 60 },
    } },
    { "glow", L.TAB_GLOW, {
      { "head", L.TAB_GLOW },
      check(L.OPT_ON, glowCfg, "enabled"),
      step(L.OPT_GLOW_STRENGTH, glowCfg, "strength", 10, 100, 5, "%"),
      cycle(L.OPT_GLOW_WIDTH, glowCfg, "width", Theme.GLOW_ORDER, L.WIDTHS),
      check(L.OPT_GLOW_CUSTOM, glowCfg, "custom"),
      { "color", L.OPT_GLOW_COLOR, function() return glowCfg().color end,
        function() return ns.DB_DEFAULTS.settings.vignette.color end },
      { "note", L.NOTE_GLOW, 60 },
    } },
    { "button", L.TAB_BUTTON, {
      { "head", L.TAB_BUTTON },
      cycle(L.OPT_BUTTON_SHOW, buttonCfg, "show", { "healer", "always", "never" }, L.BUTTON_SHOW),
      check(L.CHANNEL_party, buttonCfg, "party"),
      check(L.CHANNEL_raid, buttonCfg, "raid"),
      check(L.CHANNEL_instance, buttonCfg, "instance"),
      check(L.OPT_PREFIX, buttonCfg, "prefix"),
      cycle(L.OPT_BANNER_NAME, buttonCfg, "surname", { true, false }, L.BANNER_NAME),
      { "edit", L.OPT_LINE_THIRSTY, function() return buttonCfg().thirstyMsg end,
        function(v) buttonCfg().thirstyMsg = v end },
      { "edit", L.OPT_LINE_READY, function() return buttonCfg().readyMsg end,
        function(v) buttonCfg().readyMsg = v end },
      { "note", function() return L.OPT_LINE_PREVIEW:format(ns.Button.Line("thirsty")) end, 30 },
      { "buttons", { L.OPT_MACRO, function() ns.Button.MakeMacros() end, 190 } },
      { "note", L.NOTE_BUTTON, 60 },
    } },
  }
end

-- ---------------------------------------------------------------- preview

-- Shows samples at the preview's mana: in the window, the off-frame indicator whose tab is
-- open; on screen, every indicator where it really sits, the unit frames too.
local function paintPreview()
  local pct = preview.pct
  local open = window and (window:IsShown() or onScreen)
  if open and (onScreen or currentTab == "flask") then
    -- Three stand-ins show how several healers line up.
    ns.Flask.Demo(pct, preview.drinking, 3)
  else
    ns.Flask.Demo(nil)
  end
  if open and (onScreen or currentTab == "glow") then ns.Vignette.Demo(pct) else ns.Vignette.Demo(nil) end
  if open and (onScreen or currentTab == "banner") then ns.Banner.Demo(pct) end
  Frames.Demo(onScreen and pct or nil, preview.drinking)
end

-- The two preview buttons in the window, and the small bar that stays up on screen.
local function buildPreview(parent)
  local screen = button(parent, L.PREVIEW_SCREEN, 160, function() toggleScreen() end)
  screen:SetPoint("BOTTOMRIGHT", -14, 48)
  local play = button(parent, L.PREVIEW_PLAY, 80, function() ns.PlayPreview() end)
  play:SetPoint("RIGHT", screen, "LEFT", -8, 0)

  local bar = CreateFrame("Frame", "SoThirstyPreviewBar", UIParent)
  bar:SetSize(272, 36)
  bar:SetPoint("TOP", 0, -60)
  bar:SetFrameStrata("DIALOG")
  bar:EnableMouse(true)
  bar:SetMovable(true)
  bar:SetClampedToScreen(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
  bar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  local plate = bar:CreateTexture(nil, "BACKGROUND")
  plate:SetAllPoints()
  plate:SetColorTexture(0.06, 0.03, 0.08, 0.92)
  ns.Edge(bar, "BORDER", ns.COLORS.goldEdge, 0)
  local again = button(bar, L.PREVIEW_PLAY, 80, function() ns.PlayPreview() end)
  again:SetPoint("LEFT", 8, 0)
  local back = button(bar, L.PREVIEW_BACK, 160, function() toggleScreen() end)
  back:SetPoint("RIGHT", -8, 0)
  bar:Hide()
  preview.bar = bar
end

-- Plays a stand-in healer through the levels on every indicator, on screen: 100% down to
-- 0%, a drink, then back to the resting sample. Nothing is posted anywhere (spec 9.3).
function ns.PlayPreview()
  if not onScreen then
    if not window or not window:IsShown() then ns.ToggleOptions(true) end
    toggleScreen()
  end
  if not onScreen then return end -- refused: in combat
  if preview.ticker then preview.ticker:Cancel() end
  local tick = 0
  preview.ticker = C_Timer.NewTicker(0.3, function()
    tick = tick + 1
    if tick <= 21 then
      preview.pct, preview.drinking = 100 - (tick - 1) * 5, false
    elseif tick <= 27 then
      preview.pct, preview.drinking = (tick - 21) * 15, true
    else
      preview.pct, preview.drinking = SAMPLE_PCT, false
    end
    ns.RefreshOptions()
  end, 28)
end

-- ---------------------------------------------------------------- Save / Undo

-- Changes show at once, on the preview and on the real frames, but they only stick when
-- Save is pressed (spec 12.2). `saved` is the settings as of the last Save (or as of opening
-- the window); closing with unsaved changes puts them back.
local saved
local saveButton, revertButton, saveState

-- Where things were dragged to isn't a "setting to save": it always sticks.
local function keepPlacement()
  local s = ns.Settings()
  for _, key in ipairs({ "button", "flask", "banner" }) do
    saved[key].point = s[key].point and ns.DeepCopy(s[key].point) or nil
  end
  saved.flask.points = s.flask.points and ns.DeepCopy(s.flask.points) or nil
  saved.minimap.angle = s.minimap.angle
end

local function unsaved()
  if not saved then return false end
  keepPlacement()
  return not ns.DeepEqual(saved, ns.Settings())
end

local function save()
  saved = ns.DeepCopy(ns.Settings())
  ns.Print(L.OPT_SAVED)
  ns.RefreshOptions()
end

local function revert()
  if not saved then return end
  keepPlacement()
  SoThirstyDB.settings = ns.DeepCopy(saved)
  ns.Apply()
end

-- The Options session is over (window closed, or a fight began during the on-screen
-- preview): unsaved changes go back, and every sample and grab plate leaves the screen.
local function endSession()
  if preview.ticker then preview.ticker:Cancel() end
  preview.pct, preview.drinking = SAMPLE_PCT, false
  if unsaved() then
    revert()
    ns.Print(L.OPT_DISCARDED)
  end
  saved = nil
  if ns.unlocked then
    ns.unlocked = false
    ns.UpdateAll()
  end
  ns.Flask.Demo(nil)
  ns.Vignette.Demo(nil)
  ns.Banner.Demo(nil)
  Frames.Demo(nil)
end

-- ---------------------------------------------------------------- preview on screen

-- Tucks the window away and shows every indicator where it really sits, at a sample mana,
-- with grab plates on the ones that move. A small bar stays up; a second call brings the
-- window back. Unsaved changes ride along either way.
function toggleScreen()
  if not window then return end
  if onScreen then
    onScreen = false
    if preview.ticker then preview.ticker:Cancel() end
    preview.pct, preview.drinking = SAMPLE_PCT, false
    preview.bar:Hide()
    ns.unlocked = false
    window:Show()
  else
    if InCombatLockdown() then return ns.Print(L.SCREEN_COMBAT) end
    onScreen = true
    preview.bar:Show()
    window:Hide()
    ns.unlocked = true
    ns.Print(L.SCREEN_ON)
  end
  ns.UpdateAll()
  ns.RefreshOptions()
end

-- A fight ends the on-screen preview: nothing of ours shows in combat (spec 1.1).
local function onCombat()
  if not onScreen then return end
  onScreen = false
  preview.bar:Hide()
  ns.Print(L.SCREEN_COMBAT)
  endSession()
end

-- ---------------------------------------------------------------- the window

local function buildWindow()
  window = ns.CreateWindow("SoThirstyOptions", WIDTH, HEIGHT, L.ADDON)
  local c = window.content
  local tabs, tabButtons, keys = {}, {}, {}

  local function show(index)
    currentTab = keys[index]
    for i, tab in ipairs(tabs) do
      tab:SetShown(i == index)
      if i == index then tabButtons[i]:LockHighlight() else tabButtons[i]:UnlockHighlight() end
    end
    ns.RefreshOptions()
  end

  for i, def in ipairs(tabList()) do
    keys[i] = def[1]
    local b = button(c, def[2], TAB_W, function() show(i) end)
    b:SetPoint("TOPLEFT", 14, -16 - (i - 1) * 30)
    tabButtons[i] = b
    local tab = CreateFrame("Frame", nil, c)
    tab:SetPoint("TOPLEFT", COL_X, -18)
    tab:SetSize(COL_W, 10)
    tabs[i] = tab
    local y = 0
    for _, row in ipairs(def[3]) do
      local refresh, height = build[row[1]](tab, row, y)
      if refresh then refreshers[#refreshers + 1] = refresh end
      y = y - height
    end
  end

  buildPreview(c)

  saveButton = button(c, L.OPT_SAVE, 110, save)
  saveButton:SetPoint("BOTTOMLEFT", COL_X, 14)
  revertButton = button(c, L.OPT_REVERT, 130, function()
    revert()
    ns.Print(L.OPT_REVERTED)
  end)
  revertButton:SetPoint("LEFT", saveButton, "RIGHT", 8, 0)
  saveState = ns.Text(c, "muted", 12)
  saveState:SetPoint("LEFT", revertButton, "RIGHT", 12, 0)

  -- Closing (the X, Escape, /sot) without saving puts the settings back, and ends previews.
  -- Tucked away for the on-screen preview is not closed.
  window:HookScript("OnHide", function()
    if not onScreen then endSession() end
  end)
  window:RegisterEvent("PLAYER_REGEN_DISABLED")
  window:SetScript("OnEvent", onCombat)
  window:Hide()
  show(1)
end

-- Re-reads every control from the settings (after any change).
function ns.RefreshOptions()
  if not window or not saveButton then return end
  for _, refresh in ipairs(refreshers) do refresh() end
  paintPreview()
  local pending = unsaved()
  saveButton:SetEnabled(pending)
  revertButton:SetEnabled(pending)
  saveState:SetText(pending and L.OPT_UNSAVED or L.OPT_ALL_SAVED)
  local color = pending and ns.COLORS.gold or ns.COLORS.muted
  saveState:SetTextColor(color[1], color[2], color[3])
end

function ns.ToggleOptions(forceOpen)
  if not window then buildWindow() end
  if onScreen then return toggleScreen() end
  if not window:IsShown() then
    saved = ns.DeepCopy(ns.Settings())
    window:Show()
    ns.RefreshOptions()
  elseif not forceOpen then
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
