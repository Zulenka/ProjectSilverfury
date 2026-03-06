-- Silverfury/state/me.lua
-- Self state snapshot factory and live table.

Silverfury = Silverfury or {}
Silverfury.state = Silverfury.state or {}

-- Initial zeroed state for the player.
local function newMe()
  return {
    -- Vitals
    hp = 0, maxhp = 0,
    mp = 0, maxmp = 0,
    wp = 0, maxwp = 0,
    en = 0, maxen = 0,

    -- Balances (true = have balance)
    bal = true,
    eq  = true,

    -- Active afflictions and defences (key = name, value = true)
    affs = {},
    defs = {},

    -- Form: "human" or "dragon"
    form   = "human",
    flying = false,   -- airborne in dragon form

    -- Weapon state
    swords_wielded = false,
  }
end

Silverfury.state.me = newMe()

-- Convenience pct helpers.
function Silverfury.state.me.hpPct()
  local me = Silverfury.state.me
  if me.maxhp == 0 then return 1 end
  return me.hp / me.maxhp
end

function Silverfury.state.me.mpPct()
  local me = Silverfury.state.me
  if me.maxmp == 0 then return 1 end
  return me.mp / me.maxmp
end

function Silverfury.state.me.hasAff(name)
  return Silverfury.state.me.affs[name] == true
end

function Silverfury.state.me.hasDef(name)
  return Silverfury.state.me.defs[name] == true
end

function Silverfury.state.me.reset()
  local me = Silverfury.state.me
  local fresh = newMe()
  for k, v in pairs(fresh) do me[k] = v end
end
