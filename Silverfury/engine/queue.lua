-- Silverfury/engine/queue.lua
-- Safe, throttled command queue. Single point of dispatch for all sends.
-- One action per eligible tick. Anti-spam enforced via timestamp gate.

Silverfury = Silverfury or {}
Silverfury.engine = Silverfury.engine or {}

local Q = {}
Silverfury.engine.queue = Q

local _last_sent_ms  = 0
local _pending       = nil   -- action waiting for balance

-- ── Internal send ─────────────────────────────────────────────────────────────

-- resource: "bal" | "eq" | "eqbal" | "freestand" | "free" | "class" | "direct"
-- "direct" bypasses the server queue (used for zero-balance-cost commands like summon).
local function rawSend(cmd, resource)
  if Silverfury.config.get("combat.use_server_queue") then
    if resource == "direct" then
      send(cmd)
    else
      local slot = resource or "bal"
      sendAll("queue addclear " .. slot .. " " .. cmd)
    end
  else
    send(cmd)
  end
  _last_sent_ms = Silverfury.time.now()
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Send a command immediately if not throttled. Returns true if sent.
-- resource: "bal"|"eq"|"eqbal"|"freestand"|"free"|"class"|"direct" (default "bal")
function Q.send(cmd, resource)
  local anti_spam = Silverfury.config.get("combat.anti_spam_ms") or 275
  local elapsed   = Silverfury.time.now() - _last_sent_ms
  if elapsed < anti_spam then
    Silverfury.log.trace("queue.send throttled (%dms < %dms): %s", elapsed, anti_spam, cmd)
    return false
  end
  rawSend(cmd, resource)
  Silverfury.log.trace("queue.send [%s] → %s", resource or "bal", cmd)
  raiseEvent("SF_CommandSent", cmd)
  return true
end

-- Send multiple commands in sequence (one per send call, not batched).
function Q.sendAll(cmds, resource)
  for _, cmd in ipairs(cmds) do
    rawSend(cmd, resource)
  end
  raiseEvent("SF_CommandSent", table.concat(cmds, "; "))
end

-- Queue an action to retry when balance returns.
function Q.pend(action)
  _pending = action
end

-- Called when vitals event detects bal/eq restored.
function Q.onBalanceRestored()
  if _pending then
    local a = _pending
    _pending = nil
    Silverfury.log.trace("queue: flushing pending action")
    if Silverfury.engine.planner then
      Silverfury.engine.planner.execute(a)
    end
  end
end

-- Clear any pending action (e.g., on stop/abort).
function Q.clear()
  _pending = nil
end

-- Server-queue clear commands.
function Q.clearServerQueue(which)
  which = which or "bal"
  send("queue clear " .. which)
end

function Q.reset()
  _pending      = nil
  _last_sent_ms = 0
end
