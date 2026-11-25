-- "Is the healer already drinking?" (spec 6.4). The aura half lives here; the mana-rise half
-- and the final decision are pure, in Levels.IsDrinking. Auras are only scanned when asked
-- (an alert window closing, /sot status, /sot debug drink), never on UNIT_AURA.
local _, ns = ...
local L = ns.L

local Drink = {}
ns.Drink = Drink

-- Drink buff spell IDs, filled in as /sot debug drink finds them on Forever (spec 16 Q11).
Drink.SPELL_IDS = {}

local drinkNames
local function isDrinkName(name)
  if not drinkNames then
    drinkNames = {}
    for _, n in ipairs(L.DRINK_AURAS) do drinkNames[n] = true end
  end
  return drinkNames[name] == true
end

-- The i-th helpful aura: exists, name, spellId. Uses C_UnitAuras where the client has it.
local function aura(unit, i)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
    if not a then return false end
    return true, a.name, a.spellId
  end
  if UnitAura then
    local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HELPFUL")
    if name == nil then return false end
    return true, name, spellId
  end
  return false
end

local function scan(unit)
  local unknown = false
  for i = 1, 40 do
    local exists, name, spellId = aura(unit, i)
    if not exists then break end
    local nameOk, idOk = not ns.IsSecret(name), not ns.IsSecret(spellId)
    if idOk and spellId and Drink.SPELL_IDS[spellId] then return true end
    if nameOk and name and isDrinkName(name) then return true end
    if not nameOk and not idOk then unknown = true end
  end
  if unknown then return nil end
  return false
end

-- true: a drink buff is on them. false: no drink buff. nil: the game hid what we'd need.
function Drink.AuraMatch(unit)
  local ok, result = pcall(scan, unit)
  if not ok then return nil end
  return result
end

-- For /sot debug drink: every helpful aura as { name, spellId } (either may be a secret value).
function Drink.List(unit)
  local list = {}
  pcall(function()
    for i = 1, 40 do
      local exists, name, spellId = aura(unit, i)
      if not exists then break end
      list[#list + 1] = { name = name, spellId = spellId }
    end
  end)
  return list
end
