-- Silverfury/scenarios/venomlock.lua
-- Venom-lock pressure scenario.
-- SETUP: apply 5 lock afflictions (asthma, slickness, anorexia, paralysis, impatience/kena)
-- MAINTAIN: keep pressure up while watching for lock opportunity
-- EXECUTE: impale → disembowel

Silverfury = Silverfury or {}
Silverfury.scenarios = Silverfury.scenarios or {}

local scenario = {}
Silverfury.scenarios.venomlock = scenario

local LOCK_AFFS = { "asthma", "slickness", "anorexia", "paralysis" }

local function tgt() return Silverfury.state.target end

-- Count how many lock affs target currently has.
local function lockCount()
  local n = 0
  for _, aff in ipairs(LOCK_AFFS) do
    if tgt().hasAff(aff) then n = n + 1 end
  end
  return n
end

-- SETUP done when we have 4/4 primary lock affs stacked.
function scenario.setupDone()
  return lockCount() >= 4
end

-- Build a lockstep attack.
local function lockAction(reason)
  local v1, v2 = Silverfury.offense.venoms.pick()
  local cmd = Silverfury.engine.planner._fill(
    Silverfury.config.get("attack.templates.dsl") or "dsl {target} {limb} {venom1} {venom2}",
    { v1=v1, v2=v2, limb=Silverfury.engine.planner._nextPrepLimb() }
  )
  return { type="attack", cmd=cmd, reason=reason or "venomlock setup" }
end

function scenario.setupAction()
  return lockAction("venomlock: building lock affs (" .. lockCount() .. "/4)")
end

function scenario.maintainAction()
  return lockAction("venomlock: maintaining pressure")
end

function scenario.canExecute()
  -- All 4 lock affs + target legs broken + prone.
  local t = tgt()
  return lockCount() >= 4
    and t.limbs.left_leg.broken
    and t.limbs.right_leg.broken
    and t.prone
end

function scenario.shouldAbort()
  return not tgt().isAvailable()
end

function scenario.executeAction()
  -- Bisect path: Hugalaz core at low HP — skip impale entirely.
  if Silverfury.runelore.core.canBisect() then
    local cmd = Silverfury.engine.planner._fill(
      Silverfury.config.get("attack.templates.bisect") or "bisect {target}", {}
    )
    return { type="attack", cmd=cmd, reason="venomlock: bisect (hugalaz)" }
  end

  -- Standard path: impale → disembowel.
  local t = tgt()
  if not t.impaled then
    local cmd = Silverfury.engine.planner._fill(
      Silverfury.config.get("attack.templates.impale") or "impale {target}", {}
    )
    return { type="attack", cmd=cmd, reason="venomlock: impale" }
  end
  local cmd = Silverfury.engine.planner._fill(
    Silverfury.config.get("attack.templates.disembowel") or "disembowel {target}", {}
  )
  return { type="attack", cmd=cmd, reason="venomlock: disembowel" }
end

function scenario.isComplete()
  return tgt().dead
end

function scenario.onStart()
  Silverfury.log.info("Venom-lock scenario started on %s", tgt().name or "?")
end

function scenario.onStop()
  Silverfury.log.info("Venom-lock scenario ended.")
end

function scenario.onAbort()
  Silverfury.log.warn("Venom-lock scenario aborted.")
end

-- ── Registration helper ───────────────────────────────────────────────────────

function scenario.start()
  return Silverfury.scenarios.base.start("venomlock", scenario)
end
