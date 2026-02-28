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
    capture_path = rwda.config and rwda.config.parser and rwda.config.parser.capture_unmatched_path or "(default)",
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
    "doctor parser capture_unmatched=%s capture_path=%s",
    yesNo(report.parser.capture_unmatched),
    tostring(report.parser.capture_path)
  )

  return lines
end

function doctor.run()
  local report = doctor.collect()
  return report, doctor.format(report)
end
