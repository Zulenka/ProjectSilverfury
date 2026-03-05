-- Silverfury/scenarios/base.lua
-- Finite state machine base for all combat scenarios.
-- States: IDLE | SETUP | MAINTAIN | EXECUTE | ABORT

Silverfury = Silverfury or {}
Silverfury.scenarios = Silverfury.scenarios or {}

local base = {}
Silverfury.scenarios.base = base

-- ── FSM states ────────────────────────────────────────────────────────────────

local STATES = { IDLE="IDLE", SETUP="SETUP", MAINTAIN="MAINTAIN", EXECUTE="EXECUTE", ABORT="ABORT" }
base.STATES = STATES

-- ── Active scenario context ───────────────────────────────────────────────────

local _ctx = {
  state        = STATES.IDLE,
  name         = nil,           -- active scenario name
  scenario     = nil,           -- scenario module ref
  last_reason  = "",
  started_ms   = 0,
}

-- ── Query ─────────────────────────────────────────────────────────────────────

function base.isActive()
  return _ctx.state ~= STATES.IDLE and _ctx.state ~= STATES.ABORT
end

function base.getState()
  return _ctx.state
end

function base.getName()
  return _ctx.name
end

function base.lastReason()
  return _ctx.last_reason
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function base.start(scenario_name, scenario_module)
  if base.isActive() then
    Silverfury.log.warn("Scenario already active: %s", _ctx.name)
    return false
  end
  if not Silverfury.safety.isArmed() then
    Silverfury.log.warn("Cannot start scenario: not armed.")
    return false
  end
  if not Silverfury.state.target.isAvailable() then
    Silverfury.log.warn("Cannot start scenario: no valid target.")
    return false
  end

  _ctx.name       = scenario_name
  _ctx.scenario   = scenario_module
  _ctx.state      = STATES.SETUP
  _ctx.started_ms = Silverfury.time.now()
  _ctx.last_reason = "started"

  if scenario_module.onStart then scenario_module.onStart() end

  Silverfury.log.info("Scenario STARTED: %s", scenario_name)
  Silverfury.logging.logger.write("MODE_CHANGE", { mode="SCENARIO", scenario=scenario_name })
  raiseEvent("SF_ScenarioStarted", scenario_name)
  return true
end

function base.stop(reason)
  if not base.isActive() then return end
  local name = _ctx.name
  if _ctx.scenario and _ctx.scenario.onStop then _ctx.scenario.onStop() end
  _ctx.state      = STATES.IDLE
  _ctx.name       = nil
  _ctx.scenario   = nil
  _ctx.last_reason = reason or "stopped"
  Silverfury.log.info("Scenario STOPPED: %s (%s)", name or "?", _ctx.last_reason)
  Silverfury.logging.logger.write("MODE_CHANGE", { mode="IDLE", reason=_ctx.last_reason })
  raiseEvent("SF_ScenarioStopped", name, _ctx.last_reason)
end

function base.abort(reason)
  if _ctx.scenario and _ctx.scenario.onAbort then _ctx.scenario.onAbort() end
  _ctx.state      = STATES.ABORT
  _ctx.last_reason = reason or "aborted"
  Silverfury.log.warn("Scenario ABORTED: %s — %s", _ctx.name or "?", _ctx.last_reason)
  Silverfury.logging.logger.write("ABORT", { scenario=_ctx.name, reason=_ctx.last_reason })
  raiseEvent("SF_ScenarioAborted", _ctx.name, _ctx.last_reason)
  -- Transition to idle after event.
  _ctx.state    = STATES.IDLE
  _ctx.name     = nil
  _ctx.scenario = nil
end

-- ── Transition helpers ────────────────────────────────────────────────────────

function base.transition(new_state, reason)
  _ctx.state      = new_state
  _ctx.last_reason = reason or new_state
  Silverfury.log.trace("Scenario → %s: %s", new_state, _ctx.last_reason)
end

-- ── Next action (called by planner each tick) ─────────────────────────────────

function base.nextAction()
  if not base.isActive() or not _ctx.scenario then return nil end
  local s = _ctx.scenario

  if _ctx.state == STATES.SETUP then
    if s.setupDone and s.setupDone() then
      base.transition(STATES.MAINTAIN, "setup complete")
    elseif s.setupAction then
      local a = s.setupAction()
      if a then
        _ctx.last_reason = a.reason or "setup"
        return a
      end
    end

  elseif _ctx.state == STATES.MAINTAIN then
    -- Check if still safe to proceed.
    if s.shouldAbort and s.shouldAbort() then
      base.abort("maintain: abort condition met")
      return nil
    end
    if s.canExecute and s.canExecute() then
      base.transition(STATES.EXECUTE, "prerequisites met")
    elseif s.maintainAction then
      local a = s.maintainAction()
      if a then
        _ctx.last_reason = a.reason or "maintain"
        return a
      end
    end

  elseif _ctx.state == STATES.EXECUTE then
    if s.shouldAbort and s.shouldAbort() then
      base.abort("execute: abort condition met")
      return nil
    end
    if s.executeAction then
      local a = s.executeAction()
      if a then
        _ctx.last_reason = a.reason or "execute"
        return a
      end
    end
    if s.isComplete and s.isComplete() then
      base.stop("scenario complete")
    end
  end

  return nil
end

-- ── Status ────────────────────────────────────────────────────────────────────

function base.status()
  return {
    active  = base.isActive(),
    name    = _ctx.name,
    state   = _ctx.state,
    reason  = _ctx.last_reason,
    elapsed = _ctx.started_ms > 0 and Silverfury.time.elapsed_s(_ctx.started_ms) or 0,
  }
end
