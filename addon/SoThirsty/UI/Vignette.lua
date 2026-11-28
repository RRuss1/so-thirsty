-- The screen-edge glow (spec 8.5): a soft haze along the screen edges that breathes in as a
-- healer runs dry, out of combat. Off by default: it is the most intrusive indicator.
-- One layer per healer (up to MAX); the game colors and fades each from that healer's
-- hidden mana, so the thirstiest one shows through without the addon comparing anything.
local _, ns = ...
local Levels, Theme, Curves = ns.Levels, ns.Theme, ns.Curves

local Vignette = {}
ns.Vignette = Vignette

local MAX = 4
local root
local layers = {}
local demo  -- a plain mana percent while a preview is showing

-- { file, point 1, point 2, texcoords, sized by }: the glow art fades inward from an edge.
local EDGES = {
  { "glow-edge-v", "TOPLEFT", "BOTTOMLEFT", { 0, 1, 0, 1 }, "width" },
  { "glow-edge-v", "TOPRIGHT", "BOTTOMRIGHT", { 1, 0, 0, 1 }, "width" },
  { "glow-edge-h", "TOPLEFT", "TOPRIGHT", { 0, 1, 0, 1 }, "height" },
  { "glow-edge-h", "BOTTOMLEFT", "BOTTOMRIGHT", { 0, 1, 1, 0 }, "height" },
}

local function buildLayer(i)
  local layer = CreateFrame("Frame", nil, root)
  layer:SetAllPoints()
  layer.edges = {}
  for n, e in ipairs(EDGES) do
    local t = layer:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(Theme.MEDIA .. e[1])
    t:SetPoint(e[2])
    t:SetPoint(e[3])
    t:SetTexCoord(unpack(e[4]))
    t:SetBlendMode("ADD")
    t.sizedBy = e[5]
    layer.edges[n] = t
  end
  layers[i] = layer
  return layer
end

-- Paints one layer. Values may be secret (Curves.All) or plain (Levels.Plain).
local function paint(layer, _, r, g, b, alpha)
  for _, t in ipairs(layer.edges) do
    t:SetVertexColor(r, g, b)
    t:SetAlpha(alpha)
  end
end

local function build()
  local f = CreateFrame("Frame", "SoThirstyScreenGlow", UIParent)
  f:SetAllPoints()
  f:SetFrameStrata("BACKGROUND")
  return f
end

-- Vignette.Demo(30) previews the glow at a plain mana percent; Vignette.Demo(nil) ends it.
function Vignette.Demo(pct)
  demo = pct
  Vignette.Update()
end

function Vignette.Update()
  if not UIParent then return end -- no UI (the test runner)
  local s = ns.Settings()
  local show = s.enabled and s.vignette.enabled and (demo ~= nil or ns.Roster.Count() > 0) and true or false
  if not root then
    if not show then return end
    root = build()
  end
  root:SetShown(show)
  if not show then return end
  local width = Theme.GLOW_WIDTH[s.vignette.width] or Theme.GLOW_WIDTH.medium
  local strength = s.vignette.strength / 100

  local count = 0
  local function use()
    count = count + 1
    local layer = layers[count] or buildLayer(count)
    for _, t in ipairs(layer.edges) do
      if t.sizedBy == "width" then t:SetWidth(width) else t:SetHeight(width) end
    end
    layer:Show()
    return layer
  end

  -- One color of the player's choosing, or the level colors.
  local own = s.vignette.custom and s.vignette.color

  if demo then
    local layer = use()
    layer:SetAlpha(strength)
    local fraction, r, g, b, a = Levels.Plain(demo, s)
    if own then r, g, b = own[1], own[2], own[3] end
    paint(layer, fraction, r, g, b, a)
  else
    for _, h in pairs(ns.Roster.healers) do
      if count < MAX then
        local alpha = Levels.Holder(ns.Roster.Known(h))
        if alpha > 0 then
          local ok, fraction, r, g, b, a = Curves.All(h.unit)
          if ok then
            local layer = use()
            layer:SetAlpha(alpha * strength)
            if own then r, g, b = own[1], own[2], own[3] end
            paint(layer, fraction, r, g, b, a)
          end
        end
      end
    end
  end
  for i = count + 1, #layers do layers[i]:Hide() end
end
