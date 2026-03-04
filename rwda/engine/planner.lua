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
  local prep       = rwda.config.runewarden.prep_limbs or { "left_leg", "torso", "right_leg" }
  local tgt_limbs  = state.target.limbs or {}
  local near_break = rwda.config.runewarden.near_break_pct or 75

  -- Once any prep limb is already broken we are in the break-sequence phase.
  -- Follow the configured order for remaining unbroken limbs so the second
  -- and third breaks happen in the right order (left_leg → torso → right_leg).
  for _, limb in ipairs(prep) do
    if limbBroken(state.target, limb) then
      -- Sequence mode: return first unbroken limb in prep order.
      for _, l in ipairs(prep) do
        if not limbBroken(state.target, l) then
          return l
        end
      end
    end
  end

  -- Near-break endgame (no limb broken yet but one is close): also use
  -- sequence order so the first break is intentionally left_leg (causes prone).
  for _, limb in ipairs(prep) do
    if not limbBroken(state.target, limb) then
      local pct = (tgt_limbs[limb] and tgt_limbs[limb].damage_pct) or 0
      if pct >= near_break then
        for _, l in ipairs(prep) do
          if not limbBroken(state.target, l) then
            return l
          end
        end
      end
    end
  end

  -- Balanced phase: target the unbroken prep limb with the lowest damage_pct
  -- so all limbs approach the break threshold at roughly the same rate.
  local best, bestPct = nil, 999
  for _, limb in ipairs(prep) do
    if not limbBroken(state.target, limb) then
      local pct = (tgt_limbs[limb] and tgt_limbs[limb].damage_pct) or 0
      if pct < bestPct then
        best, bestPct = limb, pct
      end
    end
  end
  return best or prep[1] or "torso"
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

local function affScore(aff)
  if type(affstrack) ~= "table" then
    return 0
  end
  local ok, v = pcall(function()
    return affstrack.score and affstrack.score[aff] or 0
  end)
  return (ok and type(v) == "number") and v or 0
end

-- Returns two venoms for the next DSL tick.
--
-- Two-slot logic ported from the player's constDWC() function.
-- v1 (main cut) and v2 (off cut) have separate priority queues because
-- the afflictions they target serve different roles in the kill setup.
--
-- ak.check(aff, pct) equivalent: affScore(aff) >= pct
-- So "not ak.check(aff, pct)" → affScore(aff) < pct  → still needs dosing.
--
-- The "pressure" section (after core lock affs) is driven by
-- config.runewarden.venoms.kelp_cycle so rune presets can control which
-- kelp-cure venoms are prioritised each tick.

-- Venom → affliction map for configurable pressure portion.
local PRESSURE_AFF = {
  vernalius = "weariness",
  xentio    = "clumsiness",
  prefarar  = "sensitivity",
  euphorbia = "nausea",
  aconite   = "stupidity",
  larkspur  = "dizziness",
  kalmia    = "asthma",
}

local function pressureOrder()
  local cycle = rwda.config and rwda.config.runewarden
                and rwda.config.runewarden.venoms
                and rwda.config.runewarden.venoms.kelp_cycle
  if cycle and #cycle > 0 then
    local out = {}
    for _, v in ipairs(cycle) do
      local aff = PRESSURE_AFF[v]
      if aff then
        out[#out + 1] = { venom = v, aff = aff, thresh = 50 }
      end
    end
    if #out > 0 then return out end
  end
  -- Default fallback (preserves original behaviour when no cycle is set).
  return {
    { venom = "vernalius", aff = "weariness",   thresh = 50 },
    { venom = "xentio",    aff = "clumsiness",  thresh = 50 },
    { venom = "prefarar",  aff = "sensitivity", thresh = 50 },
    { venom = "euphorbia", aff = "nausea",      thresh = 50 },
    { venom = "aconite",   aff = "stupidity",   thresh = 50 },
  }
end

local function pickLockVenoms()
  local function need(aff, thresh)
    return affScore(aff) < (thresh or 100)
  end

  local function pickFrom(order, avoid)
    for _, entry in ipairs(order) do
      if entry.venom ~= avoid and need(entry.aff, entry.thresh) then
        return entry.venom
      end
    end
    return nil
  end

  local pressure = pressureOrder()

  -- ── v1: main cut ─────────────────────────────────────────────────────────
  -- Priority: asthma → slickness → anorexia → paralysis (core lock affs)
  -- then configurable kelp pressure cycle (weariness/clumsiness/sensitivity by default).
  local v1Core = {
    { venom = "kalmia", aff = "asthma",    thresh = 100 },
    { venom = "gecko",  aff = "slickness", thresh = 100 },
    { venom = "slike",  aff = "anorexia",  thresh = 100 },
    { venom = "curare", aff = "paralysis", thresh = 100 },
  }
  local v1Order = {}
  for _, e in ipairs(v1Core)    do v1Order[#v1Order + 1] = e end
  for _, e in ipairs(pressure)  do v1Order[#v1Order + 1] = e end
  local v1 = pickFrom(v1Order) or "eurypteria"  -- recklessness: always useful as filler

  -- ── v2: off cut ──────────────────────────────────────────────────────────
  -- Keep lock pressure on the off cut, then the same kelp pressure cycle.
  local v2Core = {
    { venom = "gecko",  aff = "slickness", thresh = 100 },
    { venom = "slike",  aff = "anorexia",  thresh = 100 },
    { venom = "curare", aff = "paralysis", thresh = 100 },
  }
  local v2Order = {}
  for _, e in ipairs(v2Core)   do v2Order[#v2Order + 1] = e end
  for _, e in ipairs(pressure) do v2Order[#v2Order + 1] = e end
  local v2 = pickFrom(v2Order, v1) or "larkspur"  -- dizziness: always useful as filler

  return v1, v2
end

local function humanContext(state)
  local targetImpaled  = state.target.impaled or state.target.affs.impaled
  local bothLegsBroken = limbBroken(state.target, "left_leg") and limbBroken(state.target, "right_leg")
  local goal = (state.flags.goal or "limbprep"):lower()
  local limb = planner.nextPrepLimb(state)
  local v1, v2 = pickLockVenoms()

  return {
    goal             = goal,
    target_impaled   = targetImpaled,
    both_legs_broken = bothLegsBroken,
    limb             = limb,
    v1               = v1,
    v2               = v2,
  }
end

local CURSE_THRESH = { impatience = 100, asthma = 34, paralysis = 100, stupidity = 50 }

local function dragonPickCurse()
  local order = (rwda.config and rwda.config.dragon and rwda.config.dragon.curse_priority)
                or { "impatience", "asthma", "paralysis", "stupidity" }
  for _, name in ipairs(order) do
    local thresh = CURSE_THRESH[name] or 100
    if affScore(name) < thresh then
      return name
    end
  end
  return order[1] or "impatience"
end

local VENOM_AFF = {
  curare  = "paralysis",
  kalmia  = "asthma",
  gecko   = "slickness",
  slike   = "anorexia",
  aconite = "stupidity",
}

local function dragonPickGutVenom(curse)
  local order = (rwda.config and rwda.config.dragon and rwda.config.dragon.gut_venom_priority)
                or { "curare", "kalmia", "gecko", "slike", "aconite" }
  for _, v in ipairs(order) do
    local aff = VENOM_AFF[v]
    if aff ~= curse and affScore(aff or v) < 100 then
      return v
    end
  end
  return order[1] or "curare"
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
  local curse = dragonPickCurse()
  return {
    goal = (state.flags.goal or "dragon_devour"):lower(),
    can_devour = planner.canDevour(state),
    devour_time = devourTime,
    pressure_limb = dragonPressureLimb(state),
    curse = curse,
    gut_venom = dragonPickGutVenom(curse),
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

  if id == "assess_target" then
    return action(
      "human_dualcut",
      "assess",
      { string.format("assess %s", target) },
      enrichReason("Refresh limb status from assess output.", "assess_target", profileName, id)
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

  -- ── Runelore blocks ───────────────────────────────────────────────────────
  -- bisect_window: instant-kill BISECT at ≤20% health.
  -- Requires hugalaz as core rune on an edged runeblade (config.runelore.bisect_enabled).
  -- Bypasses rebounding; does NOT require balance (freestand action).
  if id == "bisect_window" then
    local bisectEnabled = rwda.config.runelore and rwda.config.runelore.bisect_enabled
    if not bisectEnabled then
      return nil
    end
    return action(
      "human_dualcut",
      "bisect",
      { string.format("bisect %s", target) },
      enrichReason(
        "Target health ≤20% with hugalaz configured: BISECT for instant kill.",
        "bisect_window",
        profileName,
        id
      ),
      { queue_type = "freestand" }
    )
  end

  -- head_focus_dsl: dual-cut always targeting head with standard lock venoms.
  -- Maximises Pithakhan attunement (guaranteed proc on damaged head, Jul 2022)
  -- and Kena impatience delivery when target mana drops below 40% (Dec 2025).
  if id == "head_focus_dsl" then
    local cmd = string.format("dsl %s head %s %s", target, ctx.v1, ctx.v2)
    return action(
      "human_dualcut",
      "dsl",
      { cmd },
      enrichReason(
        "Head-focused dual-cut to maximise Pithakhan mana drain and Kena impatience rate.",
        "head_focus_dsl",
        profileName,
        id,
        { limb = "head", venoms = { ctx.v1, ctx.v2 } }
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

  if id == "dragon_shield_curse" then
    return action(
      "dragon_silver",
      "tailsmash",
      {
        { cmd = string.format("tailsmash %s", target),                   queue = "bal" },
        { cmd = string.format("dragoncurse %s %s 1", target, ctx.curse), queue = "eq" },
      },
      enrichReason(
        string.format("Shield up: tailsmash to strip then curse(%s) for pressure.", ctx.curse),
        "dragon_shield_curse", profileName, id, { curse = ctx.curse }
      ),
      { requires = { bal = true, eq = true } }
    )
  end

  if id == "dragon_lyred_blast" then
    return action(
      "dragon_silver",
      "blast",
      { string.format("blast %s", target) },
      enrichReason("Target lyred, apply blast pressure.", "dragon_lyred_blast", profileName, id)
    )
  end

  if id == "dragon_flying_becalm" then
    return action(
      "dragon_silver",
      "becalm",
      { "becalm" },
      enrichReason("Target airborne, becalm to ground them.", "dragon_flying_becalm", profileName, id)
    )
  end

  if id == "dragon_curse_gut" then
    return action(
      "dragon_silver",
      "gut",
      {
        { cmd = string.format("dragoncurse %s %s 1", target, ctx.curse), queue = "eq" },
        { cmd = string.format("gut %s %s", target, ctx.gut_venom),       queue = "bal" },
        { cmd = string.format("breathgust %s", target),                   queue = "eq" },
      },
      enrichReason(
        string.format("Curse(%s)+gut(%s)+breathgust combo.", ctx.curse, ctx.gut_venom),
        "dragon_curse_gut", profileName, id, { curse = ctx.curse, venom = ctx.gut_venom }
      ),
      { requires = { bal = true, eq = true } }
    )
  end

  if id == "dragon_bite" then
    return action(
      "dragon_silver",
      "bite",
      {
        { cmd = string.format("bite %s", target),       queue = "bal" },
        { cmd = string.format("breathgust %s", target), queue = "eq" },
      },
      enrichReason("Target prone, bite+breathgust for max damage.", "dragon_bite", profileName, id),
      { requires = { bal = true, eq = true } }
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
      "gut",
      {
        { cmd = string.format("dragoncurse %s %s 1", target, ctx.curse), queue = "eq" },
        { cmd = string.format("gut %s %s", target, ctx.gut_venom),       queue = "bal" },
        { cmd = string.format("breathgust %s", target),                   queue = "eq" },
      },
      enrichReason(
        string.format("Fallback curse(%s)+gut(%s)+breathgust.", ctx.curse, ctx.gut_venom),
        "dragon_curse_gut"
      ),
      { requires = { bal = true, eq = true } }
    )
  end

  if state.target.prone then
    return action(
      "dragon_silver",
      "bite",
      {
        { cmd = string.format("bite %s", target),       queue = "bal" },
        { cmd = string.format("breathgust %s", target), queue = "eq" },
      },
      enrichReason("Target prone, bite+breathgust fallback.", "dragon_bite"),
      { requires = { bal = true, eq = true } }
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

-- ─────────────────────────────────────────────────────────────────
-- Auto-goal escalation: adjusts state.flags.goal based on target
-- damage state so the correct strategy blocks fire automatically.
-- ─────────────────────────────────────────────────────────────────
function planner.autoGoal(state)
  if not (rwda.config and rwda.config.combat and rwda.config.combat.auto_goal ~= false) then
    return
  end

  local target = state.target
  if not target or not target.name then return end

  local mode = planner.resolveMode(state)

  if mode == "human_dualcut" then
    local bothLegs = limbBroken(target, "left_leg") and limbBroken(target, "right_leg")
    local impaled  = target.impaled or (target.affs and target.affs.impaled)
    local curGoal  = (state.flags.goal or "limbprep"):lower()

    if curGoal == "limbprep" and bothLegs then
      state.flags.goal = "impale_kill"
      rwda.util.log("info", "Auto-goal: both legs broken → impale_kill")
    elseif curGoal == "impale_kill" and not bothLegs and not impaled then
      state.flags.goal = "limbprep"
      rwda.util.log("info", "Auto-goal: legs recovered → limbprep")
    end
  end
  -- Dragon: blocks are condition-driven; no goal switching needed.
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

  planner.autoGoal(state)

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
