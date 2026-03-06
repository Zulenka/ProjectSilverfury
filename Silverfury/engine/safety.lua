-- Silverfury/engine/safety.lua
-- Arming, deadman timer, danger throttle, abort handling.

Silverfury = Silverfury or {}
Silverfury.engine = Silverfury.engine or {}

local safety = {}
Silverfury.safety = safety

-- ── Flags ────────────────────────────────────────────────────────────────────

local _flags = {
  armed       = false,
  paused      = false,   -- danger-throttle pause (auto-cleared)
  panic       = false,   -- manual panic stop (cleared by sf resume)
}

local _deadman_timer = nil
local _last_tick_ms  = 0

-- ── Read-only access ──────────────────────────────────────────────────────────

function safety.isArmed()    return _flags.armed  end
function safety.isPaused()   return _flags.paused  end
function safety.isPanic()    return _flags.panic   end

function safety.canAct()
  return _flags.armed and not _flags.paused and not _flags.panic
end

-- ── Arming ────────────────────────────────────────────────────────────────────

function safety.arm()
  _flags.armed  = true
  _flags.paused = false
  _flags.panic  = false
  Silverfury.state.flags = Silverfury.state.flags or {}
  Silverfury.state.flags.armed    = true
  Silverfury.state.flags.auto_tick = Silverfury.config.get("combat.auto_tick_on_prompt")
  Silverfury.log.info("Silverfury ARMED.")
  raiseEvent("SF_Armed")
  safety._resetDeadman()
end

function safety.disarm()
  _flags.armed  = false
  _flags.paused = false
  Silverfury.engine.queue.clear()
  Silverfury.state.flags = Silverfury.state.flags or {}
  Silverfury.state.flags.armed = false
  Silverfury.log.info("Silverfury disarmed.")
  raiseEvent("SF_Disarmed")
  safety._cancelDeadman()
end

-- ── Panic / abort ─────────────────────────────────────────────────────────────

function safety.abort(reason)
  _flags.panic  = true
  _flags.paused = false
  Silverfury.engine.queue.clear()
  if Silverfury.scenarios and Silverfury.scenarios.base then
    Silverfury.scenarios.base.abort("safety.abort: " .. (reason or "manual"))
  end
  Silverfury.log.warn("ABORT: %s", reason or "manual")
  raiseEvent("SF_Abort", reason)
  safety._cancelDeadman()
end

function safety.resume()
  if not _flags.armed then
    Silverfury.log.warn("Cannot resume — not armed. Use 'sf on' first.")
    return
  end
  _flags.panic  = false
  _flags.paused = false
  Silverfury.log.info("Silverfury resumed.")
  raiseEvent("SF_Resumed")
  safety._resetDeadman()
end

-- ── Danger throttle ───────────────────────────────────────────────────────────

-- Called each tick to evaluate self state and set/clear pause.
function safety.evaluate()
  if not _flags.armed then return end

  local me  = Silverfury.state.me
  local cfg = Silverfury.config

  local was_paused = _flags.paused
  _flags.paused    = false

  -- HP floor
  local hp_floor = cfg.get("safety.hp_floor_pct") or 0.30
  if me.maxhp > 0 and (me.hp / me.maxhp) < hp_floor then
    _flags.paused = true
    Silverfury.log.trace("Safety: HP below floor (%.0f%%)", (me.hp/me.maxhp)*100)
  end

  -- MP floor
  local mp_floor = cfg.get("safety.mp_floor_pct") or 0.15
  if me.maxmp > 0 and (me.mp / me.maxmp) < mp_floor then
    _flags.paused = true
    Silverfury.log.trace("Safety: MP below floor (%.0f%%)", (me.mp/me.maxmp)*100)
  end

  -- Danger affs
  local danger_affs = cfg.get("safety.danger_affs") or {}
  for _, aff in ipairs(danger_affs) do
    if me.hasAff(aff) then
      _flags.paused = true
      Silverfury.log.trace("Safety: danger aff '%s' present", aff)
      break
    end
  end

  if was_paused ~= _flags.paused then
    if _flags.paused then
      Silverfury.log.warn("Offense PAUSED (danger threshold).")
      raiseEvent("SF_SafetyPause")
    else
      Silverfury.log.info("Offense resumed (danger cleared).")
      raiseEvent("SF_SafetyResume")
    end
  end
end

-- ── Deadman timer ─────────────────────────────────────────────────────────────

function safety._resetDeadman()
  safety._cancelDeadman()
  local ms = Silverfury.config.get("safety.deadman_ms") or 0
  if ms <= 0 then return end
  _last_tick_ms = Silverfury.time.now()
  _deadman_timer = tempTimer(ms / 1000, function()
    local elapsed = Silverfury.time.now() - _last_tick_ms
    if elapsed >= ms then
      Silverfury.log.warn("Deadman timer fired — no tick in %dms. Aborting.", elapsed)
      safety.abort("deadman timer")
    end
  end)
end

function safety._cancelDeadman()
  if _deadman_timer then
    killTimer(_deadman_timer)
    _deadman_timer = nil
  end
end

function safety.heartbeat()
  _last_tick_ms = Silverfury.time.now()
  safety._resetDeadman()
end

-- ── Event hooks ───────────────────────────────────────────────────────────────

safety._handlers = safety._handlers or {}
local _handlers = safety._handlers

function safety.registerHandlers()
  for _, id in ipairs(_handlers) do killHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end

  -- Room change → abort execute if configured
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_RoomChanged", function()
    if Silverfury.config.get("safety.abort_on_room_change") then
      if Silverfury.scenarios and Silverfury.scenarios.base then
        Silverfury.scenarios.base.abort("room changed")
      end
    end
  end)

  -- Target left room → abort execute if configured
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_TargetLeftRoom", function()
    if Silverfury.config.get("safety.abort_on_target_loss") then
      if Silverfury.scenarios and Silverfury.scenarios.base then
        Silverfury.scenarios.base.abort("target left room")
      end
    end
  end)
end

function safety.shutdown()
  for _, id in ipairs(_handlers) do killHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end
  safety._cancelDeadman()
end

function safety.status()
  return {
    armed  = _flags.armed,
    paused = _flags.paused,
    panic  = _flags.panic,
    can_act = safety.canAct(),
  }
end
