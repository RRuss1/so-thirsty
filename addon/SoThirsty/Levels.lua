-- The warning-level state machine (spec 6.2). PURE: no WoW API calls, only numbers and
-- booleans in and decisions out, so addon/tests/logic.lua covers every rule.
--
-- cfg is the settings table: cfg.levels[i] = { enabled, pct }, cfg.ready = { enabled, pct },
-- cfg.rearmMargin, cfg.drinkRise.
local _, ns = ...

local Levels = {}
ns.Levels = Levels

-- Shared, read-only decisions (no table per mana update).
local ARM = { kind = "arm" }
local READY = { kind = "ready" }
Levels.ARM, Levels.READY = ARM, READY

-- A real number we may do math on (not nil, not a secret value).
local function known(v)
  return type(v) == "number" and not ns.IsSecret(v)
end

function Levels.NewState()
  return { announced = 0, cycle = false, lastPct = nil }
end

-- floor(mana / max * 100), or nil when either is unknown or max is 0.
function Levels.Pct(mana, max)
  if not known(mana) or not known(max) or max <= 0 then return nil end
  local pct = math.floor(mana / max * 100)
  if pct < 0 then return 0 end
  if pct > 100 then return 100 end
  return pct
end

-- The deepest enabled level whose threshold is greater than pct, or 0.
function Levels.Current(pct, cfg)
  for i = #cfg.levels, 1, -1 do
    local lv = cfg.levels[i]
    if lv.enabled and pct < lv.pct then return i end
  end
  return 0
end

-- The next shallower enabled level than n, or 0.
local function shallower(n, cfg)
  for i = n - 1, 1, -1 do
    if cfg.levels[i].enabled then return i end
  end
  return 0
end

-- Every (coalesced) mana update. Never announces a level.
-- Returns nil, Levels.ARM (open an alert window) or Levels.READY.
function Levels.Update(state, pct, inCombat, cfg)
  if not known(pct) then return nil end
  state.lastPct = pct
  -- Re-arm: climbing past a level's threshold + margin lets it warn again later.
  while state.announced > 0 and pct >= cfg.levels[state.announced].pct + cfg.rearmMargin do
    state.announced = shallower(state.announced, cfg)
  end
  if inCombat then return nil end
  if state.cycle and cfg.ready.enabled and pct >= cfg.ready.pct then
    state.cycle = false
    state.announced = 0
    return READY
  end
  if Levels.Current(pct, cfg) > state.announced then return ARM end
  return nil
end

-- Once per healer when an alert window closes (spec 7).
-- Returns nil or { kind = "level", level = n, pct = pct }.
function Levels.Settle(state, pct, drinking, cfg)
  if not known(pct) then return nil end
  state.lastPct = pct
  local current = Levels.Current(pct, cfg)
  if current <= state.announced then return nil end -- escalation only
  if drinking then return nil end -- leave announced alone: the next window can still warn
  state.announced = current
  state.cycle = true
  return { kind = "level", level = current, pct = pct }
end

-- The pure half of drink detection (spec 6.4). auraMatch: true, false or nil (unknown).
function Levels.IsDrinking(auraMatch, startPct, endPct, cfg)
  if auraMatch == true then return true end
  if known(startPct) and known(endPct) and endPct - startPct >= cfg.drinkRise then return true end
  return false
end

-- levels: { { enabled, pct }, ... }. Enabled thresholds must be 1..99 and strictly descending.
-- Returns true, or false and "RANGE" | "ORDER".
function Levels.Validate(levels)
  local last
  for _, lv in ipairs(levels) do
    if lv.enabled then
      local pct = lv.pct
      if type(pct) ~= "number" or pct < 1 or pct > 99 or pct ~= math.floor(pct) then return false, "RANGE" end
      if last and pct >= last then return false, "ORDER" end
      last = pct
    end
  end
  return true
end
