-- All player-facing text (design spec Section 13). Translations go in Locales/<locale>.lua.
local _, ns = ...

ns.L = {
  ADDON = "So Thirsty",
  PREFIX = "|cff4fc3f7So Thirsty:|r ",

  -- slash
  HELP = {
    "|cff4fc3f7So Thirsty|r: tells your group when the healer is low on mana, out of combat. Commands (/sot or /thirsty):",
    "  /sot status: healers being watched, their mana and whether they're drinking",
    "  /sot on | off: turn So Thirsty on or off",
    "  /sot levels 50 30 10: set the three warning levels (each lower than the last)",
    "  /sot ghost 25: how strongly the faint waterskin shows behind windows (0 = off, 100 = full)",
    "  /sot debug: print what the game tells the addon (for bug reports)",
    "  /sot debug drink: what buffs each healer has, and whether one counts as drinking",
    "  /sot debug mana: try every way the game offers to read mana (paste this into bug reports)",
    "  /sot debug curve: test whether hidden mana can still drive a color or a fade",
    "  /sot debug swatch: live preview of your own mana as a color and a fade (spend mana and watch)",
    "  /sot debug events: print role and combat events as they happen (on/off)",
    "  /sot debug window: open a sample window (checks the look and the game textures it uses)",
    "  /sot help: this list",
  },
  UNKNOWN_COMMAND = "Unknown command \"%s\". Type /sot help.",
  ENABLED = "On. Watching healers' mana.",
  DISABLED = "Off. Type /sot on to turn it back on.",
  WELCOME = "Loaded. Only one person in the group needs it. Type /sot help for commands.",

  -- /sot levels
  LEVELS_USAGE = "Usage: /sot levels 50 30 10 (three numbers from 1 to 99, each lower than the last).",
  LEVELS_SET = "Warning levels set: %d%%, %d%%, %d%%.",
  LEVELS_BAD_RANGE = "Each level must be a number from 1 to 99.",
  LEVELS_BAD_ORDER = "Each level must be lower than the one before it (for example 50 30 10).",

  -- /sot ghost
  GHOST_USAGE = "Usage: /sot ghost 25 (0 to 100; 0 turns the background ghost off).",
  GHOST_SET = "Window background ghost: %d%%. Open /sot debug window to see it.",

  -- /sot status
  STATUS_OFF = "So Thirsty is off (/sot on).",
  STATUS_SOLO = "You're not in a group, so there's no healer to watch.",
  STATUS_NONE = "No one in your group has the Healer role. Right-click the healer's portrait > Set Role.",
  STATUS_HEADER = "Watching %d healer(s):",
  STATUS_LINE = "  %s: %s%s%s",
  STATUS_MANA = "%d%% mana",
  STATUS_UNKNOWN = "mana hidden by the game",
  STATUS_DEAD = "dead",
  STATUS_OFFLINE = "offline",
  STATUS_LEVEL = " · level %d (below %d%%)",
  STATUS_DRINKING = " · drinking",
  STATUS_COMBAT = "Your group is in combat; warnings wait until it's over.",

  -- role hint (spec 5)
  ROLE_HINT = "No healer role set — right-click the healer's portrait > Set Role, so So Thirsty knows whose mana to watch.",

  -- debug
  DEBUG_HEADER = "debug (paste this into bug reports)",
  DEBUG_DRINK_HEADER = "debug drink (run it while a healer drinks, and again while they don't)",
  DEBUG_DRINK_NONE = "No healers to check. Set someone's role to Healer first.",
  DEBUG_MANA_HEADER = "debug mana (run it out of combat, in a group; paste the whole thing back)",
  DEBUG_CURVE_HEADER = "debug curve (can a hidden mana value still drive a color or a fade?)",
  SWATCH_HELP = "Spend some mana and watch. Left square: green at full, yellow at half, red when empty. Middle square: appears below 90% mana. Bar: your mana, for comparison. Tell us whether the squares change as the bar drops.",
  SWATCH_MISSING = "This client doesn't have the curve functions the swatch needs.",
  DEBUG_EVENTS_ON = "Event debug on: role and combat events will print here. /sot debug events again to stop.",
  DEBUG_EVENTS_OFF = "Event debug off.",
  SAMPLE_HEAD = "Sample window",
  SAMPLE_BODY = "This is how So Thirsty's windows will look: violet-lit stone, a violet glow, candle-gold titles and brass edges. The Options window (coming later) uses this same frame.",
  SAMPLE_MUTED = "If the background is blank, black or bright green, a game texture is missing on this client. Please report it.",
  SAMPLE_CHECK = "A Blizzard check box, for scale",

  -- compartment tooltip
  TIP_CLICK = "Click: healer status",
  TIP_NO_HEALERS = "No healers being watched.",

  -- Drink buffs, matched by name on each healer (spec 6.4). Add more as /sot debug drink finds them.
  DRINK_AURAS = { "Drink", "Food & Drink", "Refreshment" },
}
