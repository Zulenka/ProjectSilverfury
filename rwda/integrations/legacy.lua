rwda = rwda or {}
rwda.integrations = rwda.integrations or {}
rwda.integrations.legacy = rwda.integrations.legacy or {
  _handler_ids = {},
}

local legacy = rwda.integrations.legacy

local function now()
  return rwda.util.now()
end

local function bool(value)
  return not not value
end

local function hasLegacy()
  local L = rawget(_G, "Legacy")
  if type(L) ~= "table" then
    return false
  end

  if type(L.Curing) == "table" then
    return true
  end

  -- Legacy may exist briefly before Curing is populated; treat as present.
  return type(L.Settings) == "table" or type(L.Version) == "string"
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

local function autoEnableWithLegacy()
  local cfg = rwda.config and rwda.config.integration or {}
  if cfg.auto_enable_with_legacy == false then
    return false
  end

  if rwda.state and rwda.state.flags and rwda.state.flags.enabled then
    return false
  end

  if rwda.enable then
    rwda.enable()
    return true
  end

  return false
end

function legacy.detect()
  local present = hasLegacy()
  rwda.state.integration.legacy_present = present
  return present
end

function legacy.syncFromGlobals()
  if not legacy.detect() then
    return false
  end

  local L = Legacy
  local C = L.Curing or {}
  local me = rwda.state.me

  me.affs = {}
  if type(C.Affs) == "table" then
    for affName, active in pairs(C.Affs) do
      if active then
        me.affs[tostring(affName)] = { active = true, source = "legacy", at = now() }
      end
    end
  end

  me.defs = {}
  local defsCurrent = C.Defs and C.Defs.current or nil
  if type(defsCurrent) == "table" then
    for defName, active in pairs(defsCurrent) do
      if active then
        me.defs[tostring(defName)] = { active = true, source = "legacy", at = now() }
      end
    end
  elseif type(C.Defs) == "table" and type(C.Defs.tracking) == "table" then
    for defName, value in pairs(C.Defs.tracking) do
      if tonumber(value) == 0 then
        me.defs[tostring(defName)] = { active = true, source = "legacy_tracking", at = now() }
      end
    end
  end

  if type(C.bal) == "table" then
    local bal = C.bal
    if bal.active ~= nil then
      setBalance("balance", bool(bal.active))
      setBalance("equilibrium", bool(bal.active))
    end

    if bal.eat ~= nil then me.balances.herb = bool(bal.eat) end
    if bal.apply ~= nil then me.balances.salve = bool(bal.apply) end
    if bal.sip ~= nil then me.balances.sip = bool(bal.sip) end
    if bal.focus ~= nil then me.balances.focus = bool(bal.focus) end
    if bal.tree ~= nil then me.balances.tree = bool(bal.tree) end
    if bal.smoke ~= nil then me.balances.smoke = bool(bal.smoke) end
  end

  if gmcp and gmcp.Char and gmcp.Char.Vitals then
    local v = gmcp.Char.Vitals
    me.hp = tonumber(v.hp) or me.hp
    me.maxhp = tonumber(v.maxhp) or me.maxhp
    me.mp = tonumber(v.mp) or me.mp
    me.maxmp = tonumber(v.maxmp) or me.maxmp

    if v.bal ~= nil then
      setBalance("balance", rwda.util.bool(v.bal))
    end
    if v.eq ~= nil then
      setBalance("equilibrium", rwda.util.bool(v.eq))
    end
  end

  local dragon = false
  if me.defs.dragonform then
    dragon = true
  elseif C.dragonforming then
    dragon = true
  end
  me.form = dragon and "dragon" or "human"

  return true
end

function legacy.onLegacyLoaded()
  legacy.syncFromGlobals()
  autoEnableWithLegacy()
end

function legacy.onVitals()
  local hadBal = rwda.state.me.bal
  local hadEq = rwda.state.me.eq
  legacy.syncFromGlobals()
  if rwda.engine and rwda.engine.executor and (rwda.state.me.bal ~= hadBal or rwda.state.me.eq ~= hadEq) then
    rwda.engine.executor.flushPending()
  end
end

function legacy.onAffAdd()
  legacy.syncFromGlobals()
end

function legacy.onAffRemove()
  legacy.syncFromGlobals()
end

function legacy.onDefAdd()
  legacy.syncFromGlobals()
end

function legacy.onDefRemove()
  legacy.syncFromGlobals()
end

function legacy.registerHandlers()
  if type(registerAnonymousEventHandler) ~= "function" then
    return false
  end

  if legacy._handler_ids.loaded then
    return true
  end

  legacy._handler_ids.loaded = registerAnonymousEventHandler("LegacyLoaded", "rwda.integrations.legacy.onLegacyLoaded")
  legacy._handler_ids.vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", "rwda.integrations.legacy.onVitals")
  legacy._handler_ids.aff_add = registerAnonymousEventHandler("gmcp.Char.Afflictions.Add", "rwda.integrations.legacy.onAffAdd")
  legacy._handler_ids.aff_remove = registerAnonymousEventHandler("gmcp.Char.Afflictions.Remove", "rwda.integrations.legacy.onAffRemove")
  legacy._handler_ids.def_add = registerAnonymousEventHandler("gmcp.Char.Defences.Add", "rwda.integrations.legacy.onDefAdd")
  legacy._handler_ids.def_remove = registerAnonymousEventHandler("gmcp.Char.Defences.Remove", "rwda.integrations.legacy.onDefRemove")

  return true
end

function legacy.unregisterHandlers()
  if type(killAnonymousEventHandler) ~= "function" then
    return false
  end

  for _, id in pairs(legacy._handler_ids) do
    pcall(killAnonymousEventHandler, id)
  end

  legacy._handler_ids = {}
  return true
end
