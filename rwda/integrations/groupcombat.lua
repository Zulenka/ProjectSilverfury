rwda = rwda or {}
rwda.integrations = rwda.integrations or {}
rwda.integrations.groupcombat = rwda.integrations.groupcombat or {
  _handler_ids = {},
  _last_external_target = nil,
}

local adapter = rwda.integrations.groupcombat

local function trim(input)
  if type(input) ~= "string" then
    return ""
  end
  return input:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeName(name)
  if type(name) ~= "string" then
    return ""
  end
  return name:lower():gsub("[^%w%s%-']", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function sameName(a, b)
  local an = normalizeName(a)
  local bn = normalizeName(b)
  if an == "" or bn == "" then
    return false
  end
  return an == bn
end

local function ownName()
  if gmcp and gmcp.Char and gmcp.Char.Status and type(gmcp.Char.Status.name) == "string" then
    return gmcp.Char.Status.name
  end
  return nil
end

local function sanitizeTarget(name)
  name = trim(name)
  if name == "" then
    return nil
  end

  local lower = name:lower()
  if lower == "none" or lower == "(none)" or lower == "nil" or lower == "unknown" or lower == "self" or lower == "me" then
    return nil
  end

  -- IRE target GMCP may sometimes expose a numeric ID rather than a player name.
  if name:match("^%-?%d+$") then
    return nil
  end

  local mine = ownName()
  if mine and sameName(name, mine) then
    return nil
  end

  return name
end

function adapter.detect()
  local present = type(rawget(_G, "groupcombat")) == "table"
    or type(rawget(_G, "gcom")) == "table"
    or type(rawget(_G, "ga")) == "table"
    or type(rawget(_G, "target")) == "string"
    or (gmcp and gmcp.IRE and gmcp.IRE.Target ~= nil)

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

  local ga = rawget(_G, "ga")
  if type(ga) == "table" and type(ga.target) == "string" then
    return ga.target
  end

  local followLegacyTarget = true
  if rwda.config and rwda.config.integration and rwda.config.integration.follow_legacy_target == false then
    followLegacyTarget = false
  end

  if followLegacyTarget then
    local legacyTarget = rawget(_G, "target")
    if type(legacyTarget) == "string" then
      return legacyTarget
    end
  end

  if gmcp and gmcp.IRE and gmcp.IRE.Target and type(gmcp.IRE.Target.Set) == "string" then
    return gmcp.IRE.Target.Set
  end

  return nil
end

function adapter.sync()
  if not adapter.detect() then
    return false
  end

  local candidate = sanitizeTarget(adapter.pullTarget())
  if not candidate then
    return false
  end

  local current = rwda.state and rwda.state.target and rwda.state.target.name or nil
  local currentSource = rwda.state and rwda.state.target and rwda.state.target.target_source or "unknown"
  local lastExternal = adapter._last_external_target

  local shouldApply = false
  if not current or trim(current) == "" then
    shouldApply = true
  elseif sameName(current, candidate) then
    shouldApply = true
  elseif lastExternal and sameName(current, lastExternal) then
    -- Current target is still externally managed; allow live follow to new external target.
    shouldApply = true
  elseif currentSource == "external" then
    shouldApply = true
  end

  if shouldApply then
    rwda.state.setTarget(candidate, "external")
    adapter._last_external_target = candidate
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

  local eventSet = {}
  local events = (rwda.config and rwda.config.integration and rwda.config.integration.group_target_events) or {}
  for _, eventName in ipairs(events) do
    if type(eventName) == "string" and eventName ~= "" then
      eventSet[eventName] = true
    end
  end

  -- Legacy emits target updates through these data streams; include them even if not in config.
  eventSet["LPrompt"] = true
  eventSet["gmcp.IRE.Target.Set"] = true
  eventSet["gmcp.IRE.Target.Info"] = true

  local idx = 1
  for eventName, _ in pairs(eventSet) do
    local ok, id = pcall(registerAnonymousEventHandler, eventName, "rwda.integrations.groupcombat.onTargetEvent")
    if ok and id then
      adapter._handler_ids[idx] = id
      idx = idx + 1
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
  adapter._last_external_target = nil
  return true
end
