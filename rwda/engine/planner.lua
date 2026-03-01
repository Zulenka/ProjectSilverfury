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

local function enrichReason(summary, code, profileName, blockId, extra)
  local out = {}
  if type(extra) == "table" then
    for k, v in pairs(extra) do
      out[k] = v
    end
  end
  out.summary = summary
  out.code = code
  if profileName then
    out.strategy_profile = profileName
  end
  if blockId then
    out.strategy_block = blockId
  end
  return out
end

local function profileForState(state)
  if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.resolveProfileName then
    return rwda.engine.strategy.resolveProfileName(state)
  end
  return (state.flags and state.flags.profile) or "duel"
end

local function findStrategyBlockById(mode, state, blockId)
  if not blockId or blockId == "" then
    return nil, profileForState(state)
  end

  local profileName = profileForState(state)
  if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.blocksForMode then
    local blocks, resolvedProfile = rwda.engine.strategy.blocksForMode(mode, state)
    if resolvedProfile then
      profileName = resolvedProfile
    end

    for _, block in ipairs(blocks or {}) do
      if type(block) == "table" and tostring(block.id or "") == tostring(blockId) then
        return block, profileName
      end
    end
  end

  return { id = blockId, enabled = true }, profileName
end

local function finisherFallbackBlock(mode)
  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.recommendedFallbackBlock then
    return rwda.engine.finisher.recommendedFallbackBlock(mode)
  end
  return nil
end

local function tagFinisherFallback(selected, blockId)
  if not selected then
    return nil
  end

  selected.reason = selected.reason or {}
  selected.reason.finisher_fallback = true
  selected.reason.finisher_fallback_block = blockId
  return selected
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

local function humanContext(state)
  local targetImpaled = state.target.impaled or state.target.affs.impaled
  local bothLegsBroken = limbBroken(state.target, "left_leg") and limbBroken(state.target, "right_leg")
  local goal = (state.flags.goal or "limbprep"):lower()
  local limb = planner.nextPrepLimb(state)
  local vMain = rwda.config.runewarden.venoms.dsl_main or { "curare", "gecko" }
  local vOff = rwda.config.runewarden.venoms.dsl_off or { "epteth", "kalmia" }

  return {
    goal = goal,
    target_impaled = targetImpaled,
    both_legs_broken = bothLegsBroken,
    limb = limb,
    v1 = vMain[1] or "curare",
    v2 = vOff[1] or "gecko",
  }
end

local function dragonPressureLimb(state)
  local limbOrder = { "left_leg", "right_leg", "left_arm", "right_arm", "head" }
  for _, limb in ipairs(limbOrder) do
    if not limbBroken(state.target, limb) then
      return limb
    end
  end
  return "left_leg"
end

local function dragonContext(state)
  local devourTime = planner.estimateDevourTime(state)
  return {
    goal = (state.flags.goal or "dragon_devour"):lower(),
    can_devour = planner.canDevour(state),
    devour_time = devourTime,
    pressure_limb = dragonPressureLimb(state),
  }
end

local function humanActionFromBlock(state, target, block, profileName, ctx)
  local id = block and block.id or ""
  if id == "strip_rebounding" then
    return action(
      "human_dualcut",
      "raze",
      { string.format("raze %s rebounding", target) },
      enrichReason("Strip rebounding before weapon pressure.", "strip_rebounding", profileName, id)
    )
  end

  if id == "strip_shield" then
    return action(
      "human_dualcut",
      "razeslash",
      { string.format("razeslash %s", target) },
      enrichReason("Break magical shield while preserving pressure.", "strip_shield", profileName, id)
    )
  end

  if id == "impale_window" then
    return action(
      "human_dualcut",
      "impale",
      { string.format("impale %s", target) },
      enrichReason("Target is prone with both legs broken, start impale lock.", "impale_window", profileName, id)
    )
  end

  if id == "disembowel_followup" then
    return action(
      "human_dualcut",
      "disembowel",
      { string.format("disembowel %s", target) },
      enrichReason("Target is impaled, convert lock into kill damage.", "disembowel_followup", profileName, id)
    )
  end

  if id == "intimidate_lock" then
    return action(
      "human_dualcut",
      "intimidate",
      { string.format("intimidate %s", target) },
      enrichReason("Reinforce tumble delay while kill setup is active.", "intimidate_lock", profileName, id)
    )
  end

  if id == "limbprep_dsl" then
    local cmd = string.format("dsl %s %s %s %s", target, ctx.limb, ctx.v1, ctx.v2)
    return action(
      "human_dualcut",
      "dsl",
      { cmd },
      enrichReason(
        string.format("Apply dual-cut pressure on %s with venom throughput.", ctx.limb),
        "limbprep_dsl",
        profileName,
        id,
        { limb = ctx.limb, venoms = { ctx.v1, ctx.v2 } }
      )
    )
  end

  return nil
end

local function dragonActionFromBlock(state, target, block, profileName, ctx)
  local id = block and block.id or ""
  if id == "summon_breath" then
    local breathType = rwda.config.dragon.breath_type or "lightning"
    return action(
      "dragon_silver",
      "summon",
      { string.format("summon %s", breathType) },
      enrichReason("Summon breath before dragon offense cycle.", "summon_breath", profileName, id)
    )
  end

  if id == "dragon_strip_shield" then
    return action(
      "dragon_silver",
      "tailsmash",
      { string.format("tailsmash %s", target) },
      enrichReason("Shield detected, use tailsmash to reopen offense.", "dragon_strip_shield", profileName, id)
    )
  end

  if id == "dragon_strip_rebounding" then
    return action(
      "dragon_silver",
      "breathstrip",
      { string.format("breathstrip %s", target) },
      enrichReason("Rebounding detected, strip with breath utility.", "dragon_strip_rebounding", profileName, id)
    )
  end

  if id == "dragon_force_prone" then
    return action(
      "dragon_silver",
      "gust",
      { string.format("gust %s", target) },
      enrichReason("Force prone state to lock movement and prep devour window.", "dragon_force_prone", profileName, id)
    )
  end

  if id == "devour_window" then
    return action(
      "dragon_silver",
      "devour",
      { string.format("devour %s", target) },
      enrichReason(
        string.format("Estimated devour time %.1fs is under threshold, execute.", ctx.devour_time),
        "devour_window",
        profileName,
        id,
        { devour_time = ctx.devour_time }
      ),
      { queue_type = "freestand" }
    )
  end

  if id == "dragon_torso_pressure" then
    return action(
      "dragon_silver",
      "rend",
      { string.format("rend %s torso", target) },
      enrichReason("Increase torso damage to accelerate devour channel.", "dragon_torso_pressure", profileName, id)
    )
  end

  if id == "dragon_limb_pressure" then
    return action(
      "dragon_silver",
      "rend",
      { string.format("rend %s %s", target, ctx.pressure_limb) },
      enrichReason(
        string.format("Keep adding restoration pressure on %s.", ctx.pressure_limb),
        "dragon_limb_pressure",
        profileName,
        id,
        { limb = ctx.pressure_limb, devour_time = ctx.devour_time }
      )
    )
  end

  if id == "dragon_blast" then
    return action(
      "dragon_silver",
      "blast",
      { string.format("blast %s", target) },
      enrichReason("Apply direct pressure with blast.", "dragon_blast", profileName, id)
    )
  end

  return nil
end

local function humanLegacyFallback(state, target, ctx)
  if defActive(state.target, "rebounding") then
    return action(
      "human_dualcut",
      "raze",
      { string.format("raze %s rebounding", target) },
      enrichReason("Strip rebounding before weapon pressure.", "strip_rebounding")
    )
  end

  if defActive(state.target, "shield") then
    return action(
      "human_dualcut",
      "razeslash",
      { string.format("razeslash %s", target) },
      enrichReason("Break magical shield while preserving pressure.", "strip_shield")
    )
  end

  if ctx.goal == "impale_kill" then
    if state.target.prone and ctx.both_legs_broken and not ctx.target_impaled then
      return action(
        "human_dualcut",
        "impale",
        { string.format("impale %s", target) },
        enrichReason("Target is prone with both legs broken, start impale lock.", "impale_window")
      )
    end

    if ctx.target_impaled then
      return action(
        "human_dualcut",
        "disembowel",
        { string.format("disembowel %s", target) },
        enrichReason("Target is impaled, convert lock into kill damage.", "disembowel_followup")
      )
    end

    if state.target.prone and ctx.both_legs_broken then
      return action(
        "human_dualcut",
        "intimidate",
        { string.format("intimidate %s", target) },
        enrichReason("Reinforce tumble delay while kill setup is active.", "intimidate_lock")
      )
    end
  end

  local cmd = string.format("dsl %s %s %s %s", target, ctx.limb, ctx.v1, ctx.v2)
  return action(
    "human_dualcut",
    "dsl",
    { cmd },
    enrichReason(
      string.format("Apply dual-cut pressure on %s with venom throughput.", ctx.limb),
      "limbprep_dsl",
      nil,
      nil,
      { limb = ctx.limb, venoms = { ctx.v1, ctx.v2 } }
    )
  )
end

local function dragonLegacyFallback(state, target, ctx)
  if not state.me.dragon.breath_summoned then
    local breathType = rwda.config.dragon.breath_type or "lightning"
    return action(
      "dragon_silver",
      "summon",
      { string.format("summon %s", breathType) },
      enrichReason("Summon breath before dragon offense cycle.", "summon_breath")
    )
  end

  if defActive(state.target, "shield") then
    return action(
      "dragon_silver",
      "tailsmash",
      { string.format("tailsmash %s", target) },
      enrichReason("Shield detected, use tailsmash to reopen offense.", "dragon_strip_shield")
    )
  end

  if defActive(state.target, "rebounding") then
    return action(
      "dragon_silver",
      "breathstrip",
      { string.format("breathstrip %s", target) },
      enrichReason("Rebounding detected, strip with breath utility.", "dragon_strip_rebounding")
    )
  end

  if not state.target.prone then
    return action(
      "dragon_silver",
      "gust",
      { string.format("gust %s", target) },
      enrichReason("Force prone state to lock movement and prep devour window.", "dragon_force_prone")
    )
  end

  if ctx.goal == "dragon_devour" and ctx.can_devour then
    return action(
      "dragon_silver",
      "devour",
      { string.format("devour %s", target) },
      enrichReason(
        string.format("Estimated devour time %.1fs is under threshold, execute.", ctx.devour_time),
        "devour_window",
        nil,
        nil,
        { devour_time = ctx.devour_time }
      ),
      { queue_type = "freestand" }
    )
  end

  if not state.target.limbs.torso.broken then
    return action(
      "dragon_silver",
      "rend",
      { string.format("rend %s torso", target) },
      enrichReason("Increase torso damage to accelerate devour channel.", "dragon_torso_pressure")
    )
  end

  return action(
    "dragon_silver",
    "rend",
    { string.format("rend %s %s", target, ctx.pressure_limb) },
    enrichReason(
      string.format("Keep adding restoration pressure on %s.", ctx.pressure_limb),
      "dragon_limb_pressure",
      nil,
      nil,
      { limb = ctx.pressure_limb, devour_time = ctx.devour_time }
    )
  )
end

function planner.humanDualcut(state)
  local target = state.target.name
  if not target then
    return nil
  end

  local ctx = humanContext(state)
  local selected

  local fallbackBlockId = finisherFallbackBlock("human_dualcut")
  if fallbackBlockId then
    local block, profileName = findStrategyBlockById("human_dualcut", state, fallbackBlockId)
    -- Forced fallback bypasses the block's condition so it always fires.
    local forcedBlock = block and rwda.util.deepcopy(block) or { id = fallbackBlockId, enabled = true }
    forcedBlock.when = { "always" }
    selected = humanActionFromBlock(state, target, forcedBlock, profileName, ctx)
    if selected then
      return tagFinisherFallback(selected, fallbackBlockId)
    end
  end

  if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.selectBlock then
    local block, profileName = rwda.engine.strategy.selectBlock("human_dualcut", state, ctx)
    if block then
      selected = humanActionFromBlock(state, target, block, profileName, ctx)
    end
  end

  if selected then
    return selected
  end

  return humanLegacyFallback(state, target, ctx)
end

function planner.dragonSilver(state)
  local target = state.target.name
  if not target then
    return nil
  end

  local ctx = dragonContext(state)
  local selected

  local fallbackBlockId = finisherFallbackBlock("dragon_silver")
  if fallbackBlockId then
    local block, profileName = findStrategyBlockById("dragon_silver", state, fallbackBlockId)
    -- Forced fallback bypasses the block's condition so it always fires.
    local forcedBlock = block and rwda.util.deepcopy(block) or { id = fallbackBlockId, enabled = true }
    forcedBlock.when = { "always" }
    selected = dragonActionFromBlock(state, target, forcedBlock, profileName, ctx)
    if selected then
      return tagFinisherFallback(selected, fallbackBlockId)
    end
  end

  if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.selectBlock then
    local block, profileName = rwda.engine.strategy.selectBlock("dragon_silver", state, ctx)
    if block then
      selected = dragonActionFromBlock(state, target, block, profileName, ctx)
    end
  end

  if selected then
    return selected
  end

  return dragonLegacyFallback(state, target, ctx)
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
