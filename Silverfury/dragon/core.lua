-- Silverfury/dragon/core.lua
-- Silver Dragon combat state and helpers.
-- Tracks breath summon, dragonarmour, and free-form planner logic.

Silverfury       = Silverfury or {}
Silverfury.dragon = Silverfury.dragon or {}

Silverfury.dragon.core = Silverfury.dragon.core or {}
local core = Silverfury.dragon.core

-- ── Internal state ────────────────────────────────────────────────────────────

local _state = {
  breath_summoned = false,
  dragonarmour    = false,
  clawparry_part  = nil,        -- body part currently set for clawparry
  flying          = false,
}

-- ── Accessors ─────────────────────────────────────────────────────────────────

function core.isActive()
  return Silverfury.state.me.form == "dragon"
end

function core.breathSummoned()  return _state.breath_summoned  end
function core.setBreathSummoned(v)
  _state.breath_summoned = v == true
  Silverfury.log.trace("Dragon: breath_summoned = %s", tostring(_state.breath_summoned))
end

function core.hasDragonarmour()  return _state.dragonarmour  end
function core.setDragonarmour(v)
  _state.dragonarmour = v == true
  Silverfury.log.trace("Dragon: dragonarmour = %s", tostring(_state.dragonarmour))
end

function core.isFlying()  return _state.flying  end
function core.setFlying(v)  _state.flying = v == true  end

-- ── Precondition helpers ──────────────────────────────────────────────────────

function core.shouldEnsureDragonarmour()
  return core.isActive()
    and Silverfury.config.get("dragon.auto_dragonarmour")
    and not _state.dragonarmour
end

function core.shouldSummonBreath()
  return core.isActive()
    and Silverfury.config.get("dragon.auto_summon_breath")
    and not _state.breath_summoned
end

-- ── Breath selection ──────────────────────────────────────────────────────────

-- Returns the appropriate breath type for a given enemy class, defaulting to
-- the configured breath_type (Silver = lightning).
function core.breathForClass(class_name)
  local m = Silverfury.dragon.matchups.get(class_name)
  if m and m.breath then return m.breath end
  return Silverfury.config.get("dragon.breath_type") or "lightning"
end

-- ── Free-form dragon planner ──────────────────────────────────────────────────
-- Called by planner._chooseDragonAction() when no scenario is running.

function core.chooseFreeAction()
  local tgt  = Silverfury.state.target
  local me   = Silverfury.state.me
  local cmds = Silverfury.dragon.commands
  local cfg  = Silverfury.config

  local function act(cmd, reason)
    return { type = "dragon", cmd = cmd, reason = reason }
  end

  -- 1. Dragonarmour upkeep.
  if core.shouldEnsureDragonarmour() then
    return act(cmds.dragonarmour("on"), "dragon: ensure dragonarmour")
  end

  -- 2. Breath summon.
  if core.shouldSummonBreath() then
    local btype = cfg.get("dragon.breath_type") or "lightning"
    return act(cmds.summon(btype), "dragon: summon " .. btype)
  end

  -- 3. Strip shield/rebounding.
  if tgt.hasDef("shield") then
    return act(cmds.tailsmash(tgt.name), "dragon: tailsmash → strip shield")
  end
  if tgt.hasDef("rebounding") and _state.breath_summoned then
    return act(cmds.breathstrip(tgt.name), "dragon: breathstrip → strip rebounding")
  end

  -- 4. Breathstorm for matchup-specific strategies (Serpent reveal, Magi/Sentinel clear).
  if Silverfury.dragon.matchups.shouldBreathstorm(tgt.class)
      and _state.breath_summoned and me.bal then
    return act(cmds.breathstorm(tgt.name), "dragon: breathstorm (matchup)")
  end

  -- 5. Ground target if standing.
  if not tgt.prone then
    if cfg.get("dragon.prefer_breathgust") and me.eq then
      return act(cmds.breathgust(tgt.name), "dragon: breathgust → prone")
    elseif me.bal then
      return act(cmds.tailsweep(), "dragon: tailsweep → prone")
    end
  end

  -- 5. Devour window check.
  local est = Silverfury.dragon.devour.estimate()
  if est.safe and me.bal then
    return act(cmds.devour(tgt.name), "dragon: devour (" .. est.reason .. ")")
  end

  -- 6. Torso focus if torso not broken.
  local torso = tgt.limbs and tgt.limbs.torso
  if torso and not torso.broken and me.bal then
    local gv = Silverfury.offense.venoms.pick()
    return act(cmds.gut(tgt.name, gv), "dragon: gut → torso pressure")
  end

  -- 7. General pressure.
  if me.bal then
    if tgt.prone then
      return act(cmds.bite(tgt.name), "dragon: bite (prone)")
    end
    return act(cmds.rend(tgt.name, nil), "dragon: rend")
  end

  -- 8. Blast (eq-based breath attack).
  if me.eq and _state.breath_summoned then
    return act(cmds.blast(tgt.name), "dragon: blast")
  end

  return { type = "idle", cmd = nil, reason = "dragon: waiting for balance" }
end

-- ── Reset on target change ────────────────────────────────────────────────────

core._handlers = core._handlers or {}
local _handlers = core._handlers

function core.registerHandlers()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end

  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_TargetChanged", function()
    -- Keep breath/armour state; only reset per-target tracking is done in target.lua.
    Silverfury.log.trace("Dragon core: target changed")
  end)

  -- Reset state when dragon form is re-entered so upkeep reruns armour/breath checks.
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_DragonFormGained", function()
    _state.breath_summoned = false
    _state.dragonarmour    = false
    Silverfury.log.info("Dragon: transformed to dragon form — resetting dragon state")
  end)

  -- If we revert from dragon form, clear breath state.
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_DragonFormLost", function()
    _state.breath_summoned = false
    _state.dragonarmour    = false
    Silverfury.log.info("Dragon: reverted to human form — resetting dragon state")
  end)
end

function core.shutdown()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end
end
