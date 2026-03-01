rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.executor = rwda.engine.executor or {
  _safety_handler_id = nil,
}

local executor = rwda.engine.executor

local function now()
  return rwda.util.now()
end

local function keyForAction(action)
  if not action or not action.commands then
    return ""
  end

  local chunks = {}
  for _, entry in ipairs(action.commands) do
    if type(entry) == "table" then
      chunks[#chunks + 1] = tostring(entry.cmd or entry[1] or "")
    else
      chunks[#chunks + 1] = tostring(entry)
    end
  end

  return table.concat(chunks, " | ")
end

local function passesRequirements(action, state)
  local req = action.requires or {}
  if req.bal and not state.me.bal then
    return false, "no_balance"
  end
  if req.eq and not state.me.eq then
    return false, "no_equilibrium"
  end
  return true
end

local function antiSpamBlocked(action, state)
  local minMs = rwda.config.combat.anti_spam_ms or 250
  local key = keyForAction(action)
  local last = state.runtime.last_send_by_command[key] or 0
  local delta = now() - last
  if delta < minMs then
    return true, minMs - delta
  end
  return false, 0
end

local function rememberSend(action, state)
  local key = keyForAction(action)
  state.runtime.last_send_by_command[key] = now()
  state.runtime.last_action = action
end

local function sendCommand(command, queueType, mode)
  if rwda.config.executor.use_server_queue then
    if rwda.engine.queue then
      return rwda.engine.queue.add(queueType or rwda.config.executor.queue_type_default or "bal", command, mode or "addclear")
    end
  end

  if type(send) == "function" then
    send(command)
    return true
  end

  rwda.util.log("warn", "Unable to send command (send() missing): %s", command)
  return false
end

function executor.execute(action)
  local state = rwda.state

  if not action then
    return false, "no_action"
  end

  if not state.flags.enabled then
    return false, "disabled"
  end

  if state.flags.stopped then
    return false, "stopped"
  end

  local ok, reason = passesRequirements(action, state)
  if not ok then
    state.runtime.pending_action = action
    return false, reason
  end

  local blocked, waitMs = antiSpamBlocked(action, state)
  if blocked then
    return false, string.format("anti_spam_%d", waitMs)
  end

  if action.clear_queue and rwda.engine.queue then
    rwda.engine.queue.clear("all")
  end

  local defaultQueue = action.queue_type or rwda.config.executor.queue_type_default or "bal"
  for _, entry in ipairs(action.commands or {}) do
    if type(entry) == "table" then
      sendCommand(entry.cmd or entry[1], entry.queue or defaultQueue, entry.mode)
    else
      sendCommand(entry, defaultQueue, action.queue_mode)
    end
  end

  state.runtime.pending_action = nil
  rememberSend(action, state)

  if rwda.engine and rwda.engine.events and rwda.engine.events.emit then
    rwda.engine.events.emit("ACTION_SENT", {
      action = action,
      at = now(),
    })
  end

  return true
end

function executor.flushPending()
  local pending = rwda.state.runtime.pending_action
  if not pending then
    return false, "empty"
  end

  return executor.execute(pending)
end

function executor.stop(clearQueue)
  rwda.state.flags.stopped = true

  if clearQueue and rwda.engine.queue then
    rwda.engine.queue.clear("all")
  end
end

function executor.resume()
  rwda.state.flags.stopped = false
end

function executor.onSendRequest(_, command)
  if not rwda.config.safety.deny_send_when_stopped then
    return
  end

  if not rwda.state.flags.stopped then
    return
  end

  if type(command) == "string" and command:lower():match("^rwda") then
    return
  end

  if type(denyCurrentSend) == "function" then
    denyCurrentSend()
    rwda.util.log("warn", "Blocked outbound command while stopped: %s", tostring(command))
  end
end

function executor.registerSafetyValve()
  if executor._safety_handler_id or type(registerAnonymousEventHandler) ~= "function" then
    return false
  end

  executor._safety_handler_id = registerAnonymousEventHandler("sysDataSendRequest", "rwda.engine.executor.onSendRequest")
  return true
end

function executor.unregisterSafetyValve()
  if not executor._safety_handler_id or type(killAnonymousEventHandler) ~= "function" then
    return false
  end

  pcall(killAnonymousEventHandler, executor._safety_handler_id)
  executor._safety_handler_id = nil
  return true
end
