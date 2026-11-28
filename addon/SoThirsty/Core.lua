-- Startup, SavedVariables and slash commands.
local addonName, ns = ...
local L = ns.L

-- Spec 12.1 (settings v4). Account-wide. One small group per indicator.
local DB_VERSION = 4
local DB_DEFAULTS = {
  settings = {
    enabled = true,
    -- Three levels: where each one starts, and its color. Colors blend between them.
    levels = {
      { pct = 50, color = { 1, 0.82, 0, 1 } },
      { pct = 30, color = { 1, 0.5, 0, 1 } },
      { pct = 10, color = { 1, 0.125, 0.125, 1 } },
    },
    palette = "classic",            -- "classic" | "water" | "colorblind" | "custom"
    -- The five indicators (spec 8).
    bar = { enabled = true, alpha = 100 },
    pips = { enabled = true, size = "medium", corner = "TOPRIGHT" },
    flask = { enabled = true, scale = 100, names = true, alpha = 100, whenLow = false, simple = false,
      layout = "row",               -- several healers: "row" | "column"
      together = true },            -- placed as one stack (true) or one flask at a time
    banner = { enabled = true, delay = 5, hold = 5, scale = 100, surname = true },
    vignette = { enabled = false, strength = 35, width = "medium", custom = false, color = { 0.31, 0.76, 0.97, 1 } },
    -- The drink button: the only thing that posts to chat (spec 8.6).
    button = {
      show = "healer",              -- "healer" (my role is Healer, in a group) | "never"
      party = true, raid = true, instance = true,
      prefix = true,
      surname = true,               -- {name} is "First Surname" (false: first name only)
    },
    zones = { dungeon = true, raid = true, world = true },
    combatScope = "group",          -- "group" | "me"
    roleHint = true,
    minimap = { hide = false, angle = 215 },
    ghost = 35,                     -- the black-and-white art behind window content, 0-100 %
    debugEvents = false,
  },
}
ns.DB_DEFAULTS = DB_DEFAULTS

local function applyDefaults(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then
      t[k] = type(v) == "table" and applyDefaults({}, v) or v
    elseif type(v) == "table" and type(t[k]) == "table" then
      applyDefaults(t[k], v)
    end
  end
  return t
end
ns.applyDefaults = applyDefaults

-- A full copy of a settings table, and a deep comparison (the Options window's Save).
local function deepCopy(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  for k, v in pairs(t) do copy[k] = deepCopy(v) end
  return copy
end
ns.DeepCopy = deepCopy

local function deepEqual(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deepEqual(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end
ns.DeepEqual = deepEqual

function ns.Settings() return SoThirstyDB.settings end

-- Mana, health and range are always secret on Forever (spec Section 2). Never compare, test
-- or do math on a secret: check with this first.
function ns.IsSecret(v)
  return issecretvalue ~= nil and v ~= nil and issecretvalue(v) == true
end

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(L.PREFIX .. tostring(msg))
end

-- The group chat channel the drink button would use (spec 8.6). Never SAY, YELL or
-- RAID_WARNING. Returns the channel and its settings key, or nil when solo.
function ns.ChatChannel()
  if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT", "instance" end
  if IsInRaid() then return "RAID", "raid" end
  if IsInGroup() then return "PARTY", "party" end
  return nil
end

-- Battlegrounds and arenas are always off; the rest follow settings.zones (spec 10).
-- Second return is true for PvP instances.
function ns.ZoneOk()
  local _, kind = IsInInstance()
  if kind == "pvp" or kind == "arena" then return false, true end
  local z = ns.Settings().zones
  if kind == "party" then return z.dungeon end
  if kind == "raid" then return z.raid end
  return z.world
end

-- ---------------------------------------------------------------- refresh fan-out

-- One healer changed (mana event, buff, state).
function ns.UpdateHealer(h)
  if ns.Frames then ns.Frames.Update(h) end
  if ns.Flask then ns.Flask.Update() end
  if ns.Vignette then ns.Vignette.Update() end
end

-- Roster, combat or zone changed.
function ns.UpdateAll()
  if ns.Frames then ns.Frames.UpdateAll() end
  if ns.Flask then ns.Flask.Update() end
  if ns.Vignette then ns.Vignette.Update() end
  if ns.Banner then ns.Banner.Refresh() end
  if ns.Button then ns.Button.Refresh() end
end

-- A setting changed: rebuild the curves and repaint everything.
function ns.Apply()
  if ns.Curves then ns.Curves.Rebuild() end
  ns.Roster.Refresh()
  if ns.RefreshGhosts then ns.RefreshGhosts() end
  if ns.RefreshOptions then ns.RefreshOptions() end
end

-- ---------------------------------------------------------------- slash commands

-- /sot levels 50 30 10
local function setLevels(rest)
  local a, b, c = rest:match("^(%d+)%s+(%d+)%s+(%d+)$")
  if not a then return ns.Print(L.LEVELS_USAGE) end
  local wanted = { tonumber(a), tonumber(b), tonumber(c) }
  local ok, why = ns.Levels.Validate({ { pct = wanted[1] }, { pct = wanted[2] }, { pct = wanted[3] } })
  if not ok then return ns.Print(why == "RANGE" and L.LEVELS_BAD_RANGE or L.LEVELS_BAD_ORDER) end
  for i, lv in ipairs(ns.Settings().levels) do lv.pct = wanted[i] end
  ns.Print(L.LEVELS_SET:format(wanted[1], wanted[2], wanted[3]))
  ns.Apply()
end

local function setEnabled(on)
  ns.Settings().enabled = on
  ns.Apply()
  ns.Print(on and L.ENABLED or L.DISABLED)
end

-- /sot flask | banner | glow: switch one indicator on or off.
local function toggle(key, name)
  return function()
    local group = ns.Settings()[key]
    group.enabled = not group.enabled
    ns.Print((group.enabled and L.TOGGLE_ON or L.TOGGLE_OFF):format(name))
    ns.Apply()
  end
end

local function setPlacing(on)
  ns.unlocked = on
  ns.UpdateAll()
  ns.Print(on and L.MOVE_ON or L.MOVE_OFF)
end

local function openOptions()
  if ns.ToggleOptions then return ns.ToggleOptions() end
  ns.PrintStatus()
end

local DEBUG = { drink = "DebugDrink", looks = "DebugLooks", party = "DebugLooks", frames = "DebugFrames", icons = "DebugIcons" }

local COMMANDS = {
  help = function() for _, line in ipairs(L.HELP) do DEFAULT_CHAT_FRAME:AddMessage(line) end end,
  on = function() setEnabled(true) end,
  off = function() setEnabled(false) end,
  options = openOptions,
  levels = setLevels,
  drink = function() ns.Button.Say("thirsty") end,
  ready = function() ns.Button.Say("ready") end,
  macro = function() ns.Button.MakeMacros() end,
  bar = toggle("bar", L.TAB_BAR),
  pips = toggle("pips", L.TAB_PIPS),
  flask = toggle("flask", L.TAB_FLASK),
  banner = toggle("banner", L.TAB_BANNER),
  glow = toggle("vignette", L.TAB_GLOW),
  move = function() setPlacing(true) end,
  lock = function() setPlacing(false) end,
  test = function()
    if ns.PlayPreview then return ns.PlayPreview() end
    ns.Print(L.TEST_UNAVAILABLE)
  end,
  ghost = function(rest)
    local n = tonumber(rest)
    if not n or n < 0 or n > 100 then return ns.Print(L.GHOST_USAGE) end
    ns.Settings().ghost = math.floor(n)
    if ns.RefreshGhosts then ns.RefreshGhosts() end
    ns.Print(L.GHOST_SET:format(math.floor(n)))
  end,
  status = function() ns.PrintStatus() end,
  minimap = function()
    if ns.ToggleMinimap then ns.ToggleMinimap() end
  end,
  debug = function(rest)
    if rest == "events" then
      local s = ns.Settings()
      s.debugEvents = not s.debugEvents
      return ns.Print(s.debugEvents and L.DEBUG_EVENTS_ON or L.DEBUG_EVENTS_OFF)
    end
    local fn = ns[DEBUG[rest] or "Debug"]
    if fn then fn() end
  end,
}

-- Key Bindings > AddOns (Bindings.xml).
BINDING_HEADER_SOTHIRSTY = L.ADDON
BINDING_NAME_SOTHIRSTY_DRINK = L.M_DRINK
BINDING_NAME_SOTHIRSTY_READY = L.M_READY

SLASH_SOTHIRSTY1 = "/sot"
SLASH_SOTHIRSTY2 = "/thirsty"
function ns.RunCommand(input)
  local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" then cmd = "options" end
  local fn = COMMANDS[cmd]
  if not fn then return ns.Print(L.UNKNOWN_COMMAND:format(cmd)) end
  fn(rest)
end
SlashCmdList.SOTHIRSTY = ns.RunCommand

-- ---------------------------------------------------------------- addon compartment

function SoThirsty_OnAddonCompartmentClick(_, mouse, menuButton)
  if ns.MinimapClick then return ns.MinimapClick(mouse, menuButton) end
  openOptions()
end
function SoThirsty_OnAddonCompartmentEnter(_, menuButton)
  GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
  GameTooltip:AddLine(L.ADDON)
  local lines = ns.StatusLines()
  if #lines == 0 then GameTooltip:AddLine(L.TIP_NO_HEALERS, 0.66, 0.64, 0.6) end
  for _, line in ipairs(lines) do GameTooltip:AddLine(line, 1, 1, 1) end
  GameTooltip:AddLine(L.TIP_CLICK, 0.31, 0.76, 0.97)
  GameTooltip:Show()
end
function SoThirsty_OnAddonCompartmentLeave() GameTooltip:Hide() end

-- ---------------------------------------------------------------- startup

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name == addonName then
    local db = SoThirstyDB or {}
    -- Settings v1-v3 carried looks, motion, a meter and sounds that no longer exist.
    if db.settings and (db.version or 1) < DB_VERSION then db.settings = ns.Levels.Migrate(db.settings) end
    db.version = DB_VERSION
    SoThirstyDB = applyDefaults(db, DB_DEFAULTS)
    if ns.Curves then ns.Curves.Rebuild() end
    ns.Combat.Start()
    ns.Roster.Start()
    if ns.SetupMinimap then ns.SetupMinimap() end
    if ns.RegisterOptions then pcall(ns.RegisterOptions) end
    if not SoThirstyDB.welcomed then
      SoThirstyDB.welcomed = true
      C_Timer.After(6, function() ns.Print(L.WELCOME) end)
    end
    self:UnregisterEvent("ADDON_LOADED")
  end
end)
