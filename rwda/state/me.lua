rwda = rwda or {}
rwda.statebuilders = rwda.statebuilders or {}

local builders = rwda.statebuilders

function builders.newMe()
  return {
    hp = 0,
    maxhp = 0,
    mp = 0,
    maxmp = 0,
    bal = true,
    eq = true,
    form = "human",
    affs = {},
    defs = {},
    balances = {
      balance = true,
      equilibrium = true,
      herb = true,
      salve = true,
      smoke = true,
      sip = true,
      focus = true,
      tree = true,
      fitness = true,
      rage = true,
      dragonheal = true,
    },
    channels = {
      herb_ready_at = 0,
      salve_ready_at = 0,
      smoke_ready_at = 0,
      sip_ready_at = 0,
      focus_ready_at = 0,
      writhe_ready_at = 0,
    },
    dragon = {
      breath_summoned = false,
      breath_type = "lightning",
      clawparry_target = nil,
    },
    last_balance_loss = 0,
    last_eq_loss = 0,
    last_prompt_ms = 0,
  }
end
