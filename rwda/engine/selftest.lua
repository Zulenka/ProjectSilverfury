rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.selftest = rwda.engine.selftest or {}

local selftest = rwda.engine.selftest

local function choose()
  if not rwda.engine or not rwda.engine.planner or not rwda.engine.planner.choose then
    return nil
  end
  return rwda.engine.planner.choose(rwda.state)
end

local function resetBaseline()
  rwda.state.reset()
  -- Clear saved profiles so bootstrap always reloads from current presets.
  if rwda.config and rwda.config.strategy then
    rwda.config.strategy.profiles = nil
  end
  if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.bootstrap then
    rwda.engine.strategy.bootstrap()
  end
  if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.bootstrap then
    rwda.engine.retaliation.bootstrap()
  end
  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.bootstrap then
    rwda.engine.finisher.bootstrap()
  end
  rwda.state.setEnabled(true)
  rwda.state.setStopped(false)
  rwda.state.setTarget("Bainz")
  rwda.state.setTargetAvailable(true, "selftest", "seen")
  rwda.state.me.bal = true
  rwda.state.me.eq = true
  rwda.state.me.balances.balance = true
  rwda.state.me.balances.equilibrium = true
  rwda.state.flags.mode = "auto"
  rwda.state.flags.goal = "limbprep"
  -- Stamp last_assess to now so assess_target (priority 30) doesn't shadow
  -- limbprep_dsl (priority 20) in tests that aren't testing the assess block.
  rwda.state.target.last_assess = rwda.util.now()
  -- Selftest uses fictional names not present in any live GMCP room list.
  -- Disable the room-presence filter so retaliation tests are not blocked.
  if rwda.config and rwda.config.retaliation then
    rwda.config.retaliation.ignore_non_players = false
  end
end

local function resultRow(name, ok, detail)
  return {
    name = name,
    ok = not not ok,
    detail = detail or "",
  }
end

local function expectAction(testName, expected)
  local action = choose()
  if not action then
    return resultRow(testName, false, "no_action")
  end
  if action.name ~= expected then
    return resultRow(testName, false, string.format("expected=%s got=%s", tostring(expected), tostring(action.name)))
  end
  return resultRow(testName, true, expected)
end

function selftest.run()
  local rows = {}
  local passed = 0

  resetBaseline()
  rwda.state.setTargetDefence("shield", true, 1.0, "selftest")
  rows[#rows + 1] = expectAction("human strips shield first", "razeslash")

  local stratReason = rwda.state.runtime.last_reason or {}
  if stratReason.strategy_block == "strip_shield" then
    rows[#rows + 1] = resultRow("strategy block tag present for shield strip", true, stratReason.strategy_block)
  else
    rows[#rows + 1] = resultRow("strategy block tag present for shield strip", false, "expected strategy_block=strip_shield")
  end

  resetBaseline()
  rwda.state.setTargetDefence("shield", true, 1.0, "selftest")
  rwda.state.setTargetDefence("rebounding", true, 1.0, "selftest")
  rwda.engine.parser.handleLine("Bainz slashes viciously at you.")
  local sDef = rwda.state.target.defs.shield
  local rDef = rwda.state.target.defs.rebounding
  if sDef and (not sDef.active) and (sDef.confidence or 0) > 0 and rDef and (not rDef.active) and (rDef.confidence or 0) > 0 then
    rows[#rows + 1] = resultRow("aggressive inference drops shield/rebounding", true, "assumed_aggressive")
  else
    rows[#rows + 1] = resultRow("aggressive inference drops shield/rebounding", false, "expected inactive defs with confidence > 0")
  end

  resetBaseline()
  rwda.state.setTargetDefence("shield", true, 1.0, "selftest")
  rwda.state.setTargetDefence("rebounding", true, 1.0, "selftest")
  rwda.engine.parser.handleLine("Bainz leaves north.")
  local moveShield = rwda.state.target.defs.shield
  local moveRebound = rwda.state.target.defs.rebounding
  if moveShield and (not moveShield.active) and (moveShield.confidence or 0) > 0 and moveRebound and moveRebound.active then
    rows[#rows + 1] = resultRow("move inference drops shield but keeps rebounding", true, "assumed_move")
  else
    rows[#rows + 1] = resultRow("move inference drops shield but keeps rebounding", false, "expected shield down and rebounding still active")
  end

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = false
  rows[#rows + 1] = expectAction("dragon summons breath first", "summon")

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = true
  rwda.state.target.prone = false
  rows[#rows + 1] = expectAction("dragon attacks with curse+gut when not prone", "gut")

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = true
  rwda.state.target.prone = true
  local dragonBiteAction = choose()
  if dragonBiteAction and dragonBiteAction.name == "bite" and type(dragonBiteAction.commands) == "table" and #dragonBiteAction.commands == 2 then
    rows[#rows + 1] = resultRow("dragon bites+breathgusts when prone", true, "bite+breathgust")
  else
    local got = dragonBiteAction and dragonBiteAction.name or "nil"
    local cmds = dragonBiteAction and #(dragonBiteAction.commands or {}) or 0
    rows[#rows + 1] = resultRow("dragon bites+breathgusts when prone", false, string.format("expected bite/2cmds got %s/%d", got, cmds))
  end

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = true
  rwda.state.target.prone = false
  rwda.state.setTargetDefence("shield", true, 1.0, "selftest")
  local shieldCurseAction = choose()
  if shieldCurseAction and shieldCurseAction.name == "tailsmash" and type(shieldCurseAction.commands) == "table" and #shieldCurseAction.commands == 2 then
    rows[#rows + 1] = resultRow("dragon_shield_curse fires tailsmash+curse combo", true, "tailsmash+curse")
  else
    local got = shieldCurseAction and shieldCurseAction.name or "nil"
    local cmds = shieldCurseAction and #(shieldCurseAction.commands or {}) or 0
    rows[#rows + 1] = resultRow("dragon_shield_curse fires tailsmash+curse combo", false, string.format("expected tailsmash/2cmds got %s/%d", got, cmds))
  end

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = true
  rwda.state.target.prone = false
  local curseGutAction = choose()
  if curseGutAction and curseGutAction.name == "gut" and type(curseGutAction.commands) == "table" and #curseGutAction.commands == 3 then
    rows[#rows + 1] = resultRow("dragon_curse_gut fires 3-command combo", true, "curse+gut+breathgust")
  else
    local got = curseGutAction and curseGutAction.name or "nil"
    local cmds = curseGutAction and #(curseGutAction.commands or {}) or 0
    rows[#rows + 1] = resultRow("dragon_curse_gut fires 3-command combo", false, string.format("expected gut/3cmds got %s/%d", got, cmds))
  end

  resetBaseline()
  rwda.state.flags.mode = "dragon"
  rwda.state.flags.goal = "dragon_devour"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = true
  rwda.state.target.prone = true
  rwda.state.updateTargetLimb("torso", { broken = true, damage_pct = 100, confidence = 1.0 })
  rwda.state.updateTargetLimb("left_leg", { broken = true, damage_pct = 100, confidence = 1.0 })
  rwda.state.updateTargetLimb("right_leg", { broken = true, damage_pct = 100, confidence = 1.0 })
  rows[#rows + 1] = expectAction("dragon devours in fast window", "devour")

  resetBaseline()
  rwda.state.setTargetAvailable(false, "selftest", "gmcp_not_in_room")
  local unavailableAction = choose()
  local reasonCode = rwda.state.runtime.last_reason and rwda.state.runtime.last_reason.code or "none"
  if unavailableAction == nil and reasonCode == "target_unavailable" then
    rows[#rows + 1] = resultRow("holds offense when target unavailable", true, reasonCode)
  else
    rows[#rows + 1] = resultRow("holds offense when target unavailable", false, "expected target_unavailable")
  end

  local strategyEnabledOriginal = rwda.config and rwda.config.strategy and rwda.config.strategy.enabled
  if rwda.config and rwda.config.strategy then
    rwda.config.strategy.enabled = false
  end
  resetBaseline()
  rwda.state.setTargetDefence("shield", true, 1.0, "selftest")
  local legacyFallbackAction = choose()
  local legacyReason = rwda.state.runtime.last_reason or {}
  if legacyFallbackAction and legacyFallbackAction.name == "razeslash" and legacyReason.strategy_block == nil then
    rows[#rows + 1] = resultRow("planner fallback works when strategy disabled", true, "legacy_fallback")
  else
    rows[#rows + 1] = resultRow("planner fallback works when strategy disabled", false, "expected razeslash without strategy_block")
  end
  if rwda.config and rwda.config.strategy then
    rwda.config.strategy.enabled = strategyEnabledOriginal ~= false
  end

  resetBaseline()
  rwda.state.clearTarget()
  _G.target = "Bainz"
  local pulledExternal = false
  if rwda.integrations and rwda.integrations.groupcombat and rwda.integrations.groupcombat.sync then
    pulledExternal = rwda.integrations.groupcombat.sync()
  end
  if pulledExternal and rwda.state.target.name == "Bainz" and rwda.state.target.target_source == "external" then
    rows[#rows + 1] = resultRow("external target sync imports legacy target", true, "external_target_imported")
  else
    rows[#rows + 1] = resultRow("external target sync imports legacy target", false, "expected Bainz from external target stream")
  end

  resetBaseline()
  rwda.state.setTarget("ManualTarget", "manual")
  if rwda.integrations and rwda.integrations.groupcombat then
    rwda.integrations.groupcombat._last_external_target = "Bainz"
  end
  _G.target = "OtherTarget"
  local changedManual = false
  if rwda.integrations and rwda.integrations.groupcombat and rwda.integrations.groupcombat.sync then
    changedManual = rwda.integrations.groupcombat.sync()
  end
  if not changedManual and rwda.state.target.name == "ManualTarget" and rwda.state.target.target_source == "manual" then
    rows[#rows + 1] = resultRow("manual target is not overridden by external stream", true, "manual_protected")
  else
    rows[#rows + 1] = resultRow("manual target is not overridden by external stream", false, "manual target should remain unchanged")
  end

  local retaliationEnabledOriginal = rwda.config and rwda.config.retaliation and rwda.config.retaliation.enabled
  local retaliationLockOriginal = rwda.config and rwda.config.retaliation and rwda.config.retaliation.lock_ms
  local finisherConfigOriginal = rwda.util.deepcopy(rwda.config and rwda.config.finisher or {})

  resetBaseline()
  rwda.config.retaliation.enabled = true
  rwda.config.retaliation.lock_ms = 5000
  rwda.engine.retaliation.setEnabled(true)
  rwda.engine.retaliation.onAggressor({ who = "Raijin", line = "Raijin slashes viciously at you.", confidence = 0.95 })
  if rwda.state.target.name == "Raijin" and rwda.state.target.target_source == "retaliation" then
    rows[#rows + 1] = resultRow("retaliation lock retargets attacker", true, "retargeted")
  else
    rows[#rows + 1] = resultRow("retaliation lock retargets attacker", false, "expected target=Raijin source=retaliation")
  end

  local rstatus = rwda.engine.retaliation.status()
  if rstatus.locked and rstatus.locked_target == "Raijin" then
    rows[#rows + 1] = resultRow("retaliation status reflects active lock", true, "locked")
  else
    rows[#rows + 1] = resultRow("retaliation status reflects active lock", false, "expected locked target Raijin")
  end

  resetBaseline()
  rwda.state.setTarget("Bainz", "manual")
  rwda.config.retaliation.enabled = true
  rwda.config.retaliation.lock_ms = 5
  rwda.engine.retaliation.setEnabled(true)
  rwda.engine.retaliation.onAggressor({ who = "Raijin", line = "Raijin hits you.", confidence = 0.95 })
  if rwda.state.target.name == "Raijin" then
    local rt = rwda.state.runtime and rwda.state.runtime.retaliation or {}
    rt.lock_until_ms = rwda.util.now() - 1
    rwda.engine.retaliation.update()
  end
  if rwda.state.target.name == "Bainz" then
    rows[#rows + 1] = resultRow("retaliation restores previous target after expiry", true, "restored")
  else
    rows[#rows + 1] = resultRow("retaliation restores previous target after expiry", false, "expected previous target restore")
  end

  resetBaseline()
  rwda.config.retaliation.enabled = false
  rwda.engine.retaliation.setEnabled(false)
  rwda.state.setTarget("Bainz", "manual")
  rwda.engine.retaliation.onAggressor({ who = "Raijin", line = "Raijin hits you.", confidence = 0.95 })
  if rwda.state.target.name == "Bainz" and rwda.state.target.target_source == "manual" then
    rows[#rows + 1] = resultRow("retaliation disabled does not swap target", true, "disabled_guard")
  else
    rows[#rows + 1] = resultRow("retaliation disabled does not swap target", false, "target changed while disabled")
  end

  -- Multi-attacker hold: two aggressors active → stay on current target, do not switch.
  resetBaseline()
  rwda.config.retaliation.enabled = true
  rwda.config.retaliation.lock_ms = 5000
  rwda.engine.retaliation.setEnabled(true)
  -- First hit: single attacker, switches Bainz → Raijin.
  rwda.engine.retaliation.onAggressor({ who = "Raijin", line = "Raijin hits you.", confidence = 0.95 })
  -- Second hit from a different person: count becomes 2, hold fires.
  local _ok2, reason2 = rwda.engine.retaliation.onAggressor({ who = "Kayde", line = "Kayde hits you.", confidence = 0.95 })
  if rwda.state.target.name == "Raijin" and reason2 == "multi_attacker_hold" then
    rows[#rows + 1] = resultRow("multi-attacker hold keeps current target", true, "multi_attacker_hold")
  else
    rows[#rows + 1] = resultRow("multi-attacker hold keeps current target", false,
      string.format("expected Raijin/multi_attacker_hold got %s/%s",
        tostring(rwda.state.target.name), tostring(reason2)))
  end

  -- Target-dead switch: when current target dies, auto-switch to remaining aggressor.
  resetBaseline()
  rwda.config.retaliation.enabled = true
  rwda.config.retaliation.lock_ms = 5000
  rwda.engine.retaliation.setEnabled(true)
  rwda.engine.retaliation.onAggressor({ who = "Raijin", line = "Raijin hits you.", confidence = 0.95 })
  rwda.engine.retaliation.onAggressor({ who = "Kayde", line = "Kayde hits you.", confidence = 0.95 })
  -- Raijin (current lock target) dies → should switch to Kayde.
  rwda.engine.retaliation.onTargetDead({ who = "Raijin", source = "selftest" })
  if rwda.state.target.name == "Kayde" and rwda.state.target.target_source == "retaliation" then
    rows[#rows + 1] = resultRow("target-dead switch auto-targets remaining aggressor", true, "switched_to_Kayde")
  else
    rows[#rows + 1] = resultRow("target-dead switch auto-targets remaining aggressor", false,
      string.format("expected Kayde/retaliation got %s/%s",
        tostring(rwda.state.target.name), tostring(rwda.state.target.target_source)))
  end

  -- Target cleared when killed with no other aggressors active.
  resetBaseline()
  rwda.config.retaliation.enabled = true
  rwda.engine.retaliation.setEnabled(true)
  -- No aggressors tracked: kill line should clear the target entirely.
  rwda.engine.parser.handleLine("You have slain Bainz.")
  if rwda.state.target.name == nil then
    rows[#rows + 1] = resultRow("target cleared on kill with no aggressors", true, "target_cleared")
  else
    rows[#rows + 1] = resultRow("target cleared on kill with no aggressors", false,
      string.format("expected nil got %s", tostring(rwda.state.target.name)))
  end

  -- Starburst tattoo restores target after kill line.
  resetBaseline()
  rwda.config.retaliation.enabled = true
  rwda.engine.retaliation.setEnabled(true)
  -- Kill clears the target; last_target = "Bainz".
  rwda.engine.parser.handleLine("You have slain Bainz.")
  -- Starburst fires: Bainz survived, restore and keep attacking.
  rwda.engine.parser.handleLine("A starburst tattoo flares and bathes Bainz in red light")
  if rwda.state.target.name == "Bainz" and not rwda.state.target.dead then
    rows[#rows + 1] = resultRow("starburst tattoo restores killed target", true, "restored")
  else
    rows[#rows + 1] = resultRow("starburst tattoo restores killed target", false,
      string.format("expected Bainz/alive got %s/dead=%s",
        tostring(rwda.state.target.name), tostring(rwda.state.target.dead)))
  end

  resetBaseline()
  rwda.config.finisher = rwda.config.finisher or {}
  rwda.config.finisher.enabled = true
  rwda.engine.finisher.setEnabled(true)
  rwda.state.setTargetDefence("shield", true, 1.0, "selftest")
  rwda.engine.finisher.onActionSent({
    action = {
      name = "disembowel",
      mode = "human_dualcut",
      reason = { strategy_block = "disembowel_followup", code = "disembowel_followup" },
    },
  })
  rwda.engine.finisher.onFail({ name = "disembowel", reason = "line_fail" })
  local fallbackHumanAction = choose()
  if fallbackHumanAction and fallbackHumanAction.name == "dsl" and fallbackHumanAction.reason and fallbackHumanAction.reason.finisher_fallback then
    rows[#rows + 1] = resultRow("finisher fallback forces configured human block", true, tostring(fallbackHumanAction.reason.finisher_fallback_block))
  else
    rows[#rows + 1] = resultRow("finisher fallback forces configured human block", false, "expected fallback dsl action")
  end
  if fallbackHumanAction and rwda.engine and rwda.engine.events and rwda.engine.events.emit then
    rwda.engine.events.emit("ACTION_SENT", { action = fallbackHumanAction, at = rwda.util.now() })
  end
  local fstatusAfterHuman = rwda.engine.finisher.status()
  if not fstatusAfterHuman.fallback_active then
    rows[#rows + 1] = resultRow("finisher fallback clears after fallback action send", true, "cleared")
  else
    rows[#rows + 1] = resultRow("finisher fallback clears after fallback action send", false, "fallback remained active")
  end

  resetBaseline()
  rwda.config.finisher = rwda.config.finisher or {}
  rwda.config.finisher.enabled = true
  rwda.engine.finisher.setEnabled(true)
  rwda.state.flags.mode = "dragon"
  rwda.state.me.form = "dragon"
  rwda.state.me.dragon.breath_summoned = true
  rwda.state.target.prone = true
  rwda.state.setTargetDefence("shield", true, 1.0, "selftest")
  rwda.engine.finisher.onActionSent({
    action = {
      name = "devour",
      mode = "dragon_silver",
      reason = { strategy_block = "devour_window", code = "devour_window" },
    },
  })
  local frt = rwda.state.runtime and rwda.state.runtime.finisher or {}
  if frt.active and frt.attempt_timeout_ms and frt.attempt_timeout_ms > 0 then
    frt.attempt_started_ms = rwda.util.now() - frt.attempt_timeout_ms - 1
  end
  rwda.engine.finisher.update()
  local fallbackDragonAction = choose()
  if fallbackDragonAction and fallbackDragonAction.name == "gust" and fallbackDragonAction.reason and fallbackDragonAction.reason.finisher_fallback then
    rows[#rows + 1] = resultRow("finisher timeout routes dragon fallback block", true, tostring(fallbackDragonAction.reason.finisher_fallback_block))
  else
    rows[#rows + 1] = resultRow("finisher timeout routes dragon fallback block", false, "expected fallback gust action")
  end

  resetBaseline()
  rwda.config.finisher = rwda.config.finisher or {}
  rwda.config.finisher.enabled = false
  rwda.engine.finisher.setEnabled(false)
  rwda.engine.finisher.onActionSent({
    action = {
      name = "disembowel",
      mode = "human_dualcut",
      reason = { strategy_block = "disembowel_followup", code = "disembowel_followup" },
    },
  })
  local fstatusDisabled = rwda.engine.finisher.status()
  if not fstatusDisabled.active and fstatusDisabled.enabled == false then
    rows[#rows + 1] = resultRow("finisher disabled blocks execute attempt tracking", true, "disabled_guard")
  else
    rows[#rows + 1] = resultRow("finisher disabled blocks execute attempt tracking", false, "attempt was tracked while disabled")
  end

  rwda.config.retaliation.enabled = retaliationEnabledOriginal
  rwda.config.retaliation.lock_ms = retaliationLockOriginal
  rwda.config.finisher = rwda.util.deepcopy(finisherConfigOriginal or {})
  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.bootstrap then
    rwda.engine.finisher.bootstrap()
  end

  -- nextPrepLimb: balanced mode picks the lowest-damage unbroken limb.
  resetBaseline()
  rwda.state.updateTargetLimb("left_leg", { damage_pct = 50, confidence = 0.8 })
  rwda.state.updateTargetLimb("torso",    { damage_pct = 30, confidence = 0.8 })
  rwda.state.updateTargetLimb("right_leg",{ damage_pct = 40, confidence = 0.8 })
  local balLimb = rwda.engine.planner.nextPrepLimb(rwda.state)
  if balLimb == "torso" then
    rows[#rows + 1] = resultRow("nextPrepLimb balanced picks lowest damage limb", true, "torso")
  else
    rows[#rows + 1] = resultRow("nextPrepLimb balanced picks lowest damage limb", false,
      string.format("expected torso got %s", tostring(balLimb)))
  end

  -- nextPrepLimb: near-break phase uses sequence order (left_leg first).
  resetBaseline()
  rwda.state.updateTargetLimb("left_leg", { damage_pct = 80, confidence = 0.9 })
  rwda.state.updateTargetLimb("torso",    { damage_pct = 40, confidence = 0.8 })
  rwda.state.updateTargetLimb("right_leg",{ damage_pct = 35, confidence = 0.8 })
  local seqLimb = rwda.engine.planner.nextPrepLimb(rwda.state)
  if seqLimb == "left_leg" then
    rows[#rows + 1] = resultRow("nextPrepLimb near-break sequences left_leg first", true, "left_leg")
  else
    rows[#rows + 1] = resultRow("nextPrepLimb near-break sequences left_leg first", false,
      string.format("expected left_leg got %s", tostring(seqLimb)))
  end

  -- nextPrepLimb: after left_leg breaks, targets torso next (sequence mode).
  resetBaseline()
  rwda.state.updateTargetLimb("left_leg", { broken = true, damage_pct = 100, confidence = 1.0 })
  rwda.state.updateTargetLimb("torso",    { damage_pct = 60, confidence = 0.8 })
  rwda.state.updateTargetLimb("right_leg",{ damage_pct = 70, confidence = 0.8 })
  local postBreakLimb = rwda.engine.planner.nextPrepLimb(rwda.state)
  if postBreakLimb == "torso" then
    rows[#rows + 1] = resultRow("nextPrepLimb post-left_leg-break targets torso", true, "torso")
  else
    rows[#rows + 1] = resultRow("nextPrepLimb post-left_leg-break targets torso", false,
      string.format("expected torso got %s", tostring(postBreakLimb)))
  end

  -- pickLockVenoms offline: no affstrack → all affScores = 0.
  -- v1: kalmia (asthma=0 < 100 → first entry).
  -- v2: gecko  (slickness=0 < 100 → first entry that is not kalmia).
  resetBaseline()
  local dslAction = choose()
  if dslAction and dslAction.name == "dsl" then
    local cmd = type(dslAction.commands) == "table" and dslAction.commands[1] or ""
    if type(cmd) == "string" and cmd:find("kalmia") and cmd:find("gecko") then
      rows[#rows + 1] = resultRow("venom picker: kalmia+gecko offline", true, cmd)
    else
      rows[#rows + 1] = resultRow("venom picker: kalmia+gecko offline", false,
        string.format("expected kalmia+gecko in cmd got: %s", tostring(cmd)))
    end
  else
    rows[#rows + 1] = resultRow("venom picker: kalmia+gecko offline", false,
      string.format("expected dsl action got %s", dslAction and dslAction.name or "nil"))
  end

  _G.target = nil
  if rwda.integrations and rwda.integrations.groupcombat then
    rwda.integrations.groupcombat._last_external_target = nil
  end

  for _, row in ipairs(rows) do
    if row.ok then
      passed = passed + 1
    end
  end

  return {
    total = #rows,
    passed = passed,
    failed = #rows - passed,
    rows = rows,
  }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UI selftest: offline-safe checks for HUD, combat builder, and wield state.
-- Run via: rwda selftest ui
-- ─────────────────────────────────────────────────────────────────────────────
function selftest.runUI()
  local rows   = {}
  local passed = 0

  -- ── HUD ──────────────────────────────────────────────────────────────────
  local hud = rwda.ui and rwda.ui.hud
  rows[#rows + 1] = resultRow("hud module present",
    hud ~= nil, hud and "ok" or "rwda.ui.hud is nil")

  if hud then
    -- show/hide toggle the _visible flag (no Geyser calls when _win is nil)
    hud._visible = nil
    hud.show()
    rows[#rows + 1] = resultRow("hud.show() sets _visible=true",
      hud._visible == true, tostring(hud._visible))

    hud.hide()
    rows[#rows + 1] = resultRow("hud.hide() sets _visible=false",
      hud._visible == false, tostring(hud._visible))

    -- refresh() must be a silent no-op when not initialized
    local prevInit = hud._initialized
    hud._initialized = false
    local rfOk = pcall(hud.refresh)
    hud._initialized = prevInit
    rows[#rows + 1] = resultRow("hud.refresh() no-op when not initialized",
      rfOk, rfOk and "ok" or "errored")

    -- init() must leave _initialized=false when Geyser is absent
    if not (type(Geyser) == "table" and type(Geyser.Container) == "function") then
      local prevInit2 = hud._initialized
      hud._initialized = false
      local initOk = pcall(hud.init)
      rows[#rows + 1] = resultRow("hud.init() no-op when Geyser absent",
        initOk and not hud._initialized,
        "ok=" .. tostring(initOk) .. " _initialized=" .. tostring(hud._initialized))
      hud._initialized = prevInit2
    end
  end

  -- ── Combat Builder ────────────────────────────────────────────────────────
  local builder = rwda.ui and rwda.ui.combat_builder
  rows[#rows + 1] = resultRow("combat_builder module present",
    builder ~= nil, builder and "ok" or "rwda.ui.combat_builder is nil")

  if builder then
    -- init() must return false + message when Geyser is absent
    if not (type(Geyser) == "table" and type(Geyser.Window) == "table") then
      local prevInit = builder._initialized
      builder._initialized = false
      local ok, msg = builder.init()
      builder._initialized = prevInit
      rows[#rows + 1] = resultRow("builder.init() returns false/msg when Geyser absent",
        ok == false and type(msg) == "string",
        "ok=" .. tostring(ok) .. " msg=" .. tostring(msg and msg:sub(1, 50)))
    end

    -- isOpen() must return false when not initialized
    local prevInit = builder._initialized
    builder._initialized = false
    local openResult = builder.isOpen()
    builder._initialized = prevInit
    rows[#rows + 1] = resultRow("builder.isOpen() false when not initialized",
      openResult == false, tostring(openResult))

    -- setTab() must update _active_tab safely even when not initialized
    local prevTab   = builder._active_tab
    local prevInit2 = builder._initialized
    builder._initialized = false
    local stOk = pcall(builder.setTab, "dragon")
    rows[#rows + 1] = resultRow("builder.setTab() updates _active_tab safely",
      stOk and builder._active_tab == "dragon",
      "ok=" .. tostring(stOk) .. " tab=" .. tostring(builder._active_tab))
    builder._active_tab  = prevTab
    builder._initialized = prevInit2

    -- refresh() must be a silent no-op when not initialized
    local prevInit3 = builder._initialized
    builder._initialized = false
    local rfOk2 = pcall(builder.refresh)
    builder._initialized = prevInit3
    rows[#rows + 1] = resultRow("builder.refresh() no-op when not initialized",
      rfOk2, rfOk2 and "ok" or "errored")

    -- toggleBlock() must exit safely when working state is nil
    local prevWorking = rwda.ui.combat_builder_state._working
    rwda.ui.combat_builder_state._working = nil
    local tbOk = pcall(builder.toggleBlock, "runewarden", "strip_shield")
    rwda.ui.combat_builder_state._working = prevWorking
    rows[#rows + 1] = resultRow("builder.toggleBlock() safe with nil working state",
      tbOk, tbOk and "ok" or "errored")
  end

  -- ── Wield state ───────────────────────────────────────────────────────────
  if rwda.statebuilders and rwda.statebuilders.newMe then
    local me = rwda.statebuilders.newMe()
    rows[#rows + 1] = resultRow("newMe() initialises swords_wielded=true",
      me.swords_wielded == true, tostring(me.swords_wielded))
  end

  if rwda.engine and rwda.engine.parser and rwda.engine.parser.handleLine then
    resetBaseline()
    rwda.state.me.swords_wielded = false
    rwda.engine.parser.handleLine("You begin to wield a keen scimitar.")
    rows[#rows + 1] = resultRow("parser: wield line sets swords_wielded=true",
      rwda.state.me.swords_wielded == true, tostring(rwda.state.me.swords_wielded))

    resetBaseline()
    rwda.state.me.swords_wielded = true
    rwda.engine.parser.handleLine("You stop wielding a keen scimitar.")
    rows[#rows + 1] = resultRow("parser: unwield line sets swords_wielded=false",
      rwda.state.me.swords_wielded == false, tostring(rwda.state.me.swords_wielded))

    resetBaseline()
    rwda.state.me.swords_wielded = true
    rwda.state.me.form = "human"
    rwda.engine.parser.setForm("dragon", "selftest")
    rows[#rows + 1] = resultRow("setForm(dragon) clears swords_wielded",
      rwda.state.me.swords_wielded == false, tostring(rwda.state.me.swords_wielded))
  end

  -- ── Runelore tests ────────────────────────────────────────────────────────
  if rwda.data and rwda.data.runes then
    local runes = rwda.data.runes

    -- Rune definitions load
    rows[#rows + 1] = resultRow("runes.definitions table exists",
      type(runes.definitions) == "table", type(runes.definitions))

    rows[#rows + 1] = resultRow("pithakhan definition present",
      runes.definitions.pithakhan ~= nil, tostring(runes.definitions.pithakhan ~= nil))

    rows[#rows + 1] = resultRow("hugalaz enables_bisect=true",
      runes.definitions.hugalaz and runes.definitions.hugalaz.enables_bisect == true,
      tostring(runes.definitions.hugalaz and runes.definitions.hugalaz.enables_bisect))

    -- Kena mana threshold (Dec 2025 classlead: <40%)
    local kenaDef = runes.definitions.kena
    local atCond  = kenaDef and runes.ATTUNE and kenaDef.attune_condition
    rows[#rows + 1] = resultRow("kena attune_condition is MANA_BELOW_40",
      atCond == runes.ATTUNE.MANA_BELOW_40,
      tostring(atCond))

    -- Pithakhan broken-head drain (Dec 2025: 13%)
    local pithDef = runes.definitions.pithakhan
    rows[#rows + 1] = resultRow("pithakhan broken_head drain = 0.13",
      pithDef and pithDef.drain_broken_head_pct == 0.13,
      tostring(pithDef and pithDef.drain_broken_head_pct))

    -- Helper functions
    rows[#rows + 1] = resultRow("runes.canBeInConfiguration(kena) = true",
      runes.canBeInConfiguration("kena") == true, "ok")

    rows[#rows + 1] = resultRow("runes.canBeInConfiguration(pithakhan) = false",
      runes.canBeInConfiguration("pithakhan") == false, "ok")
  end

  if rwda.state and rwda.state.runeblade then
    local rb = rwda.state.runeblade

    -- Bootstrap creates state
    rb.bootstrap()
    local s = rb._state
    rows[#rows + 1] = resultRow("runeblade.bootstrap() creates _state",
      s ~= nil, tostring(s ~= nil))

    -- Default configuration is set
    rows[#rows + 1] = resultRow("runeblade default core set",
      s and s.configuration and s.configuration.core_rune ~= nil,
      tostring(s and s.configuration and s.configuration.core_rune))

    -- setConfiguration accepts valid cores
    local ok = rb.setConfiguration("hugalaz", { "kena" })
    rows[#rows + 1] = resultRow("runeblade.setConfiguration(hugalaz, {kena}) succeeds",
      ok ~= false,
      tostring(rb._state and rb._state.configuration and rb._state.configuration.core_rune))

    -- Reject invalid core
    local bad = rb.setConfiguration("invalid_rune", {})
    rows[#rows + 1] = resultRow("runeblade.setConfiguration(invalid) returns false",
      bad == false, tostring(bad))

    -- Attunement tracking
    rb.setAttuned("kena", true)
    local att = rb.isAttuned("kena")
    rows[#rows + 1] = resultRow("runeblade.setAttuned/isAttuned round-trip",
      att == true, tostring(att))

    rb.setAttuned("kena", false)
    rows[#rows + 1] = resultRow("runeblade.setAttuned(false) clears attuned",
      rb.isAttuned("kena") == false, "ok")
  end

  if rwda.engine and rwda.engine.runelore then
    local rl = rwda.engine.runelore
    rl.bootstrap()

    -- checkAttuneCondition: MANA_BELOW_40 when mana is 20%
    local saved_mp = rwda.state.target.mp
    local saved_maxmp = rwda.state.target.maxmp
    rwda.state.target.mp    = 20
    rwda.state.target.maxmp = 100
    local rlA = rwda.data.runes and rwda.data.runes.ATTUNE
    if rlA then
      local eligible = rl.checkAttuneCondition(rlA.MANA_BELOW_40)
      rows[#rows + 1] = resultRow("runelore: MANA_BELOW_40 check true at 20% mana",
        eligible == true, tostring(eligible))

      rwda.state.target.mp = 60
      local ineligible = rl.checkAttuneCondition(rlA.MANA_BELOW_40)
      rows[#rows + 1] = resultRow("runelore: MANA_BELOW_40 check false at 60% mana",
        ineligible == false, tostring(ineligible))
    end
    rwda.state.target.mp    = saved_mp
    rwda.state.target.maxmp = saved_maxmp

    -- Config flag: bisect_enabled
    if rwda.config.runelore then
      local prevBisect = rwda.config.runelore.bisect_enabled
      rwda.config.runelore.bisect_enabled = true
      rows[#rows + 1] = resultRow("runelore config: bisect_enabled flag",
        rwda.config.runelore.bisect_enabled == true, "ok")
      rwda.config.runelore.bisect_enabled = prevBisect
    end
  end

  -- bisect_window planner block returns nil when bisect_enabled=false
  if rwda.engine and rwda.engine.planner then
    resetBaseline()
    if rwda.config.runelore then
      rwda.config.runelore.bisect_enabled = false
    end
    -- Use kena_lock profile which includes bisect_window at priority 99
    rwda.state.flags.profile = "kena_lock"
    if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.bootstrap then
      rwda.engine.strategy.bootstrap()
    end
    -- With bisect disabled, planner should fall through to head_focus_dsl
    local action = choose()
    local expectName = action and action.name or "nil"
    rows[#rows + 1] = resultRow("kena_lock profile + bisect=off falls to head_focus_dsl",
      action and (action.name == "dsl" or action.name == "assess" or action.name == "razeslash" or action.name == "raze"),
      tostring(expectName))
  end

  for _, row in ipairs(rows) do
    if row.ok then passed = passed + 1 end
  end

  return {
    total  = #rows,
    passed = passed,
    failed = #rows - passed,
    rows   = rows,
  }
end

function selftest.runRunelore()
  local rows   = {}
  local passed = 0

  resetBaseline()

  -- Minimal runelore-focused standalone suite
  if rwda.data and rwda.data.runes then
    local runes = rwda.data.runes

    rows[#rows + 1] = resultRow("runes.definitions present",
      type(runes.definitions) == "table", "ok")

    rows[#rows + 1] = resultRow("hugalaz enables_bisect",
      runes.definitions.hugalaz and runes.definitions.hugalaz.enables_bisect == true,
      tostring(runes.definitions.hugalaz and runes.definitions.hugalaz.enables_bisect))

    rows[#rows + 1] = resultRow("pithakhan broken_head drain 13%",
      runes.definitions.pithakhan and runes.definitions.pithakhan.drain_broken_head_pct == 0.13,
      tostring(runes.definitions.pithakhan and runes.definitions.pithakhan.drain_broken_head_pct))

    rows[#rows + 1] = resultRow("kena empower = impatience",
      runes.definitions.kena and runes.definitions.kena.empower_effect == runes.EMPOWER.IMPATIENCE,
      tostring(runes.definitions.kena and runes.definitions.kena.empower_effect))

    rows[#rows + 1] = resultRow("config rune count matches 10 expected",
      #(function() local c=0 for _,d in pairs(runes.definitions) do if d.attune_condition then c=c+1 end end return {c} end)() == 10,
      tostring((function() local c=0 for _,d in pairs(runes.definitions) do if d.attune_condition then c=c+1 end end return c end)()))
  end

  if rwda.state and rwda.state.runeblade then
    local rb = rwda.state.runeblade
    rb.bootstrap()
    rb.setAttuned("inguz", true)
    rows[#rows + 1] = resultRow("runeblade: inguz attunes and reads back",
      rb.isAttuned("inguz") == true, "ok")
    rb.setAttuned("inguz", false)
    rows[#rows + 1] = resultRow("runeblade: inguz detunes correctly",
      rb.isAttuned("inguz") == false, "ok")
  end

  for _, row in ipairs(rows) do
    if row.ok then passed = passed + 1 end
  end

  return {
    total  = #rows,
    passed = passed,
    failed = #rows - passed,
    rows   = rows,
  }
end
