rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.retaliation = rwda.engine.retaliation or {
  _event_handler_id = nil,
  _dead_handler_id  = nil,
}

local retaliation = rwda.engine.retaliation

local function now()
  return rwda.util.now()
end

local function trim(input)
  if type(input) ~= "string" then
    return ""
  end
  return input:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize(name)
  return trim(tostring(name or "")):lower():gsub("[^%w%s%-']", ""):gsub("%s+", " ")
end

local function sameName(a, b)
  local an = normalize(a)
  local bn = normalize(b)
  return an ~= "" and bn ~= "" and an == bn
end

local function ownName()
  if gmcp and gmcp.Char and gmcp.Char.Status and type(gmcp.Char.Status.name) == "string" then
    return gmcp.Char.Status.name
  end
  return nil
end

local function roomPlayersTable()
  if not gmcp or not gmcp.Room then
    return nil
  end
  return gmcp.Room.Players or gmcp.Room.players
end

local function inRoomByGMCP(name)
  local players = roomPlayersTable()
  if type(players) ~= "table" then
    return nil
  end

  local target = normalize(name)
  if target == "" then
    return false
  end

  for k, v in pairs(players) do
    local candidate = nil
    if type(v) == "string" then
      candidate = v
    elseif type(v) == "table" then
      candidate = v.name or v.fullname or v.id
    elseif type(k) == "string" and type(v) == "boolean" and v then
      candidate = k
    end

    if candidate and normalize(candidate) == target then
      return true
    end
  end

  return false
end

local function likelyPlayerName(name)
  name = trim(name)
  if name == "" then
    return false
  end

  local lowered = name:lower()
  if lowered == "you" or lowered == "someone" then
    return false
  end
  if lowered == "a" or lowered == "an" or lowered == "the" then
    return false
  end
  if lowered:sub(1, 2) == "a " or lowered:sub(1, 3) == "an " or lowered:sub(1, 4) == "the " then
    return false
  end

  if name:match("^[A-Z][%w'%-]+$") then
    return true
  end

  return false
end

local function ensureRuntimeState()
  rwda.state.runtime = rwda.state.runtime or {}
  rwda.state.runtime.retaliation = rwda.state.runtime.retaliation or {
    enabled           = false,
    locked            = false,
    locked_target     = nil,
    lock_until_ms     = 0,
    previous_target   = nil,
    previous_source   = nil,
    last_switch_ms    = 0,
    last_aggressor    = nil,
    last_aggress_line = nil,
    last_reason       = "idle",
    active_aggressors = {},  -- [normalized_name] = { name, last_hit_ms }
  }
  -- Ensure the field exists on pre-existing runtime tables.
  if rwda.state.runtime.retaliation.active_aggressors == nil then
    rwda.state.runtime.retaliation.active_aggressors = {}
  end
  return rwda.state.runtime.retaliation
end

local function configTable()
  rwda.config.retaliation = rwda.config.retaliation or {}
  local cfg = rwda.config.retaliation
  if cfg.enabled == nil then cfg.enabled = false end
  if cfg.lock_ms == nil then cfg.lock_ms = 8000 end
  if cfg.swap_debounce_ms == nil then cfg.swap_debounce_ms = 1500 end
  if cfg.min_confidence == nil then cfg.min_confidence = 0.65 end
  if cfg.restore_previous_target == nil then cfg.restore_previous_target = true end
  if cfg.ignore_non_players == nil then cfg.ignore_non_players = true end
  -- How long (ms) without a hit before an aggressor is considered inactive.
  if cfg.aggressor_ttl_ms == nil then cfg.aggressor_ttl_ms = 20000 end
  return cfg
end

local function isEnabled()
  local rt = ensureRuntimeState()
  return rt.enabled and configTable().enabled ~= false
end

-- Remove aggressors whose last hit was more than ttl_ms ago.
local function pruneAggressors(rt, ttl_ms)
  local t = now()
  for key, entry in pairs(rt.active_aggressors) do
    if t - (entry.last_hit_ms or 0) > ttl_ms then
      rt.active_aggressors[key] = nil
    end
  end
end

local function countActiveAggressors(rt)
  local n = 0
  for _ in pairs(rt.active_aggressors) do
    n = n + 1
  end
  return n
end

-- Return the name of the aggressor who hit most recently.
local function bestAggressor(rt)
  local best = nil
  local bestMs = 0
  for _, entry in pairs(rt.active_aggressors) do
    if (entry.last_hit_ms or 0) > bestMs then
      bestMs = entry.last_hit_ms
      best = entry.name
    end
  end
  return best
end

function retaliation.setEnabled(enabled)
  local rt = ensureRuntimeState()
  local value = not not enabled
  rt.enabled = value
  configTable().enabled = value
  if not value then
    rt.locked = false
    rt.locked_target = nil
    rt.lock_until_ms = 0
    rt.last_reason = "disabled"
  else
    rt.last_reason = "enabled"
  end
  return value
end

local function canAcceptAggressor(name, confidence)
  if not isEnabled() then
    return false, "disabled"
  end

  if not rwda.state.flags.enabled or rwda.state.flags.stopped then
    return false, "rwda_inactive"
  end

  name = trim(name)
  if name == "" then
    return false, "no_name"
  end

  local mine = ownName()
  if mine and sameName(name, mine) then
    return false, "self"
  end

  local cfg = configTable()
  confidence = tonumber(confidence) or 0.8
  if confidence < (tonumber(cfg.min_confidence) or 0.65) then
    return false, "low_confidence"
  end

  if cfg.ignore_non_players then
    local present = inRoomByGMCP(name)
    -- present == true  → confirmed in room, accept
    -- present == nil   → GMCP not available, fall through to name check
    -- present == false → GMCP available but attacker not found yet (GMCP
    --                    update often arrives after the attack line); treat
    --                    as unknown and fall through to name check
    if present ~= true and not likelyPlayerName(name) then
      return false, "non_player_like"
    end
  end

  return true, "ok"
end

local function applyRetaliationTarget(name, reason)
  local rt = ensureRuntimeState()
  local current = rwda.state.target.name
  local source = rwda.state.target.target_source or "unknown"

  if configTable().restore_previous_target and current and current ~= "" and not sameName(current, name) then
    if not rt.locked then
      rt.previous_target = current
      rt.previous_source = source
    end
  end

  rwda.state.setTarget(name, "retaliation")
  rwda.state.setTargetAvailable(true, "retaliation", "seen")

  rt.locked = true
  rt.locked_target = name
  rt.lock_until_ms = now() + (tonumber(configTable().lock_ms) or 8000)
  rt.last_switch_ms = now()
  rt.last_reason = reason or "retaliation_lock"
end

function retaliation.onAggressor(payload)
  local rt = ensureRuntimeState()
  payload = payload or {}

  local who = trim(payload.who)
  local confidence = tonumber(payload.confidence) or 0.8
  rt.last_aggressor = who ~= "" and who or rt.last_aggressor
  rt.last_aggress_line = payload.line or rt.last_aggress_line

  local ok, reason = canAcceptAggressor(who, confidence)
  if not ok then
    rt.last_reason = reason
    return false, reason
  end

  -- Track this validated aggressor and prune stale ones.
  local cfg = configTable()
  local key = normalize(who)
  if key ~= "" then
    rt.active_aggressors[key] = { name = who, last_hit_ms = now() }
  end

  pruneAggressors(rt, tonumber(cfg.aggressor_ttl_ms) or 20000)
  local aggressorCount = countActiveAggressors(rt)

  -- Multiple people attacking: hold current target, don't switch.
  if aggressorCount >= 2 then
    rt.last_reason = "multi_attacker_hold"
    return false, "multi_attacker_hold"
  end

  -- Single attacker path — apply debounce as before.
  local currentMs = now()
  local debounce = tonumber(cfg.swap_debounce_ms) or 1500

  if rt.locked and rt.locked_target and not sameName(rt.locked_target, who) then
    if currentMs < ((tonumber(rt.last_switch_ms) or 0) + debounce) then
      rt.last_reason = "debounced"
      return false, "debounced"
    end
  end

  applyRetaliationTarget(who, "retaliation_lock")
  rwda.util.log("info", "Retaliation lock -> %s", tostring(who))
  return true, "locked"
end

-- Called when the current target dies.  Remove them from active aggressors,
-- switch to whoever is still attacking, or clear the target entirely.
-- This runs regardless of whether retaliation is enabled so that the target
-- is always cleaned up when the kill is confirmed.
function retaliation.onTargetDead(payload)
  local rt = ensureRuntimeState()

  -- Remove the dead target from the aggressor table.
  local who = payload and trim(payload.who) or ""
  if who ~= "" then
    rt.active_aggressors[normalize(who)] = nil
  end

  -- Clear the current retaliation lock — target is dead.
  rt.locked = false
  rt.locked_target = nil
  rt.lock_until_ms = 0
  rt.previous_target = nil
  rt.previous_source = nil

  local cfg = configTable()
  pruneAggressors(rt, tonumber(cfg.aggressor_ttl_ms) or 20000)

  -- If retaliation is enabled and another attacker is still active, switch to them.
  if isEnabled() then
    local next = bestAggressor(rt)
    if next and next ~= "" then
      applyRetaliationTarget(next, "target_dead_switch")
      -- Don't restore to the dead player when this new lock eventually expires.
      rt.previous_target = nil
      rt.previous_source = nil
      rwda.util.log("info", "Target died; switching to remaining aggressor %s", tostring(next))
      return true, "switched"
    end
  end

  -- No remaining attacker: clear the target so we aren't stuck on a dead player.
  -- The parser will restore the target automatically if a starburst tattoo saves them.
  if rwda.state and rwda.state.clearTarget then
    rwda.state.clearTarget()
    rwda.util.log("info", "Target died with no remaining aggressors; target cleared.")
  end

  rt.last_reason = "target_dead_no_aggressor"
  return false, "no_aggressor"
end

function retaliation.update()
  local rt = ensureRuntimeState()
  if not isEnabled() then
    return false
  end

  if not rt.locked then
    return false
  end

  if now() < (tonumber(rt.lock_until_ms) or 0) then
    return false
  end

  local restore = configTable().restore_previous_target
  local previous = rt.previous_target
  if restore and previous and previous ~= "" then
    local restoreSource = rt.previous_source or "manual"
    rwda.state.setTarget(previous, restoreSource)
    rwda.util.log("info", "Retaliation lock expired; restored target %s", tostring(previous))
  end

  rt.locked = false
  rt.locked_target = nil
  rt.lock_until_ms = 0
  rt.previous_target = nil
  rt.previous_source = nil
  rt.last_reason = "lock_expired"
  return true
end

function retaliation.status()
  local rt = ensureRuntimeState()
  local cfg = configTable()
  pruneAggressors(rt, tonumber(cfg.aggressor_ttl_ms) or 20000)

  local aggressorList = {}
  for _, entry in pairs(rt.active_aggressors) do
    aggressorList[#aggressorList + 1] = entry.name
  end
  table.sort(aggressorList)

  return {
    enabled               = isEnabled(),
    locked                = rt.locked,
    locked_target         = rt.locked_target,
    lock_until_ms         = rt.lock_until_ms,
    previous_target       = rt.previous_target,
    last_aggressor        = rt.last_aggressor,
    last_reason           = rt.last_reason,
    active_aggressor_count = countActiveAggressors(rt),
    active_aggressors     = aggressorList,
  }
end

function retaliation.bootstrap()
  local rt = ensureRuntimeState()
  local cfg = configTable()
  if rt.enabled ~= true and cfg.enabled == true then
    rt.enabled = true
  elseif rt.enabled == false and cfg.enabled == false then
    rt.enabled = false
  elseif rt.enabled == nil then
    rt.enabled = cfg.enabled ~= false
  end

  if retaliation._event_handler_id and rwda.engine and rwda.engine.events then
    return true
  end

  if rwda.engine and rwda.engine.events and rwda.engine.events.on then
    retaliation._event_handler_id = rwda.engine.events.on("AGGRESSOR_HIT", retaliation.onAggressor)
    retaliation._dead_handler_id  = rwda.engine.events.on("TARGET_DEAD",   retaliation.onTargetDead)
  end

  return true
end

function retaliation.shutdown()
  if retaliation._event_handler_id and rwda.engine and rwda.engine.events and rwda.engine.events.off then
    rwda.engine.events.off("AGGRESSOR_HIT", retaliation._event_handler_id)
  end
  retaliation._event_handler_id = nil

  if retaliation._dead_handler_id and rwda.engine and rwda.engine.events and rwda.engine.events.off then
    rwda.engine.events.off("TARGET_DEAD", retaliation._dead_handler_id)
  end
  retaliation._dead_handler_id = nil

  return true
end
