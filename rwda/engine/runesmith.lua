rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.runesmith = rwda.engine.runesmith or {}

local runesmith = rwda.engine.runesmith

-- ─────────────────────────────────────────────────────────────────────────────
-- State machine
-- ─────────────────────────────────────────────────────────────────────────────

-- States:
--   idle → sketching_baseline → sketching_core → empowering_weapon →
--          sketching_config → setting_priority → done
-- OR:
--   idle → sketching_gebu → sketching_gebo → empowering_armour → done
-- OR (configure-only):
--   idle → sketching_config → setting_priority → done

local sm = {
  state       = "idle",
  work_ref    = nil,   -- item reference string (e.g. "runeblade", "left", "armour")
  config_name = nil,   -- chosen preset name
  steps       = {},    -- { cmd, confirm, fail_patterns } ordered list
  step_index  = 0,
  _timer      = nil,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function cfg()
  return (rwda.config and rwda.config.runesmith) or {}
end

local function log(fmt, ...)
  if rwda.util and rwda.util.log then
    rwda.util.log("info", "[Runesmith] " .. fmt, ...)
  end
end

local function warn(fmt, ...)
  if rwda.util and rwda.util.log then
    rwda.util.log("warn", "[Runesmith] " .. fmt, ...)
  end
end

local function sendGame(cmd)
  if type(send) == "function" then
    send(cmd)
  end
end

local function cancelTimer()
  if sm._timer and type(killTimer) == "function" then
    pcall(killTimer, sm._timer)
  end
  sm._timer = nil
end

local function emit(name, payload)
  if rwda.engine and rwda.engine.events and rwda.engine.events.emit then
    rwda.engine.events.emit(name, payload)
  end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Step runner
-- ─────────────────────────────────────────────────────────────────────────────

local function advanceStep()
  sm.step_index = sm.step_index + 1
  if sm.step_index > #sm.steps then
    runesmith.complete()
    return
  end

  local step = sm.steps[sm.step_index]
  sm.state = step.state_name or "working"
  log("Step %d/%d: %s", sm.step_index, #sm.steps, step.cmd)
  sendGame(step.cmd)
end

local function scheduleAdvance()
  cancelTimer()
  local delayMs = cfg().step_delay_ms or 800
  if type(tempTimer) == "function" then
    sm._timer = tempTimer(delayMs / 1000, function()
      sm._timer = nil
      advanceStep()
    end)
  else
    -- Fallback: immediate (no timer API in test context)
    advanceStep()
  end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Step builder helpers
-- ─────────────────────────────────────────────────────────────────────────────

local SKETCH_FAIL = {
  "You need more equilibrium",
  "you need more equilibrium",
  "You don't have any",
  "you don't have any",
  "You aren't holding",
  "you aren't holding",
  "That is not a runeblade",
  "that is not a runeblade",
  "You cannot sketch",
  "you cannot sketch",
}

local EMPOWER_FAIL = {
  "You need more equilibrium",
  "you need more equilibrium",
  "You don't have enough mana",
  "you don't have enough mana",
  "You cannot empower",
  "you cannot empower",
  "That is not a runeblade",
  "that is not a runeblade",
}

local function sketchStep(rune, ref, stateName)
  return {
    cmd        = string.format("sketch %s on %s", rune:lower(), ref),
    confirm    = string.format("you finish sketching a %s rune", rune:lower()),
    fail       = SKETCH_FAIL,
    state_name = stateName or ("sketching_" .. rune:lower()),
  }
end

local function empowerStep(ref, stateName)
  return {
    cmd        = string.format("empower %s", ref),
    confirm    = "you empower",
    fail       = EMPOWER_FAIL,
    state_name = stateName or "empowering",
  }
end

local function configStep(ref, runes, stateName)
  return {
    cmd        = string.format("sketch configuration %s %s", ref, table.concat(runes, " ")),
    confirm    = "you finish sketching the configuration",
    fail       = SKETCH_FAIL,
    state_name = stateName or "sketching_config",
  }
end

local function priorityStep(runes)
  return {
    cmd        = "empower priority set " .. table.concat(runes, " "),
    confirm    = "you set the empowerment priority",
    fail       = { "you cannot", "no rune" },
    state_name = "setting_priority",
  }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Step sequence builders
-- ─────────────────────────────────────────────────────────────────────────────

local function buildWeaponSteps(ref, preset)
  local steps = {}

  -- 1. Baseline weapon runes (lagul, lagua, laguz)
  for _, r in ipairs(preset.weapon_runes or { "lagul", "lagua", "laguz" }) do
    steps[#steps + 1] = sketchStep(r, ref, "sketching_baseline")
  end

  -- 2. Core runeblade rune
  if preset.core_rune then
    steps[#steps + 1] = sketchStep(preset.core_rune, ref, "sketching_core")
  end

  -- 3. Empower weapon
  steps[#steps + 1] = empowerStep(ref, "empowering_weapon")

  -- 4. Configuration runes (if any)
  if preset.config_runes and #preset.config_runes > 0 then
    steps[#steps + 1] = configStep(ref, preset.config_runes, "sketching_config")
    steps[#steps + 1] = priorityStep(preset.config_runes)
  end

  return steps
end

local function buildArmourSteps(ref)
  return {
    sketchStep("gebu", ref, "sketching_gebu"),
    sketchStep("gebo", ref, "sketching_gebo"),
    empowerStep(ref, "empowering_armour"),
  }
end

local function buildConfigureSteps(ref, preset)
  if not preset.config_runes or #preset.config_runes == 0 then
    return {}
  end
  return {
    configStep(ref, preset.config_runes, "sketching_config"),
    priorityStep(preset.config_runes),
  }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Completion and failure
-- ─────────────────────────────────────────────────────────────────────────────

function runesmith.complete()
  cancelTimer()
  sm.state = "done"
  local preset = sm.config_name and rwda.data and rwda.data.rune_configs and rwda.data.rune_configs.get(sm.config_name)
  log("Workflow complete for '%s' using preset '%s'.", tostring(sm.work_ref), tostring(sm.config_name or "armour"))

  -- Auto-sync runelore config
  if preset and not preset.armour and cfg().auto_sync_runelore ~= false then
    if rwda.config and rwda.config.runelore then
      rwda.config.runelore.default_core        = preset.core_rune
      rwda.config.runelore.default_config_runes = { table.unpack(preset.config_runes) }
      rwda.config.runelore.empower_priority     = { table.unpack(preset.config_runes) }
      if preset.bisect ~= nil then
        rwda.config.runelore.bisect_enabled = preset.bisect
      end
      log("Runelore config synced: core=%s config=%s", tostring(preset.core_rune), table.concat(preset.config_runes, ","))
    end
    -- Also update live runeblade state if loaded
    if rwda.state and rwda.state.runeblade then
      if rwda.state.runeblade.setConfiguration then
        rwda.state.runeblade.setConfiguration(preset.core_rune, preset.config_runes)
      end
      if rwda.state.runeblade.setEmpowerPriority then
        rwda.state.runeblade.setEmpowerPriority(preset.config_runes)
      end
    end
  end

  -- Auto-apply kelp_cycle from preset to venom planner
  if preset and preset.kelp_cycle and #preset.kelp_cycle > 0 then
    if rwda.config and rwda.config.runewarden then
      rwda.config.runewarden.venoms = rwda.config.runewarden.venoms or {}
      rwda.config.runewarden.venoms.kelp_cycle = { table.unpack(preset.kelp_cycle) }
      log("Kelp venom cycle set to: %s", table.concat(preset.kelp_cycle, ", "))
    end
  end

  -- Auto-switch RWDA profile
  if preset and preset.profile_hint and cfg().auto_switch_profile ~= false then
    if rwda.state and rwda.state.flags then
      rwda.state.flags.profile = preset.profile_hint
      log("Profile switched to '%s'.", preset.profile_hint)
    end
  end

  log("Run: rwda save config   -- to persist this setup.")
  emit("RUNESMITH_DONE", { config_name = sm.config_name, ref = sm.work_ref })

  -- Reset
  sm.config_name = nil
  sm.work_ref    = nil
  sm.steps       = {}
  sm.step_index  = 0
end

function runesmith.fail(reason)
  cancelTimer()
  warn("Workflow FAILED at step %d/%d (%s): %s", sm.step_index, #sm.steps, sm.state, tostring(reason))
  emit("RUNESMITH_FAILED", { reason = reason, state = sm.state, step = sm.step_index })
  sm.state      = "idle"
  sm.steps      = {}
  sm.step_index = 0
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Line handler (called by parser for every game line while active)
-- ─────────────────────────────────────────────────────────────────────────────

function runesmith.onLine(line)
  if sm.state == "idle" or sm.state == "done" or #sm.steps == 0 then return end
  if not line then return end

  local lower = line:lower()
  local step  = sm.steps[sm.step_index]
  if not step then return end

  -- Check confirm
  if lower:find(step.confirm, 1, true) then
    emit("RUNESMITH_STEP_DONE", { step = sm.step_index, cmd = step.cmd })
    scheduleAdvance()
    return
  end

  -- Check fail patterns
  for _, pat in ipairs(step.fail or {}) do
    if lower:find(pat:lower(), 1, true) then
      runesmith.fail(pat)
      return
    end
  end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public workflow entry points
-- ─────────────────────────────────────────────────────────────────────────────

--- Full weapon build: sketch baseline runes → core → EMPOWER → CONFIGURATION.
function runesmith.beginWeapon(ref, configName)
  if sm.state ~= "idle" and sm.state ~= "done" then
    warn("Already running a workflow (state=%s). Cancel first.", sm.state)
    return false
  end

  local preset = rwda.data and rwda.data.rune_configs and rwda.data.rune_configs.get(configName)
  if not preset then
    warn("Unknown preset '%s'. Use: rwda runesmith list", tostring(configName))
    return false
  end
  if preset.armour then
    warn("Preset '%s' is an armour preset. Use: rwda runesmith armour <ref>", configName)
    return false
  end

  sm.work_ref    = ref
  sm.config_name = configName
  sm.steps       = buildWeaponSteps(ref, preset)
  sm.step_index  = 0

  local inkStr = rwda.data.rune_configs.inkCostString(configName)
  log("Starting weapon workflow: ref='%s' preset='%s' steps=%d ink=%s", ref, configName, #sm.steps, inkStr)
  scheduleAdvance()
  return true
end

--- Armour empowerment: sketch Gebu + Gebo → EMPOWER.
function runesmith.beginArmour(ref)
  if sm.state ~= "idle" and sm.state ~= "done" then
    warn("Already running a workflow (state=%s). Cancel first.", sm.state)
    return false
  end

  sm.work_ref    = ref
  sm.config_name = nil
  sm.steps       = buildArmourSteps(ref)
  sm.step_index  = 0

  log("Starting armour workflow: ref='%s' steps=%d ink=2G", ref, #sm.steps)
  scheduleAdvance()
  return true
end

--- Configuration-only: for an already-empowered runeblade.
--- Sends SKETCH CONFIGURATION + EMPOWER PRIORITY SET only.
function runesmith.beginConfigure(ref, configName)
  if sm.state ~= "idle" and sm.state ~= "done" then
    warn("Already running a workflow (state=%s). Cancel first.", sm.state)
    return false
  end

  local preset = rwda.data and rwda.data.rune_configs and rwda.data.rune_configs.get(configName)
  if not preset then
    warn("Unknown preset '%s'. Use: rwda runesmith list", tostring(configName))
    return false
  end
  if preset.armour then
    warn("Preset '%s' is an armour preset. Use: rwda runesmith armour <ref>", configName)
    return false
  end

  sm.work_ref    = ref
  sm.config_name = configName
  sm.steps       = buildConfigureSteps(ref, preset)
  sm.step_index  = 0

  if #sm.steps == 0 then
    warn("Preset '%s' has no configuration runes defined.", configName)
    return false
  end

  log("Starting configure-only workflow: ref='%s' preset='%s' steps=%d", ref, configName, #sm.steps)
  scheduleAdvance()
  return true
end

--- Abort any active workflow.
function runesmith.cancel()
  cancelTimer()
  if sm.state == "idle" then
    log("Nothing to cancel.")
    return
  end
  warn("Workflow cancelled at step %d/%d (state=%s).", sm.step_index, #sm.steps, sm.state)
  emit("RUNESMITH_FAILED", { reason = "cancelled", state = sm.state })
  sm.state      = "idle"
  sm.steps      = {}
  sm.step_index = 0
  sm.work_ref   = nil
  sm.config_name = nil
end

--- Print current state to the RWDA log.
function runesmith.status()
  if sm.state == "idle" then
    log("Idle — no active workflow.")
    return
  end
  local step = sm.steps[sm.step_index]
  log(
    "state=%s step=%d/%d ref='%s' preset='%s' next='%s'",
    sm.state,
    sm.step_index,
    #sm.steps,
    tostring(sm.work_ref   or "none"),
    tostring(sm.config_name or "armour"),
    step and step.cmd or "n/a"
  )
end

--- Bootstrap: register line listener, log init.
function runesmith.bootstrap()
  -- Register as a listener on the parser's DATA_LINE event if available.
  -- Parser also calls runesmith.onLine() directly from parser.lua.
  if rwda.engine and rwda.engine.events then
    rwda.engine.events.on("DATA_LINE", function(payload)
      runesmith.onLine(payload and payload.line)
    end)
  end
  log("Bootstrap complete (step_delay=%dms auto_sync_runelore=%s auto_switch_profile=%s)",
    cfg().step_delay_ms or 800,
    tostring(cfg().auto_sync_runelore ~= false),
    tostring(cfg().auto_switch_profile ~= false)
  )
end
