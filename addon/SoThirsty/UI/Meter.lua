-- The thirst meter (spec 8.3): an optional small panel with one mana bar per healer.
-- The bars are filled and colored by the game from the hidden mana value.
local _, ns = ...
local L = ns.L
local Theme, Curves = ns.Theme, ns.Curves

local Meter = {}
ns.Meter = Meter

local WIDTH, ROW, PAD = 170, 18, 6
local panel
local rows = {}

local function buildRow(i)
  local row = CreateFrame("Frame", nil, panel)
  row:SetSize(WIDTH - 2 * PAD, ROW - 2)
  row:SetPoint("TOPLEFT", PAD, -PAD - 14 - (i - 1) * ROW)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT")
  row.name:SetWidth(64)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

  local bar = CreateFrame("StatusBar", nil, row)
  bar:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
  bar:SetPoint("RIGHT")
  bar:SetHeight(10)
  bar:SetStatusBarTexture(Theme.BAR)
  bar:SetMinMaxValues(0, 1)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.6)
  row.bar = bar

  -- A tick every 10%; the three level lines are repositioned in layout().
  row.ticks = {}
  for t = 1, 9 do
    local line = bar:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(0, 0, 0, 0.55)
    line:SetWidth(1)
    row.ticks[t] = line
  end

  row.drop = row:CreateTexture(nil, "OVERLAY")
  row.drop:SetSize(11, 11)
  row.drop:SetPoint("RIGHT", row.name, "RIGHT", 0, 0)
  rows[i] = row
  return row
end

local function layoutTicks(row)
  local width = row.bar:GetWidth()
  for t, line in ipairs(row.ticks) do
    line:ClearAllPoints()
    line:SetPoint("TOP", row.bar, "TOPLEFT", width * t / 10, 0)
    line:SetPoint("BOTTOM", row.bar, "BOTTOMLEFT", width * t / 10, 0)
  end
end

local function build()
  local f = CreateFrame("Frame", "SoThirstyMeter", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, 40)
  f:SetPoint("CENTER", 260, -120)
  f:SetFrameStrata("LOW")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.6, 0.45, 0.75, 0.9)
  f:SetBackdropBorderColor(0.75, 0.55, 0.2, 0.9)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.title:SetPoint("TOPLEFT", PAD + 2, -PAD)
  f.title:SetText(L.METER_TITLE)
  -- Always draggable: grab it anywhere and move it.
  f:EnableMouse(true)
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    local saved = { point, rel, x, y }
    ns.Settings().meter.point = saved
    self.placed = saved
  end)
  f:Hide()
  return f
end

local function wanted(s)
  if not s.meter.enabled or not s.enabled then return false end
  if ns.unlocked then return true end
  return ns.Roster.Count() > 0 and not ns.Combat.Is() and (ns.ZoneOk() and true or false)
end

local sorted = {}
local function byName(a, b) return tostring(a.unit) < tostring(b.unit) end

-- Rebuilds the rows and repaints the bars.
function Meter.Update()
  local s = ns.Settings()
  local show = wanted(s)
  if not panel then
    if not show then return end
    panel = build()
  end
  panel:SetShown(show)
  if not show then return end
  panel:SetScale(s.meter.scale / 100)
  -- Only re-place it when the saved spot changed (a reset), never while it is being dragged.
  local p = s.meter.point or false
  if panel.placed ~= p then
    panel.placed = p
    panel:ClearAllPoints()
    if p then panel:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else panel:SetPoint("CENTER", 260, -120) end
  end

  for i in ipairs(sorted) do sorted[i] = nil end
  for _, h in pairs(ns.Roster.healers) do sorted[#sorted + 1] = h end
  table.sort(sorted, byName)

  for i, h in ipairs(sorted) do
    local row = rows[i] or buildRow(i)
    row:Show()
    row.name:SetText(ns.Roster.DisplayName(h))
    local k = ns.Roster.Known(h)
    row.drop:SetTexture(Theme.ICONS[s.look.icon] or Theme.ICONS.drop)
    row.drop:SetShown(k.drinking)
    layoutTicks(row)
    local bar = row.bar
    local okF, fraction = Curves.Fraction(h.unit)
    local okC, r, g, b = Curves.Color(h.unit, "meter")
    if k.dead or k.offline or not okF then
      bar:SetValue(0)
    else
      bar:SetValue(fraction)
      local tex = bar:GetStatusBarTexture()
      if okC and tex then tex:SetVertexColor(r, g, b) end
    end
  end
  for i = #sorted + 1, #rows do rows[i]:Hide() end
  panel:SetHeight(PAD * 2 + 14 + math.max(1, #sorted) * ROW)
end
