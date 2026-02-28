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

  if type(echo) == "function" then
    echo("[RWDA] " .. message .. "\n")
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
  local mainVenom = cfg.runewarden and cfg.runewarden.venoms and cfg.runewarden.venoms.dsl_main and cfg.runewarden.venoms.dsl_main[1] or "curare"
  local offVenom = cfg.runewarden and cfg.runewarden.venoms and cfg.runewarden.venoms.dsl_off and cfg.runewarden.venoms.dsl_off[1] or "epteth"

  return string.format(
    "cfg breath=%s dsl=%s/%s autostart_legacy=%s prompttick=%s use_legacy=%s use_svof=%s",
    tostring(dragon.breath_type or "lightning"),
    tostring(mainVenom),
    tostring(offVenom),
    tostring(integration.auto_enable_with_legacy ~= false),
    tostring(combat.auto_tick_on_prompt == true),
    tostring(integration.use_legacy ~= false),
    tostring(integration.use_svof == true)
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
    return "0"
  end

  local target = s.target.name or "(none)"
  local backend = "none"
  if s.integration.legacy_present then
    backend = "legacy"
  elseif s.integration.svof_present then
    backend = "svof"
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

  return string.format(
    "enabled=%s stopped=%s backend=%s mode=%s goal=%s profile=%s form=%s target=%s tavail=%s treason=%s bal=%s eq=%s tshield=%s trebound=%s",
    tostring(s.flags.enabled),
    stopped,
    backend,
    mode,
    goal,
    profile,
    form,
    target,
    targetAvail,
    targetAvailReason,
    bal,
    eq,
    defStatus("shield"),
    defStatus("rebounding")
  )
end

function commands.printHelp()
  tell("Commands: rwda on|off|stop|resume|reload|status|explain|tick|selftest|target <name>|mode <auto|human|dragon>|goal <pressure|limbprep|impale_kill|dragon_devour>|profile <duel|group>|debug <on|off>|set breath <type>|set venoms <main> <off>|set autostart <on|off>|set prompttick <on|off>|show config|save config|load config|line <text>|replay <file>|clear target|reset")
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

    tell("Usage: rwda set breath <type> | set venoms <main> <off> | set autostart <on|off> | set prompttick <on|off>")
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
    local path = raw:match("^replay%s+(.+)$")
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
