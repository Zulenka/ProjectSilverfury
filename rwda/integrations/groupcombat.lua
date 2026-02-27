rwda = rwda or {}
rwda.integrations = rwda.integrations or {}
rwda.integrations.groupcombat = rwda.integrations.groupcombat or {}

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
