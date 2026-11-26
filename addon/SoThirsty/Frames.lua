-- The two on-frame indicators (spec 8.1, 8.2): the mana bar color and the pips.
-- Each healer gets a "holder": our own plain frame laid over their unit frame. The addon
-- sets what it knows (combat, drinking, dead) as plain alpha on our frames; the game
-- applies the hidden mana part (fill, color, on/off) to the textures through curves.
-- Taint safety: holders are ours, parented to UIParent, created and anchored out of combat.
-- We read where a Blizzard frame's power bar is; we never change a Blizzard frame.
local _, ns = ...
local Levels, Theme, Curves = ns.Levels, ns.Theme, ns.Curves

local Frames = {}
ns.Frames = Frames

local WHITE = "Interface\\Buttons\\WHITE8x8"
local STRIP = 6      -- px: the fallback bar along the frame's bottom, when it has no power bar
local PIP_GAP = 2

local holders = {}   -- guid -> holder
local spare = {}     -- holders whose healer left
local owner = {}     -- Blizzard frame -> the holder on it
local hooked = {}    -- Blizzard frames we post-hooked OnShow/OnHide on

-- ---------------------------------------------------------------- building a holder

-- Adds the layers to a holder. Also used for the Options preview frame.
function Frames.Build(holder)
  -- Mana bar color: our bar exactly over the frame's own power bar.
  local barFrame = CreateFrame("Frame", nil, holder)
  local bar = CreateFrame("StatusBar", nil, barFrame)
  bar:SetAllPoints()
  bar:SetStatusBarTexture(Theme.BAR)
  bar:SetMinMaxValues(0, 1)
  holder.barFrame, holder.bar = barFrame, bar

  -- Pips: three squares, each on a dark backing so it reads on any frame color.
  local pipFrame = CreateFrame("Frame", nil, holder)
  pipFrame:SetFrameLevel(barFrame:GetFrameLevel() + 2)
  holder.pipFrame, holder.pips = pipFrame, {}
  for i = 1, 3 do
    local back = pipFrame:CreateTexture(nil, "ARTWORK")
    back:SetTexture(WHITE)
    back:SetVertexColor(0, 0, 0, 0.85)
    local dot = pipFrame:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(WHITE)
    dot:SetPoint("TOPLEFT", back, "TOPLEFT", 1, -1)
    dot:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -1, 1)
    holder.pips[i] = { back = back, dot = dot }
  end

  -- The "drinking" mark.
  local drop = holder:CreateTexture(nil, "OVERLAY", nil, 3)
  drop:SetSize(14, 14)
  drop:SetPoint("TOPLEFT", -3, 3)
  drop:SetTexture(Theme.ICONS.drop)
  drop:Hide()
  holder.drop = drop
end

-- Applies the settings to a holder: where the bar sits, pip size and corner, level colors.
-- `powerBar` is the region to cover (the unit frame's own power bar), or nil for the strip.
function Frames.Layout(holder, powerBar)
  local cfg = ns.Settings()
  local barFrame = holder.barFrame
  barFrame:ClearAllPoints()
  if powerBar then
    barFrame:SetAllPoints(powerBar)
  else
    barFrame:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
    barFrame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    barFrame:SetHeight(STRIP)
  end
  barFrame:SetShown(cfg.bar.enabled)

  local size = Theme.PIP_SIZE[cfg.pips.size] or Theme.PIP_SIZE.medium
  local corner = cfg.pips.corner
  local right = corner:find("RIGHT") ~= nil
  local top = corner:find("TOP") ~= nil
  local pipFrame = holder.pipFrame
  pipFrame:ClearAllPoints()
  pipFrame:SetSize(size * 3 + PIP_GAP * 2, size)
  pipFrame:SetPoint(corner, holder, corner, right and -3 or 3, top and -3 or 3)
  pipFrame:SetShown(cfg.pips.enabled)
  for i, pip in ipairs(holder.pips) do
    pip.back:ClearAllPoints()
    pip.back:SetSize(size, size)
    pip.back:SetPoint("LEFT", pipFrame, "LEFT", (i - 1) * (size + PIP_GAP), 0)
    local c = cfg.levels[i].color
    pip.dot:SetVertexColor(c[1], c[2], c[3])
  end
  holder.barAlpha = cfg.bar.alpha / 100
end

-- Paints the mana-driven parts. The values may be secret (from Curves.All) or plain numbers
-- (from Levels.Plain, for the preview): either way they only go into setters.
function Frames.Paint(holder, fraction, r, g, b, _, low, p1, p2, p3)
  local bar = holder.bar
  bar:SetValue(fraction)
  local fill = bar:GetStatusBarTexture()
  if fill then
    fill:SetVertexColor(r, g, b)
    fill:SetAlpha(low)
  end
  local pips = holder.pips
  pips[1].back:SetAlpha(p1)
  pips[1].dot:SetAlpha(p1)
  pips[2].back:SetAlpha(p2)
  pips[2].dot:SetAlpha(p2)
  pips[3].back:SetAlpha(p3)
  pips[3].dot:SetAlpha(p3)
end

-- The known-state parts: overall visibility and the drinking mark.
function Frames.SetKnown(holder, alpha, drinking)
  holder.barFrame:SetAlpha(alpha * holder.barAlpha)
  holder.pipFrame:SetAlpha(alpha)
  holder.drop:SetShown(drinking)
end

-- ---------------------------------------------------------------- finding unit frames

local function candidates()
  local list = {}
  local function add(f) if f then list[#list + 1] = f end end
  for i = 1, 5 do add(_G["CompactPartyFrameMember" .. i]) end
  for i = 1, 40 do add(_G["CompactRaidFrame" .. i]) end
  for g = 1, 8 do
    for m = 1, 5 do add(_G["CompactRaidGroup" .. g .. "Member" .. m]) end
  end
  local party = _G.PartyFrame
  if type(party) == "table" then
    for i = 1, 4 do add(party["MemberFrame" .. i]) end
  end
  for i = 1, 4 do add(_G["PartyMemberFrame" .. i]) end
  add(_G.PlayerFrame)
  return list
end

local function unitMatches(f, unit)
  local u = f.displayedUnit or f.unit
  if ns.IsSecret(u) or type(u) ~= "string" then return false end
  if u == unit then return true end
  local same = UnitIsUnit(u, unit)
  return not ns.IsSecret(same) and same == true
end

local function usable(f)
  if type(f) ~= "table" or not f.IsVisible then return false end
  if f.IsForbidden and f:IsForbidden() then return false end
  return f:IsVisible() and true or false
end

-- The visible unit frame showing this unit, or nil.
function Frames.Find(unit, list)
  for _, f in ipairs(list or candidates()) do
    if usable(f) and unitMatches(f, unit) then return f end
  end
  return nil
end

-- The unit frame's own power bar, if it has one showing. Returns the region and the key
-- it was found under (for /sot debug looks).
local POWER_KEYS = { "powerBar", "PowerBar", "manabar", "ManaBar" }
function Frames.PowerBar(target)
  for _, key in ipairs(POWER_KEYS) do
    local bar = target[key]
    if type(bar) == "table" and bar.IsShown and bar.GetWidth and not (bar.IsForbidden and bar:IsForbidden()) then
      if bar:IsShown() then return bar, key end
    end
  end
  return nil
end

-- ---------------------------------------------------------------- holders

local refreshQueued = false
local function queueRefresh()
  if refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0.2, function()
    refreshQueued = false
    Frames.UpdateAll()
  end)
end

local function hook(target)
  if hooked[target] then return end
  hooked[target] = true
  target:HookScript("OnHide", function(self)
    local holder = owner[self]
    if holder and holder.target == self then holder:Hide() end
  end)
  target:HookScript("OnShow", queueRefresh)
end

local function attach(h, list)
  local target = Frames.Find(h.unit, list)
  local holder = holders[h.guid]
  if not target then
    if holder then
      holder.target = nil
      holder:Hide()
    end
    return
  end
  if not holder then
    holder = table.remove(spare)
    if not holder then
      holder = CreateFrame("Frame", nil, UIParent)
      Frames.Build(holder)
    end
    holders[h.guid] = holder
  end
  if holder.target ~= target then
    holder.target = target
    holder:ClearAllPoints()
    holder:SetAllPoints(target)
    holder:SetFrameStrata(target:GetFrameStrata())
    holder:SetFrameLevel(target:GetFrameLevel() + 20)
    hook(target)
  end
  owner[target] = holder
  Frames.Layout(holder, (Frames.PowerBar(target)))
end

-- The on-screen preview: healers' real frames show a plain sample percent, out of combat.
local demo
local demoKnown = { enabled = true, zoneOk = true, inCombat = false, dead = false, offline = false }

-- Frames.Demo(40, drinking) starts or updates it; Frames.Demo(nil) ends it.
function Frames.Demo(pct, drinking)
  if not pct and not demo then return end
  demo = pct
  demoKnown.drinking = drinking and true or false
  for _, h in pairs(ns.Roster.healers) do Frames.Update(h) end
end

-- Repaints one healer.
function Frames.Update(h)
  local holder = holders[h.guid]
  if not holder then return end
  local target = holder.target
  if not target or not target:IsVisible() then return holder:Hide() end
  holder:Show()
  if demo and not InCombatLockdown() then
    local cfg = ns.Settings()
    demoKnown.enabled = cfg.enabled
    Frames.SetKnown(holder, Levels.Holder(demoKnown))
    return Frames.Paint(holder, Levels.Plain(demo, cfg))
  end
  local alpha, drinking = Levels.Holder(ns.Roster.Known(h))
  Frames.SetKnown(holder, alpha, drinking)
  if alpha <= 0 then return end
  -- Never test the secret values themselves: only the ok flag.
  local ok, fraction, r, g, b, a, low, p1, p2, p3 = Curves.All(h.unit)
  if not ok then return Frames.SetKnown(holder, 0, false) end
  Frames.Paint(holder, fraction, r, g, b, a, low, p1, p2, p3)
end

-- Re-attaches (out of combat only) and repaints every healer.
function Frames.UpdateAll()
  local healers = ns.Roster.healers
  if not InCombatLockdown() then
    for guid, holder in pairs(holders) do
      if not healers[guid] then
        holder:Hide()
        if holder.target and owner[holder.target] == holder then owner[holder.target] = nil end
        holder.target = nil
        holders[guid] = nil
        spare[#spare + 1] = holder
      end
    end
    if Curves.Available() then
      local list = candidates()
      for _, h in pairs(healers) do attach(h, list) end
    end
  end
  for _, h in pairs(healers) do Frames.Update(h) end
end

-- For /sot debug frames and looks: the frame found for each group unit, and its power bar.
function Frames.Report()
  local out = {}
  local list = candidates()
  for _, unit in ipairs(ns.Roster.GroupUnits() or { "player" }) do
    if UnitExists(unit) then
      local f = Frames.Find(unit, list)
      local entry = { unit = unit, healer = ns.Roster.ByUnit(unit) ~= nil }
      if f then
        entry.frame = f.GetName and f:GetName() or "(unnamed)"
        local bar, key = Frames.PowerBar(f)
        if bar then
          local ok, size = pcall(string.format, "%s %dx%d", key, bar:GetWidth(), bar:GetHeight())
          entry.powerBar = ok and size or key
        end
      end
      out[#out + 1] = entry
    end
  end
  return out, #list
end
