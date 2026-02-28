rwda = rwda or {}
rwda.state = rwda.state or {}

local state = rwda.state
local util = rwda.util

local function ensure()
  if type(rwda.statebuilders) ~= "table" then
    error("rwda.statebuilders missing. Load state modules first.")
  end

  if not state.me then
    state.me = rwda.statebuilders.newMe()
  end
  if not state.target then
    state.target = rwda.statebuilders.newTarget()
  end
  if not state.cooldowns then
    state.cooldowns = rwda.statebuilders.newCooldowns()
  end
  if not state.flags then
    state.flags = {
      enabled = false,
      stopped = false,
      debug = false,
      mode = "auto",
      goal = "limbprep",
      profile = "duel",
    }
  end
  if not state.integration then
    state.integration = {
      gmcp_present = false,
      legacy_present = false,
      svof_present = false,
      aklimb_present = false,
      group_present = false,
    }
  end
  if not state.runtime then
    state.runtime = {
      last_action = nil,
      last_reason = nil,
      pending_action = nil,
      last_send_by_command = {},
    }
  end
end

function state.bootstrap()
  ensure()
  return state
end

function state.reset()
  state.me = rwda.statebuilders.newMe()
  state.target = rwda.statebuilders.newTarget()
  state.cooldowns = rwda.statebuilders.newCooldowns()
  state.flags = {
    enabled = false,
    stopped = false,
    debug = false,
    mode = "auto",
    goal = "limbprep",
    profile = "duel",
  }
  state.integration = {
    gmcp_present = false,
    legacy_present = false,
    svof_present = false,
    aklimb_present = false,
    group_present = false,
  }
  state.runtime = {
    last_action = nil,
    last_reason = nil,
    pending_action = nil,
    last_send_by_command = {},
  }
end

function state.setEnabled(enabled)
  ensure()
  state.flags.enabled = not not enabled
end

function state.setStopped(stopped)
  ensure()
  state.flags.stopped = not not stopped
end

function state.setTarget(name)
  ensure()
  if type(name) == "string" then
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
  end
  state.target.name = name
  state.target.dead = false
  state.target.available = true
  state.target.unavailable_reason = nil
  state.target.unavailable_since = 0
  state.target.last_seen = util.now()
end

function state.clearTarget()
  ensure()
  local oldName = state.target.name
  state.target = rwda.statebuilders.newTarget()
  if oldName then
    state.target.last_target = oldName
  end
end

function state.setMode(mode)
  ensure()
  state.flags.mode = mode
end

function state.setGoal(goal)
  ensure()
  state.flags.goal = goal
end

function state.setForm(form)
  ensure()
  if form ~= "human" and form ~= "dragon" then
    return
  end
  state.me.form = form
end

function state.setMeAff(affliction, active, source)
  ensure()
  if not affliction then
    return
  end

  if active then
    state.me.affs[affliction] = {
      active = true,
      source = source or "unknown",
      at = util.now(),
    }
  else
    state.me.affs[affliction] = nil
  end
end

function state.setTargetAff(affliction, active, source)
  ensure()
  if not affliction then
    return
  end

  if active then
    state.target.affs[affliction] = {
      active = true,
      source = source or "unknown",
      at = util.now(),
    }
  else
    state.target.affs[affliction] = nil
  end
end

function state.setTargetDefence(name, active, confidence, source)
  ensure()
  if not name then
    return
  end

  if not state.target.defs[name] then
    state.target.defs[name] = {
      active = false,
      confidence = 0,
      source = "unknown",
      last_seen = 0,
    }
  end

  local d = state.target.defs[name]
  d.active = not not active
  d.confidence = confidence or (active and 1.0 or 0)
  d.source = source or "unknown"
  d.last_seen = util.now()
end

function state.setTargetProne(prone, source)
  ensure()
  state.target.prone = not not prone
  state.target.stance.standing = not state.target.prone
  state.target.last_seen = util.now()
  state.target.prone_source = source or "unknown"
end

function state.setTargetDead(isDead, source)
  ensure()
  state.target.dead = not not isDead
  if isDead then
    state.target.available = false
    state.target.unavailable_reason = "dead"
    state.target.unavailable_since = util.now()
  end
  state.target.last_seen = util.now()
  state.target.dead_source = source or "unknown"
end

function state.setTargetAvailable(isAvailable, source, reason)
  ensure()
  isAvailable = not not isAvailable

  state.target.available = isAvailable
  if isAvailable then
    state.target.unavailable_reason = nil
    state.target.unavailable_since = 0
    state.target.last_seen = util.now()
  else
    state.target.unavailable_reason = reason or "unknown"
    state.target.unavailable_since = util.now()
  end

  state.target.available_source = source or "unknown"
end

function state.setTargetImpaled(isImpaled, source)
  ensure()
  state.target.impaled = not not isImpaled
  state.target.last_seen = util.now()
  state.target.impaled_source = source or "unknown"
end

function state.updateTargetLimb(limb, patch)
  ensure()
  if not limb or not state.target.limbs[limb] then
    return
  end

  patch = patch or {}
  util.merge(state.target.limbs[limb], patch)
  state.target.limbs[limb].last_updated = util.now()

  local l = state.target.limbs[limb]
  if l.broken then
    l.state = "broken"
  elseif l.mangled then
    l.state = "mangled"
  elseif l.damage_pct and l.damage_pct > 0 then
    l.state = "damaged"
  else
    l.state = "ok"
  end
end

function state.hasTargetDefence(name)
  ensure()
  local d = state.target.defs[name]
  return d and d.active and d.confidence > 0
end

function state.hasTarget()
  ensure()
  return state.target.name and state.target.name ~= "" and not state.target.dead
end

function state.isTargetAvailable()
  ensure()
  if not state.hasTarget() then
    return false
  end

  if rwda.config and rwda.config.combat and rwda.config.combat.require_target_available == false then
    return true
  end

  return state.target.available
end

function state.decayTargetDefences(nowMs)
  ensure()
  if not rwda.data or not rwda.data.defences then
    return
  end

  nowMs = nowMs or util.now()
  for name, def in pairs(state.target.defs) do
    local hasSignal = def.active or ((def.confidence or 0) > 0)
    if hasSignal and def.last_seen and def.last_seen > 0 then
      local spec = rwda.data.defences[name]
      local decay = spec and spec.decay_seconds or 0
      if decay and decay > 0 then
        local ageSec = (nowMs - def.last_seen) / 1000
        if ageSec >= decay then
          def.active = false
          def.confidence = 0
          def.source = "decay"
        else
          local remain = 1 - (ageSec / decay)
          if def.active then
            def.confidence = math.max(0.05, util.round(remain, 3))
          else
            def.confidence = math.max(0, util.round(remain, 3))
          end
        end
      end
    end
  end
end

state.bootstrap()
