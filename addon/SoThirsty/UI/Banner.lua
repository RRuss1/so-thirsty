-- The after-fight banner (spec 8.4): a few seconds after a fight, each healer's name near
-- the top of the screen, in their thirst color. A healer who is fine is invisible: the
-- game decides that from the hidden mana value, and the addon never learns who showed.
-- Our own frame. Never the raid-warning frame, never chat, never a sound.
local _, ns = ...
local L = ns.L
local Levels, Theme, Curves = ns.Levels, ns.Theme, ns.Curves

local Banner = {}
ns.Banner = Banner

local WIDTH, LINE, MAX_LINES = 260, 26, 8
local frame
local lines = {}
local hideTimer
local samplePct = 25     -- the mana the placing sample shows (the preview can set it)
local textWorks = true  -- set false if this client won't color or fade text from hidden values

local function buildLine(i)
  local line = CreateFrame("Frame", nil, frame)
  line:SetSize(WIDTH, LINE)
  line:SetPoint("TOP", 0, -(i - 1) * LINE)
  line.icon = line:CreateTexture(nil, "ARTWORK")
  line.icon:SetSize(LINE - 4, LINE - 4)
  line.icon:SetPoint("RIGHT", line, "CENTER", -60, 0)
  line.icon:SetTexture(Theme.ICONS.drop)
  line.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  -- A colored bar under the name: it carries the color even if text can't.
  line.bar = line:CreateTexture(nil, "ARTWORK")
  line.bar:SetTexture("Interface\\Buttons\\WHITE8x8")
  line.bar:SetHeight(3)
  line.bar:SetPoint("BOTTOMLEFT", line.icon, "BOTTOMRIGHT", 6, 0)
  line.bar:SetWidth(150)
  line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  line.text:SetPoint("LEFT", line.icon, "RIGHT", 6, 1)
  line.text:SetJustifyH("LEFT")
  line.text:SetShadowOffset(1, -1)
  lines[i] = line
  return line
end

-- Paints one line. Values may be secret (Curves.All) or plain (Levels.Plain).
local function paint(line, _, r, g, b, _, low)
  line.icon:SetAlpha(low)
  line.bar:SetVertexColor(r, g, b)
  line.bar:SetAlpha(low)
  -- Coloring and fading text from hidden values is unproven (spec 16 Q27). If the client
  -- refuses, the name is dropped and the icon and bar still show.
  if textWorks then
    local ok = pcall(line.text.SetTextColor, line.text, r, g, b)
    ok = ok and pcall(line.text.SetAlpha, line.text, low)
    if not ok then textWorks = false end
  end
  line.text:SetShown(textWorks)
end

local function build()
  local f = CreateFrame("Frame", "SoThirstyBanner", UIParent)
  f:SetSize(WIDTH, LINE)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f.plate = f:CreateTexture(nil, "BACKGROUND")
  f.plate:SetPoint("TOPLEFT", -6, 6)
  f.plate:SetPoint("BOTTOMRIGHT", 6, -6)
  f.plate:SetColorTexture(0.62, 0.3, 1, 0.25)
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    local saved = { point, rel, x, y }
    ns.Settings().banner.point = saved
    self.placed = saved
  end)
  f:Hide()
  return f
end

local function place(s, placing)
  frame = frame or build()
  frame:EnableMouse(placing)
  frame.plate:SetShown(placing)
  frame:SetScale(s.banner.scale / 100)
  local p = s.banner.point or false
  if frame.placed ~= p then
    frame.placed = p
    frame:ClearAllPoints()
    if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("TOP", 0, -170) end
  end
end

local function stopTimer()
  if hideTimer then
    hideTimer:Cancel()
    hideTimer = nil
  end
end

local function isOn(s) return s.enabled and s.banner.enabled end

-- While placing (and the banner is on), the sample stays up to be dragged.
function Banner.Hide()
  stopTimer()
  if frame and not (ns.unlocked and isOn(ns.Settings())) then frame:Hide() end
end

-- A stand-in line at a plain mana percent (the Options preview and placing).
local function showSample(s, pct)
  local line = lines[1] or buildLine(1)
  line:Show()
  line.text:SetText(L.PREVIEW_NAME)
  paint(line, Levels.Plain(pct, s))
  for i = 2, #lines do lines[i]:Hide() end
  frame:SetHeight(LINE)
  frame:Show()
end

-- Called by Combat.Nudge, banner.delay seconds after a fight (never after a wipe, never if
-- a new fight started), with the healers who may be shown. The game hides the fine ones.
function Banner.Show(list)
  if not UIParent then return end -- no UI (the test runner)
  local s = ns.Settings()
  if not (s.enabled and s.banner.enabled) then return end
  place(s, ns.unlocked == true)
  local count = 0
  for _, h in ipairs(list) do
    if count < MAX_LINES then
      local ok, fraction, r, g, b, a, low = Curves.All(h.unit)
      if ok then
        count = count + 1
        local line = lines[count] or buildLine(count)
        line:Show()
        line.text:SetText(ns.Roster.DisplayName(h))
        paint(line, fraction, r, g, b, a, low)
      end
    end
  end
  for i = count + 1, #lines do lines[i]:Hide() end
  if count == 0 then return end
  frame:SetHeight(count * LINE)
  frame:Show()
  stopTimer()
  hideTimer = C_Timer.NewTimer(s.banner.hold, Banner.Hide)
end

-- Banner.Demo(40) shows a sample line for a few seconds; Banner.Demo(nil) hides it.
function Banner.Demo(pct)
  if not UIParent then return end
  local s = ns.Settings()
  if not pct or not isOn(s) then
    samplePct = 25
    return Banner.Hide()
  end
  samplePct = pct
  place(s, ns.unlocked == true)
  showSample(s, pct)
  stopTimer()
  hideTimer = C_Timer.NewTimer(s.banner.hold, Banner.Hide)
end

-- Roster, combat or placing changed.
function Banner.Refresh()
  if not UIParent then return end
  local s = ns.Settings()
  -- Switched off means nothing of it shows, placing or not.
  if ns.unlocked and isOn(s) then
    place(s, true)
    stopTimer()
    showSample(s, samplePct)
  elseif frame then
    frame:EnableMouse(false)
    frame.plate:Hide()
    if ns.Combat.Is() or not isOn(s) or not hideTimer then
      stopTimer()
      frame:Hide()
    end
  end
end
