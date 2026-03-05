-- Silverfury/scenarios/runelore_kill.lua
-- Runelore Pith+Kena kill scenario — Pithakhan mana drain + Kena impatience lock.
--
-- Phase flow (all managed internally under the MAINTAIN state):
--   PHASE_BUILD_KELP  → apply kelp-cured venoms until target has N kelp affs
--   PHASE_PREP_LIMBS  → prep left_leg, head, right_leg to near-break threshold
--   PHASE_BREAK_LEG1  → break left_leg to get target prone
--   PHASE_BREAK_HEAD  → break head (makes Pithakhan fire reliably, drains more)
--   PHASE_BREAK_LEG2  → break right_leg (maintain prone / setup complete)
--   PHASE_EXECUTE     → finisher: bisect (hugalaz) or impale → disembowel
--
-- Key mechanics encoded here:
--   • Pithakhan fires on damaged head; gains 13% drain on broken head.
--   • Kena fires at <=40% mana (Dec 2025, configurable via runelore.kena_mana_threshold).
--   • Kelp stack = pre-load kelp-cured affs to clog herb channel before executing.
--   • Limb targeting is hard-selected per phase (not delegated to _nextPrepLimb).

Silverfury = Silverfury or {}
Silverfury.scenarios = Silverfury.scenarios or {}

local scenario = {}
Silverfury.scenarios.runelore_kill = scenario

-- ── Phases ────────────────────────────────────────────────────────────────────

local PHASE = {
  BUILD_KELP  = "BUILD_KELP",
  PREP_LIMBS  = "PREP_LIMBS",
  BREAK_LEG1  = "BREAK_LEG1",
  BREAK_HEAD  = "BREAK_HEAD",
  BREAK_LEG2  = "BREAK_LEG2",
  EXECUTE     = "EXECUTE",
}

local _phase            = PHASE.BUILD_KELP
local _kelp_phase_start = 0   -- epoch_ms when BUILD_KELP began

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function tgt() return Silverfury.state.target end
local function cfg()  return Silverfury.config end
local function hasAff(name) return tgt().hasAff(name) end

-- How many kelp-cured affs does the target have?
local function kelpCount()
  if Silverfury.offense and Silverfury.offense.venoms then
    return Silverfury.offense.venoms.countKelpAffs()
  end
  return 0
end

-- Build an attack action using the given template and limb.
local function attack(template_name, limb, mode, reason)
  local tpl = cfg().get("attack.templates." .. template_name)
            or "dsl {target} {limb} {venom1} {venom2}"
  local v1, v2 = Silverfury.offense.venoms.pick(mode)
  local cmd = Silverfury.engine.planner._fill(tpl, { v1=v1, v2=v2, limb=limb })
  return { type="attack", cmd=cmd, reason=reason }
end

-- ── Phase advancement ─────────────────────────────────────────────────────────

local function advancePhase()
  local t          = tgt()
  local near_break = cfg().get("attack.near_break_pct") or 75

  if _phase == PHASE.BUILD_KELP then
    local target_n   = cfg().get("venoms.kelp_stack_target_count") or 3
    local timeout_ms = cfg().get("runelore.kelp_phase_timeout_ms") or 30000
    local count      = kelpCount()
    local timed_out  = _kelp_phase_start > 0
                       and (Silverfury.time.now() - _kelp_phase_start) > timeout_ms
    if count >= target_n or timed_out then
      _phase = PHASE.PREP_LIMBS
      Silverfury.log.info("Runelore: BUILD_KELP done (count=%d, timeout=%s) → PREP_LIMBS",
        count, tostring(timed_out))
    end

  elseif _phase == PHASE.PREP_LIMBS then
    local ll = t.limbs.left_leg
    local hd = t.limbs.head
    local rl = t.limbs.right_leg
    if ll.damage_pct >= near_break
    and hd.damage_pct >= near_break
    and rl.damage_pct >= near_break then
      _phase = PHASE.BREAK_LEG1
      Silverfury.log.info("Runelore: PREP_LIMBS done → BREAK_LEG1")
    end

  elseif _phase == PHASE.BREAK_LEG1 then
    if t.limbs.left_leg.broken or t.prone then
      _phase = PHASE.BREAK_HEAD
      Silverfury.log.info("Runelore: BREAK_LEG1 done → BREAK_HEAD")
    end

  elseif _phase == PHASE.BREAK_HEAD then
    if t.limbs.head.broken then
      _phase = PHASE.BREAK_LEG2
      Silverfury.log.info("Runelore: BREAK_HEAD done → BREAK_LEG2")
    end

  elseif _phase == PHASE.BREAK_LEG2 then
    if t.limbs.right_leg.broken then
      _phase = PHASE.EXECUTE
      Silverfury.log.info("Runelore: BREAK_LEG2 done → EXECUTE")
    end
  end
end

-- ── Phase actions ─────────────────────────────────────────────────────────────

local function buildKelpAction()
  -- Apply kelp-cured venoms to clog the target's herb channel.
  -- Pick undercut (or dsl if not configured) targeting left_leg to start prep.
  local tpl = cfg().get("attack.templates.undercut") and "undercut" or "dsl"
  return attack(tpl, "left_leg", "kelp_stack", "kelp-stack: building kelp affs")
end

local function prepLimbsAction()
  -- Hit limbs in order: left_leg first, then head, then right_leg.
  -- Use damage percentages to decide which is most urgent (furthest from near_break).
  local t = tgt()
  local near = cfg().get("attack.near_break_pct") or 75
  local order = { "left_leg", "head", "right_leg" }
  local limb = order[1]
  local min_pct = t.limbs[order[1]].damage_pct
  for _, lname in ipairs(order) do
    local pct = t.limbs[lname].damage_pct
    if pct < min_pct then
      min_pct = pct
      limb = lname
    end
  end
  return attack("dsl", limb, "lock", "prep: targeting " .. limb
    .. string.format(" (%d%%)", min_pct))
end

local function breakLeg1Action()
  -- Finish off left_leg; use undercut for the break if available.
  local tpl = cfg().get("attack.templates.undercut") and "undercut" or "dsl"
  return attack(tpl, "left_leg", "lock", "BREAK_LEG1: finishing left leg break")
end

local function breakHeadAction()
  -- Switch targeting to head to break it.
  -- A broken head → Pithakhan fires more reliably and drains 13% mana.
  return attack("dsl", "head", "lock", "BREAK_HEAD: breaking head for Pithakhan proc")
end

local function breakLeg2Action()
  -- Break the second leg to keep target prone and complete the setup.
  local tpl = cfg().get("attack.templates.undercut") and "undercut" or "dsl"
  return attack(tpl, "right_leg", "lock", "BREAK_LEG2: finishing right leg break")
end

local function executeFinisher()
  -- Bisect (hugalaz builds) takes priority.
  if Silverfury.runelore.core.canBisect() then
    local cmd = Silverfury.engine.planner._fill(
      cfg().get("attack.templates.bisect") or "bisect {target}", {}
    )
    return { type="attack", cmd=cmd, reason="execute: bisect (hugalaz)" }
  end

  -- Standard: require prone, then impale, then disembowel.
  local t = tgt()
  if not t.prone then
    return attack("dsl", "left_leg", "lock", "execute: forcing prone via leg")
  end
  if not t.impaled then
    local cmd = Silverfury.engine.planner._fill(
      cfg().get("attack.templates.impale") or "impale {target}", {}
    )
    return { type="attack", cmd=cmd, reason="execute: impale" }
  end
  local cmd = Silverfury.engine.planner._fill(
    cfg().get("attack.templates.disembowel") or "disembowel {target}", {}
  )
  return { type="attack", cmd=cmd, reason="execute: disembowel" }
end

-- ── Empower injection ─────────────────────────────────────────────────────────
-- Check before every action: if a rune is ready to empower, do that first.
local function checkEmpower()
  if Silverfury.runelore.core.shouldEmpower() then
    local rune = Silverfury.runelore.core.nextEmpowerRune()
    if rune then
      Silverfury.runelore.core.noteEmpowerSent(rune)
      return { type="rune", cmd="empower " .. rune, reason="empower: " .. rune }
    end
  end
  return nil
end

-- ── Scenario interface ────────────────────────────────────────────────────────

-- Setup is done once kena is attuned (means the runeblade is sketched and active).
function scenario.setupDone()
  return Silverfury.runelore.core.isAttuned("kena")
end

-- canExecute tells the base FSM we've reached the EXECUTE phase internally.
function scenario.canExecute()
  return _phase == PHASE.EXECUTE
end

function scenario.shouldAbort()
  return not tgt().isAvailable()
end

-- setupAction: empower kena / hit until kena attunes.
function scenario.setupAction()
  local emp = checkEmpower()
  if emp then return emp end
  -- Just keep hitting; the attunement will happen automatically.
  return attack("dsl", "left_leg", "kelp_stack", "setup: waiting for Kena attunement")
end

-- maintainAction: run the phase machine.
function scenario.maintainAction()
  -- Empower takes priority over everything (instant action, doesn't cost a tick).
  local emp = checkEmpower()
  if emp then return emp end

  -- Advance phase based on current state before choosing action.
  advancePhase()

  if _phase == PHASE.BUILD_KELP then
    return buildKelpAction()
  elseif _phase == PHASE.PREP_LIMBS then
    return prepLimbsAction()
  elseif _phase == PHASE.BREAK_LEG1 then
    return breakLeg1Action()
  elseif _phase == PHASE.BREAK_HEAD then
    return breakHeadAction()
  elseif _phase == PHASE.BREAK_LEG2 then
    return breakLeg2Action()
  end

  -- Fallback: standard attack while we wait.
  return attack("dsl", "left_leg", "lock", "runelore maintain: fallback")
end

function scenario.executeAction()
  local emp = checkEmpower()
  if emp then return emp end
  return executeFinisher()
end

function scenario.isComplete()
  return tgt().dead
end

function scenario.onStart()
  _phase            = PHASE.BUILD_KELP
  _kelp_phase_start = Silverfury.time.now()
  Silverfury.log.info("Runelore-kill started on %s | Phase: BUILD_KELP",
    tgt().name or "?")
end

function scenario.onStop()
  Silverfury.log.info("Runelore-kill ended. Final phase: %s", _phase)
end

function scenario.onAbort()
  Silverfury.log.warn("Runelore-kill aborted at phase: %s", _phase)
end

-- ── Registration ──────────────────────────────────────────────────────────────

function scenario.start()
  return Silverfury.scenarios.base.start("runelore_kill", scenario)
end

-- Expose current phase for status display.
function scenario.phase()
  return _phase
end
