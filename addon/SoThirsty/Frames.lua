-- The glow on healers' party/raid frames (spec 8.1).
-- Each healer gets a "holder": our own plain frame laid over their unit frame. The addon
-- sets what it knows (combat, drinking, dead) on the holder; the game applies the hidden
-- mana part (color and strength) to the textures through curves.
-- Taint safety: holders are ours, parented to UIParent, created and anchored out of combat.
-- We never change a Blizzard frame.
local _, ns = ...
local Levels, Theme, Curves = ns.Levels, ns.Theme, ns.Curves

local Frames = {}
ns.Frames = Frames

local WHITE = "Interface\\Buttons\\WHITE8x8"
local GLOW = 10      -- px of soft glow outside the frame
local CORNER = 9     -- px length of a corner bracket

local holders = {}   -- guid -> holder
local spare = {}     -- holders whose healer left
local owner = {}     -- Blizzard frame -> the holder on it
local hooked = {}    -- Blizzard frames we post-hooked OnShow/OnHide on

-- ---------------------------------------------------------------- pieces

local function piece(parent, list, file)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetTexture(file or WHITE)
  list[#list + 1] = t
  return t
end

-- Four lines around the parent, `out` px outside it.
local function edgeInto(parent, list, thick, out)
  local top = piece(parent, list)
  top:SetHeight(thick)
  top:SetPoint("TOPLEFT", -out, out)
  top:SetPoint("TOPRIGHT", out, out)
  local bottom = piece(parent, list)
  bottom:SetHeight(thick)
  bottom:SetPoint("BOTTOMLEFT", -out, -out)
  bottom:SetPoint("BOTTOMRIGHT", out, -out)
  local left = piece(parent, list)
  left:SetWidth(thick)
  left:SetPoint("TOPLEFT", -out, out - thick)
  left:SetPoint("BOTTOMLEFT", -out, thick - out)
  local right = piece(parent, list)
  right:SetWidth(thick)
  right:SetPoint("TOPRIGHT", out, out - thick)
  right:SetPoint("BOTTOMRIGHT", out, thick - out)
end

-- { file, point on the piece, point on the parent, texcoords, sized by }
local GLOW_PIECES = {
  { "glow-corner", "BOTTOMRIGHT", "TOPLEFT", { 1, 0, 1, 0 } },
  { "glow-corner", "BOTTOMLEFT", "TOPRIGHT", { 0, 1, 1, 0 } },
  { "glow-corner", "TOPRIGHT", "BOTTOMLEFT", { 1, 0, 0, 1 } },
  { "glow-corner", "TOPLEFT", "BOTTOMRIGHT", { 0, 1, 0, 1 } },
}
local GLOW_EDGES = {
  { "glow-edge-v", "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", { 1, 0, 0, 1 } },
  { "glow-edge-v", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", { 0, 1, 0, 1 } },
  { "glow-edge-h", "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", { 0, 1, 1, 0 } },
  { "glow-edge-h", "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", { 0, 1, 0, 1 } },
}

local STYLE = {
  border = function(parent, list, look) edgeInto(parent, list, look.thickness, 0) end,
  glow = function(parent, list)
    for _, g in ipairs(GLOW_PIECES) do
      local t = piece(parent, list, Theme.MEDIA .. g[1])
      t:SetSize(GLOW, GLOW)
      t:SetPoint(g[2], parent, g[3])
      t:SetTexCoord(unpack(g[4]))
      t:SetBlendMode("ADD")
    end
    for _, g in ipairs(GLOW_EDGES) do
      local t = piece(parent, list, Theme.MEDIA .. g[1])
      t:SetSize(GLOW, GLOW)
      t:SetPoint(g[2], parent, g[3])
      t:SetPoint(g[4], parent, g[5])
      t:SetTexCoord(unpack(g[6]))
      t:SetBlendMode("ADD")
    end
    edgeInto(parent, list, 1, 0) -- a fine line so the color reads on bright frames
  end,
  corners = function(parent, list, look)
    local thick = look.thickness
    for _, v in ipairs({ "TOP", "BOTTOM" }) do
      for _, h in ipairs({ "LEFT", "RIGHT" }) do
        local a = piece(parent, list)
        a:SetSize(CORNER, thick)
        a:SetPoint(v .. h)
        local b = piece(parent, list)
        b:SetSize(thick, CORNER)
        b:SetPoint(v .. h)
      end
    end
  end,
  tint = function(parent, list) piece(parent, list):SetAllPoints() end,
  bar = function(parent, list)
    local t = piece(parent, list)
    t:SetHeight(6)
    t:SetPoint("BOTTOMLEFT")
    t:SetPoint("BOTTOMRIGHT")
  end,
}

-- ---------------------------------------------------------------- building a holder

local function scaleAnim(group, order, from, to, seconds)
  local s = group:CreateAnimation("Scale")
  s:SetOrder(order)
  s:SetDuration(seconds)
  if s.SetScaleFrom then
    s:SetScaleFrom(from, from)
    s:SetScaleTo(to, to)
  else
    s:SetScale(to / from, to / from)
  end
  return s
end

-- Adds the layers to a holder. Also used for the Options preview frame.
function Frames.Build(holder)
  local body = CreateFrame("Frame", nil, holder)
  body:SetAllPoints()
  holder.body = body

  local glow = CreateFrame("Frame", nil, body)
  glow:SetAllPoints()
  holder.glow, holder.styles, holder.pieces = glow, {}, {}

  -- Pulse: an outer edge in the level 3 color. The game decides whether it's visible
  -- (below level 3); our animation just breathes.
  local pulse = CreateFrame("Frame", nil, body)
  pulse:SetAllPoints()
  pulse.pieces = {}
  edgeInto(pulse, pulse.pieces, 2, 2)
  pulse.anim = pulse:CreateAnimationGroup()
  pulse.anim:SetLooping("BOUNCE")
  pulse.fade = pulse.anim:CreateAnimation("Alpha")
  pulse.fade:SetFromAlpha(1)
  pulse.fade:SetToAlpha(0.15)
  pulse.fade:SetSmoothing("IN_OUT")
  holder.pulse = pulse

  local tick = CreateFrame("Frame", nil, body)
  tick:SetSize(16, 16)
  tick:SetPoint("TOPRIGHT", 3, 3)
  tick.tex = tick:CreateTexture(nil, "OVERLAY")
  tick.tex:SetAllPoints()
  tick.tex:SetTexture(Theme.READY_ICON)
  tick:Hide()
  holder.tick = tick

  -- The drop sits on the holder, not the body, so it stays bright while the glow is dimmed.
  local drop = holder:CreateTexture(nil, "OVERLAY", nil, 3)
  drop:SetSize(14, 14)
  drop:SetPoint("TOPLEFT", -3, 3)
  drop:Hide()
  holder.drop = drop

  holder.grey = {}
  edgeInto(holder, holder.grey, 1, 0)
  for _, t in ipairs(holder.grey) do t:Hide() end

  -- The nudge: brighten and swell, hold, ease back.
  local n = body:CreateAnimationGroup()
  n.up = n:CreateAnimation("Alpha")
  n.up:SetOrder(1)
  n.up:SetDuration(0.35)
  n.up:SetToAlpha(1)
  scaleAnim(n, 1, 1, 1.08, 0.35)
  n.down = n:CreateAnimation("Alpha")
  n.down:SetOrder(2)
  n.down:SetDuration(0.6)
  n.down:SetFromAlpha(1)
  n.shrink = scaleAnim(n, 2, 1.08, 1, 0.6)
  body.nudge = n

  Frames.Style(holder)
end

-- Applies the look settings to a holder: which style's pieces show, and the known colors.
function Frames.Style(holder)
  local cfg = ns.Settings()
  local look = cfg.look
  local build = STYLE[look.style] or STYLE.glow
  local key = (STYLE[look.style] and look.style or "glow") .. look.thickness
  if not holder.styles[key] then
    holder.styles[key] = {}
    build(holder.glow, holder.styles[key], look)
  end
  for k, list in pairs(holder.styles) do
    for _, t in ipairs(list) do t:SetShown(k == key) end
  end
  holder.pieces = holder.styles[key]
  holder.glowAlpha = look.style == "tint" and 0.45 or 1
  holder.glow:SetAlpha(holder.glowAlpha)

  local c3 = cfg.levels[3].color
  for _, t in ipairs(holder.pulse.pieces) do t:SetVertexColor(c3[1], c3[2], c3[3]) end
  holder.pulse.fade:SetDuration(Theme.PULSE_SECONDS[look.pulseSpeed] or 1)
  holder.pulse:SetShown(look.pulse)
  if look.pulse then holder.pulse.anim:Play() else holder.pulse.anim:Stop() end

  holder.drop:SetTexture(Theme.ICONS[look.icon] or Theme.ICONS.drop)
  local g = look.greyColor
  for _, t in ipairs(holder.grey) do t:SetVertexColor(g[1], g[2], g[3], g[4]) end
  local rc = cfg.ready.color
  holder.tick.tex:SetVertexColor(rc[1], rc[2], rc[3])
end

-- Paints the mana-driven layers. The values may be secret (from Curves) or plain numbers
-- (the preview): either way they only go into texture setters.
function Frames.Paint(holder, r, g, b, alpha, pulseAlpha, readyAlpha)
  for _, t in ipairs(holder.pieces) do
    t:SetVertexColor(r, g, b)
    t:SetAlpha(alpha)
  end
  for _, t in ipairs(holder.pulse.pieces) do t:SetAlpha(pulseAlpha) end
  holder.tick.tex:SetAlpha(readyAlpha)
end

-- The known-state layers: overall brightness, the drinking drop, the grey edge.
function Frames.SetKnown(holder, alpha, grey, drinking)
  holder.body:SetAlpha(alpha)
  holder.drop:SetShown(drinking and ns.Settings().frames.drop)
  for _, t in ipairs(holder.grey) do t:SetShown(grey) end
end

-- Plays the nudge on a holder (spec 7).
function Frames.PlayNudge(holder)
  local cfg = ns.Settings()
  local n = holder.body.nudge
  local rest = cfg.look.rest / 100
  n.up:SetFromAlpha(rest)
  n.down:SetToAlpha(rest)
  n.down:SetStartDelay(cfg.nudgeHold)
  n.shrink:SetStartDelay(cfg.nudgeHold)
  n:Stop()
  n:Play()
  if cfg.frames.readyTick then
    holder.tick:Show()
    C_Timer.After(cfg.nudgeHold + 1, function() holder.tick:Hide() end)
  end
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
end

-- Repaints one healer.
function Frames.Update(h)
  local holder = holders[h.guid]
  if not holder then return end
  local target = holder.target
  if not target or not target:IsVisible() then return holder:Hide() end
  holder:Show()
  local cfg = ns.Settings()
  local alpha, grey, drinking = Levels.Holder(ns.Roster.Known(h), cfg)
  Frames.SetKnown(holder, alpha, grey, drinking)
  if alpha <= 0 then return end

  local unit = h.unit
  local okC, r, g, b = Curves.Color(unit, "color")
  local okA, a = Curves.Value(unit, "alpha")
  if not okC or not okA then return holder.body:SetAlpha(0) end
  -- Never test the secret values themselves: only the ok flags.
  local okP, p = Curves.Value(unit, "pulse")
  if not okP then p = 0 end
  local okR, ready = Curves.Value(unit, "ready")
  if not okR then ready = 0 end
  Frames.Paint(holder, r, g, b, a, p, ready)

  -- Range fade (option): the game dims the glow by the hidden in-range flag.
  local full = holder.glowAlpha
  local glow = holder.glow
  if cfg.frames.rangeFade and glow.SetAlphaFromBoolean and ns.Roster.ByUnit("player") ~= h then
    if not pcall(glow.SetAlphaFromBoolean, glow, UnitInRange(unit), full, full * 0.4) then glow:SetAlpha(full) end
  else
    glow:SetAlpha(full)
  end
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

function Frames.Nudge(h)
  local holder = holders[h.guid]
  if holder and holder:IsShown() then Frames.PlayNudge(holder) end
end

-- A look setting changed.
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, _, unit)
  local h = ns.Roster.ByUnit(unit)
  if h then Frames.Update(h) end
end)

function Frames.Restyle()
  for _, holder in pairs(holders) do Frames.Style(holder) end
  for _, holder in ipairs(spare) do Frames.Style(holder) end
  if ns.Settings().frames.rangeFade then
    pcall(events.RegisterEvent, events, "UNIT_IN_RANGE_UPDATE")
  else
    events:UnregisterAllEvents()
  end
end

-- For /sot debug frames: the frame found for each group unit.
function Frames.Report()
  local out = {}
  local list = candidates()
  for _, unit in ipairs(ns.Roster.GroupUnits() or { "player" }) do
    if UnitExists(unit) then
      local f = Frames.Find(unit, list)
      out[#out + 1] = { unit = unit, frame = f and (f.GetName and f:GetName() or "(unnamed)") or nil,
        healer = ns.Roster.ByUnit(unit) ~= nil }
    end
  end
  return out, #list
end
