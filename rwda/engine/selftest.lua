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
