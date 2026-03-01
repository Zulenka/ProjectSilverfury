rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.finisher = rwda.engine.finisher or {
  _handlers = {},
}

local finisher = rwda.engine.finisher

local FINISHER_MODES = {
  disembowel = "human_dualcut",
  devour = "dragon_silver",
}

local function now()
  return rwda.util.now()
end

local function ensureConfig()
  rwda.config.finisher = rwda.config.finisher or {}
  local cfg = rwda.config.finisher
  if cfg.enabled == nil then cfg.enabled = true end
  if cfg.cooldown_ms == nil then cfg.cooldown_ms = 1500 end
  if cfg.fallback_window_ms == nil then cfg.fallback_window_ms = 6000 end
  cfg.timeouts = cfg.timeouts or {}
  if cfg.timeouts.disembowel_ms == nil then cfg.timeouts.disembowel_ms = 2500 end
  if cfg.timeouts.devour_ms == nil then cfg.timeouts.devour_ms = 8000 end
  cfg.fallback_blocks = cfg.fallback_blocks or {}
  if cfg.fallback_blocks.human_dualcut == nil then cfg.fallback_blocks.human_dualcut = "limbprep_dsl" end
  if cfg.fallback_blocks.dragon_silver == nil then cfg.fallback_blocks.dragon_silver = "dragon_force_prone" end
  return cfg
end

local function ensureRuntime()
  rwda.state.runtime = rwda.state.runtime or {}
  rwda.state.runtime.finisher = rwda.state.runtime.finisher or {
    enabled = true,
    active = false,
    attempt_name = nil,
    attempt_mode = nil,
    attempt_target = nil,
    attempt_started_ms = 0,
    attempt_timeout_ms = 0,
    fallback_active = false,
    fallback_mode = nil,
    fallback_action = nil,
    fallback_until_ms = 0,
    last_result = "idle",
    last_reason = "idle",
    last_success_ms = 0,
    last_failure_ms = 0,
    cooldown_until_ms = 0,
  }
  return rwda.state.runtime.finisher
end

local function timeoutForAction(actionName)
  local cfg = ensureConfig()
  if actionName == "disembowel" then
    return tonumber(cfg.timeouts.disembowel_ms) or 2500
  end
  if actionName == "devour" then
    return tonumber(cfg.timeouts.devour_ms) or 8000
  end
  return 2500
end

local function fallbackBlockForMode(mode)
  local cfg = ensureConfig()
  return cfg.fallback_blocks and cfg.fallback_blocks[mode] or nil
end

local function startAttempt(action)
  local rt = ensureRuntime()
  local cfg = ensureConfig()
  local mode = FINISHER_MODES[action.name]
  if not mode then
    return
  end

  if now() < (tonumber(rt.cooldown_until_ms) or 0) then
    return
  end

  rt.active = true
  rt.attempt_name = action.name
  rt.attempt_mode = mode
  rt.attempt_target = rwda.state.target and rwda.state.target.name or nil
  rt.attempt_started_ms = now()
  rt.attempt_timeout_ms = timeoutForAction(action.name)
  rt.last_result = "attempting"
  rt.last_reason = "sent"

  if cfg.enabled == false then
    rt.enabled = false
  end
end

local function markFailure(reason)
  local rt = ensureRuntime()
  if not rt.active then
    return false
  end

  local cfg = ensureConfig()
  rt.active = false
  rt.last_result = "failed"
  rt.last_reason = reason or "failed"
  rt.last_failure_ms = now()
  rt.cooldown_until_ms = now() + (tonumber(cfg.cooldown_ms) or 1500)

  local fallback = fallbackBlockForMode(rt.attempt_mode)
  if fallback and fallback ~= "" then
    rt.fallback_active = true
    rt.fallback_mode = rt.attempt_mode
    rt.fallback_action = fallback
    rt.fallback_until_ms = now() + (tonumber(cfg.fallback_window_ms) or 6000)
  else
    rt.fallback_active = false
    rt.fallback_mode = nil
    rt.fallback_action = nil
    rt.fallback_until_ms = 0
  end

  return true
end

local function markSuccess(reason)
  local rt = ensureRuntime()
  if not rt.active then
    return false
  end

  local cfg = ensureConfig()
  rt.active = false
  rt.last_result = "success"
  rt.last_reason = reason or "success"
  rt.last_success_ms = now()
  rt.cooldown_until_ms = now() + (tonumber(cfg.cooldown_ms) or 1500)
  rt.fallback_active = false
  rt.fallback_mode = nil
  rt.fallback_action = nil
  rt.fallback_until_ms = 0
  return true
end

function finisher.setEnabled(enabled)
  local cfg = ensureConfig()
  local rt = ensureRuntime()
  local value = not not enabled
  cfg.enabled = value
  rt.enabled = value
  if not value then
    rt.active = false
    rt.fallback_active = false
    rt.last_reason = "disabled"
  else
    rt.last_reason = "enabled"
  end
  return value
end

function finisher.onActionSent(payload)
  payload = payload or {}
  local action = payload.action
  if type(action) ~= "table" then
    return
  end

  local cfg = ensureConfig()
  local rt = ensureRuntime()
  if cfg.enabled == false or rt.enabled == false then
    return
  end

  if FINISHER_MODES[action.name] then
    startAttempt(action)
    return
  end

  if rt.fallback_active then
    local reason = action.reason or {}
    local blockId = reason.strategy_block or reason.code
    if type(blockId) == "string" and blockId ~= "" then
      finisher.onFallbackActionTaken(action.mode, blockId)
    end
  end
end

function finisher.onSuccess(payload)
  payload = payload or {}
  local name = payload.name
  local rt = ensureRuntime()
  if not rt.active then
    return
  end
  if name and rt.attempt_name and name ~= rt.attempt_name then
    return
  end
  markSuccess(payload.reason or "line_success")
end

function finisher.onFail(payload)
  payload = payload or {}
  local name = payload.name
  local rt = ensureRuntime()
  if not rt.active then
    return
  end
  if name and rt.attempt_name and name ~= rt.attempt_name then
    return
  end
  markFailure(payload.reason or "line_fail")
end

function finisher.update()
  local cfg = ensureConfig()
  local rt = ensureRuntime()
  if cfg.enabled == false or rt.enabled == false then
    return false
  end

  local changed = false

  if rt.active and rt.attempt_started_ms > 0 and rt.attempt_timeout_ms > 0 then
    if now() >= (rt.attempt_started_ms + rt.attempt_timeout_ms) then
      if markFailure("timeout") then
        changed = true
      end
    end
  end

  if rt.fallback_active and rt.fallback_until_ms > 0 and now() >= rt.fallback_until_ms then
    rt.fallback_active = false
    rt.fallback_mode = nil
    rt.fallback_action = nil
    rt.fallback_until_ms = 0
    if rt.last_result == "failed" then
      rt.last_reason = "fallback_window_expired"
    end
    changed = true
  end

  return changed
end

function finisher.recommendedFallbackBlock(mode)
  local cfg = ensureConfig()
  local rt = ensureRuntime()
  if cfg.enabled == false or rt.enabled == false then
    return nil
  end
  if not rt.fallback_active then
    return nil
  end
  if mode ~= rt.fallback_mode then
    return nil
  end
  return rt.fallback_action
end

function finisher.onFallbackActionTaken(mode, blockId)
  local rt = ensureRuntime()
  if not rt.fallback_active then
    return
  end
  if mode ~= rt.fallback_mode then
    return
  end
  if blockId ~= rt.fallback_action then
    return
  end

  rt.fallback_active = false
  rt.fallback_mode = nil
  rt.fallback_action = nil
  rt.fallback_until_ms = 0
  rt.last_reason = "fallback_applied"
end

function finisher.status()
  local rt = ensureRuntime()
  return {
    enabled = rt.enabled,
    active = rt.active,
    attempt_name = rt.attempt_name,
    attempt_mode = rt.attempt_mode,
    attempt_target = rt.attempt_target,
    fallback_active = rt.fallback_active,
    fallback_mode = rt.fallback_mode,
    fallback_action = rt.fallback_action,
    fallback_until_ms = rt.fallback_until_ms,
    last_result = rt.last_result,
    last_reason = rt.last_reason,
    cooldown_until_ms = rt.cooldown_until_ms,
  }
end

function finisher.bootstrap()
  ensureConfig()
  local rt = ensureRuntime()
  rt.enabled = ensureConfig().enabled ~= false

  local events = rwda.engine and rwda.engine.events
  if not events then
    return true
  end

  if finisher._handlers.action_sent then
    return true
  end

  finisher._handlers.action_sent = events.on("ACTION_SENT", finisher.onActionSent)
  finisher._handlers.success = events.on("FINISHER_SUCCESS", finisher.onSuccess)
  finisher._handlers.fail = events.on("FINISHER_FAIL", finisher.onFail)
  return true
end

function finisher.shutdown()
  local events = rwda.engine and rwda.engine.events
  if not events then
    finisher._handlers = {}
    return true
  end

  if finisher._handlers.action_sent then
    events.off("ACTION_SENT", finisher._handlers.action_sent)
  end
  if finisher._handlers.success then
    events.off("FINISHER_SUCCESS", finisher._handlers.success)
  end
  if finisher._handlers.fail then
    events.off("FINISHER_FAIL", finisher._handlers.fail)
  end

  finisher._handlers = {}
  return true
end
