rwda = rwda or {}
rwda.integrations = rwda.integrations or {}
rwda.integrations.groupcombat = rwda.integrations.groupcombat or {
  _handler_ids = {},
}

local adapter = rwda.integrations.groupcombat

function adapter.detect()
  local present = type(rawget(_G, "groupcombat")) == "table"
    or type(rawget(_G, "gcom")) == "table"
    or type(rawget(_G, "ga")) == "table"

  rwda.state.integration.group_present = present
  return present
end

function adapter.pullTarget()
  local gc = rawget(_G, "groupcombat")
  if type(gc) == "table" and type(gc.target) == "string" then
    return gc.target
  end

  local gcom = rawget(_G, "gcom")
  if type(gcom) == "table" and type(gcom.target) == "string" then
    return gcom.target
  end

  return nil
end

function adapter.sync()
  if not adapter.detect() then
    return false
  end

  local target = adapter.pullTarget()
  if target and target ~= "" then
    rwda.state.setTarget(target)
    return true
  end

  return false
end

function adapter.onTargetEvent()
  adapter.sync()
end

function adapter.registerHandlers()
  if type(registerAnonymousEventHandler) ~= "function" then
    return false
  end

  if next(adapter._handler_ids) then
    return true
  end

  local events = (rwda.config and rwda.config.integration and rwda.config.integration.group_target_events) or {}
  for i, eventName in ipairs(events) do
    if type(eventName) == "string" and eventName ~= "" then
      local ok, id = pcall(registerAnonymousEventHandler, eventName, "rwda.integrations.groupcombat.onTargetEvent")
      if ok and id then
        adapter._handler_ids[i] = id
      end
    end
  end

  return true
end

function adapter.unregisterHandlers()
  if type(killAnonymousEventHandler) ~= "function" then
    return false
  end

  for _, id in pairs(adapter._handler_ids) do
    pcall(killAnonymousEventHandler, id)
  end
  adapter._handler_ids = {}
  return true
end
