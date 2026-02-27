rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.planner = rwda.engine.planner or {}

local planner = rwda.engine.planner

local function defActive(target, name)
  local d = target and target.defs and target.defs[name]
  return d and d.active and (d.confidence or 0) > 0
end

local function limbBroken(target, limb)
  local l = target and target.limbs and target.limbs[limb]
  return l and l.broken
end

local function getAbility(mode, name)
  local data = rwda.data and rwda.data.abilities
  if not data then
    return nil
  end

  if mode == "human_dualcut" then
    return data.human and data.human[name]
  end

  return data.dragon and data.dragon[name]
end

local function action(mode, name, commands, reason, extra)
  extra = extra or {}
  local spec = getAbility(mode, name) or {}

  return {
    mode = mode,
    name = name,
    commands = commands,
    queue_type = extra.queue_type or spec.queue,
    requires = extra.requires or spec.requires or {},
    reason = reason,
    clear_queue = extra.clear_queue,
  }
end

function planner.resolveMode(state)
  local forced = (state.flags.mode or "auto"):lower()

  if forced == "human" or forced == "human_dualcut" then
    return "human_dualcut"
  end
  if forced == "dragon" or forced == "dragon_silver" then
    return "dragon_silver"
  end

  if state.me.form == "dragon" then
    return "dragon_silver"
  end

  return "human_dualcut"
end

function planner.nextPrepLimb(state)
  local prep = rwda.config.runewarden.prep_limbs or { "left_leg", "right_leg", "torso" }
  for _, limb in ipairs(prep) do
    if not limbBroken(state.target, limb) then
      return limb
    end
  end
  return "torso"
end

function planner.estimateDevourTime(state)
  local target = state.target
  local torso = target.limbs.torso
  local time = 8.5

  if torso.broken then
    time = time - 2.2
  end

  if (torso.damage_pct or 0) >= 65 then
    time = time - 0.9
  end

  for limbName, limb in pairs(target.limbs) do
    if limbName ~= "torso" and limb.broken then
      time = time - 0.6
    end
  end

  if target.prone then
    time = time - 0.3
  end

  if defActive(target, "shield") then
    time = time + 1.0
  end
  if defActive(target, "rebounding") then
    time = time + 0.5
  end

  return math.max(1.0, time)
end

function planner.canDevour(state)
  local threshold = rwda.config.dragon.devour_threshold or 6.0
  return planner.estimateDevourTime(state) < threshold
end

function planner.humanDualcut(state)
  local target = state.target.name
  if not target then
    return nil
  end

  if defActive(state.target, "rebounding") then
    return action(
      "human_dualcut",
      "raze",
      { string.format("raze %s rebounding", target) },
      { summary = "Strip rebounding before weapon pressure.", code = "strip_rebounding" }
    )
  end

  if defActive(state.target, "shield") then
    return action(
      "human_dualcut",
      "razeslash",
      { string.format("razeslash %s", target) },
      { summary = "Break magical shield while preserving pressure.", code = "strip_shield" }
    )
  end

  local bothLegsBroken = limbBroken(state.target, "left_leg") and limbBroken(state.target, "right_leg")
  local goal = (state.flags.goal or "limbprep"):lower()
  local targetImpaled = state.target.impaled or state.target.affs.impaled

  if goal == "impale_kill" then
    if state.target.prone and bothLegsBroken and not targetImpaled then
      return action(
        "human_dualcut",
        "impale",
        { string.format("impale %s", target) },
        { summary = "Target is prone with both legs broken, start impale lock.", code = "impale_window" }
      )
    end

    if targetImpaled then
      return action(
        "human_dualcut",
        "disembowel",
        { string.format("disembowel %s", target) },
        { summary = "Target is impaled, convert lock into kill damage.", code = "disembowel_followup" }
      )
    end

    if state.target.prone and bothLegsBroken then
      return action(
        "human_dualcut",
        "intimidate",
        { string.format("intimidate %s", target) },
        { summary = "Reinforce tumble delay while kill setup is active.", code = "intimidate_lock" }
      )
    end
  end

  local limb = planner.nextPrepLimb(state)
  local vMain = rwda.config.runewarden.venoms.dsl_main or { "curare", "gecko" }
  local vOff = rwda.config.runewarden.venoms.dsl_off or { "epteth", "kalmia" }
  local v1 = vMain[1] or "curare"
  local v2 = vOff[1] or "gecko"

  local cmd = string.format("dsl %s %s %s %s", target, limb, v1, v2)
  return action(
    "human_dualcut",
    "dsl",
    { cmd },
    {
      summary = string.format("Apply dual-cut pressure on %s with venom throughput.", limb),
      code = "limbprep_dsl",
      limb = limb,
      venoms = { v1, v2 },
    }
  )
end

function planner.dragonSilver(state)
  local target = state.target.name
  if not target then
    return nil
  end

  if not state.me.dragon.breath_summoned then
    local breathType = rwda.config.dragon.breath_type or "lightning"
    return action(
      "dragon_silver",
      "summon",
      { string.format("summon %s", breathType) },
      { summary = "Summon breath before dragon offense cycle.", code = "summon_breath" }
    )
  end

  if defActive(state.target, "shield") then
    return action(
      "dragon_silver",
      "tailsmash",
      { string.format("tailsmash %s", target) },
      { summary = "Shield detected, use tailsmash to reopen offense.", code = "dragon_strip_shield" }
    )
  end

  if defActive(state.target, "rebounding") then
    return action(
      "dragon_silver",
      "breathstrip",
      { string.format("breathstrip %s", target) },
      { summary = "Rebounding detected, strip with breath utility.", code = "dragon_strip_rebounding" }
    )
  end

  if not state.target.prone then
    return action(
      "dragon_silver",
      "gust",
      { string.format("gust %s", target) },
      { summary = "Force prone state to lock movement and prep devour window.", code = "dragon_force_prone" }
    )
  end

  local goal = (state.flags.goal or "dragon_devour"):lower()
  if goal == "dragon_devour" and planner.canDevour(state) then
    local devourTime = planner.estimateDevourTime(state)
    return action(
      "dragon_silver",
      "devour",
      { string.format("devour %s", target) },
      {
        summary = string.format("Estimated devour time %.1fs is under threshold, execute.", devourTime),
        code = "devour_window",
        devour_time = devourTime,
      },
      {
        queue_type = "freestand",
      }
    )
  end

  if not state.target.limbs.torso.broken then
    return action(
      "dragon_silver",
      "rend",
      { string.format("rend %s torso", target) },
      { summary = "Increase torso damage to accelerate devour channel.", code = "dragon_torso_pressure" }
    )
  end

  local limbOrder = { "left_leg", "right_leg", "left_arm", "right_arm", "head" }
  local chosen = "left_leg"
  for _, limb in ipairs(limbOrder) do
    if not limbBroken(state.target, limb) then
      chosen = limb
      break
    end
  end

  return action(
    "dragon_silver",
    "rend",
    { string.format("rend %s %s", target, chosen) },
    {
      summary = string.format("Keep adding restoration pressure on %s.", chosen),
      code = "dragon_limb_pressure",
      limb = chosen,
      devour_time = planner.estimateDevourTime(state),
    }
  )
end

function planner.choose(state)
  if not state.flags.enabled or state.flags.stopped then
    return nil
  end

  if rwda.config.parser and rwda.config.parser.decay_target_defences and rwda.state and rwda.state.decayTargetDefences then
    rwda.state.decayTargetDefences(rwda.util.now())
  end

  if not state.target.name or state.target.dead then
    return nil
  end

  if rwda.state and rwda.state.isTargetAvailable and not rwda.state.isTargetAvailable() then
    state.runtime.last_reason = {
      summary = string.format("Target unavailable (%s), hold offense.", tostring(state.target.unavailable_reason or "unknown")),
      code = "target_unavailable",
    }
    return nil
  end

  local mode = planner.resolveMode(state)
  local selected

  if mode == "human_dualcut" then
    selected = planner.humanDualcut(state)
  else
    selected = planner.dragonSilver(state)
  end

  if selected then
    state.runtime.last_reason = selected.reason
  end

  return selected
end
