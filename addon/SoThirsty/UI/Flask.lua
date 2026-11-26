-- The draining flask (spec 8.3): one flask per healer, off the party frames, so it works
-- even with party frames hidden. A stand-in for a mana bar: it always shows (unless set to
-- "only when low"), the liquid drains with their mana, and its edge shifts from the
-- healer's class color to the level colors as they run dry.
-- Several healers line up in a row or a column, and are placed as one stack or one by one.
-- All game art. The game does the fading, draining and coloring from the hidden mana value.
local _, ns = ...
local L = ns.L
local Levels, Theme, Curves = ns.Levels, ns.Theme, ns.Curves

local Flask = {}
ns.Flask = Flask

local SIZE, GAP, EDGE, NAME_H = 40, 10, 2, 14
local SAMPLES = 3        -- stand-in flasks shown while placing, so the layout can be seen
local stack              -- the frame the flasks sit in (and move with, when placed as one)
local items = {}
local namesWork = true   -- set false if this client won't fade text from a hidden value
local demo               -- { pct, drinking, count } while a preview is showing

local function plate(frame)
  local t = frame:CreateTexture(nil, "BACKGROUND")
  t:SetPoint("TOPLEFT", -6, 6)
  t:SetPoint("BOTTOMRIGHT", 6, -6)
  t:SetColorTexture(0.62, 0.3, 1, 0.25)
  t:Hide()
  return t
end

local function buildItem(i)
  local item = CreateFrame("Frame", nil, stack)
  item:SetSize(SIZE, SIZE + NAME_H)
  item:SetClampedToScreen(true)
  item:SetMovable(true)
  item:RegisterForDrag("LeftButton")
  item.plate = plate(item)
  -- Dragged only when flasks are placed one by one. The spot belongs to the slot (first
  -- healer, second healer...), not to a person.
  item:SetScript("OnDragStart", function(self) self:StartMoving() end)
  item:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    local flask = ns.Settings().flask
    flask.points = flask.points or {}
    local saved = { point, rel, x, y }
    flask.points[i] = saved
    self.placed = saved
  end)

  -- The empty flask: the icon, dark and colorless.
  item.back = item:CreateTexture(nil, "BORDER")
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

  -- The edge: class color while fine, level colors when low.
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
  f:SetSize(SIZE, SIZE + NAME_H)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f.plate = plate(f)
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

-- Where flask i sits inside the stack: across for a row, down for a column.
local function offset(i, column)
  if column then return 0, -(i - 1) * (SIZE + NAME_H + GAP) end
  return (i - 1) * (SIZE + GAP), 0
end

-- Puts flask i where it belongs: in the stack, or (placed one by one) at its own spot.
local function position(item, i, flask, placing)
  local column = flask.layout == "column"
  local x, y = offset(i, column)
  local own = not flask.together and flask.points and flask.points[i]
  local key = own or (flask.together and "stack" or "loose") .. (column and "column" or "row")
  if item.placed ~= key then
    item.placed = key
    item:ClearAllPoints()
    if own then
      item:SetPoint(own[1], UIParent, own[2], own[3], own[4])
    else
      item:SetPoint("TOPLEFT", stack, "TOPLEFT", x, y)
    end
  end
  local separate = placing and not flask.together
  item:EnableMouse(separate)
  item.plate:SetShown(separate)
end

-- Shows stand-in flasks at a plain mana percent (the Options preview and placing).
-- Flask.Demo(nil) ends it.
function Flask.Demo(pct, drinking, count)
  demo = pct and { pct = pct, drinking = drinking, count = count or 1 } or nil
  Flask.Update()
end

local sorted = {}
local function byUnit(a, b) return tostring(a.unit) < tostring(b.unit) end

-- Lays out and repaints every flask.
function Flask.Update()
  if not UIParent then return end -- no UI (the test runner)
  local s = ns.Settings()
  local flask = s.flask
  local placing = ns.unlocked == true
  local showDemo = demo or (placing and { pct = 25, count = SAMPLES })
  local show = s.enabled and flask.enabled and (showDemo ~= nil or ns.Roster.Count() > 0) and true or false
  if not stack then
    if not show then return end
    stack = build()
  end
  stack:SetShown(show)
  if not show then return end
  stack:EnableMouse(placing and flask.together)
  stack.plate:SetShown(placing and flask.together)
  stack:SetScale(flask.scale / 100)
  local p = flask.point or false
  if stack.placed ~= p then
    stack.placed = p
    stack:ClearAllPoints()
    if p then stack:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else stack:SetPoint("CENTER", 0, -150) end
  end

  -- By default the flask always shows, like a mana bar you can read at a glance. With
  -- "only when low" it stays invisible until mana drops below level 1.
  local always = not flask.whenLow
  local opacity = flask.alpha / 100
  local count = 0
  if showDemo then
    count = showDemo.count
    for i = 1, count do
      local item = items[i] or buildItem(i)
      item:Show()
      position(item, i, flask, placing)
      item:SetAlpha((showDemo.drinking and Levels.DRINK_DIM or 1) * opacity)
      item.drop:SetShown(showDemo.drinking == true)
      item.name:SetText(L.PREVIEW_NAME)
      item.name:SetShown(flask.names and namesWork)
      local fraction, r, g, b, a, low = Levels.Plain(showDemo.pct, s)
      if always then a, low = 1, 1 end
      paint(item, fraction, r, g, b, a, low)
    end
  else
    for i in ipairs(sorted) do sorted[i] = nil end
    for _, h in pairs(ns.Roster.healers) do sorted[#sorted + 1] = h end
    table.sort(sorted, byUnit)
    for i, h in ipairs(sorted) do
      count = i
      local item = items[i] or buildItem(i)
      item:Show()
      position(item, i, flask, placing)
      local alpha, drinking = Levels.Holder(ns.Roster.Known(h))
      item:SetAlpha(alpha * opacity)
      item.drop:SetShown(drinking)
      item.name:SetText(ns.Roster.DisplayName(h))
      item.name:SetShown(flask.names and namesWork)
      if alpha > 0 then
        local ok, fraction, r, g, b, a, low = Curves.All(h.unit)
        if ok then
          -- The edge: the healer's class color while they're fine, level colors when low.
          local class = h.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[h.class]
          if class then
            local okC, cr, cg, cb = Curves.ClassColor(h.unit, h.class, class)
            if okC then r, g, b = cr, cg, cb end
          end
          -- Always showing: plain 1s replace the mana-driven fade (no test on a secret).
          if always then a, low = 1, 1 end
          paint(item, fraction, r, g, b, a, low)
        else
          item:SetAlpha(0)
        end
      end
    end
  end
  for i = count + 1, #items do items[i]:Hide() end

  -- The stack is as big as the flasks in it, so its grab plate covers them all.
  local n = math.max(1, count)
  if flask.layout == "column" then
    stack:SetSize(SIZE, n * (SIZE + NAME_H + GAP) - GAP)
  else
    stack:SetSize(n * (SIZE + GAP) - GAP, SIZE + NAME_H)
  end
end
