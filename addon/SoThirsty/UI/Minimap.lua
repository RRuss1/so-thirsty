-- Minimap button (adapted from Bounty Line): the menu for everything, so nobody has to
-- remember slash commands.
--   Left-click   opens the Options window
--   Right-click  a dropdown with every /sot command
--   Drag         moves it around the minimap's edge (position and visibility are saved)
-- The same clicks work on the entry in the minimap's addon compartment menu. Self-contained
-- instead of LibDBIcon, to avoid libraries. The only OnUpdate in the addon runs while the
-- button is being dragged, and is removed on release.
local _, ns = ...
local L = ns.L

local ICON = "Interface\\AddOns\\SoThirsty\\Media\\logo"
local button

local function settings() return ns.Settings().minimap end

local function place()
  local a = math.rad(settings().angle)
  local r = Minimap:GetWidth() / 2 + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function onDragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  settings().angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
  place()
end

-- "Options   /sot": each entry shows the command that does the same thing, in grey.
local function entry(text, command)
  return ("%s   |cff8a8a8a/sot%s|r"):format(text, command ~= "" and (" " .. command) or "")
end

-- The right-click menu: every player command.
function ns.OpenMainMenu(owner)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return ns.RunCommand("help") end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    local function run(command) return function() ns.RunCommand(command) end end
    local s = ns.Settings()
    root:CreateTitle(L.ADDON)
    root:CreateButton(entry(L.M_OPTIONS, ""), run("options"))
    root:CreateButton(entry(L.M_DRINK, "drink"), run("drink"))
    root:CreateButton(entry(L.M_READY, "ready"), run("ready"))

    root:CreateDivider()
    root:CreateCheckbox(entry(L.M_ENABLED, "on | off"), function() return s.enabled end,
      function() ns.RunCommand(s.enabled and "off" or "on") end)
    root:CreateCheckbox(entry(L.M_METER, "meter"), function() return s.meter.enabled end, run("meter"))
    root:CreateCheckbox(entry(L.M_UNLOCK, "move | lock"), function() return ns.unlocked == true end,
      function() ns.RunCommand(ns.unlocked and "lock" or "move") end)
    root:CreateButton(entry(L.M_TEST, "test"), run("test"))
    root:CreateButton(entry(L.M_STATUS, "status"), run("status"))

    root:CreateDivider()
    root:CreateButton(entry(L.M_HELP, "help"), run("help"))
    root:CreateButton(entry(L.M_HIDE, "minimap"), run("minimap"))
    local debug = root:CreateButton(L.M_DEBUG)
    debug:CreateButton(entry(L.M_DEBUG_INFO, "debug"), run("debug"))
    debug:CreateButton(entry(L.M_DEBUG_PARTY, "debug party"), run("debug party"))
    debug:CreateButton(entry(L.M_DEBUG_FRAMES, "debug frames"), run("debug frames"))
    debug:CreateButton(entry(L.M_DEBUG_DRINK, "debug drink"), run("debug drink"))
    debug:CreateButton(entry(L.M_DEBUG_ICONS, "debug icons"), run("debug icons"))
  end)
end

function ns.MinimapClick(mouse, owner)
  if mouse == "RightButton" then return ns.OpenMainMenu(owner or button or UIParent) end
  ns.RunCommand("options")
end

function ns.MinimapTooltip(tooltip)
  tooltip:SetText(L.ADDON, 0.98, 0.8, 0.36)
  for _, line in ipairs(ns.StatusLines()) do tooltip:AddLine(line, 1, 1, 1) end
  for _, line in ipairs(L.MINIMAP_TIP) do tooltip:AddLine(line, 0.68, 0.62, 0.7) end
  tooltip:Show()
end

local function build()
  local b = CreateFrame("Button", "SoThirstyMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(24, 24)
  bg:SetPoint("TOPLEFT", 2, -4)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexture(ICON)

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(50, 50)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  b:SetScript("OnClick", function(self, mouse)
    GameTooltip:Hide()
    ns.MinimapClick(mouse, self)
  end)
  b:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", onDragUpdate)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    ns.MinimapTooltip(GameTooltip)
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function ns.SetupMinimap()
  if not Minimap then return end
  button = button or build()
  place()
  button:SetShown(not settings().hide)
end

function ns.ToggleMinimap()
  settings().hide = not settings().hide
  ns.SetupMinimap()
  ns.Print(settings().hide and L.MINIMAP_HIDDEN or L.MINIMAP_SHOWN)
end
