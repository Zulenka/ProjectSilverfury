rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.events = rwda.engine.events or {
  _handlers = {},
  _next_id = 1,
}

local events = rwda.engine.events

local function bucket(name)
  events._handlers[name] = events._handlers[name] or {}
  return events._handlers[name]
end

function events.on(name, fn)
  if type(name) ~= "string" or type(fn) ~= "function" then
    return nil
  end

  local id = events._next_id
  events._next_id = id + 1
  bucket(name)[id] = fn
  return id
end

function events.off(name, id)
  local b = events._handlers[name]
  if not b then
    return
  end
  b[id] = nil
end

function events.emit(name, payload)
  local b = events._handlers[name]
  if not b then
    return
  end

  for id, fn in pairs(b) do
    local ok, err = pcall(fn, payload)
    if not ok and rwda.util then
      rwda.util.log("error", "event %s handler %s failed: %s", name, tostring(id), tostring(err))
    end
  end
end

function events.clear(name)
  if name then
    events._handlers[name] = {}
  else
    events._handlers = {}
  end
end
