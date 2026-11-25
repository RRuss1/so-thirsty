-- Startup, SavedVariables and slash commands.
local addonName, ns = ...
local L = ns.L

-- Spec 12.1. Account-wide; there's no per-character DB in v1.
local DB_DEFAULTS = {
  version = 1,
  settings = {
    enabled = true,
    -- color: {r, g, b, a} from the color picker; out: the output grid row (spec 9.1).
    levels = {
      { enabled = true, pct = 50, color = { 1, 0.82, 0, 1 },
        out = { frame = true, screen = true, party = false, raid = false, instance = false, sound = false } },
      { enabled = true, pct = 30, color = { 1, 0.5, 0, 1 },
        out = { frame = true, screen = true, party = true, raid = false, instance = true, sound = false } },
      { enabled = true, pct = 10, color = { 1, 0.125, 0.125, 1 },
        out = { frame = true, screen = true, party = true, raid = true, instance = true, sound = true } },
    },
    ready = { enabled = true, pct = 90, color = { 0.25, 1, 0.25, 1 },
      out = { frame = true, screen = true, party = false, raid = false, instance = false, sound = false } },
    rearmMargin = 5,
    settleSeconds = 10,
    drinkRise = 10,
    quietAfterWipe = true,
    combatScope = "group",          -- "group" | "me"
    announceMode = "group",         -- "group" | "self" | "local"
    announceMe = true,
    chat = { prefix = true },
    onScreen = {
      mode = "all",                 -- "all" | "tank" | "off" (always our banner; never raid warnings)
      self = false,
      scale = 100, hold = 4, sameSize = false,
      bgColor = { 0.08, 0.05, 0.1, 0.85 }, borderColor = { 0.62, 0.3, 1, 1 },
    },
    frames = { enabled = true, badge = true, showDrinking = true },
    look = {
      palette = "classic",
      drinkColor = { 0.31, 0.76, 0.97, 1 },
      prefixColor = { 0.31, 0.76, 0.97, 1 },
      style = "glow", thickness = 2, alpha = 80,
      pulse = "L3", pulseSpeed = "normal",
      badgeContent = "pct", badgePos = "TOPRIGHT", badgeSize = "medium",
      icon = "drop",
      ghost = 25,                   -- the faint greyscale icon behind window content, 0-100 % (0 = off)
    },
    highlightInCombat = "hide",     -- "hide" | "freeze"
    sound = { enabled = true, channel = "Master", tankAll = true, levels = { "none", "none", "alert" }, ready = "none" },
    zones = { dungeon = true, raid = true, world = false },
    roleHint = true,
    debugEvents = false,
  },
}

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

-- Midnight-era clients hide some unit data as "secret values" (spec Section 2). Never do math
-- or comparisons on one: check with this first.
function ns.IsSecret(v)
  return issecretvalue ~= nil and v ~= nil and issecretvalue(v) == true
end

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(L.PREFIX .. tostring(msg))
end

-- The group chat channel a line would go to (spec 8.3). Never SAY, YELL or RAID_WARNING.
-- Returns the channel and the per-level key ("party" | "raid" | "instance"), or nil when solo.
function ns.ChatChannel()
  if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT", "instance" end
  if IsInRaid() then return "RAID", "raid" end
  if IsInGroup() then return "PARTY", "party" end
  return nil
end

-- ---------------------------------------------------------------- slash commands

-- /sot levels 50 30 10
local function setLevels(rest)
  local a, b, c = rest:match("^(%d+)%s+(%d+)%s+(%d+)$")
  if not a then return ns.Print(L.LEVELS_USAGE) end
  local wanted = { tonumber(a), tonumber(b), tonumber(c) }
  local list = {}
  for i, lv in ipairs(ns.Settings().levels) do list[i] = { enabled = lv.enabled, pct = wanted[i] } end
  local ok, why = ns.Levels.Validate(list)
  if not ok then return ns.Print(why == "RANGE" and L.LEVELS_BAD_RANGE or L.LEVELS_BAD_ORDER) end
  for i, lv in ipairs(ns.Settings().levels) do lv.pct = wanted[i] end
  ns.Print(L.LEVELS_SET:format(wanted[1], wanted[2], wanted[3]))
  ns.Roster.Refresh()
end

local COMMANDS = {
  help = function() for _, line in ipairs(L.HELP) do DEFAULT_CHAT_FRAME:AddMessage(line) end end,
  on = function()
    ns.Settings().enabled = true
    ns.Roster.Refresh()
    ns.Print(L.ENABLED)
  end,
  off = function()
    ns.Settings().enabled = false
    ns.Roster.Refresh()
    ns.Print(L.DISABLED)
  end,
  levels = setLevels,
  ghost = function(rest)
    local n = tonumber(rest)
    if not n or n < 0 or n > 100 then return ns.Print(L.GHOST_USAGE) end
    ns.Settings().look.ghost = math.floor(n)
    if ns.RefreshGhosts then ns.RefreshGhosts() end
    ns.Print(L.GHOST_SET:format(math.floor(n)))
  end,
  status = function() ns.PrintStatus() end,
  debug = function(rest)
    if rest == "drink" then return ns.DebugDrink() end
    if rest == "window" then return ns.DebugWindow() end
    if rest == "mana" then return ns.DebugMana() end
    if rest == "curve" then return ns.DebugCurve() end
    if rest == "events" then
      local s = ns.Settings()
      s.debugEvents = not s.debugEvents
      return ns.Print(s.debugEvents and L.DEBUG_EVENTS_ON or L.DEBUG_EVENTS_OFF)
    end
    ns.Debug()
  end,
}

SLASH_SOTHIRSTY1 = "/sot"
SLASH_SOTHIRSTY2 = "/thirsty"
function ns.RunCommand(input)
  local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" then cmd = "status" end -- opens Options once that window exists (Phase 6)
  local fn = COMMANDS[cmd]
  if not fn then return ns.Print(L.UNKNOWN_COMMAND:format(cmd)) end
  fn(rest)
end
SlashCmdList.SOTHIRSTY = ns.RunCommand

-- ---------------------------------------------------------------- addon compartment

function SoThirsty_OnAddonCompartmentClick() ns.PrintStatus() end
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
    SoThirstyDB = applyDefaults(SoThirstyDB or {}, DB_DEFAULTS)
    ns.Roster.Start()
    if not SoThirstyDB.welcomed then
      SoThirstyDB.welcomed = true
      C_Timer.After(6, function() ns.Print(L.WELCOME) end)
    end
    self:UnregisterEvent("ADDON_LOADED")
  end
end)
