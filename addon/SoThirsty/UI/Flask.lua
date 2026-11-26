-- The draining flask (spec 8.3): one flask per healer, off the party frames, so it works
-- even with party frames hidden. Invisible while mana is fine; as the healer runs dry it
-- fades in, the liquid drains, and its edge shifts from blue to red.
-- All game art. The game does the fading, draining and coloring from the hidden mana value.
local _, ns = ...
local L = ns.L
local Levels, Theme, Curves = ns.Levels, ns.Theme, ns.Curves

local Flask = {}
ns.Flask = Flask

local SIZE, GAP, EDGE = 40, 10, 2
local row
local items = {}
local namesWork = true   -- set false if this client won't fade text from a hidden value
local demo               -- { pct, drinking } while a preview is showing

local function buildItem(i)
  local item = CreateFrame("Frame", nil, row)
  item:SetSize(SIZE, SIZE + 14)
  item:SetPoint("TOPLEFT", (i - 1) * (SIZE + GAP), 0)

  -- The empty flask: the icon, dark and colorless.
  item.back = item:CreateTexture(nil, "BACKGROUND")
  item.back:SetSize(SIZE, SIZE)
  item.back:SetPoint("TOP")
  item.back:SetTexture(Theme.ICONS.flask)
  item.back:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  item.back:SetDesaturated(true)
  item.back:SetVertexColor(0.3, 0.3, 0.3)

  -- The liquid: the same icon in color, as a bar that fills from the bottom.
  local liquid = CreateFrame("StatusBar", nil, item)
  liquid:SetAllPoints(item.back)
  liquid:SetStatusBarTexture(Theme.ICONS.flask)
  liquid:SetOrientation("VERTICAL")
  liquid:SetMinMaxValues(0, 1)
  item.liquid = liquid

  -- The glowing edge.
  item.edge = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = liquid:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(EDGE)
      t:SetPoint(side .. "LEFT", item.back, side .. "LEFT", -EDGE, side == "TOP" and EDGE or -EDGE)
      t:SetPoint(side .. "RIGHT", item.back, side .. "RIGHT", EDGE, side == "TOP" and EDGE or -EDGE)
    else
      t:SetWidth(EDGE)
      t:SetPoint("TOP" .. side, item.back, "TOP" .. side, side == "LEFT" and -EDGE or EDGE, 0)
      t:SetPoint("BOTTOM" .. side, item.back, "BOTTOM" .. side, side == "LEFT" and -EDGE or EDGE, 0)
    end
    item.edge[#item.edge + 1] = t
  end

  item.name = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  item.name:SetPoint("TOP", item.back, "BOTTOM", 0, -3)
  item.name:SetWidth(SIZE + GAP)
  item.name:SetWordWrap(false)

  item.drop = liquid:CreateTexture(nil, "OVERLAY", nil, 2)
  item.drop:SetSize(16, 16)
  item.drop:SetPoint("BOTTOMRIGHT", item.back, "BOTTOMRIGHT", 4, -4)
  item.drop:SetTexture(Theme.ICONS.drop)
  items[i] = item
  return item
end

-- Paints one flask. Values may be secret (Curves.All) or plain (Levels.Plain).
local function paint(item, fraction, r, g, b, alpha, low)
  item.back:SetAlpha(alpha)
  item.liquid:SetValue(fraction)
  local fill = item.liquid:GetStatusBarTexture()
  if fill then fill:SetAlpha(alpha) end
  for _, t in ipairs(item.edge) do
    t:SetVertexColor(r, g, b)
    t:SetAlpha(alpha)
  end
  -- Fading text from a hidden value is the one unproven part (spec 16 Q27).
  if namesWork and not pcall(item.name.SetAlpha, item.name, low) then
    namesWork = false
    item.name:Hide()
  end
end

local function build()
  local f = CreateFrame("Frame", "SoThirstyFlasks", UIParent)
  f:SetSize(SIZE, SIZE + 14)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  -- Shown only while placing: a faint plate to grab.
  f.plate = f:CreateTexture(nil, "BACKGROUND")
  f.plate:SetPoint("TOPLEFT", -6, 6)
  f.plate:SetPoint("BOTTOMRIGHT", 6, -6)
  f.plate:SetColorTexture(0.62, 0.3, 1, 0.25)
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    local saved = { point, rel, x, y }
    ns.Settings().flask.point = saved
    self.placed = saved
  end)
  return f
end

-- Shows a stand-in flask at a plain mana percent (the Options preview and placing).
-- Flask.Demo(nil) ends it.
function Flask.Demo(pct, drinking)
  demo = pct and { pct = pct, drinking = drinking } or nil
  Flask.Update()
end

local sorted = {}
local function byUnit(a, b) return tostring(a.unit) < tostring(b.unit) end

-- Rebuilds the row and repaints every flask.
function Flask.Update()
  if not UIParent then return end -- no UI (the test runner)
  local s = ns.Settings()
  local placing = ns.unlocked == true
  local showDemo = demo or (placing and { pct = 25 })
  local show = s.enabled and s.flask.enabled and (showDemo ~= nil or ns.Roster.Count() > 0) and true or false
  if not row then
    if not show then return end
    row = build()
  end
  row:SetShown(show)
  if not show then return end
  row:EnableMouse(placing)
  row.plate:SetShown(placing)
  row:SetScale(s.flask.scale / 100)
  local p = s.flask.point or false
  if row.placed ~= p then
    row.placed = p
    row:ClearAllPoints()
    if p then row:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else row:SetPoint("CENTER", 0, -150) end
  end

  local count = 0
  if showDemo then
    count = 1
    local item = items[1] or buildItem(1)
    item:Show()
    item:SetAlpha(showDemo.drinking and Levels.DRINK_DIM or 1)
    item.drop:SetShown(showDemo.drinking == true)
    item.name:SetText(L.PREVIEW_NAME)
    item.name:SetShown(s.flask.names and namesWork)
    paint(item, Levels.Plain(showDemo.pct, s))
  else
    for i in ipairs(sorted) do sorted[i] = nil end
    for _, h in pairs(ns.Roster.healers) do sorted[#sorted + 1] = h end
    table.sort(sorted, byUnit)
    for i, h in ipairs(sorted) do
      count = i
      local item = items[i] or buildItem(i)
      item:Show()
      local alpha, drinking = Levels.Holder(ns.Roster.Known(h))
      item:SetAlpha(alpha)
      item.drop:SetShown(drinking)
      item.name:SetText(ns.Roster.DisplayName(h))
      item.name:SetShown(s.flask.names and namesWork)
      if alpha > 0 then
        local ok, fraction, r, g, b, a, low = Curves.All(h.unit)
        if ok then paint(item, fraction, r, g, b, a, low) else item:SetAlpha(0) end
      end
    end
  end
  for i = count + 1, #items do items[i]:Hide() end
  row:SetWidth(math.max(1, count) * (SIZE + GAP) - GAP)
end
