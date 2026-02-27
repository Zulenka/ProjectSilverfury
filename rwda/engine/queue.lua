rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.queue = rwda.engine.queue or {}

local queue = rwda.engine.queue

local function sendRaw(command)
  if type(send) == "function" then
    send(command)
    return true
  end

  if rwda.util then
    rwda.util.log("warn", "send() is unavailable, skipped command: %s", command)
  end
  return false
end

function queue.clear(which)
  which = which or "all"
  return sendRaw("clearqueue " .. which)
end

function queue.add(queueType, command, mode)
  queueType = queueType or "bal"
  mode = mode or "addclear"

  local verb = "addclear"
  if mode == "prepend" then
    verb = "prepend"
  elseif mode == "add" then
    verb = "add"
  elseif mode == "addclearfull" then
    verb = "addclearfull"
  end

  return sendRaw(string.format("queue %s %s %s", verb, queueType, command))
end

function queue.attack(command)
  return queue.add("freestand", command, "addclear")
end

function queue.escape(command)
  return queue.add("bal", command, "prepend")
end
