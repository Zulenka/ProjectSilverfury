-- ============================================================
-- RWDA :: engine/fury.lua
-- Keep FURY active for every second of every fight.
--
-- Achaea Fury mechanics:
--   FURY ON / FURY OFF / RELAX FURY
--   +2 STR while active
--   Max 1/4 Achaean day uptime (~4.5 real minutes per 20-min day)
--   First activation per Achaean day: free
--   Re-activations same day:         500 willpower each
--   Higher endurance drain while active
-- ============================================================

rwda         = rwda         or {}
rwda.engine  = rwda.engine  or {}
rwda.engine.fury = rwda.engine.fury or {}

local fury = rwda.engine.fury

-- Internal state (NOT part of rwda.state.me — module-private counters).
local state = {
  active             = false,
  activated_this_day = false,
  reactivations      = 0,
  last_activated_ms  = 0,
}

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function cfg()
  return (rwda.config and rwda.config.fury) or {}
end

local function log(fmt, ...)
  if rwda.util and rwda.util.log then
    rwda.util.log("info", "[Fury] " .. fmt, ...)
  end
end

local function warn(fmt, ...)
  if rwda.util and rwda.util.log then
    rwda.util.log("warn", "[Fury] " .. fmt, ...)
  end
end

local function sendGame(cmd)
  if type(send) == "function" then send(cmd) end
end

local function tell(msg)
  if rwda.util and rwda.util.log then
    rwda.util.log("info", "%s", msg)
  elseif type(decho) == "function" then
    decho("<186,242,239>[RWDA] " .. tostring(msg) .. "<r>\n")
  end
end

-- ─────────────────────────────────────────────
-- Public API – engagement & lifecycle
-- ─────────────────────────────────────────────

--- Called from `rwda engage` / `att` to activate fury at fight start.
--- Guards: already active, auto_activate off, rwda not running.
function fury.onEngage()
  local c = cfg()
  if c.auto_activate == false then return end
  if not (rwda.state and rwda.state.flags and rwda.state.flags.enabled) then return end
  if state.active then return end

  tempTimer(0.1, function() sendGame("fury on") end)
  log("FURY ON sent on engage.")
end

--- Called when the game confirms fury was activated.
function fury.onFuryActivated()
  state.active = true
  if rwda.state and rwda.state.me then
    rwda.state.me.fury_active = true
  end

  if state.activated_this_day then
    state.reactivations = state.reactivations + 1
    log("Fury re-activated (cost: 500 willpower — reactivations today: %d).", state.reactivations)
  else
    state.activated_this_day = true
    log("Fury activated (free slot used).")
  end
  state.last_activated_ms = (type(getEpochMs) == "function") and getEpochMs() or 0
  raiseEvent("FURY_ACTIVATED", { reactivations = state.reactivations })
end

--- Called when the game reports fury has faded or was relaxed.
function fury.onFuryLost()
  state.active = false
  if rwda.state and rwda.state.me then
    rwda.state.me.fury_active = false
  end

  local engaged = rwda.state and rwda.state.flags and rwda.state.flags.enabled
                  and not rwda.state.flags.stopped
  if not engaged then
    log("Fury lost — combat not active, not re-activating.")
    return
  end

  local c = cfg()
  if c.auto_reactivate == false then
    log("Fury lost. auto_reactivate is off.")
    return
  end

  local wp    = (rwda.state and rwda.state.me and rwda.state.me.willpower) or 0
  local minWP = c.min_wp_reactivate or 1500

  if state.activated_this_day and wp < minWP then
    warn("Fury lost — willpower %d < threshold %d. Not re-activating.", wp, minWP)
    return
  end

  sendGame("fury on")
  log("Fury lost mid-fight — re-activating (willpower=%d).", wp)
end

--- Called when server echoes "you are already in a fury".
function fury.onAlreadyActive()
  state.active = true
  if rwda.state and rwda.state.me then
    rwda.state.me.fury_active = true
  end
end

--- Called when server says there is not enough willpower for fury on.
function fury.onWillpowerTooLow()
  warn("FURY ON failed — not enough willpower (willpower=%d).",
    (rwda.state and rwda.state.me and rwda.state.me.willpower) or 0)
end

--- Called each Achaean new-day to reset the free-activation slot.
function fury.onNewDay()
  state.activated_this_day = false
  state.reactivations      = 0
  log("New Achaean day — fury free slot reset.")
end

-- ─────────────────────────────────────────────
-- Endurance safety check
-- Called from the prompt event so it runs every heartbeat.
-- ─────────────────────────────────────────────

function fury.checkEndurance()
  local me = rwda.state and rwda.state.me
  if not me or not me.fury_active then return end

  local maxEnd = me.maxendurance or 0
  if maxEnd == 0 then return end

  local pct = (me.endurance or 0) / maxEnd
  local c   = cfg()

  if pct < (c.endurance_floor_pct or 0.10) then
    sendGame("fury off")
    warn("FURY OFF: endurance critical (%.0f%%).", pct * 100)
  elseif pct < (c.endurance_warn_pct or 0.25) then
    warn("Endurance low (%.0f%%) — fury drain is significant.", pct * 100)
  end
end

-- ─────────────────────────────────────────────
-- Line dispatcher (called from parser.lua)
-- ─────────────────────────────────────────────

function fury.onLine(line)
  local lower = line:lower()

  if lower:find("surge of fury",           1, true)
  or lower:find("you activate your fury",  1, true)
  or lower:find("you enter a fury",        1, true) then
    fury.onFuryActivated()
    return
  end

  if lower:find("your fury fades",          1, true)
  or lower:find("your fury dissipates",     1, true)
  or lower:find("you relax out of your fury", 1, true) then
    fury.onFuryLost()
    return
  end

  if lower:find("you are already in a fury", 1, true) then
    fury.onAlreadyActive()
    return
  end

  if lower:find("you do not have enough willpower", 1, true) then
    fury.onWillpowerTooLow()
    return
  end
end

-- ─────────────────────────────────────────────
-- Status / control commands
-- ─────────────────────────────────────────────

function fury.status()
  local me     = rwda.state and rwda.state.me
  local wp     = me and me.willpower    or 0
  local en     = me and me.endurance    or 0
  local maxen  = me and me.maxendurance or 1
  tell(string.format(
    "[Fury] active=%s  activated_today=%s  reactivations=%d  willpower=%d  endurance=%.0f%%",
    tostring(state.active),
    tostring(state.activated_this_day),
    state.reactivations,
    wp,
    (en / maxen) * 100
  ))
end

function fury.cancel()
  sendGame("fury off")
  state.active = false
  if rwda.state and rwda.state.me then
    rwda.state.me.fury_active = false
  end
  log("Fury manually deactivated via `rwda fury off`.")
end

-- ─────────────────────────────────────────────
-- Bootstrap
-- ─────────────────────────────────────────────

function fury.bootstrap()
  local c = cfg()
  log("Bootstrap complete (auto_activate=%s  auto_reactivate=%s  min_wp=%d).",
    tostring(c.auto_activate  ~= false),
    tostring(c.auto_reactivate ~= false),
    c.min_wp_reactivate or 1500)
end
