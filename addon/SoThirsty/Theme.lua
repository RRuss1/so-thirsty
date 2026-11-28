-- Look data (spec 9): palettes, icons, sizes. Data only.
local _, ns = ...

local MEDIA = "Interface\\AddOns\\SoThirsty\\Media\\"

ns.Theme = {
  MEDIA = MEDIA,
  -- Level 1, 2 and 3 colors (spec 9.2).
  PALETTE_ORDER = { "classic", "water", "colorblind" },
  PALETTES = {
    classic = { { 1, 0.82, 0, 1 }, { 1, 0.5, 0, 1 }, { 1, 0.125, 0.125, 1 } },
    water = { { 0.61, 0.91, 1, 1 }, { 0.31, 0.76, 0.97, 1 }, { 0.48, 0.31, 0.97, 1 } },
    colorblind = { { 0.94, 0.89, 0.26, 1 }, { 0.9, 0.62, 0, 1 }, { 0.8, 0.47, 0.65, 1 } },
  },
  -- Game art (spec 9.7); /sot debug icons shows them.
  ICON_ORDER = { "drop", "flask" },
  ICONS = {
    drop = "Interface\\Icons\\INV_Drink_07",      -- the drink button and the "drinking" mark
    flask = "Interface\\Icons\\INV_Potion_76",    -- the draining flask
  },
  BAR = "Interface\\TargetingFrame\\UI-StatusBar",
  PIP_ORDER = { "small", "medium", "large" },
  PIP_SIZE = { small = 5, medium = 7, large = 9 },
  CORNER_ORDER = { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" },
  GLOW_ORDER = { "thin", "medium", "wide" },
  GLOW_WIDTH = { thin = 60, medium = 110, wide = 170 },
}

function ns.Theme.ApplyPalette(settings, name)
  local p = ns.Theme.PALETTES[name]
  if not p then return false end
  for i = 1, 3 do
    local c = settings.levels[i].color
    c[1], c[2], c[3], c[4] = p[i][1], p[i][2], p[i][3], 1
  end
  settings.palette = name
  return true
end
