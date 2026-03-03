rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.falcon = rwda.engine.falcon or {}

local falcon = rwda.engine.falcon

-- Action names that are NOT attacks and should NOT trigger observe.
local NON_ATTACK_NAMES = {
  assess   = true,
  predict  = true,
  recall   = true,
  wield    = true,
  ["none"] = true,
}

-- Per-fight tracking state (reset on bootstrap / rwda stop).
local last_track_target  = nil
local last_slay_target   = nil
local last_follow_target = nil
local _event_handler_id  = nil

-- ─────────────────────────────────────────────
-- Internal helpers
-- ─────────────────────────────────────────────

local function cfg()
  return (rwda.config and rwda.config.falcon) or {}
end

local function sendGame(cmd)
  if type(send) == "function" then
    send(cmd)
  end
end

local function currentTargetName()
  return rwda.state and rwda.state.target and rwda.state.target.name
end

local function isAttackAction(actionName)
  if not actionName then return false end
  return not NON_ATTACK_NAMES[actionName]
end

-- ─────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────

--- Called once from `rwda engage` / `att`.
--- Sends FALCON SLAY, FALCON TRACK (if auto_track on), plus player FOLLOW (if auto_follow on).
--- Guards against re-tracking / re-following the same target on repeated engage calls.
function falcon.onEngage(targetName)
  if not targetName or targetName == "" then return end
  local c = cfg()

  -- FALCON SLAY — sent unconditionally on each new engage.
  sendGame("falcon slay " .. targetName)
  last_slay_target = targetName

  -- FALCON TRACK — sent once per engage. Mid-fight re-tracking on target change is
  -- handled by onActionSent() so the falcon never repeatedly follows the same name.
  if c.auto_track ~= false then
    sendGame("falcon track " .. targetName)
    last_track_target = targetName
  end

  -- Player FOLLOW — follow the target automatically (requires explicit opt-in).
  if c.auto_follow then
    sendGame("follow " .. targetName)
    last_follow_target = targetName
  end
end

--- Registered as an ACTION_SENT listener by bootstrap().
--- Handles two jobs per attack tick:
---   1. Re-issue FALCON TRACK / player FOLLOW only when target has changed mid-fight.
---   2. Send `observe <target>` alongside each offensive action (not assess/predict/etc.).
function falcon.onActionSent(payload)
  local c = cfg()
  local tname = currentTargetName()
  if not tname or tname == "" then return end

  local actionName = payload and payload.action and payload.action.name

  -- Re-track falcon only when target changed (e.g. retaliation swap).
  if c.auto_track ~= false and tname ~= last_track_target then
    sendGame("falcon track " .. tname)
    last_track_target = tname
  end

  -- Re-follow player only when target changed.
  if c.auto_follow and tname ~= last_follow_target then
    sendGame("follow " .. tname)
    last_follow_target = tname
  end

  -- Observe on each offensive attack to get health reports (per FALCON TRACK ability).
  if c.observe_on_attack ~= false and isAttackAction(actionName) then
    if type(tempTimer) == "function" then
      -- Small delay so queue commands reach the server first.
      tempTimer(0.05, function()
        local t = currentTargetName()
        if t and t ~= "" and type(send) == "function" then
          send("observe " .. t)
        end
      end)
    else
      sendGame("observe " .. tname)
    end
  end
end

-- ─────────────────────────────────────────────
-- Toggle helpers (called from commands)
-- ─────────────────────────────────────────────

--- Enable or disable FALCON TRACK on engage / target change.
function falcon.setAutoTrack(enabled)
  rwda.config.falcon = rwda.config.falcon or {}
  rwda.config.falcon.auto_track = enabled
  -- Clear last-track so the next tick re-sends when re-enabled.
  if not enabled then last_track_target = nil end
  rwda.util.log("info", "Falcon auto-track: %s", enabled and "ON" or "OFF")
end

--- Enable or disable automatic player `follow <target>`.
function falcon.setAutoFollow(enabled)
  rwda.config.falcon = rwda.config.falcon or {}
  rwda.config.falcon.auto_follow = enabled
  if not enabled then last_follow_target = nil end
  rwda.util.log("info", "Falcon auto-follow (player): %s", enabled and "ON" or "OFF")
end

--- Enable or disable `observe <target>` sent alongside each attack tick.
function falcon.setObserveOnAttack(enabled)
  rwda.config.falcon = rwda.config.falcon or {}
  rwda.config.falcon.observe_on_attack = enabled
  rwda.util.log("info", "Falcon observe-on-attack: %s", enabled and "ON" or "OFF")
end

--- Print current falcon state to the RWDA log.
function falcon.status()
  local c = cfg()
  rwda.util.log("info",
    "Falcon: auto_track=%s  observe_on_attack=%s  auto_follow=%s | last_track=%s  last_slay=%s  last_follow=%s",
    tostring(c.auto_track ~= false),
    tostring(c.observe_on_attack ~= false),
    tostring(c.auto_follow == true),
    tostring(last_track_target  or "none"),
    tostring(last_slay_target   or "none"),
    tostring(last_follow_target or "none")
  )
end

--- Reset per-fight tracking state (call on rwda stop / new fight).
function falcon.reset()
  last_track_target  = nil
  last_slay_target   = nil
  last_follow_target = nil
end

--- Bootstrap: register the ACTION_SENT event listener.
function falcon.bootstrap()
  if rwda.engine and rwda.engine.events then
    if _event_handler_id then
      rwda.engine.events.off("ACTION_SENT", _event_handler_id)
    end
    _event_handler_id = rwda.engine.events.on("ACTION_SENT", function(payload)
      falcon.onActionSent(payload)
    end)
  end

  local c = cfg()
  rwda.util.log("info",
    "Falcon bootstrap complete (auto_track=%s  observe=%s  auto_follow=%s)",
    tostring(c.auto_track ~= false),
    tostring(c.observe_on_attack ~= false),
    tostring(c.auto_follow == true)
  )
end
