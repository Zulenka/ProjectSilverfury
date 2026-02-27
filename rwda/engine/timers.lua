rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.timers = rwda.engine.timers or {
  _ids = {},
}

local timers = rwda.engine.timers

function timers.set(name, seconds, fn)
  if timers._ids[name] and type(killTimer) == "function" then
    pcall(killTimer, timers._ids[name])
  end

  if type(tempTimer) ~= "function" then
    return nil
  end

  local id = tempTimer(seconds, function()
    timers._ids[name] = nil
    if type(fn) == "function" then
      fn()
    end
  end)

  timers._ids[name] = id
  return id
end

function timers.cancel(name)
  if not timers._ids[name] then
    return
  end

  if type(killTimer) == "function" then
    pcall(killTimer, timers._ids[name])
  end

  timers._ids[name] = nil
end

function timers.cancelAll()
  for name in pairs(timers._ids) do
    timers.cancel(name)
  end
end
