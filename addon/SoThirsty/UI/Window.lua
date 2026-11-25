-- Shared window look (adapted from Bounty Line): the classic grey metal dialog border around a
-- violet-stone panel, a candle-gold title bar, an inset content panel with a fine brass edge,
-- and a slowly pulsing violet glow that grows inward over the metal. The palette comes from the
-- SoThirsty icon: violet haze over slate stone, candle gold, brass fittings, leather.
local _, ns = ...

-- Blizzard's own art wherever the game has it (spec 9.7); we ship only the logo and the glow.
local WHITE = "Interface\\Buttons\\WHITE8x8"
local MEDIA = "Interface\\AddOns\\SoThirsty\\Media\\"
local ICON = MEDIA .. "logo-128"
-- The game's tiling rock, tinted violet: the stone floor under the icon's purple haze. (If a
-- client lacks it, art/fallback/ has addon-made backgrounds; spec 16 Q16.)
local WINDOW_BG = { file = "Interface\\FrameGeneral\\UI-Background-Rock", tint = { 0.45, 0.3, 0.58, 1 } }
local PANEL_BG = { file = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", tint = { 0.6, 0.45, 0.75, 0.9 } }
-- The logo in black and white (Media/ghost.tga, from art/logo-256.png): a faint ghost of it
-- fills every window's content panel. Strength is settings.look.ghost (0-100 %, 0 = off).
local GHOST = MEDIA .. "ghost"
local GHOST_TINT = { 1, 1, 1 } -- plain black and white
local GHOST_DEFAULT = 25

local COLORS = {
  header = { 0.06, 0.03, 0.08, 0.8 },    -- darkens the title strip (shadowed plum)
  gold = { 0.98, 0.8, 0.36 },            -- candle gold (the flames and the brass ring)
  goldEdge = { 0.75, 0.55, 0.2, 0.8 },   -- darker brass for fine edges
  glow = { 0.62, 0.3, 1 },               -- the icon's violet haze
  leather = { 0.65, 0.38, 0.23 },        -- section markers (the waterskin)
  fel = { 0.42, 0.88, 0.3 },             -- the cauldron's green fire (accents, "good to go")
  water = { 0.31, 0.76, 0.97 },          -- the chat prefix blue
  body = { 0.95, 0.92, 0.88 },           -- warm, candle-lit white
  muted = { 0.68, 0.62, 0.7 },
  error = { 1, 0.35, 0.3 },
}
ns.COLORS = COLORS

local function rect(parent, layer, color, sublevel)
  local t = parent:CreateTexture(nil, layer, nil, sublevel or 0)
  t:SetTexture(WHITE)
  t:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  return t
end

-- A tiled, tinted game texture ({ file, tint }).
local function tiled(parent, layer, art)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture(art.file, "REPEAT", "REPEAT")
  t:SetHorizTile(true)
  t:SetVertTile(true)
  t:SetVertexColor(art.tint[1], art.tint[2], art.tint[3], art.tint[4])
  return t
end

-- 1px edge drawn as four lines, `out` pixels outside the frame. A negative `out` draws inside.
local function edge(parent, layer, color, out, sublevel)
  local lines = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = rect(parent, layer, color, sublevel)
    lines[#lines + 1] = t
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(1)
      t:SetPoint(side .. "LEFT", -out, side == "TOP" and out or -out)
      t:SetPoint(side .. "RIGHT", out, side == "TOP" and out or -out)
    else
      t:SetWidth(1)
      t:SetPoint("TOP" .. side, side == "LEFT" and -out or out, out)
      t:SetPoint("BOTTOM" .. side, side == "LEFT" and -out or out, -out)
    end
  end
  return lines
end
ns.Edge = edge

-- The glow grows inward from the metal's inner edge: four corner pieces and four edge strips
-- (Media/glow-*.tga, white with a soft falloff), tinted, additive. Pulses slowly.
local GLOW_SIZE = 16
local BORDER_INSET = 12 -- px from the window edge to the inside of the metal
local MARGIN = BORDER_INSET + GLOW_SIZE + 2 -- title bar and content start past the glow

local function glowPiece(holder, file, coords)
  local t = holder:CreateTexture(nil, "OVERLAY")
  holder.pieces[#holder.pieces + 1] = t
  t:SetTexture(MEDIA .. file)
  t:SetTexCoord(unpack(coords))
  t:SetVertexColor(COLORS.glow[1], COLORS.glow[2], COLORS.glow[3], 0.95)
  t:SetBlendMode("ADD")
  return t
end

local function glow(f, level)
  local holder = CreateFrame("Frame", nil, f)
  holder.pieces = {}
  holder:SetPoint("TOPLEFT", BORDER_INSET, -BORDER_INSET)
  holder:SetPoint("BOTTOMRIGHT", -BORDER_INSET, BORDER_INSET)
  holder:SetFrameLevel(level)
  local G = GLOW_SIZE
  for point, coords in pairs({
    TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 }, BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
  }) do
    local c = glowPiece(holder, "glow-corner", coords)
    c:SetSize(G, G)
    c:SetPoint(point)
  end
  local left = glowPiece(holder, "glow-edge-v", { 0, 1, 0, 1 })
  left:SetPoint("TOPLEFT", 0, -G)
  left:SetPoint("BOTTOMLEFT", 0, G)
  left:SetWidth(G)
  local right = glowPiece(holder, "glow-edge-v", { 1, 0, 0, 1 })
  right:SetPoint("TOPRIGHT", 0, -G)
  right:SetPoint("BOTTOMRIGHT", 0, G)
  right:SetWidth(G)
  local top = glowPiece(holder, "glow-edge-h", { 0, 1, 0, 1 })
  top:SetPoint("TOPLEFT", G, 0)
  top:SetPoint("TOPRIGHT", -G, 0)
  top:SetHeight(G)
  local bottom = glowPiece(holder, "glow-edge-h", { 0, 1, 1, 0 })
  bottom:SetPoint("BOTTOMLEFT", G, 0)
  bottom:SetPoint("BOTTOMRIGHT", -G, 0)
  bottom:SetHeight(G)

  local pulse = holder:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local a = pulse:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0.45)
  a:SetDuration(1.4)
  a:SetSmoothing("IN_OUT")
  pulse:Play() -- new frames start shown, so OnShow never fires for the first open
  f:HookScript("OnShow", function() pulse:Play() end)
  f:HookScript("OnHide", function() pulse:Stop() end)
  return holder
end

local BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"

local function metalBorder(f)
  local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
  border:SetAllPoints()
  border:SetFrameLevel(f:GetFrameLevel() + 3)
  border:SetBackdrop({ edgeFile = BORDER, edgeSize = 42 })
end

local windows = {}

-- Puts every window back where it opens by default.
function ns.ResetWindows()
  for _, w in ipairs(windows) do
    w:ClearAllPoints()
    w:SetPoint("CENTER", 0, 120)
  end
end

-- Returns a movable window; put things in f.content.
function ns.CreateWindow(name, width, height, title)
  local f = CreateFrame("Frame", name, UIParent)
  windows[#windows + 1] = f
  f:SetSize(width, height)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  tinsert(UISpecialFrames, name) -- Escape closes it

  local bg = tiled(f, "BACKGROUND", WINDOW_BG)
  bg:SetPoint("TOPLEFT", BORDER_INSET, -BORDER_INSET)
  bg:SetPoint("BOTTOMRIGHT", -BORDER_INSET, BORDER_INSET)
  metalBorder(f)
  local glowHolder = glow(f, f:GetFrameLevel() + 5)
  -- Tints this window's glow; no colour puts the violet back.
  function f.SetGlowColor(_, r, g, b)
    if not r then r, g, b = COLORS.glow[1], COLORS.glow[2], COLORS.glow[3] end
    for _, piece in ipairs(glowHolder.pieces) do piece:SetVertexColor(r, g, b, 0.95) end
  end

  -- Title bar: only the bar drags.
  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT", MARGIN, -MARGIN)
  bar:SetPoint("TOPRIGHT", -MARGIN, -MARGIN)
  bar:SetHeight(38)
  bar:SetFrameLevel(f:GetFrameLevel() + 4)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() f:StartMoving() end)
  bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  local header = rect(bar, "BACKGROUND", COLORS.header)
  header:SetAllPoints()
  local rule = rect(bar, "BORDER", COLORS.goldEdge)
  rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")

  local icon = bar:CreateTexture(nil, "ARTWORK")
  icon:SetSize(30, 30)
  icon:SetPoint("LEFT", 6, 0)
  icon:SetTexture(ICON)

  local t = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  local font = t:GetFont()
  t:SetFont(font, 20, "")
  t:SetPoint("LEFT", icon, "RIGHT", 10, 0)
  t:SetText(title)
  t:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
  t:SetShadowOffset(1, -1)

  local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
  close:SetSize(30, 30)
  close:SetPoint("RIGHT", -2, 0)
  close:SetFrameLevel(bar:GetFrameLevel() + 2)
  close:SetScript("OnClick", function() f:Hide() end)

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", MARGIN + 4, -MARGIN - 46)
  content:SetPoint("BOTTOMRIGHT", -MARGIN - 4, MARGIN + 4)
  tiled(content, "BACKGROUND", PANEL_BG):SetAllPoints()
  edge(content, "BORDER", COLORS.goldEdge, 0)

  -- Over the panel, under every text and control. The square picture fills the whole panel:
  -- it's cropped (not squashed) on whichever side the panel is shorter.
  content:SetClipsChildren(true)
  local ghost = content:CreateTexture(nil, "BACKGROUND", nil, 2)
  ghost:SetTexture(GHOST)
  ghost:SetAllPoints()
  local cw, ch = width - 2 * (MARGIN + 4), height - 2 * MARGIN - 50
  if cw >= ch then
    local cut = (1 - ch / cw) / 2
    ghost:SetTexCoord(0, 1, cut, 1 - cut)
  else
    local cut = (1 - cw / ch) / 2
    ghost:SetTexCoord(cut, 1 - cut, 0, 1)
  end
  function f.SetGhost(_, percent)
    if percent == nil then
      local look = SoThirstyDB and SoThirstyDB.settings and SoThirstyDB.settings.look
      percent = look and look.ghost or GHOST_DEFAULT
    end
    ghost:SetVertexColor(GHOST_TINT[1], GHOST_TINT[2], GHOST_TINT[3], percent / 100)
    ghost:SetShown(percent > 0)
  end
  f:SetGhost()
  f:HookScript("OnShow", function() f:SetGhost() end) -- picks up a changed setting

  f.content = content
  return f
end

-- Re-applies the ghost strength to every window (the Options slider calls this).
function ns.RefreshGhosts()
  for _, w in ipairs(windows) do w:SetGhost() end
end

-- Text roles: "heading" (big candle gold), "section" (gold, with a leather marker), "body", "muted".
function ns.Text(parent, role, size)
  local template = role == "heading" and "GameFontNormalHuge" or "GameFontHighlight"
  local fs = parent:CreateFontString(nil, "ARTWORK", template)
  if size then
    local font, _, flags = fs:GetFont()
    fs:SetFont(font, size, flags)
  end
  local c = (role == "heading" or role == "section") and COLORS.gold or role == "muted" and COLORS.muted or COLORS.body
  fs:SetTextColor(c[1], c[2], c[3])
  fs:SetJustifyH("LEFT")
  if role == "section" then
    local marker = rect(parent, "ARTWORK", COLORS.leather)
    marker:SetSize(5, 5)
    marker:SetPoint("RIGHT", fs, "LEFT", -6, 0)
  end
  return fs
end
