rwda = rwda or {}
rwda.ui = rwda.ui or {}
rwda.ui.commands = rwda.ui.commands or {
  _alias_id = nil,
}

local commands = rwda.ui.commands

local function tell(message)
  if rwda.util then
    rwda.util.log("info", "%s", message)
    return
  end

  if type(cecho) == "function" then
    cecho("<silver>[RWDA] " .. tostring(message) .. "<reset>\n")
  elseif type(decho) == "function" then
    decho("<192,192,192>[RWDA] " .. tostring(message) .. "<r>\n")
  elseif type(echo) == "function" then
    echo("[RWDA] " .. tostring(message) .. "\n")
  end
end

local function splitWords(input)
  local out = {}
  for word in tostring(input or ""):gmatch("%S+") do
    out[#out + 1] = word
  end
  return out
end

local function trim(input)
  if type(input) ~= "string" then
    return ""
  end
  return input:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Resolve a file path: if relative (no drive letter or leading slash), prepend rwda.base_path.
local function resolvePath(path)
  if type(path) ~= "string" or path == "" then return path end
  -- Absolute: Windows drive letter or Unix root
  if path:match("^[A-Za-z]:[/\\]") or path:match("^/") then
    return path
  end
  local base = rwda and rwda.base_path or ""
  if base == "" then return path end
  -- Join with the separator already present in base_path, or default to backslash on Windows.
  local sep = base:match("[/\\]") or "\\"
  return base:gsub("[/\\]$", "") .. sep .. path
end

local function parseBoolWord(word)
  word = tostring(word or ""):lower()
  if word == "on" or word == "true" or word == "1" or word == "yes" then
    return true, true
  end
  if word == "off" or word == "false" or word == "0" or word == "no" then
    return true, false
  end
  return false, nil
end

local function formatCurrentConfig()
  local cfg = rwda.config or {}
  local dragon = cfg.dragon or {}
  local integration = cfg.integration or {}
  local combat = cfg.combat or {}
  local retaliation = cfg.retaliation or {}
  local finisher = cfg.finisher or {}
  local parser = cfg.parser or {}
  local mainVenom = cfg.runewarden and cfg.runewarden.venoms and cfg.runewarden.venoms.dsl_main and cfg.runewarden.venoms.dsl_main[1] or "curare"
  local offVenom = cfg.runewarden and cfg.runewarden.venoms and cfg.runewarden.venoms.dsl_off and cfg.runewarden.venoms.dsl_off[1] or "epteth"

  return string.format(
    "cfg breath=%s dsl=%s/%s autostart_legacy=%s follow_legacy_target=%s prompttick=%s retaliation=%s retalock=%sms execute=%s executecooldown=%sms use_legacy=%s capture_unmatched=%s",
    tostring(dragon.breath_type or "lightning"),
    tostring(mainVenom),
    tostring(offVenom),
    tostring(integration.auto_enable_with_legacy ~= false),
    tostring(integration.follow_legacy_target ~= false),
    tostring(combat.auto_tick_on_prompt == true),
    tostring(retaliation.enabled == true),
    tostring(retaliation.lock_ms or 8000),
    tostring(finisher.enabled ~= false),
    tostring(finisher.cooldown_ms or 1500),
    tostring(integration.use_legacy ~= false),
    tostring(parser.capture_unmatched_lines == true)
  )
end

function commands.statusText()
  local s = rwda.state
  local function defStatus(name)
    local d = s.target.defs and s.target.defs[name]
    if not d then
      return "0"
    end
    if d.active then
      return string.format("1(%.2f)", d.confidence or 1.0)
    end
    if d.confidence and d.confidence > 0 then
      return string.format("0(%.2f)", d.confidence)
    end
    return "0"
  end

  local target = s.target.name or "(none)"
  local targetSource = s.target.target_source or "-"
  local backend = "none"
  if s.integration.legacy_present then
    backend = "legacy"
  end
  local targetAvail = s.target.available and "yes" or "no"
  local targetAvailReason = s.target.unavailable_reason or "-"
  local mode = s.flags.mode or "auto"
  local goal = s.flags.goal or "limbprep"
  local profile = s.flags.profile or "duel"
  local form = s.me.form or "human"
  local bal = s.me.bal and "up" or "down"
  local eq = s.me.eq and "up" or "down"
  local stopped = s.flags.stopped and "yes" or "no"
  local finisherStatus = rwda.engine and rwda.engine.finisher and rwda.engine.finisher.status and rwda.engine.finisher.status() or {}
  local execEnabled = finisherStatus.enabled
  if execEnabled == nil then
    execEnabled = rwda.config and rwda.config.finisher and rwda.config.finisher.enabled ~= false
  end
  local execActive = finisherStatus.active == true and "yes" or "no"
  local execFallback = finisherStatus.fallback_active == true and "yes" or "no"

  return string.format(
    "enabled=%s stopped=%s backend=%s mode=%s goal=%s profile=%s form=%s target=%s tsrc=%s tavail=%s treason=%s bal=%s eq=%s tshield=%s trebound=%s execute=%s eactive=%s efallback=%s",
    tostring(s.flags.enabled),
    stopped,
    backend,
    mode,
    goal,
    profile,
    form,
    target,
    targetSource,
    targetAvail,
    targetAvailReason,
    bal,
    eq,
    defStatus("shield"),
    defStatus("rebounding"),
    tostring(execEnabled),
    execActive,
    execFallback
  )
end

function commands.printHelp()
  tell("Commands: rwda on|off|stop|resume|reload|status|doctor|explain|tick|selftest|target <name>|mode <auto|human|dragon>|goal <pressure|limbprep|impale_kill|dragon_devour>|profile <duel|group>|debug <on|off>|retaliate <on|off>|execute <on|off>|builder open|close|strategy show|apply|save|load|set breath <type>|set venoms <main> <off>|set autostart <on|off>|set followlegacytarget <on|off>|set prompttick <on|off>|set retalockms <ms>|set retaldebounce <ms>|set retalminconf <0-1>|set executecooldown <ms>|set executefallbackwindow <ms>|set executetimeout <disembowel|devour> <ms>|set executefallback <human|dragon> <block_id>|set capture <on|off>|set captureprompts <on|off>|set capturepath <path>|show config|save config|load config|line <text>|replay <file>|replayassert <file> <expected_last_action> [min_actions]|replaysuite <suite_file>|clear target|reset")
end

function commands.handle(raw)
  raw = (raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if raw == "" then
    commands.printHelp()
    return
  end

  local words = splitWords(raw)
  local sub = (words[1] or ""):lower()

  if sub == "on" then
    rwda.enable()
    return
  end

  if sub == "off" then
    rwda.disable()
    return
  end

  if sub == "stop" then
    rwda.stop()
    return
  end

  if sub == "resume" then
    rwda.resume()
    return
  end

  if sub == "reload" then
    if rwda.reload then
      local ok, err = pcall(rwda.reload)
      if ok then
        tell("RWDA reloaded.")
      else
        tell("Reload failed: " .. tostring(err))
      end
    else
      tell("Reload unavailable.")
    end
    return
  end

  if sub == "status" then
    tell(commands.statusText())
    return
  end

  if sub == "explain" then
    local reason = rwda.state.runtime.last_reason
    if reason then
      tell(string.format("last_action=%s (%s)", reason.summary or "no summary", reason.code or "no code"))
    else
      tell("No action reason recorded yet.")
    end
    return
  end

  if sub == "doctor" then
    if not rwda.engine or not rwda.engine.doctor or not rwda.engine.doctor.run then
      tell("Doctor module not loaded.")
      return
    end

    local _, lines = rwda.engine.doctor.run()
    for _, line in ipairs(lines or {}) do
      tell(line)
    end
    return
  end

  if sub == "tick" or sub == "attack" then
    local action = rwda.tick("manual")
    if action then
      tell(string.format("planned=%s", action.name or "unknown"))
    else
      tell("No action planned.")
    end
    return
  end

  if sub == "selftest" then
    if not rwda.engine or not rwda.engine.selftest or not rwda.engine.selftest.run then
      tell("Selftest module not loaded.")
      return
    end

    local report = rwda.engine.selftest.run()
    tell(string.format("selftest passed=%d failed=%d total=%d", report.passed, report.failed, report.total))
    for _, row in ipairs(report.rows or {}) do
      tell(string.format("selftest %s: %s (%s)", row.ok and "ok" or "fail", tostring(row.name), tostring(row.detail)))
    end
    return
  end

  if sub == "target" then
    local target = raw:match("^target%s+(.+)$")
    target = trim(target)
    if target and target ~= "" then
      rwda.setTarget(target)
      tell("Target set to " .. target)
    else
      tell("Usage: rwda target <name>")
    end
    return
  end

  if sub == "clear" and (words[2] or ""):lower() == "target" then
    rwda.state.clearTarget()
    tell("Target state cleared.")
    return
  end

  if sub == "mode" then
    local mode = (words[2] or ""):lower()
    if mode == "auto" or mode == "human" or mode == "dragon" then
      rwda.state.setMode(mode)
      tell("Mode set to " .. mode)
    else
      tell("Usage: rwda mode <auto|human|dragon>")
    end
    return
  end

  if sub == "goal" then
    local goal = (words[2] or ""):lower()
    if goal == "pressure" or goal == "limbprep" or goal == "impale_kill" or goal == "dragon_devour" then
      rwda.state.setGoal(goal)
      tell("Goal set to " .. goal)
    else
      tell("Usage: rwda goal <pressure|limbprep|impale_kill|dragon_devour>")
    end
    return
  end

  if sub == "profile" then
    local profile = (words[2] or ""):lower()
    local profileCfg = rwda.config.profiles and rwda.config.profiles[profile]
    if profileCfg then
      rwda.state.flags.profile = profile
      rwda.config.strategy = rwda.config.strategy or {}
      rwda.config.strategy.active_profile = profile
      if profileCfg.mode then
        rwda.state.setMode(profileCfg.mode)
      end
      if profileCfg.goal then
        rwda.state.setGoal(profileCfg.goal)
      end
      tell(string.format("Profile set to %s (mode=%s goal=%s)", profile, rwda.state.flags.mode, rwda.state.flags.goal))
    else
      tell("Usage: rwda profile <duel|group>")
    end
    return
  end

  if sub == "debug" then
    local v = (words[2] or ""):lower()
    rwda.state.flags.debug = (v == "on" or v == "1" or v == "true")
    tell("Debug set to " .. tostring(rwda.state.flags.debug))
    return
  end

  if sub == "retaliate" then
    local ok, value = parseBoolWord(words[2])
    if not ok then
      tell("Usage: rwda retaliate <on|off>")
      return
    end

    rwda.config.retaliation = rwda.config.retaliation or {}
    rwda.config.retaliation.enabled = value
    if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.setEnabled then
      rwda.engine.retaliation.setEnabled(value)
    end
    tell("Retaliation set to " .. tostring(value))
    return
  end

  if sub == "execute" then
    local ok, value = parseBoolWord(words[2])
    if not ok then
      tell("Usage: rwda execute <on|off>")
      return
    end

    rwda.config.finisher = rwda.config.finisher or {}
    rwda.config.finisher.enabled = value
    if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.setEnabled then
      rwda.engine.finisher.setEnabled(value)
    end
    tell("Execute automation set to " .. tostring(value))
    return
  end

  if sub == "builder" then
    local action = (words[2] or ""):lower()
    if action == "open" then
      if rwda.ui and rwda.ui.combat_builder and rwda.ui.combat_builder.open then
        local pok, v1, v2 = pcall(rwda.ui.combat_builder.open)
        if not pok then
          tell("Combat builder error: " .. tostring(v1))
        elseif v1 == false then
          tell("Combat builder open failed: " .. tostring(v2))
        end
      else
        tell("Combat builder not loaded.")
      end
    elseif action == "close" then
      if rwda.ui and rwda.ui.combat_builder and rwda.ui.combat_builder.close then
        pcall(rwda.ui.combat_builder.close)
      else
        tell("Combat builder not loaded.")
      end
    else
      tell("Usage: rwda builder open|close")
    end
    return
  end

  if sub == "strategy" then
    local action = (words[2] or ""):lower()
    if action == "show" then
      if not (rwda.ui and rwda.ui.combat_builder_state and rwda.ui.combat_builder_state.summaryLines) then
        tell("Strategy module not loaded.")
        return
      end
      local lines = rwda.ui.combat_builder_state.summaryLines(false)
      for _, line in ipairs(lines or {}) do
        tell(line)
      end
    elseif action == "apply" then
      if not (rwda.ui and rwda.ui.combat_builder_state) then
        tell("Strategy module not loaded.")
        return
      end
      local state = rwda.ui.combat_builder_state
      if not state.isOpen() then state.open() end
      local ok, err = state.apply()
      if ok then
        tell("Strategy applied.")
      else
        tell("Apply failed: " .. tostring(err))
      end
    elseif action == "save" then
      if not (rwda.ui and rwda.ui.combat_builder_state) then
        tell("Strategy module not loaded.")
        return
      end
      local state = rwda.ui.combat_builder_state
      if not state.isOpen() then state.open() end
      local ok, err = state.apply()
      if not ok then
        tell("Apply failed: " .. tostring(err))
        return
      end
      if rwda.config and rwda.config.savePersisted then
        local saveOk, result = rwda.config.savePersisted()
        if saveOk then
          tell("Strategy saved to " .. tostring(result))
        else
          tell("Save failed: " .. tostring(result))
        end
      else
        tell("Config persistence unavailable.")
      end
    elseif action == "load" then
      if rwda.config and rwda.config.loadPersisted then
        local ok, result = rwda.config.loadPersisted()
        if not ok then
          tell("Load failed: " .. tostring(result))
          return
        end
        if rwda.applyConfigToState then
          rwda.applyConfigToState()
        end
        tell("Strategy loaded from " .. tostring(result))
      else
        tell("Config persistence unavailable.")
      end
    else
      tell("Usage: rwda strategy show|apply|save|load")
    end
    return
  end

  if sub == "set" then
    local key = (words[2] or ""):lower()
    if key == "breath" then
      local breath = trim(raw:match("^set%s+breath%s+(.+)$"))
      if breath == "" then
        tell("Usage: rwda set breath <type>")
        return
      end
      rwda.config.dragon = rwda.config.dragon or {}
      rwda.config.dragon.breath_type = breath
      tell("Breath type set to " .. breath)
      return
    end

    if key == "venoms" then
      local main = trim(words[3] or "")
      local off = trim(words[4] or "")
      if main == "" or off == "" then
        tell("Usage: rwda set venoms <main> <off>")
        return
      end

      rwda.config.runewarden = rwda.config.runewarden or {}
      rwda.config.runewarden.venoms = rwda.config.runewarden.venoms or {}
      rwda.config.runewarden.venoms.dsl_main = rwda.config.runewarden.venoms.dsl_main or {}
      rwda.config.runewarden.venoms.dsl_off = rwda.config.runewarden.venoms.dsl_off or {}
      rwda.config.runewarden.venoms.dsl_main[1] = main
      rwda.config.runewarden.venoms.dsl_off[1] = off
      tell(string.format("DSL venoms set to %s/%s", main, off))
      return
    end

    if key == "autostart" then
      local ok, value = parseBoolWord(words[3])
      if not ok then
        tell("Usage: rwda set autostart <on|off>")
        return
      end
      rwda.config.integration = rwda.config.integration or {}
      rwda.config.integration.auto_enable_with_legacy = value
      tell("Legacy autostart set to " .. tostring(value))
      return
    end

    if key == "followlegacytarget" then
      local ok, value = parseBoolWord(words[3])
      if not ok then
        tell("Usage: rwda set followlegacytarget <on|off>")
        return
      end
      rwda.config.integration = rwda.config.integration or {}
      rwda.config.integration.follow_legacy_target = value
      tell("Legacy target-follow set to " .. tostring(value))
      return
    end

    if key == "prompttick" then
      local ok, value = parseBoolWord(words[3])
      if not ok then
        tell("Usage: rwda set prompttick <on|off>")
        return
      end
      rwda.config.combat = rwda.config.combat or {}
      rwda.config.combat.auto_tick_on_prompt = value
      tell("Prompt auto-tick set to " .. tostring(value))
      return
    end

    if key == "retalockms" then
      local value = tonumber(words[3] or "")
      if not value or value < 0 then
        tell("Usage: rwda set retalockms <ms>")
        return
      end
      rwda.config.retaliation = rwda.config.retaliation or {}
      rwda.config.retaliation.lock_ms = math.floor(value)
      tell("Retaliation lock_ms set to " .. tostring(rwda.config.retaliation.lock_ms))
      return
    end

    if key == "retaldebounce" then
      local value = tonumber(words[3] or "")
      if not value or value < 0 then
        tell("Usage: rwda set retaldebounce <ms>")
        return
      end
      rwda.config.retaliation = rwda.config.retaliation or {}
      rwda.config.retaliation.swap_debounce_ms = math.floor(value)
      tell("Retaliation swap_debounce_ms set to " .. tostring(rwda.config.retaliation.swap_debounce_ms))
      return
    end

    if key == "retalminconf" then
      local value = tonumber(words[3] or "")
      if not value or value < 0 or value > 1 then
        tell("Usage: rwda set retalminconf <0-1>")
        return
      end
      rwda.config.retaliation = rwda.config.retaliation or {}
      rwda.config.retaliation.min_confidence = value
      tell("Retaliation min_confidence set to " .. tostring(value))
      return
    end

    if key == "executecooldown" then
      local value = tonumber(words[3] or "")
      if not value or value < 0 then
        tell("Usage: rwda set executecooldown <ms>")
        return
      end
      rwda.config.finisher = rwda.config.finisher or {}
      rwda.config.finisher.cooldown_ms = math.floor(value)
      tell("Execute cooldown_ms set to " .. tostring(rwda.config.finisher.cooldown_ms))
      return
    end

    if key == "executefallbackwindow" then
      local value = tonumber(words[3] or "")
      if not value or value < 0 then
        tell("Usage: rwda set executefallbackwindow <ms>")
        return
      end
      rwda.config.finisher = rwda.config.finisher or {}
      rwda.config.finisher.fallback_window_ms = math.floor(value)
      tell("Execute fallback_window_ms set to " .. tostring(rwda.config.finisher.fallback_window_ms))
      return
    end

    if key == "executetimeout" then
      local actionName = tostring(words[3] or ""):lower()
      local value = tonumber(words[4] or "")
      if (actionName ~= "disembowel" and actionName ~= "devour") or not value or value < 0 then
        tell("Usage: rwda set executetimeout <disembowel|devour> <ms>")
        return
      end
      rwda.config.finisher = rwda.config.finisher or {}
      rwda.config.finisher.timeouts = rwda.config.finisher.timeouts or {}
      rwda.config.finisher.timeouts[actionName .. "_ms"] = math.floor(value)
      tell(string.format("Execute timeout for %s set to %s", actionName, tostring(rwda.config.finisher.timeouts[actionName .. "_ms"])))
      return
    end

    if key == "executefallback" then
      local modeWord = tostring(words[3] or ""):lower()
      local blockId = trim(raw:match("^set%s+executefallback%s+%S+%s+(.+)$"))
      if blockId == "" then
        tell("Usage: rwda set executefallback <human|dragon> <block_id>")
        return
      end

      local mode
      if modeWord == "human" or modeWord == "runewarden" then
        mode = "human_dualcut"
      elseif modeWord == "dragon" then
        mode = "dragon_silver"
      else
        tell("Usage: rwda set executefallback <human|dragon> <block_id>")
        return
      end

      rwda.config.finisher = rwda.config.finisher or {}
      rwda.config.finisher.fallback_blocks = rwda.config.finisher.fallback_blocks or {}
      if blockId == "none" or blockId == "off" then
        rwda.config.finisher.fallback_blocks[mode] = nil
      else
        rwda.config.finisher.fallback_blocks[mode] = blockId
      end
      tell(string.format("Execute fallback block for %s set to %s", mode, tostring(rwda.config.finisher.fallback_blocks[mode] or "none")))
      return
    end

    if key == "capture" then
      local ok, value = parseBoolWord(words[3])
      if not ok then
        tell("Usage: rwda set capture <on|off>")
        return
      end
      rwda.config.parser = rwda.config.parser or {}
      rwda.config.parser.capture_unmatched_lines = value
      tell("Capture unmatched lines set to " .. tostring(value))
      return
    end

    if key == "captureprompts" then
      local ok, value = parseBoolWord(words[3])
      if not ok then
        tell("Usage: rwda set captureprompts <on|off>")
        return
      end
      rwda.config.parser = rwda.config.parser or {}
      rwda.config.parser.capture_unmatched_include_prompts = value
      tell("Capture prompts set to " .. tostring(value))
      return
    end

    if key == "capturepath" then
      local path = trim(raw:match("^set%s+capturepath%s+(.+)$"))
      if path == "" then
        tell("Usage: rwda set capturepath <path>")
        return
      end
      rwda.config.parser = rwda.config.parser or {}
      rwda.config.parser.capture_unmatched_path = path
      tell("Capture path set to " .. path)
      return
    end

    tell("Usage: rwda set breath <type> | set venoms <main> <off> | set autostart <on|off> | set followlegacytarget <on|off> | set prompttick <on|off> | set retalockms <ms> | set retaldebounce <ms> | set retalminconf <0-1> | set executecooldown <ms> | set executefallbackwindow <ms> | set executetimeout <disembowel|devour> <ms> | set executefallback <human|dragon> <block_id> | set capture <on|off> | set captureprompts <on|off> | set capturepath <path>")
    return
  end

  if sub == "show" and (words[2] or ""):lower() == "config" then
    tell(formatCurrentConfig())
    return
  end

  if sub == "save" and (words[2] or ""):lower() == "config" then
    if not rwda.config or not rwda.config.savePersisted then
      tell("Config persistence unavailable.")
      return
    end

    local ok, result = rwda.config.savePersisted()
    if ok then
      tell("Config saved to " .. tostring(result))
    else
      tell("Save failed: " .. tostring(result))
    end
    return
  end

  if sub == "load" and (words[2] or ""):lower() == "config" then
    if not rwda.config or not rwda.config.loadPersisted then
      tell("Config persistence unavailable.")
      return
    end

    local ok, result = rwda.config.loadPersisted()
    if not ok then
      tell("Load failed: " .. tostring(result))
      return
    end

    if rwda.applyConfigToState then
      rwda.applyConfigToState()
    end
    tell("Config loaded from " .. tostring(result))
    return
  end

  if sub == "line" then
    local text = raw:match("^line%s+(.+)$")
    if text and text ~= "" then
      rwda.engine.parser.handleLine(text)
      tell("Line parsed.")
    else
      tell("Usage: rwda line <raw combat line>")
    end
    return
  end

  if sub == "replay" then
    local path = resolvePath(raw:match("^replay%s+(.+)$"))
    if not path or path == "" then
      tell("Usage: rwda replay <path-to-log-file>")
      return
    end

    if not rwda.engine or not rwda.engine.replay then
      tell("Replay module not loaded.")
      return
    end

    local result, err = rwda.engine.replay.runFile(path, {
      auto_tick = rwda.config.replay and rwda.config.replay.auto_tick,
      prompt_pattern = rwda.config.replay and rwda.config.replay.prompt_pattern,
    })

    if not result then
      tell("Replay failed: " .. tostring(err))
      return
    end

    tell(string.format(
      "Replay done: lines=%d prompts=%d actions=%d last_action=%s",
      result.lines,
      result.prompts,
      result.actions,
      tostring(result.last_action or "nil")
    ))
    return
  end

  if sub == "replayassert" then
    local path, expectedAction, minActions = raw:match("^replayassert%s+(.+)%s+(%S+)%s+(%d+)$")
    if not path then
      path, expectedAction = raw:match("^replayassert%s+(.+)%s+(%S+)$")
    end

    path = resolvePath(trim(path))
    if path == "" or not expectedAction or expectedAction == "" then
      tell("Usage: rwda replayassert <path-to-log-file> <expected_last_action> [min_actions]")
      return
    end

    if not rwda.engine or not rwda.engine.replay or not rwda.engine.replay.runFileWithAssertions then
      tell("Replay module not loaded.")
      return
    end

    local result, err = rwda.engine.replay.runFileWithAssertions(path, {
      auto_tick = rwda.config.replay and rwda.config.replay.auto_tick,
      prompt_pattern = rwda.config.replay and rwda.config.replay.prompt_pattern,
      assertions = {
        expected_last_action = expectedAction,
        min_actions = tonumber(minActions),
      },
    })

    if not result then
      tell("Replay assertion failed to run: " .. tostring(err))
      return
    end

    if result.assertions_ok then
      tell(string.format("Replay assertion PASSED: last_action=%s actions=%d prompts=%d", tostring(result.last_action), tonumber(result.actions or 0), tonumber(result.prompts or 0)))
    else
      tell(string.format("Replay assertion FAILED: last_action=%s actions=%d prompts=%d", tostring(result.last_action), tonumber(result.actions or 0), tonumber(result.prompts or 0)))
      for _, msg in ipairs(result.assertion_failures or {}) do
        tell("assert: " .. tostring(msg))
      end
    end
    return
  end

  if sub == "replaysuite" then
    local suitePath = resolvePath(trim(raw:match("^replaysuite%s+(.+)$")))
    if suitePath == "" then
      tell("Usage: rwda replaysuite <path-to-suite-file>")
      return
    end

    if not rwda.engine or not rwda.engine.replay or not rwda.engine.replay.runSuite then
      tell("Replay module not loaded.")
      return
    end

    local summary, err = rwda.engine.replay.runSuite(suitePath)
    if not summary then
      tell("Replay suite failed: " .. tostring(err))
      return
    end

    tell(string.format("Replay suite: passed=%d failed=%d total=%d", tonumber(summary.passed or 0), tonumber(summary.failed or 0), tonumber(summary.total or 0)))
    for _, row in ipairs(summary.cases or {}) do
      tell(string.format("suite %s: %s (%s)", row.passed and "ok" or "fail", tostring(row.name), tostring(row.detail)))
    end
    return
  end

  if sub == "reset" then
    rwda.state.reset()
    rwda.state.flags.profile = rwda.config.combat.profile or "duel"
    rwda.state.flags.mode = rwda.config.combat.mode or "auto"
    rwda.state.flags.goal = rwda.config.combat.goal or "limbprep"
    tell("RWDA state reset.")
    return
  end

  if sub == "queue" and (words[2] or ""):lower() == "clear" then
    if rwda.engine and rwda.engine.queue then
      rwda.engine.queue.clear("all")
      tell("Server queue cleared.")
    end
    return
  end

  commands.printHelp()
end

function commands.registerAlias()
  if commands._alias_id or type(tempAlias) ~= "function" then
    return false
  end

  commands._alias_id = tempAlias("^rwda(?:\\s+(.+))?$", [[rwda.ui.commands.handle(matches[2] or "")]])
  return true
end

function commands.unregisterAlias()
  if not commands._alias_id or type(killAlias) ~= "function" then
    return false
  end

  pcall(killAlias, commands._alias_id)
  commands._alias_id = nil
  return true
end
