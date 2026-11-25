-- Startup, SavedVariables and slash commands.
local addonName, ns = ...
local L = ns.L

-- Spec 12.1 (design v2). Account-wide.
local DB_VERSION = 2
local DB_DEFAULTS = {
  settings = {
    enabled = true,
    -- The three level colors are anchors; the bands between them are blended (spec 6.1).
    levels = {
      { pct = 50, color = { 1, 0.82, 0, 1 } },
      { pct = 30, color = { 1, 0.5, 0, 1 } },
      { pct = 10, color = { 1, 0.125, 0.125, 1 } },
    },
    ready = { pct = 90, color = { 0.25, 1, 0.25, 1 } },
    nudge = true, nudgeDelay = 5, nudgeHold = 3,
    quietAfterWipe = true,
    combatScope = "group",          -- "group" | "me"
    frames = { enabled = true, drop = true, readyTick = false, rangeFade = false },
    look = {
      palette = "classic",          -- "classic" | "water" | "colorblind" | "custom"
      bands = "smooth",             -- "smooth" | "steps"
      strength = true, alpha = 80, faint = 35,
      rest = 70,                    -- resting brightness; the nudge lifts it to 100 for a moment
      drinkDim = 35,
      combat = "hide",              -- "hide" | "faint"
      pulse = true, pulseSpeed = "normal",
      style = "glow",               -- "glow" | "border" | "corners" | "tint" | "bar"
      thickness = 2,
      icon = "drop",
      drinkColor = { 0.31, 0.76, 0.97, 1 },
      greyColor = { 0.6, 0.6, 0.6, 0.6 },
      ghost = 25,                   -- the faint greyscale icon behind window content, 0-100 %
    },
    button = {
      show = "healer",              -- "healer" | "always" | "never"
      party = true, raid = true, instance = true,
      prefix = true,
    },
    meter = { enabled = false, scale = 100 },
    zones = { dungeon = true, raid = true, world = true },
    roleHint = true,
    minimap = { hide = false, angle = 215 },
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

function ns.Settings() return SoThirstyDB.settings end

-- Mana, health and range are always secret on Forever (spec Section 2). Never compare, test
-- or do math on a secret: check with this first.
function ns.IsSecret(v)
  return issecretvalue ~= nil and v ~= nil and issecretvalue(v) == true
end

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(L.PREFIX .. tostring(msg))
end

-- The group chat channel the drink button would use (spec 8.2). Never SAY, YELL or
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
  if ns.Meter then ns.Meter.Update() end
end

-- Roster, combat or zone changed.
function ns.UpdateAll()
  if ns.Frames then ns.Frames.UpdateAll() end
  if ns.Meter then ns.Meter.Update() end
  if ns.Button then ns.Button.Refresh() end
end

-- A setting changed: rebuild the curves and repaint everything.
function ns.Apply()
  if ns.Curves then ns.Curves.Rebuild() end
  if ns.Frames then ns.Frames.Restyle() end
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
  local s = ns.Settings()
  local ok, why = ns.Levels.Validate({ { pct = wanted[1] }, { pct = wanted[2] }, { pct = wanted[3] } }, s.ready)
  if not ok then
    return ns.Print(why == "RANGE" and L.LEVELS_BAD_RANGE or why == "READY" and L.LEVELS_BAD_READY:format(s.ready.pct)
      or L.LEVELS_BAD_ORDER)
  end
  for i, lv in ipairs(s.levels) do lv.pct = wanted[i] end
  ns.Print(L.LEVELS_SET:format(wanted[1], wanted[2], wanted[3]))
  ns.Apply()
end

local function setEnabled(on)
  ns.Settings().enabled = on
  ns.Apply()
  ns.Print(on and L.ENABLED or L.DISABLED)
end

local function openOptions()
  if ns.ToggleOptions then return ns.ToggleOptions() end
  ns.PrintStatus()
end

local DEBUG = {
  drink = "DebugDrink", window = "DebugWindow", mana = "DebugMana", curve = "DebugCurve", swatch = "DebugSwatch",
  party = "DebugParty", frames = "DebugFrames", icons = "DebugIcons",
}

local COMMANDS = {
  help = function() for _, line in ipairs(L.HELP) do DEFAULT_CHAT_FRAME:AddMessage(line) end end,
  on = function() setEnabled(true) end,
  off = function() setEnabled(false) end,
  options = openOptions,
  levels = setLevels,
  drink = function() ns.Button.Say("thirsty") end,
  ready = function() ns.Button.Say("ready") end,
  meter = function()
    local m = ns.Settings().meter
    m.enabled = not m.enabled
    ns.Print(m.enabled and L.METER_ON or L.METER_OFF)
    ns.Apply()
  end,
  move = function()
    ns.unlocked = true
    ns.UpdateAll()
    ns.Print(L.MOVE_ON)
  end,
  lock = function()
    ns.unlocked = false
    ns.UpdateAll()
    ns.Print(L.MOVE_OFF)
  end,
  test = function()
    if ns.PlayPreview then return ns.PlayPreview() end
    ns.Print(L.TEST_UNAVAILABLE)
  end,
  ghost = function(rest)
    local n = tonumber(rest)
    if not n or n < 0 or n > 100 then return ns.Print(L.GHOST_USAGE) end
    ns.Settings().look.ghost = math.floor(n)
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
      ns.Roster.Refresh()
      return ns.Print(s.debugEvents and L.DEBUG_EVENTS_ON or L.DEBUG_EVENTS_OFF)
    end
    local fn = ns[DEBUG[rest] or "Debug"]
    if fn then fn() end
  end,
}

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
    -- Design v1 kept an output grid, sounds and a banner; v2 keeps levels, colors and look.
    if db.settings and db.version ~= DB_VERSION then db.settings = ns.Levels.Migrate(db.settings) end
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
