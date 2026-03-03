rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.doctor = rwda.engine.doctor or {}

local doctor = rwda.engine.doctor

local function countTable(tbl)
  if type(tbl) ~= "table" then
    return 0
  end
  local n = 0
  for _, _ in pairs(tbl) do
    n = n + 1
  end
  return n
end

local function yesNo(v)
  return v and "yes" or "no"
end

function doctor.collect()
  local report = {}
  local st = rwda.state or {}
  local legacy = rawget(_G, "Legacy")

  report.legacy = {
    present = type(legacy) == "table",
    has_curing = type(legacy) == "table" and type(legacy.Curing) == "table",
    version = type(legacy) == "table" and tostring(legacy.Version or "?") or "n/a",
  }

  report.backend = {
    legacy_present = st.integration and st.integration.legacy_present or false,
    gmcp_present = st.integration and st.integration.gmcp_present or false,
    aklimb_present = st.integration and st.integration.aklimb_present or false,
    group_present = st.integration and st.integration.group_present or false,
  }

  report.runtime = {
    enabled = st.flags and st.flags.enabled or false,
    stopped = st.flags and st.flags.stopped or false,
    target = st.target and st.target.name or "(none)",
    target_source = st.target and st.target.target_source or "-",
    target_available = st.target and st.target.available or false,
    target_reason = st.target and st.target.unavailable_reason or "-",
    bal = st.me and st.me.bal or false,
    eq = st.me and st.me.eq or false,
    form = st.me and st.me.form or "human",
  }

  report.handlers = {
    alias_present = rwda.ui and rwda.ui.commands and rwda.ui.commands._alias_id ~= nil or false,
    parser_count = rwda.engine and rwda.engine.parser and countTable(rwda.engine.parser._handler_ids) or 0,
    legacy_count = rwda.integrations and rwda.integrations.legacy and countTable(rwda.integrations.legacy._handler_ids) or 0,
    group_count = rwda.integrations and rwda.integrations.groupcombat and countTable(rwda.integrations.groupcombat._handler_ids) or 0,
    safety_present = rwda.engine and rwda.engine.executor and rwda.engine.executor._safety_handler_id ~= nil or false,
  }

  report.parser = {
    capture_unmatched = rwda.config and rwda.config.parser and rwda.config.parser.capture_unmatched_lines or false,
    capture_all = rwda.config and rwda.config.parser and rwda.config.parser.capture_all_lines or false,
    capture_path = rwda.config and rwda.config.parser and rwda.config.parser.capture_unmatched_path or "(default)",
  }

  local hudMod = rwda.ui and rwda.ui.hud or {}
  report.hud = {
    initialized = hudMod._initialized == true,
    visible     = hudMod._visible ~= false,
    polling     = hudMod._timerId ~= nil,
  }

  local assessCfg = rwda.config and rwda.config.combat or {}
  report.assess = {
    enabled     = assessCfg.assess_enabled ~= false,
    interval_ms = tonumber(assessCfg.assess_interval_ms) or 9000,
    stale_ms    = tonumber(assessCfg.assess_stale_ms) or 7000,
    last_assess = st.target and tonumber(st.target.last_assess) or 0,
  }

  local strategyCfg = rwda.config and rwda.config.strategy or {}
  report.strategy = {
    enabled = strategyCfg.enabled ~= false,
    version = tonumber(strategyCfg.version) or 0,
    active_profile = (st.flags and st.flags.profile) or strategyCfg.active_profile or "duel",
  }

  local retaliationStatus = rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.status and rwda.engine.retaliation.status() or {}
  report.retaliation = {
    enabled = retaliationStatus.enabled or false,
    locked = retaliationStatus.locked or false,
    locked_target = retaliationStatus.locked_target or "-",
    last_aggressor = retaliationStatus.last_aggressor or "-",
    last_reason = retaliationStatus.last_reason or "-",
  }

  local finisherStatus = rwda.engine and rwda.engine.finisher and rwda.engine.finisher.status and rwda.engine.finisher.status() or {}
  report.finisher = {
    enabled = finisherStatus.enabled or false,
    active = finisherStatus.active or false,
    attempt_name = finisherStatus.attempt_name or "-",
    attempt_mode = finisherStatus.attempt_mode or "-",
    fallback_active = finisherStatus.fallback_active or false,
    fallback_action = finisherStatus.fallback_action or "-",
    last_result = finisherStatus.last_result or "-",
    last_reason = finisherStatus.last_reason or "-",
  }

  local rlCfg = rwda.config and rwda.config.runelore or {}
  local rbState = rwda.state and rwda.state.runeblade and rwda.state.runeblade._state
  local rbCfg = rbState and rbState.configuration or {}
  local attuned = {}
  for runeName, att in pairs(rbState and rbState.attunement or {}) do
    if att.attuned then attuned[#attuned + 1] = runeName end
  end
  table.sort(attuned)
  report.runelore = {
    bootstrapped   = rbState ~= nil,
    core_rune      = rbCfg.core_rune or "none",
    config_runes   = table.concat(rbCfg.config_runes or {}, ","),
    empowered      = rbState and rbState.empowered or false,
    attuned_runes  = table.concat(attuned, ","),
    auto_empower   = rlCfg.auto_empower ~= false,
    bisect_enabled = rlCfg.bisect_enabled == true,
    kena_threshold = rlCfg.kena_mana_threshold or 0.40,
  }

  return report
end

function doctor.format(report)
  report = report or doctor.collect()
  local lines = {}

  lines[#lines + 1] = string.format(
    "doctor legacy_present=%s legacy_curing=%s legacy_version=%s backend=legacy:%s gmcp:%s ak:%s group:%s",
    yesNo(report.legacy.present),
    yesNo(report.legacy.has_curing),
    tostring(report.legacy.version),
    yesNo(report.backend.legacy_present),
    yesNo(report.backend.gmcp_present),
    yesNo(report.backend.aklimb_present),
    yesNo(report.backend.group_present)
  )

  lines[#lines + 1] = string.format(
    "doctor runtime enabled=%s stopped=%s form=%s target=%s tsrc=%s tavail=%s treason=%s bal=%s eq=%s",
    yesNo(report.runtime.enabled),
    yesNo(report.runtime.stopped),
    tostring(report.runtime.form),
    tostring(report.runtime.target),
    tostring(report.runtime.target_source),
    yesNo(report.runtime.target_available),
    tostring(report.runtime.target_reason),
    yesNo(report.runtime.bal),
    yesNo(report.runtime.eq)
  )

  lines[#lines + 1] = string.format(
    "doctor handlers alias=%s parser=%d legacy=%d group=%d safety=%s",
    yesNo(report.handlers.alias_present),
    tonumber(report.handlers.parser_count or 0),
    tonumber(report.handlers.legacy_count or 0),
    tonumber(report.handlers.group_count or 0),
    yesNo(report.handlers.safety_present)
  )

  lines[#lines + 1] = string.format(
    "doctor parser capture_unmatched=%s capture_all=%s capture_path=%s",
    yesNo(report.parser.capture_unmatched),
    yesNo(report.parser.capture_all),
    tostring(report.parser.capture_path)
  )

  lines[#lines + 1] = string.format(
    "doctor hud initialized=%s visible=%s polling=%s",
    yesNo(report.hud.initialized),
    yesNo(report.hud.visible),
    yesNo(report.hud.polling)
  )

  lines[#lines + 1] = string.format(
    "doctor assess enabled=%s interval_ms=%d stale_ms=%d last_assess=%d",
    yesNo(report.assess.enabled),
    tonumber(report.assess.interval_ms or 0),
    tonumber(report.assess.stale_ms or 0),
    tonumber(report.assess.last_assess or 0)
  )

  lines[#lines + 1] = string.format(
    "doctor strategy enabled=%s version=%s profile=%s",
    yesNo(report.strategy.enabled),
    tostring(report.strategy.version),
    tostring(report.strategy.active_profile)
  )

  lines[#lines + 1] = string.format(
    "doctor retaliation enabled=%s locked=%s target=%s last_aggressor=%s reason=%s",
    yesNo(report.retaliation.enabled),
    yesNo(report.retaliation.locked),
    tostring(report.retaliation.locked_target),
    tostring(report.retaliation.last_aggressor),
    tostring(report.retaliation.last_reason)
  )

  lines[#lines + 1] = string.format(
    "doctor finisher enabled=%s active=%s attempt=%s mode=%s fallback=%s fallback_action=%s last=%s reason=%s",
    yesNo(report.finisher.enabled),
    yesNo(report.finisher.active),
    tostring(report.finisher.attempt_name),
    tostring(report.finisher.attempt_mode),
    yesNo(report.finisher.fallback_active),
    tostring(report.finisher.fallback_action),
    tostring(report.finisher.last_result),
    tostring(report.finisher.last_reason)
  )

  if report.runelore then
    lines[#lines + 1] = string.format(
      "doctor runelore boot=%s core=%s config=%s empowered=%s attuned=%s auto_empower=%s bisect=%s kena_threshold=%.2f",
      yesNo(report.runelore.bootstrapped),
      tostring(report.runelore.core_rune),
      tostring(report.runelore.config_runes),
      yesNo(report.runelore.empowered),
      tostring(report.runelore.attuned_runes),
      yesNo(report.runelore.auto_empower),
      yesNo(report.runelore.bisect_enabled),
      tonumber(report.runelore.kena_threshold or 0.40)
    )
  end

  return lines
end

function doctor.run()
  local report = doctor.collect()
  return report, doctor.format(report)
end
