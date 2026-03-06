-- Silverfury/scenarios/dragon_devour.lua
-- Silver Dragon guided kill scenario.
-- FSM phases: LOCATE → PIN → GROUND → PRESSURE → TORSO_FOCUS → (execute via canExecute)
--
-- Plugs into scenarios/base.lua's FSM:
--   SETUP    — verify dragon form, dragonarmour, breath summon
--   MAINTAIN — run internal phase machine (locate/pin/ground/pressure/torso focus)
--   EXECUTE  — fire DEVOUR when estimator says safe
--   ABORT    — grove / target loss / manual stop

Silverfury          = Silverfury or {}
Silverfury.scenarios = Silverfury.scenarios or {}

local scenario = {}
Silverfury.scenarios.dragon_devour = scenario

-- ── Internal phases ───────────────────────────────────────────────────────────

local PHASE = {
  LOCATE      = "LOCATE",
  PIN         = "PIN",
  GROUND      = "GROUND",
  PRESSURE    = "PRESSURE",
  TORSO_FOCUS = "TORSO_FOCUS",
}

local _phase          = PHASE.LOCATE
local _devour_start_t = nil   -- epoch_ms when DEVOUR was sent (for outcome timing)

-- ── Shorthand ─────────────────────────────────────────────────────────────────

local function tgt()   return Silverfury.state.target           end
local function me()    return Silverfury.state.me                end
local function cfg()   return Silverfury.config                  end
local function cmds()  return Silverfury.dragon.commands         end
local function core()  return Silverfury.dragon.core             end
local function match() return Silverfury.dragon.matchups         end
local function room()  return Silverfury.state.room              end

local function act(cmd, reason, resource)
  return { type = "dragon", cmd = cmd, reason = reason, resource = resource or "bal" }
end

-- ── SETUP phase ───────────────────────────────────────────────────────────────

function scenario.setupDone()
  if not core().isActive() then return false end
  if cfg().get("dragon.auto_dragonarmour") and not core().hasDragonarmour() then return false end
  if cfg().get("dragon.auto_summon_breath") and not core().breathSummoned()  then return false end
  return true
end

function scenario.setupAction()
  if not core().isActive() then
    return act("dragonform", "setup: transform to dragon form")
  end
  if cfg().get("dragon.auto_dragonarmour") and not core().hasDragonarmour() then
    return act(cmds().dragonarmour("on"), "setup: dragonarmour on", "eq")
  end
  if cfg().get("dragon.auto_summon_breath") and not core().breathSummoned() then
    local btype = cfg().get("dragon.breath_type") or "lightning"
    return act(cmds().summon(btype), "setup: summon " .. btype, "direct")
  end
  return nil
end

-- ── Phase machine helpers ─────────────────────────────────────────────────────

local function advancePhase()
  local t = tgt()
  if _phase == PHASE.LOCATE then
    if t.in_room then
      _phase = PHASE.PIN
      Silverfury.log.info("Dragon: %s in room → advancing to PIN", t.name or "?")
    end

  elseif _phase == PHASE.PIN then
    -- PIN exits to GROUND from within pinAction() once control work is done.
    -- advancePhase() does not auto-advance here to avoid skipping pin work.

  elseif _phase == PHASE.GROUND then
    if t.prone then
      _phase = PHASE.PRESSURE
      Silverfury.log.info("Dragon: target prone → advancing to PRESSURE")
    end

  elseif _phase == PHASE.PRESSURE then
    -- Move to TORSO_FOCUS when at least one leg has reached the leg_prep threshold.
    local ll   = t.limbs and t.limbs.left_leg
    local rl   = t.limbs and t.limbs.right_leg
    local best = math.max(ll and ll.damage_pct or 0, rl and rl.damage_pct or 0)
    if best >= (cfg().get("dragon.leg_prep_pct") or 70) then
      _phase = PHASE.TORSO_FOCUS
      Silverfury.log.info("Dragon: leg pressure threshold met → advancing to TORSO_FOCUS")
    end
  end
  -- TORSO_FOCUS stays until canExecute() opens the EXECUTE phase.
end

-- ── Phase action helpers ──────────────────────────────────────────────────────

local function locateAction()
  local t = tgt()
  if not t.in_room then
    if t.name then
      return act(cmds().track(t.name), "locate: TRACK " .. t.name)
    end
    return nil
  end
  return nil
end

local function pinAction()
  local t = tgt()

  -- Grove abort check.
  if match().shouldAbortInGrove(t.class) and room().is_grove then
    Silverfury.log.warn("Dragon: grove detected for %s — aborting", tostring(t.class))
    Silverfury.scenarios.base.abort()
    return nil
  end

  -- Becalm if flying.
  if t.can_fly and cfg().get("dragon.auto_becalm") then
    return act(cmds().becalm(t.name), "pin: becalm flier")
  end

  -- Block known escape direction (no balance cost — direct send).
  local edir = t.last_escape_dir
  if edir and cfg().get("dragon.control_block_dirs") then
    return act(cmds().block(edir), "pin: block " .. edir, "direct")
  end

  -- Enmesh if configured and target not already enmeshed (equilibrium cost).
  if cfg().get("dragon.use_enmesh") and not t.enmeshed and me().eq then
    return act(cmds().enmesh(t.name), "pin: enmesh", "eq")
  end

  -- PIN is a transient gating phase — advance immediately.
  _phase = PHASE.GROUND
  return nil
end

local function groundAction()
  local t = tgt()
  local m = me()

  -- Strip shield/rebounding before grounding.
  if t.hasDef("shield") and m.bal then
    return act(cmds().tailsmash(t.name), "ground: tailsmash strip shield")
  end
  if t.hasDef("rebounding") and core().breathSummoned() and m.bal then
    return act(cmds().breathstrip(t.name), "ground: breathstrip strip rebounding")
  end

  if not t.prone then
    if cfg().get("dragon.prefer_breathgust") and m.eq then
      return act(cmds().breathgust(t.name), "ground: breathgust → prone", "eq")
    end
    if m.bal then
      return act(cmds().tailsweep(), "ground: tailsweep → prone")
    end
  end

  return nil
end

local function pressureAction()
  local t = tgt()
  local m = me()

  -- Re-ground if no longer prone.
  if not t.prone then
    _phase = PHASE.GROUND
    return groundAction()
  end

  if not m.bal then return nil end

  local limbs    = t.limbs or {}
  local ll_pct   = (limbs.left_leg  and limbs.left_leg.damage_pct)  or 0
  local rl_pct   = (limbs.right_leg and limbs.right_leg.damage_pct) or 0
  local prep_pct = cfg().get("dragon.leg_prep_pct") or 70

  -- Target the least-pressured leg.
  local target_limb = ll_pct <= rl_pct and "left leg" or "right leg"
  local target_pct  = math.min(ll_pct, rl_pct)

  if target_pct >= prep_pct then
    _phase = PHASE.TORSO_FOCUS
    return act(cmds().gut(t.name), "pressure→torso: gut")
  end

  -- Bite deals bonus damage on prone targets.
  if t.prone then
    return act(cmds().bite(t.name), "pressure: bite (prone bonus)")
  end

  return act(cmds().rend(t.name, target_limb), "pressure: rend " .. target_limb)
end

local function torsoFocusAction()
  local t = tgt()
  local m = me()

  -- Re-ground if no longer prone.
  if not t.prone then
    _phase = PHASE.GROUND
    return groundAction()
  end

  local torso     = t.limbs and t.limbs.torso
  local torso_pct = (torso and torso.damage_pct) or 0

  if not m.bal then return nil end

  -- Swipe hits a leg AND torso simultaneously — efficient dual-limb pressure.
  if t.prone and torso and not torso.broken then
    local torso_focus_pct = cfg().get("dragon.torso_focus_pct") or 60
    if torso_pct < torso_focus_pct then
      return act(cmds().swipe(t.name, "left leg", "torso"), "torso_focus: swipe leg+torso")
    end
  end

  -- Gut for pure torso damage.
  if torso and not torso.broken then
    return act(cmds().gut(t.name), "torso_focus: gut")
  end

  -- Torso broken — maintain pressure on anything while canExecute() evaluates.
  if t.prone then
    return act(cmds().bite(t.name), "torso_focus: bite (maintain prone)")
  end

  return act(cmds().rend(t.name, nil), "torso_focus: rend")
end

-- ── MAINTAIN phase (base.lua FSM hook) ───────────────────────────────────────

function scenario.maintainAction()
  advancePhase()

  if _phase == PHASE.LOCATE      then return locateAction()     end
  if _phase == PHASE.PIN         then return pinAction()        end
  if _phase == PHASE.GROUND      then return groundAction()     end
  if _phase == PHASE.PRESSURE    then return pressureAction()   end
  if _phase == PHASE.TORSO_FOCUS then return torsoFocusAction() end
  return nil
end

-- ── EXECUTE phase (base.lua FSM hook) ────────────────────────────────────────

-- canExecute() is called every tick in MAINTAIN. If it returns true, base.lua
-- advances to EXECUTE and calls executeAction() instead of maintainAction().
function scenario.canExecute()
  local est = Silverfury.dragon.devour.estimate()
  -- Store estimate on target for UI/status display.
  tgt().devour_estimate = est
  return est.safe
end

function scenario.executeAction()
  local t   = tgt()
  local est = Silverfury.dragon.devour.estimate()
  t.devour_estimate = est

  if est.safe and me().bal then
    _devour_start_t = Silverfury.time.now()
    Silverfury.log.info("Dragon: DEVOUR %s — %s", t.name or "?", est.reason)
    return act(cmds().devour(t.name), "execute: devour (" .. est.reason .. ")", "freestand")
  end

  -- Window closed between canExecute check and now — drop back.
  Silverfury.log.info("Dragon: devour window closed (%s) — falling back", est.reason)
  _phase = PHASE.TORSO_FOCUS
  return torsoFocusAction()
end

-- ── Abort / complete ──────────────────────────────────────────────────────────

function scenario.shouldAbort()
  local t = tgt()
  if not t.isAvailable() then return true end
  if match().shouldAbortInGrove(t.class) and room().is_grove then
    Silverfury.log.warn("Dragon: aborting — grove match (%s)", tostring(t.class))
    return true
  end
  return false
end

function scenario.isComplete()
  return tgt().dead
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

-- Public entry point — called by bindings.lua "sf exec dragon".
function scenario.start()
  Silverfury.scenarios.base.start("dragon_devour", scenario)
end

function scenario.onStart()
  _phase          = PHASE.LOCATE
  _devour_start_t = nil
  tgt().devour_estimate = nil
  Silverfury.log.info("Dragon-devour: started on %s", tostring(tgt().name))
end

function scenario.onStop()
  Silverfury.log.info("Dragon-devour: stopped.")
end

function scenario.onAbort()
  Silverfury.log.warn("Dragon-devour: aborted.")
end

function scenario.phase()
  return _phase
end

-- Expose devour start time for outcome logging in incoming parser.
function scenario.devourStartT()
  return _devour_start_t
end

function scenario.clearDevourStartT()
  _devour_start_t = nil
end
