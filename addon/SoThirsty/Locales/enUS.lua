-- All player-facing text (design spec Section 13). Translations go in Locales/<locale>.lua.
local _, ns = ...

ns.L = {
  ADDON = "So Thirsty",
  PREFIX = "|cff4fc3f7So Thirsty:|r ",
  CHAT_TAG = "[Thirsty]",

  -- slash
  HELP = {
    "|cff4fc3f7So Thirsty|r: shows when your healer is low on mana, out of combat. Commands (/sot or /thirsty):",
    "  /sot: open the options window",
    "  /sot status: the healers being watched",
    "  /sot on | off: turn So Thirsty on or off",
    "  /sot levels 50 30 10: set the three levels (each lower than the last)",
    "  /sot bar | pips | flask | banner | glow: switch one indicator on or off",
    "  /sot drink | ready: post \"I need a drink\" or \"good to go\" to your group (same as the button)",
    "  /sot macro: make action-bar macros for those two lines (or bind keys under Key Bindings > AddOns)",
    "  /sot move | lock: show the flask, banner and drink button so you can drag them into place",
    "  /sot test: play the preview (nothing is posted to chat)",
    "  /sot ghost 35: how strongly the art shows behind windows (0 = off)",
    "  /sot minimap: show or hide the minimap button",
    "  /sot debug | debug looks | debug frames | debug drink | debug icons: in-game checks for bug reports",
    "  /sot help: this list",
  },
  UNKNOWN_COMMAND = "Unknown command \"%s\". Type /sot help.",
  ENABLED = "On. Watching your healers.",
  DISABLED = "Off. Type /sot on to turn it back on.",
  WELCOME = "Loaded. A healer low on mana shows on their frame and as a flask, out of combat. Type /sot for options.",
  TEST_UNAVAILABLE = "The preview isn't available.",
  TOGGLE_ON = "%s: on.",
  TOGGLE_OFF = "%s: off.",

  -- /sot levels
  LEVELS_USAGE = "Usage: /sot levels 50 30 10 (three numbers from 1 to 99, each lower than the last).",
  LEVELS_SET = "Levels set: %d%%, %d%%, %d%%.",
  LEVELS_BAD_RANGE = "Each level must be a number from 1 to 99.",
  LEVELS_BAD_ORDER = "Each level must be lower than the one before it (for example 50 30 10).",

  -- /sot ghost, move
  GHOST_USAGE = "Usage: /sot ghost 35 (0 to 100; 0 turns the background art off).",
  GHOST_SET = "Window background art: %d%%.",
  MOVE_ON = "Placing: the flask, the banner and the drink button are showing. Drag them, then type /sot lock.",
  MOVE_OFF = "Done placing.",

  -- /sot status
  STATUS_OFF = "So Thirsty is off (/sot on).",
  STATUS_SOLO = "You're not in a group, so there's no healer to watch.",
  STATUS_NONE = "No one in your group has the Healer role. Right-click the healer's portrait > Set Role.",
  STATUS_HEADER = "Watching %d healer(s). Mana shows as color; the game hides the number from addons.",
  STATUS_LINE = "  %s: %s",
  STATUS_WATCHING = "watching",
  STATUS_DEAD = "dead",
  STATUS_OFFLINE = "offline",
  STATUS_DRINKING = "drinking",
  STATUS_COMBAT = "Your group is in combat; the indicators are hidden until it's over.",
  STATUS_ZONE = "So Thirsty is switched off for this kind of zone (see Options > General).",

  -- role hint (spec 5)
  ROLE_HINT = "No healer role set — right-click the healer's portrait > Set Role, so So Thirsty knows whose mana to watch.",

  -- the drink button (spec 8.6)
  MSG_THIRSTY = "{name} needs a drink - hold the pull",
  MSG_READY = "{name} is good to go",
  BTN_TITLE = "So Thirsty",
  BTN_TIP_LEFT = "Left-click: tell the group you need a drink",
  BTN_TIP_RIGHT = "Right-click: tell the group you're good to go",
  BTN_TIP_DRAG = "Drag to move",
  BTN_OFF = "So Thirsty is off (/sot on).",
  BTN_SOLO = "You're not in a group.",
  BTN_PVP = "So Thirsty stays quiet in battlegrounds and arenas.",
  BTN_COMBAT = "Not in combat. Try again when the fight is over.",
  BTN_CHANNEL_OFF = "Posting to %s is switched off (Options > Drink button).",
  BTN_COOLDOWN = "You just posted. Give it 15 seconds.",
  BTN_CAP = "That's 3 lines in 5 minutes. So Thirsty is staying quiet for a bit.",
  CHANNEL_party = "Post in party chat",
  CHANNEL_raid = "Post in raid chat",
  CHANNEL_instance = "Post in instance chat",
  MACRO_DONE = "Made the macros \"SoT Drink\" and \"SoT Ready\". The drink one is on your cursor: drop it on an action bar. Both are in /macro.",
  MACRO_COMBAT = "Macros can only be made out of combat.",
  MACRO_FULL = "Your macro list is full. Delete one in /macro and try again.",
  MACRO_UNAVAILABLE = "This client would not let the addon make macros. Make one by hand with the text /sot drink.",

  -- options: tabs (also the indicator names)
  TAB_LEVELS = "Levels",
  TAB_BAR = "Mana bar",
  TAB_PIPS = "Pips",
  TAB_FLASK = "Flask",
  TAB_BANNER = "Banner",
  TAB_GLOW = "Screen glow",
  TAB_BUTTON = "Drink button",
  TAB_GENERAL = "General",

  -- options: shared
  OPT_ON = "Show this",
  OPT_SIZE = "Size",
  OPT_RESET = "Reset",
  OPT_PLACE = "Show it to place it",
  SIZES = { small = "Small", medium = "Medium", large = "Large" },
  SECONDS = { [3] = "3 seconds", [5] = "5 seconds", [8] = "8 seconds", [10] = "10 seconds" },

  -- options: levels
  OPT_LEVEL1 = "Level 1: getting thirsty",
  OPT_LEVEL2 = "Level 2: thirsty",
  OPT_LEVEL3 = "Level 3: so thirsty",
  OPT_PALETTE = "Color preset",
  PALETTES = { classic = "Classic", water = "Water", colorblind = "Color-blind safe", custom = "Custom" },
  NOTE_LEVELS = "Nothing shows above level 1. Below it, every indicator uses these colors, blending from one level to the next.",

  -- options: the indicators
  OPT_OPACITY = "Opacity",
  NOTE_BAR = "Recolors the healer's own mana bar on their party or raid frame: yellow, orange, then red. Needs party frames showing.",
  OPT_CORNER = "Corner",
  CORNERS = { TOPRIGHT = "Top right", TOPLEFT = "Top left", BOTTOMRIGHT = "Bottom right", BOTTOMLEFT = "Bottom left" },
  NOTE_PIPS = "Three dots on the healer's frame: one below level 1, two below level 2, three below level 3. Needs party frames showing.",
  OPT_FLASK_WHEN_LOW = "Hide it while their mana is fine",
  OPT_FLASK_NAMES = "Show the healer's name under it",
  NOTE_FLASK = "A flask per healer, anywhere on your screen: a mana bar you can read at a glance. The liquid drains with their mana; the edge goes from their class color to the level colors.",
  OPT_BANNER_DELAY = "How long after the fight",
  OPT_BANNER_HOLD = "How long it stays",
  NOTE_BANNER = "Once after each fight, a low healer's name appears in their level color. Skipped on chain pulls, after a wipe, and for a healer who's drinking.",
  OPT_GLOW_STRENGTH = "Strength",
  OPT_GLOW_WIDTH = "Width",
  WIDTHS = { thin = "Thin", medium = "Medium", wide = "Wide" },
  OPT_GLOW_CUSTOM = "Use one color of my own",
  OPT_GLOW_COLOR = "My color",
  NOTE_GLOW = "A soft haze on the edges of your screen as a healer runs dry. It uses the level colors unless you pick your own. Off unless you turn it on.",

  -- options: drink button
  OPT_BUTTON_SHOW = "Show the button",
  BUTTON_SHOW = { healer = "When I'm the healer", always = "Whenever I'm grouped", never = "Never" },
  OPT_PREFIX = "Start the line with [Thirsty]",
  OPT_LINE_THIRSTY = "Need a drink",
  OPT_LINE_READY = "Good to go",
  OPT_LINE_PREVIEW = "A left-click would post:  %s",
  OPT_MACRO = "Make action-bar macros",
  NOTE_BUTTON = "The only way So Thirsty posts to chat: one line per click, 15 seconds apart, 3 per 5 minutes, never in combat. Empty line = default.",

  -- options: general
  OPT_ENABLED = "So Thirsty is on",
  OPT_ZONE_DUNGEON = "Run in dungeons",
  OPT_ZONE_RAID = "Run in raids",
  OPT_ZONE_WORLD = "Run in the open world",
  OPT_COMBAT_SCOPE = "Counts as \"in combat\"",
  COMBAT_SCOPE = { group = "Anyone in my group", me = "Only me" },
  OPT_ROLE_HINT = "Remind me (as leader) when nobody has the Healer role",
  OPT_MINIMAP = "Minimap button",
  OPT_GHOST = "Window background art",
  OPT_RESET_ALL = "Reset all",
  OPT_RESET_DONE = "All settings are back to their defaults. Press Save to keep that.",
  OPT_DEBUG = "Debug info",
  OPT_OPEN = "Open So Thirsty options",

  -- options: save
  OPT_SAVE = "Save",
  OPT_REVERT = "Undo changes",
  OPT_UNSAVED = "Unsaved changes. Closing without Save undoes them.",
  OPT_ALL_SAVED = "All changes saved.",
  OPT_SAVED = "Settings saved.",
  OPT_REVERTED = "Changes undone.",
  OPT_DISCARDED = "Options closed without Save: your changes were undone.",

  -- options: preview
  PREVIEW = "Preview",
  PREVIEW_NAME = "Healer",
  PREVIEW_MANA = "Mana",
  PREVIEW_DRINK = "Drinking",
  PREVIEW_PLAY = "Play",

  -- minimap button and its menu
  MINIMAP_TIP = { "Left-click: options", "Right-click: menu of commands", "Drag: move this button" },
  MINIMAP_HIDDEN = "Minimap button hidden. /sot minimap brings it back.",
  MINIMAP_SHOWN = "Minimap button shown.",
  M_OPTIONS = "Options",
  M_DRINK = "I need a drink",
  M_READY = "Good to go",
  M_MACRO = "Make action-bar macros",
  M_ENABLED = "So Thirsty is on",
  M_PLACE = "Show the flask, banner and button to place them",
  M_TEST = "Play the preview",
  M_STATUS = "Healer status",
  M_HELP = "Command list",
  M_HIDE = "Hide minimap button",
  M_DEBUG = "Debug",
  M_DEBUG_INFO = "Debug info",
  M_DEBUG_LOOKS = "Check the indicators on group members",
  M_DEBUG_FRAMES = "Check unit frames",
  M_DEBUG_DRINK = "Check drink buffs",
  M_DEBUG_ICONS = "Check icons",

  -- debug
  DEBUG_HEADER = "debug (paste this into bug reports)",
  DEBUG_DRINK_HEADER = "debug drink (run it while a healer drinks, and again while they don't)",
  DEBUG_DRINK_NONE = "No healers to check. Set someone's role to Healer first.",
  DEBUG_LOOKS_HEADER = "debug looks (run it in a group, out of combat; paste the whole thing back)",
  DEBUG_LOOKS_FOOT = "Done. Please paste this back.",
  DEBUG_FRAMES_HEADER = "debug frames (which unit frame each indicator sits on)",
  DEBUG_ICONS_NOTE = "Game art the addon borrows. If one is blank or bright green, this client doesn't have it. Please report which.",
  DEBUG_EVENTS_ON = "Event debug on: roster and combat changes will print here. /sot debug events again to stop.",
  DEBUG_EVENTS_OFF = "Event debug off.",

  -- compartment tooltip
  TIP_CLICK = "Click: options. Right-click: menu.",
  TIP_NO_HEALERS = "No healers being watched.",

  -- Drink buffs, matched by name on each healer (spec 6.4). Add more as /sot debug drink finds them.
  DRINK_AURAS = { "Drink", "Food & Drink", "Refreshment" },
}
