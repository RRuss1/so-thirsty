std = "lua51"
max_line_length = 140
-- Player-facing sentences are kept on one line each.
files["addon/SoThirsty/Locales/"] = { max_line_length = 200 }

-- The test runner stubs the WoW API as globals.
files["addon/tests/"] = { std = "lua51+luajit", allow_defined_top = true, allow_defined = true,
  -- The stubs are read by the addon files under test, not by the test file itself.
  ignore = { "131", "121", "122" } }

-- Globals the addon sets.
globals = {
  "SoThirstyDB", "SLASH_SOTHIRSTY1", "SLASH_SOTHIRSTY2", "SlashCmdList",
  -- addon compartment callbacks named in the TOC
  "BINDING_HEADER_SOTHIRSTY", "BINDING_NAME_SOTHIRSTY_DRINK", "BINDING_NAME_SOTHIRSTY_READY",
  "SoThirsty_OnAddonCompartmentClick", "SoThirsty_OnAddonCompartmentEnter", "SoThirsty_OnAddonCompartmentLeave",
}

-- WoW API the addon reads. Keep this list accurate (spec 13).
read_globals = {
  -- frames & UI
  "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "DEFAULT_CHAT_FRAME", "tinsert", "CLOSE",
  "RAID_CLASS_COLORS", "ColorPickerFrame",
  -- units
  "UnitExists", "UnitGUID", "UnitName", "UnitClass", "UnitIsUnit", "UnitGroupRolesAssigned", "UnitIsDeadOrGhost",
  "UnitIsConnected", "UnitPower", "UnitPowerMax", "UnitPowerType", "UnitAffectingCombat", "UnitInRange",
  "UnitIsGroupLeader", "UnitAura", "C_UnitAuras", "issecretvalue", "Enum", "UnitHealth", "UnitHealthMax",
  -- group, world & client
  "IsInGroup", "IsInRaid", "IsInInstance", "LE_PARTY_CATEGORY_INSTANCE", "InCombatLockdown",
  "GetBuildInfo", "WOW_PROJECT_ID", "C_Timer", "C_CurveUtil", "GetTime",
  -- chat (the drink button only, spec 8.2)
  "C_ChatInfo", "SendChatMessage",
  -- minimap button and menu
  "Minimap", "GetCursorPosition", "MenuUtil",
  -- macros (/sot macro)
  "CreateMacro", "GetMacroIndexByName", "PickupMacro",
}
