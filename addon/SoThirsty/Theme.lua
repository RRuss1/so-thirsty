-- Look data (spec 9): palettes, styles, icons, presets. Data only.
local _, ns = ...

local MEDIA = "Interface\\AddOns\\SoThirsty\\Media\\"

ns.Theme = {
  MEDIA = MEDIA,
  -- Level 1, 2, 3 and Ready colors (spec 9.2).
  PALETTE_ORDER = { "classic", "water", "colorblind" },
  PALETTES = {
    classic = { { 1, 0.82, 0, 1 }, { 1, 0.5, 0, 1 }, { 1, 0.125, 0.125, 1 }, ready = { 0.25, 1, 0.25, 1 } },
    water = { { 0.61, 0.91, 1, 1 }, { 0.31, 0.76, 0.97, 1 }, { 0.48, 0.31, 0.97, 1 }, ready = { 1, 1, 1, 1 } },
    colorblind = { { 0.94, 0.89, 0.26, 1 }, { 0.9, 0.62, 0, 1 }, { 0.8, 0.47, 0.65, 1 }, ready = { 0.34, 0.71, 0.91, 1 } },
  },
  STYLES = { "glow", "border", "corners", "tint", "bar" },
  PULSE_SECONDS = { slow = 1.6, normal = 1.0, fast = 0.6 },
  PULSE_ORDER = { "slow", "normal", "fast" },
  -- Game icons (spec 9.7); /sot debug icons shows them.
  ICON_ORDER = { "drop", "cup", "logo" },
  ICONS = {
    drop = "Interface\\Icons\\INV_Drink_07",
    cup = "Interface\\Icons\\INV_Drink_18",
    logo = MEDIA .. "logo",
  },
  READY_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready",
  BAR = "Interface\\TargetingFrame\\UI-StatusBar",
  -- One-click feel presets (spec 9.1). Colors are left alone.
  FEEL_ORDER = { "calm", "normal", "full" },
  FEEL = {
    calm = { nudge = false, pulse = false, strength = false, readyTick = false, rangeFade = false, meter = false },
    normal = { nudge = true, pulse = true, strength = true, readyTick = false, rangeFade = false, meter = false },
    full = { nudge = true, pulse = true, strength = true, readyTick = true, rangeFade = true, meter = true },
  },
}

function ns.Theme.ApplyFeel(settings, name)
  local f = ns.Theme.FEEL[name]
  if not f then return false end
  settings.nudge = f.nudge
  settings.look.pulse = f.pulse
  settings.look.strength = f.strength
  settings.frames.readyTick = f.readyTick
  settings.frames.rangeFade = f.rangeFade
  settings.meter.enabled = f.meter
  return true
end

function ns.Theme.ApplyPalette(settings, name)
  local p = ns.Theme.PALETTES[name]
  if not p then return false end
  for i = 1, 3 do
    local c = settings.levels[i].color
    c[1], c[2], c[3], c[4] = p[i][1], p[i][2], p[i][3], 1
  end
  local r = settings.ready.color
  r[1], r[2], r[3], r[4] = p.ready[1], p.ready[2], p.ready[3], 1
  settings.look.palette = name
  return true
end
