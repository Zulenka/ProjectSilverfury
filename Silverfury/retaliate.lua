-- Silverfury/retaliate.lua
-- Auto-retaliation: detect incoming attacks, switch target to aggressor.

Silverfury = Silverfury or {}

local retal = {}
Silverfury.retaliate = retal

-- ── State ─────────────────────────────────────────────────────────────────────

local _state = {
  enabled          = false,
  prev_target      = nil,
  lock_expires_ms  = 0,
  debounce_ms      = 0,
  aggressors       = {},   -- name → last_hit_ms
}

-- ── Config shortcuts ──────────────────────────────────────────────────────────

local function cfg(key) return Silverfury.config.get("retaliation." .. key) end

-- ── Enable / disable ──────────────────────────────────────────────────────────

function retal.enable()
  _state.enabled = true
  Silverfury.config.set("retaliation.enabled", true)
  Silverfury.log.info("Auto-retaliate ON.")
end

function retal.disable()
  _state.enabled = false
  Silverfury.config.set("retaliation.enabled", false)
  _state.aggressors = {}
  Silverfury.log.info("Auto-retaliate OFF.")
end

function retal.isEnabled()
  return _state.enabled
end

-- ── Aggressor handling ────────────────────────────────────────────────────────

local function inRoom(name)
  return Silverfury.state.room.players[name:lower()] == true
end

function retal.onAggressor(attacker_name)
  if not _state.enabled then return end
  if not attacker_name then return end

  -- Ignore non-players if configured.
  if cfg("ignore_non_players") then
    -- Heuristic: player names are capitalised. Denizen names often contain spaces/lowercase.
    -- This is an approximation — parser should pass a is_player flag when available.
    if attacker_name:match("[a-z]") and not attacker_name:match("^%u") then return end
  end

  -- Must be in the room.
  if not inRoom(attacker_name) then return end

  local now = Silverfury.time.now()
  _state.aggressors[attacker_name] = now

  -- Debounce check.
  local debounce = cfg("swap_debounce_ms") or 1500
  if (now - _state.debounce_ms) < debounce then return end
  _state.debounce_ms = now

  local current = Silverfury.state.target.name

  -- If no current target, set immediately.
  if not current then
    _state.prev_target = nil
    Silverfury.state.target.setName(attacker_name)
    Silverfury.safety.arm()
    Silverfury.log.info("Retaliate: target set to %s", attacker_name)
    _state.lock_expires_ms = now + (cfg("lock_ms") or 8000)
    return
  end

  -- Already targeting them.
  if current:lower() == attacker_name:lower() then
    _state.lock_expires_ms = now + (cfg("lock_ms") or 8000)
    return
  end

  -- Different attacker — switch only if current target not present or lock expired.
  if now > _state.lock_expires_ms or not inRoom(current) then
    _state.prev_target = current
    Silverfury.state.target.setName(attacker_name)
    Silverfury.log.info("Retaliate: switched target to %s (prev: %s)", attacker_name, current)
    _state.lock_expires_ms = now + (cfg("lock_ms") or 8000)
  end
end

-- Called each tick to expire locks and restore previous target.
function retal.update()
  if not _state.enabled then return end
  local now = Silverfury.time.now()

  -- Expire aggressors.
  local lock_ms = cfg("lock_ms") or 8000
  for name, ts in pairs(_state.aggressors) do
    if (now - ts) > lock_ms then
      _state.aggressors[name] = nil
    end
  end

  -- If lock expired and we had a prev target, restore it.
  if now > _state.lock_expires_ms and _state.prev_target then
    if cfg("restore_prev") then
      Silverfury.log.info("Retaliate: restoring previous target %s", _state.prev_target)
      Silverfury.state.target.setName(_state.prev_target)
    end
    _state.prev_target = nil
  end
end

-- ── Event hooks ───────────────────────────────────────────────────────────────

local _handlers = {}

function retal.registerHandlers()
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}

  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_AggressorHit", function(_, name)
    retal.onAggressor(name)
  end)

  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_TargetDead", function()
    -- Remove dead target from aggressors.
    local tname = Silverfury.state.target.name
    if tname then _state.aggressors[tname] = nil end
    -- Find next aggressor if any.
    for name in pairs(_state.aggressors) do
      if inRoom(name) then
        Silverfury.state.target.setName(name)
        return
      end
    end
    if cfg("restore_prev") and _state.prev_target then
      Silverfury.state.target.setName(_state.prev_target)
      _state.prev_target = nil
    end
  end)
end

function retal.shutdown()
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}
  _state.aggressors = {}
end

-- ── Status ────────────────────────────────────────────────────────────────────

function retal.status()
  local aggressors = {}
  for name in pairs(_state.aggressors) do aggressors[#aggressors+1] = name end
  return {
    enabled          = _state.enabled,
    aggressors       = aggressors,
    prev_target      = _state.prev_target,
    lock_expires_in  = math.max(0, _state.lock_expires_ms - Silverfury.time.now()),
  }
end
