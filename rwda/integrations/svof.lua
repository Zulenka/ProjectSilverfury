rwda = rwda or {}
rwda.integrations = rwda.integrations or {}
rwda.integrations.svof = rwda.integrations.svof or {
  _handler_ids = {},
}

local svof = rwda.integrations.svof

local function now()
  return rwda.util.now()
end

local function setBalance(balance, value)
  rwda.state.me.balances[balance] = value
  if balance == "balance" then
    rwda.state.me.bal = value
    if not value then
      rwda.state.me.last_balance_loss = now()
    end
  elseif balance == "equilibrium" then
    rwda.state.me.eq = value
    if not value then
      rwda.state.me.last_eq_loss = now()
    end
  end
end

function svof.detect()
  local present = type(rawget(_G, "defc")) == "table"
    and type(rawget(_G, "affl")) == "table"
    and type(rawget(_G, "bals")) == "table"

  rwda.state.integration.svof_present = present
  return present
end

function svof.syncFromGlobals()
  if not svof.detect() then
    return false
  end

  local me = rwda.state.me

  me.affs = {}
  for affName, affState in pairs(affl) do
    if type(affName) == "string" and affState then
      me.affs[affName] = { active = true, source = "svof", at = now() }
    end
  end

  me.defs = {}
  for defName, active in pairs(defc) do
    if active then
      me.defs[defName] = { active = true, source = "svof", at = now() }
    end
  end

  for balanceName, up in pairs(bals) do
    if type(balanceName) == "string" then
      me.balances[balanceName] = not not up
    end
  end

  me.bal = not not bals.balance
  me.eq = not not bals.equilibrium
  me.form = defc.dragonform and "dragon" or "human"

  return true
end

function svof.onGotAff(_, affName)
  rwda.state.setMeAff(affName, true, "svof")
end

function svof.onLostAff(_, affName)
  rwda.state.setMeAff(affName, false, "svof")
end

function svof.onGotDef(_, defName)
  rwda.state.me.defs[defName] = { active = true, source = "svof", at = now() }
  if defName == "dragonform" then
    rwda.state.setForm("dragon")
  end
end

function svof.onLostDef(_, defName)
  rwda.state.me.defs[defName] = nil
  if defName == "dragonform" then
    rwda.state.setForm("human")
  end
end

function svof.onGotBalance(_, balance)
  setBalance(balance, true)
  if (balance == "balance" or balance == "equilibrium") and rwda.engine and rwda.engine.executor then
    rwda.engine.executor.flushPending()
  end
end

function svof.onLostBalance(_, balance)
  setBalance(balance, false)
end

function svof.onDragonForm()
  rwda.state.setForm("dragon")
end

function svof.onLostDragonForm()
  rwda.state.setForm("human")
end

function svof.registerHandlers()
  if type(registerAnonymousEventHandler) ~= "function" then
    return false
  end

  if svof._handler_ids.aff_gain then
    return true
  end

  svof._handler_ids.aff_gain = registerAnonymousEventHandler("svo got aff", "rwda.integrations.svof.onGotAff")
  svof._handler_ids.aff_lost = registerAnonymousEventHandler("svo lost aff", "rwda.integrations.svof.onLostAff")
  svof._handler_ids.def_gain = registerAnonymousEventHandler("svo got def", "rwda.integrations.svof.onGotDef")
  svof._handler_ids.def_lost = registerAnonymousEventHandler("svo lost def", "rwda.integrations.svof.onLostDef")
  svof._handler_ids.bal_gain = registerAnonymousEventHandler("svo got balance", "rwda.integrations.svof.onGotBalance")
  svof._handler_ids.bal_lost = registerAnonymousEventHandler("svo lost balance", "rwda.integrations.svof.onLostBalance")
  svof._handler_ids.dragon_gain = registerAnonymousEventHandler("svo got dragonform", "rwda.integrations.svof.onDragonForm")
  svof._handler_ids.dragon_lost = registerAnonymousEventHandler("svo lost dragonform", "rwda.integrations.svof.onLostDragonForm")

  return true
end

function svof.unregisterHandlers()
  if type(killAnonymousEventHandler) ~= "function" then
    return false
  end

  for _, id in pairs(svof._handler_ids) do
    pcall(killAnonymousEventHandler, id)
  end

  svof._handler_ids = {}
  return true
end
