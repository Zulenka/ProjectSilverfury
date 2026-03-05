rwda = rwda or {}
rwda.config = rwda.config or {}

local config = rwda.config

local function setDefault(tbl, key, value)
  if tbl[key] == nil then
    tbl[key] = value
  end
end

local function normalizePath(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  return path:gsub("/", "\\")
end

local function defaultPersistPath()
  if type(getMudletHomeDir) == "function" then
    local ok, home = pcall(getMudletHomeDir)
    if ok and type(home) == "string" and home ~= "" then
      return normalizePath(home .. "\\rwda_config.lua")
    end
  end

  return normalizePath("rwda_config.lua")
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t or {}) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end

local function serialize(value, indent)
  indent = indent or 0
  local t = type(value)
  if t == "nil" then
    return "nil"
  end
  if t == "number" or t == "boolean" then
    return tostring(value)
  end
  if t == "string" then
    return string.format("%q", value)
  end
  if t ~= "table" then
    error("Unsupported value type for config serialization: " .. t)
  end

  local nextIndent = indent + 2
  local lines = { "{" }
  for _, key in ipairs(sortedKeys(value)) do
    local keyRepr
    if type(key) == "string" and key:match("^[%a_][%w_]*$") then
      keyRepr = key
    else
      keyRepr = "[" .. serialize(key, nextIndent) .. "]"
    end

    lines[#lines + 1] = string.rep(" ", nextIndent) .. keyRepr .. " = " .. serialize(value[key], nextIndent) .. ","
  end
  lines[#lines + 1] = string.rep(" ", indent) .. "}"
  return table.concat(lines, "\n")
end

local function copyArray(src)
  local out = {}
  if type(src) ~= "table" then
    return out
  end
  for i = 1, #src do
    out[i] = src[i]
  end
  return out
end

local function exportPersistedConfig()
  return {
    logging = {
      enabled = config.logging.enabled,
      level = config.logging.level,
    },
    integration = {
      use_legacy = config.integration.use_legacy,
      auto_enable_with_legacy = config.integration.auto_enable_with_legacy,
      follow_legacy_target = config.integration.follow_legacy_target,
      group_target_events = copyArray(config.integration.group_target_events),
    },
    combat = {
      auto_tick_on_prompt = config.combat.auto_tick_on_prompt,
      auto_goal = config.combat.auto_goal,
      require_target_available = config.combat.require_target_available,
      clear_queue_when_target_missing = config.combat.clear_queue_when_target_missing,
      require_room_presence_when_gmcp = config.combat.require_room_presence_when_gmcp,
    },
    retaliation = {
      enabled = config.retaliation.enabled,
      lock_ms = config.retaliation.lock_ms,
      swap_debounce_ms = config.retaliation.swap_debounce_ms,
      min_confidence = config.retaliation.min_confidence,
      restore_previous_target = config.retaliation.restore_previous_target,
      ignore_non_players = config.retaliation.ignore_non_players,
    },
    finisher = rwda.util.deepcopy(config.finisher or {}),
    parser = {
      capture_unmatched_lines = config.parser.capture_unmatched_lines,
      capture_all_lines = config.parser.capture_all_lines,
      capture_unmatched_path = config.parser.capture_unmatched_path,
      capture_unmatched_include_prompts = config.parser.capture_unmatched_include_prompts,
      infer_defence_loss_on_aggressive = config.parser.infer_defence_loss_on_aggressive,
      infer_defence_loss_on_move = config.parser.infer_defence_loss_on_move,
      inferred_defence_confidence = config.parser.inferred_defence_confidence,
      form_detect = {
        enabled = config.parser.form_detect and config.parser.form_detect.enabled,
        dragon_on = copyArray(config.parser.form_detect and config.parser.form_detect.dragon_on),
        dragon_off = copyArray(config.parser.form_detect and config.parser.form_detect.dragon_off),
      },
    },
    runewarden = {
      prep_limbs = copyArray(config.runewarden.prep_limbs),
      near_break_pct = config.runewarden.near_break_pct,
      lock_venom_priority = copyArray(config.runewarden.lock_venom_priority),
      venoms = {
        dsl_main = copyArray(config.runewarden.venoms and config.runewarden.venoms.dsl_main),
        dsl_off = copyArray(config.runewarden.venoms and config.runewarden.venoms.dsl_off),
      },
    },
    dragon = {
      breath_type = config.dragon.breath_type,
      default_goal = config.dragon.default_goal,
      devour_threshold = config.dragon.devour_threshold,
    },
    strategy = rwda.util.deepcopy(config.strategy or {}),
    runelore  = rwda.util.deepcopy(config.runelore  or {}),
    falcon    = rwda.util.deepcopy(config.falcon    or {}),
    runesmith = rwda.util.deepcopy(config.runesmith or {}),
    fury      = rwda.util.deepcopy(config.fury      or {}),
  }
end

config.logging = config.logging or {}
setDefault(config.logging, "enabled", true)
setDefault(config.logging, "level", "info")

config.integration = config.integration or {}
setDefault(config.integration, "use_legacy", true)
config.integration.use_legacy = true
setDefault(config.integration, "auto_enable_with_legacy", true)
setDefault(config.integration, "legacy_control_mode", false)
setDefault(config.integration, "use_aklimb", true)
setDefault(config.integration, "use_group_layer", true)
setDefault(config.integration, "follow_legacy_target", true)
config.integration.group_target_events = config.integration.group_target_events or {
  "GroupTargetChanged",
  "group target changed",
  "gcom target changed",
  "ga target changed",
  "gmcp.IRE.Target.Set",
  "gmcp.IRE.Target.Info",
  "LPrompt",
}

config.combat = config.combat or {}
setDefault(config.combat, "enabled", false)
setDefault(config.combat, "mode", "auto")
setDefault(config.combat, "goal", "limbprep")
setDefault(config.combat, "profile", "duel")
setDefault(config.combat, "target", nil)
setDefault(config.combat, "anti_spam_ms", 250)
setDefault(config.combat, "auto_tick_on_prompt", true)
setDefault(config.combat, "auto_goal", true)
setDefault(config.combat, "require_target_available", true)
setDefault(config.combat, "clear_queue_when_target_missing", true)
setDefault(config.combat, "require_room_presence_when_gmcp", true)
setDefault(config.combat, "assess_enabled", true)
setDefault(config.combat, "assess_interval_ms", 9000)
setDefault(config.combat, "assess_stale_ms", 7000)

config.retaliation = config.retaliation or {}
setDefault(config.retaliation, "enabled", false)
setDefault(config.retaliation, "lock_ms", 8000)
setDefault(config.retaliation, "swap_debounce_ms", 1500)
setDefault(config.retaliation, "min_confidence", 0.65)
setDefault(config.retaliation, "restore_previous_target", true)
setDefault(config.retaliation, "ignore_non_players", true)

config.finisher = config.finisher or {}
setDefault(config.finisher, "enabled", true)
setDefault(config.finisher, "cooldown_ms", 1500)
setDefault(config.finisher, "fallback_window_ms", 6000)
config.finisher.timeouts = config.finisher.timeouts or {}
setDefault(config.finisher.timeouts, "disembowel_ms", 2500)
setDefault(config.finisher.timeouts, "devour_ms", 8000)
config.finisher.fallback_blocks = config.finisher.fallback_blocks or {}
setDefault(config.finisher.fallback_blocks, "human_dualcut", "limbprep_dsl")
setDefault(config.finisher.fallback_blocks, "dragon_silver", "dragon_force_prone")

config.parser = config.parser or {}
setDefault(config.parser, "use_temp_line_trigger", false)
setDefault(config.parser, "use_data_events", true)
setDefault(config.parser, "decay_target_defences", true)
setDefault(config.parser, "infer_defence_loss_on_aggressive", true)
setDefault(config.parser, "infer_defence_loss_on_move", true)
setDefault(config.parser, "inferred_defence_confidence", 0.35)
setDefault(config.parser, "capture_unmatched_lines", false)
setDefault(config.parser, "capture_all_lines", false)
setDefault(config.parser, "capture_unmatched_path", nil)
setDefault(config.parser, "capture_unmatched_include_prompts", false)
config.parser.form_detect = config.parser.form_detect or {}
setDefault(config.parser.form_detect, "enabled", true)
config.parser.form_detect.dragon_on = config.parser.form_detect.dragon_on or {
  "you assume the form of a dragon",
  "you are now in dragonform",
  "you transform into a dragon",
  "you morph into a dragon",
  "you shift into a dragon",
  "you surge into dragonform",
  "you take draconic form",
  "you assume draconic form",
}
config.parser.form_detect.dragon_off = config.parser.form_detect.dragon_off or {
  "you return to your lesser form",
  "you are no longer in dragonform",
  "you return to your human form",
  "you return to your mortal form",
  "you return to your normal form",
  "you revert to your lesser form",
  "you revert to your human form",
  "you are no longer a dragon",
}

config.weapons = config.weapons or {}
setDefault(config.weapons, "mainhand", "scimitar")
setDefault(config.weapons, "offhand", "scimitar")

config.executor = config.executor or {}
setDefault(config.executor, "use_server_queue", true)
setDefault(config.executor, "clear_on_stop", true)
setDefault(config.executor, "queue_type_default", "bal")
setDefault(config.executor, "queue_kill_moves_as_freestand", true)

config.runewarden = config.runewarden or {}
setDefault(config.runewarden, "default_goal", "limbprep")
-- Break sequence order: left_leg (causes prone) → torso → right_leg → impale
config.runewarden.prep_limbs = config.runewarden.prep_limbs or { "left_leg", "torso", "right_leg" }
-- Damage % at which nextPrepLimb switches from balanced to sequential-break mode
setDefault(config.runewarden, "near_break_pct", 75)
-- Lock venom priority: pick the two most-needed from this list each tick
config.runewarden.lock_venom_priority = config.runewarden.lock_venom_priority or {
  "kalmia",
  "gecko",
  "slike",
  "curare",
  "epteth",
  "vernalius",
  "xentio",
  "prefarar",
  "euphorbia",
  "aconite",
  "larkspur",
}
config.runewarden.venoms = config.runewarden.venoms or {}
config.runewarden.venoms.dsl_main = config.runewarden.venoms.dsl_main or { "curare", "gecko" }
config.runewarden.venoms.dsl_off = config.runewarden.venoms.dsl_off or { "epteth", "kalmia" }
-- Ordered list of pressure venoms applied after core lock affs (asthma/slickness/anorexia/paralysis).
-- These are kelp-cure venoms whose purpose is to burn the target's kelp supply so asthma sticks.
-- Set automatically by rwda runesmith when a preset with kelp_cycle is applied.
config.runewarden.venoms.kelp_cycle = config.runewarden.venoms.kelp_cycle or { "vernalius", "xentio", "prefarar", "euphorbia", "aconite" }

-- Runelore / runeblade configuration
-- Reflects December 2025 classleads (Kena <40% mana, Pithakhan 13% broken-head drain).
config.runelore = config.runelore or {}
-- Auto-send EMPOWER <rune> immediately when a configuration rune attunes.
setDefault(config.runelore, "auto_empower", true)
-- Enable the bisect_window strategy block (requires hugalaz as core rune).
setDefault(config.runelore, "bisect_enabled", false)
-- Mana fraction below which Kena is considered eligible to attune (Dec 2025: 0.40).
setDefault(config.runelore, "kena_mana_threshold", 0.40)
-- Mana fraction drained by Pithakhan on a broken head (Dec 2025: 0.13).
setDefault(config.runelore, "pithakhan_broken_head_drain", 0.13)
-- Default core rune for the configured runeblade.
setDefault(config.runelore, "default_core", "pithakhan")
-- Default configuration runes (up to 3 around the core).
config.runelore.default_config_runes = config.runelore.default_config_runes or { "kena", "sleizak", "inguz" }
-- Empower priority order (first eligible attuned rune in this list is empowered).
config.runelore.empower_priority = config.runelore.empower_priority or { "kena", "inguz", "sleizak" }

-- Falcon / falconry integration
config.falcon = config.falcon or {}
-- Send FALCON SLAY + FALCON TRACK once on each engage; re-track when target changes.
setDefault(config.falcon, "auto_track", true)
-- Send `observe <target>` alongside each offensive attack tick (health report).
setDefault(config.falcon, "observe_on_attack", true)
-- Automatically send `follow <target>` on engage and when target changes (opt-in).
setDefault(config.falcon, "auto_follow", false)

-- Runesmith: automated sketch/empower workflow engine
config.runesmith = config.runesmith or {}
-- Delay between sequential sketch commands (ms)
setDefault(config.runesmith, "step_delay_ms", 800)
-- After runesmith finishes, auto-sync rwda.config.runelore with the preset's core/config/priority.
setDefault(config.runesmith, "auto_sync_runelore", true)
-- After runesmith finishes, auto-switch RWDA profile to the preset's profile_hint.
setDefault(config.runesmith, "auto_switch_profile", true)

-- Fury: keep FURY on for the duration of every fight
config.fury = config.fury or {}
-- Send FURY ON automatically when rwda engage fires.
setDefault(config.fury, "auto_activate",       true)
-- Re-send FURY ON automatically when fury fades mid-fight.
setDefault(config.fury, "auto_reactivate",     true)
-- Minimum willpower required to pay the 500-wp re-activation cost.
setDefault(config.fury, "min_wp_reactivate",   1500)
-- Endurance fraction below which a low-endurance warning is echoed.
setDefault(config.fury, "endurance_warn_pct",  0.25)
-- Endurance fraction below which FURY OFF is sent automatically.
setDefault(config.fury, "endurance_floor_pct", 0.10)

config.dragon = config.dragon or {}
setDefault(config.dragon, "breath_type", "lightning")
setDefault(config.dragon, "default_goal", "dragon_devour")
setDefault(config.dragon, "devour_threshold", 6.0)
config.dragon.curse_priority = config.dragon.curse_priority or { "impatience", "asthma", "paralysis", "stupidity" }
config.dragon.gut_venom_priority = config.dragon.gut_venom_priority or { "curare", "kalmia", "gecko", "slike", "aconite" }
-- Commands sent automatically when RWDA detects a shift INTO dragon form.
-- e.g. { "sk rend", "dragonarmour on" }
config.dragon.on_shift_cmds = config.dragon.on_shift_cmds or {}
-- Commands sent automatically when RWDA detects a return to human (runewarden) form.
-- e.g. { "sk slash" }
config.dragon.on_revert_cmds = config.dragon.on_revert_cmds or {}

config.profiles = config.profiles or {}
config.profiles.duel      = config.profiles.duel      or { mode = "auto", goal = "limbprep" }
config.profiles.group     = config.profiles.group     or { mode = "auto", goal = "pressure" }
config.profiles.kena_lock = config.profiles.kena_lock or { mode = "auto", goal = "impale_kill" }
config.profiles.kena_bisect = config.profiles.kena_bisect or { mode = "auto", goal = "impale_kill", bisect = true }
config.profiles.head_focus  = config.profiles.head_focus  or { mode = "auto", goal = "pressure" }

config.strategy = config.strategy or {}
setDefault(config.strategy, "enabled", true)
setDefault(config.strategy, "version", 1)
setDefault(config.strategy, "active_profile", "duel")
config.strategy.profiles = config.strategy.profiles or {}

config.replay = config.replay or {}
setDefault(config.replay, "prompt_pattern", "^%d+h, %d+m")
setDefault(config.replay, "auto_tick", true)

config.safety = config.safety or {}
setDefault(config.safety, "deny_send_when_stopped", false)

config.persistence = config.persistence or {}
setDefault(config.persistence, "enabled", true)
setDefault(config.persistence, "auto_load", true)
setDefault(config.persistence, "path", nil)

function config.resolvePersistPath(path)
  local chosen = normalizePath(path or config.persistence.path)
  if chosen and chosen ~= "" then
    return chosen
  end
  return defaultPersistPath()
end

function config.persistedExists(path)
  local resolved = config.resolvePersistPath(path)
  local f = io.open(resolved, "r")
  if not f then
    return false
  end
  f:close()
  return true
end

function config.savePersisted(path)
  if config.persistence.enabled == false then
    return nil, "persistence_disabled"
  end

  local resolved = config.resolvePersistPath(path)
  local f, err = io.open(resolved, "w")
  if not f then
    return nil, err
  end

  local ok, payload = pcall(function()
    return "return " .. serialize(exportPersistedConfig(), 0) .. "\n"
  end)

  if not ok then
    f:close()
    return nil, payload
  end

  f:write(payload)
  f:close()
  return true, resolved
end

function config.loadPersisted(path)
  if config.persistence.enabled == false then
    return nil, "persistence_disabled"
  end

  local resolved = config.resolvePersistPath(path)
  local chunk, loadErr = loadfile(resolved)
  if not chunk then
    return nil, loadErr
  end

  local ok, loaded = pcall(chunk)
  if not ok then
    return nil, loaded
  end

  if type(loaded) ~= "table" then
    return nil, "persisted_config_not_table"
  end

  if rwda.util and rwda.util.merge then
    rwda.util.merge(config, loaded)
  else
    for k, v in pairs(loaded) do
      config[k] = v
    end
  end

  config.integration = config.integration or {}
  config.integration.use_legacy = true

  return true, resolved
end
