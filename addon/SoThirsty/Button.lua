-- The "I need a drink" button (spec 8.2). The only thing in SoThirsty that posts to chat,
-- and only when a person clicks it or types /sot drink.
local _, ns = ...
local L = ns.L
local Levels = ns.Levels

local Button = {}
ns.Button = Button

local log = {}   -- this session's send times
local frame

local function now() return GetTime() end

-- Why a line can't be sent right now, or nil. Hard rules from the quiet contract (1.1).
local function blocked(s)
  if not s.enabled then return L.BTN_OFF end
  local channel, key = ns.ChatChannel()
  if not channel then return L.BTN_SOLO end
  local _, pvp = ns.ZoneOk()
  if pvp then return L.BTN_PVP end
  if InCombatLockdown() or ns.Combat.Is() then return L.BTN_COMBAT end
  if not s.button[key] then return L.BTN_CHANNEL_OFF:format(L["CHANNEL_" .. key]) end
  local ok, why = Levels.ButtonAllowed(now(), log)
  if not ok then return why == "CAP" and L.BTN_CAP or L.BTN_COOLDOWN end
  return nil, channel
end

-- The line a click would send (also shown as the Options preview).
function Button.Line(kind)
  local s = ns.Settings()
  local template = kind == "ready" and (s.button.readyMsg or L.MSG_READY) or (s.button.thirstyMsg or L.MSG_THIRSTY)
  local name = UnitName("player")
  if ns.IsSecret(name) or not name then name = "Healer" end
  local _, class = UnitClass("player")
  if ns.IsSecret(class) then class = nil end
  local line = Levels.Message(template, name, class)
  if s.button.prefix then line = L.CHAT_TAG .. " " .. line end
  return line
end

-- Posts one line to group chat. kind: "thirsty" | "ready". Returns true if sent.
function Button.Say(kind)
  local why, channel = blocked(ns.Settings())
  if why then
    ns.Print(why)
    return false
  end
  local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
  send(Button.Line(kind), channel)
  -- Keep only what the cap needs.
  local t = now()
  for i = #log, 1, -1 do
    if t - log[i] >= Levels.CAP_WINDOW then table.remove(log, i) end
  end
  log[#log + 1] = t
  Button.Refresh()
  return true
end

-- ---------------------------------------------------------------- the button itself

local function build()
  local f = CreateFrame("Button", "SoThirstyDrinkButton", UIParent)
  f:SetSize(40, 40)
  f:SetPoint("CENTER", 0, -160)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:RegisterForDrag("LeftButton")

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("TOPLEFT", 3, -3)
  f.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  -- The border takes my own mana color through the curve.
  f.border = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(3)
      t:SetPoint(side .. "LEFT")
      t:SetPoint(side .. "RIGHT")
    else
      t:SetWidth(3)
      t:SetPoint("TOP" .. side)
      t:SetPoint("BOTTOM" .. side)
    end
    f.border[#f.border + 1] = t
  end

  f:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  local ok, cd = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
  if ok and cd then
    cd:SetAllPoints(f.icon)
    f.cooldown = cd
  end

  f:SetScript("OnClick", function(_, mouse)
    if Button.Say(mouse == "RightButton" and "ready" or "thirsty") and f.cooldown then
      f.cooldown:SetCooldown(GetTime(), Levels.COOLDOWN)
    end
  end)
  f:SetScript("OnDragStart", function(self) if ns.unlocked then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    ns.Settings().button.point = { point, rel, x, y }
  end)
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.BTN_TITLE)
    GameTooltip:AddLine(L.BTN_TIP_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.BTN_TIP_RIGHT, 1, 1, 1)
    GameTooltip:AddLine(ns.unlocked and L.BTN_TIP_UNLOCKED or L.BTN_TIP_LOCKED, 0.68, 0.62, 0.7)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- My own mana moves the border color.
  f:SetScript("OnEvent", function() Button.Tint() end)
  f:SetScript("OnShow", function(self)
    self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    Button.Tint()
  end)
  f:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
  f:Hide()
  return f
end

function Button.Tint()
  if not frame or not ns.Curves then return end
  local ok, r, g, b = ns.Curves.Color("player", "meter")
  for _, t in ipairs(frame.border) do
    if ok then t:SetVertexColor(r, g, b) else t:SetVertexColor(0.31, 0.76, 0.97) end
  end
end

local function wanted(s)
  if ns.unlocked then return true end
  if not s.enabled or s.button.show == "never" then return false end
  if not ns.ChatChannel() or not ns.ZoneOk() then return false end
  if s.button.show == "always" then return true end
  local role = UnitGroupRolesAssigned("player")
  return not ns.IsSecret(role) and role == "HEALER"
end

-- Shows, hides and greys the button to match the current state.
function Button.Refresh()
  if not UIParent then return end -- no UI (the test runner)
  local s = ns.Settings()
  local show = wanted(s)
  if not frame then
    if not show then return end
    frame = build()
  end
  if show then
    local p = s.button.point
    frame:ClearAllPoints()
    if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("CENTER", 0, -160) end
    frame.icon:SetTexture(ns.Theme.ICONS[s.look.icon] or ns.Theme.ICONS.drop)
    local busy = ns.Combat.Is()
    frame.icon:SetDesaturated(busy)
    frame:SetAlpha(busy and 0.4 or 1)
  end
  frame:SetShown(show)
end
