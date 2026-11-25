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
local GLOW = 10      -- px of soft glow just inside the frame's edge
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

-- The glow art (Media/glow-*.tga) is drawn to grow INWARD from an edge: the corner piece is
-- an L, bright along its two outer sides. So the glow sits just inside the unit frame, the
-- same way it does on SoThirsty's windows. (Flipping it outward makes the L's arms stick
-- out past the corners and cross.)
-- Corners: { point, texcoords }. Edges: { file, point 1, x, y, point 2, x, y, texcoords }.
local G = GLOW
local GLOW_CORNERS = {
  { "TOPLEFT", { 0, 1, 0, 1 } }, { "TOPRIGHT", { 1, 0, 0, 1 } },
  { "BOTTOMLEFT", { 0, 1, 1, 0 } }, { "BOTTOMRIGHT", { 1, 0, 1, 0 } },
}
local GLOW_EDGES = {
  { "glow-edge-v", "TOPLEFT", 0, -G, "BOTTOMLEFT", 0, G, { 0, 1, 0, 1 } },
  { "glow-edge-v", "TOPRIGHT", 0, -G, "BOTTOMRIGHT", 0, G, { 1, 0, 0, 1 } },
  { "glow-edge-h", "TOPLEFT", G, 0, "TOPRIGHT", -G, 0, { 0, 1, 0, 1 } },
  { "glow-edge-h", "BOTTOMLEFT", G, 0, "BOTTOMRIGHT", -G, 0, { 0, 1, 1, 0 } },
}

local STYLE = {
  border = function(parent, list, look) edgeInto(parent, list, look.thickness, 0) end,
  glow = function(parent, list)
    for _, g in ipairs(GLOW_CORNERS) do
      local t = piece(parent, list, Theme.MEDIA .. "glow-corner")
      t:SetSize(G, G)
      t:SetPoint(g[1])
      t:SetTexCoord(unpack(g[2]))
      t:SetBlendMode("ADD")
    end
    for _, g in ipairs(GLOW_EDGES) do
      local t = piece(parent, list, Theme.MEDIA .. g[1])
      t:SetSize(G, G)
      t:SetPoint(g[2], g[3], g[4])
      t:SetPoint(g[5], g[6], g[7])
      t:SetTexCoord(unpack(g[8]))
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

-- Motion (the pulse and the nudge) is driven by one shared timer that sets plain alpha on
-- our own frames. Not AnimationGroups: an Alpha animation on a parent OVERRIDES its child
-- textures' alpha instead of multiplying with it, so the mana-driven alpha was lost and the
-- glow showed at full mana (found in game). A frame's own SetAlpha multiplies correctly.
-- The timer only runs while something is moving.
local PULSE_MAX = 0.3            -- the pulse adds at most this much on top of the tint
local NUDGE_UP, NUDGE_DOWN = 0.35, 0.6
local STEP = 0.05
local moving = {}                -- holders with a pulse or nudge running
local ticker
local clock = 0

local function tick()
  clock = clock + STEP
  local any = false
  for holder in pairs(moving) do
    local keep = false
    local visible = holder:IsShown() and holder.baseAlpha > 0
    if holder.pulseOn and visible then
      local x = (clock % (2 * holder.pulsePeriod)) / holder.pulsePeriod -- 0..2
      if x > 1 then x = 2 - x end
      holder.pulse:SetAlpha(PULSE_MAX * x)
      keep = true
    end
    if holder.nudgeAt then
      local t = clock - holder.nudgeAt
      local k
      if not visible then
        k = nil
      elseif t < NUDGE_UP then
        k = t / NUDGE_UP
      elseif t < NUDGE_UP + holder.nudgeHold then
        k = 1
      elseif t < NUDGE_UP + holder.nudgeHold + NUDGE_DOWN then
        k = 1 - (t - NUDGE_UP - holder.nudgeHold) / NUDGE_DOWN
      end
      if k then
        holder.body:SetAlpha(holder.baseAlpha + (1 - holder.baseAlpha) * k)
        keep = true
      else
        holder.nudgeAt = nil
        holder.body:SetAlpha(holder.baseAlpha)
      end
    end
    if keep then any = true else moving[holder] = nil end
  end
  if not any and ticker then
    ticker:Cancel()
    ticker = nil
  end
end

local function move(holder)
  moving[holder] = true
  if not ticker then ticker = C_Timer.NewTicker(STEP, tick) end
end

-- Adds the layers to a holder. Also used for the Options preview frame.
function Frames.Build(holder)
  local body = CreateFrame("Frame", nil, holder)
  body:SetAllPoints()
  holder.body = body

  local glow = CreateFrame("Frame", nil, body)
  glow:SetAllPoints()
  holder.glow, holder.styles, holder.pieces = glow, {}, {}

  -- Pulse: a wash of the level 3 color over the whole frame. The game decides whether its
  -- texture is visible (below level 3); the shared timer breathes the frame's alpha.
  local pulse = CreateFrame("Frame", nil, body)
  pulse:SetAllPoints()
  pulse:SetAlpha(0)
  pulse.pieces = {}
  piece(pulse, pulse.pieces):SetAllPoints()
  holder.pulse = pulse
  holder.baseAlpha = 0

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

  Frames.Style(holder)
end

-- Applies the look settings to a holder: which style's pieces show, and the known colors.
function Frames.Style(holder)
  local cfg = ns.Settings()
  local look = cfg.look
  local build = STYLE[look.style] or STYLE.tint
  local key = (STYLE[look.style] and look.style or "tint") .. look.thickness
  if not holder.styles[key] then
    holder.styles[key] = {}
    build(holder.glow, holder.styles[key], look)
  end
  for k, list in pairs(holder.styles) do
    for _, t in ipairs(list) do t:SetShown(k == key) end
  end
  holder.pieces = holder.styles[key]
  holder.glowAlpha = 1
  holder.glow:SetAlpha(1)

  local c3 = cfg.levels[3].color
  for _, t in ipairs(holder.pulse.pieces) do t:SetVertexColor(c3[1], c3[2], c3[3]) end
  holder.pulseOn = look.pulse and true or false
  holder.pulsePeriod = Theme.PULSE_SECONDS[look.pulseSpeed] or 1
  holder.pulse:SetShown(holder.pulseOn)
  if holder.pulseOn then move(holder) end

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
  holder.baseAlpha = alpha
  -- A running nudge owns the body's alpha; the timer puts it back to baseAlpha when done.
  if not holder.nudgeAt then holder.body:SetAlpha(alpha) end
  if holder.pulseOn and alpha > 0 then move(holder) end
  holder.drop:SetShown(drinking and ns.Settings().frames.drop)
  for _, t in ipairs(holder.grey) do t:SetShown(grey) end
end

-- Plays the nudge on a holder (spec 7): brighten, hold, ease back. No size change.
function Frames.PlayNudge(holder)
  local cfg = ns.Settings()
  holder.nudgeAt = clock
  holder.nudgeHold = cfg.nudgeHold
  move(holder)
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
