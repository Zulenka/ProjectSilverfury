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
    },
    combat = {
      auto_tick_on_prompt = config.combat.auto_tick_on_prompt,
      require_target_available = config.combat.require_target_available,
      clear_queue_when_target_missing = config.combat.clear_queue_when_target_missing,
      require_room_presence_when_gmcp = config.combat.require_room_presence_when_gmcp,
    },
    parser = {
      form_detect = {
        enabled = config.parser.form_detect and config.parser.form_detect.enabled,
        dragon_on = copyArray(config.parser.form_detect and config.parser.form_detect.dragon_on),
        dragon_off = copyArray(config.parser.form_detect and config.parser.form_detect.dragon_off),
      },
    },
    runewarden = {
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
config.integration.group_target_events = config.integration.group_target_events or {
  "GroupTargetChanged",
  "group target changed",
  "gcom target changed",
  "ga target changed",
}

config.combat = config.combat or {}
setDefault(config.combat, "enabled", false)
setDefault(config.combat, "mode", "auto")
setDefault(config.combat, "goal", "limbprep")
setDefault(config.combat, "profile", "duel")
setDefault(config.combat, "target", nil)
setDefault(config.combat, "anti_spam_ms", 250)
setDefault(config.combat, "auto_tick_on_prompt", false)
setDefault(config.combat, "require_target_available", true)
setDefault(config.combat, "clear_queue_when_target_missing", true)
setDefault(config.combat, "require_room_presence_when_gmcp", true)

config.parser = config.parser or {}
setDefault(config.parser, "use_temp_line_trigger", false)
setDefault(config.parser, "use_data_events", true)
setDefault(config.parser, "decay_target_defences", true)
setDefault(config.parser, "infer_defence_loss_on_aggressive", true)
setDefault(config.parser, "infer_defence_loss_on_move", true)
setDefault(config.parser, "inferred_defence_confidence", 0.35)
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
config.runewarden.prep_limbs = config.runewarden.prep_limbs or { "left_leg", "right_leg", "torso" }
config.runewarden.venoms = config.runewarden.venoms or {}
config.runewarden.venoms.dsl_main = config.runewarden.venoms.dsl_main or { "curare", "gecko" }
config.runewarden.venoms.dsl_off = config.runewarden.venoms.dsl_off or { "epteth", "kalmia" }

config.dragon = config.dragon or {}
setDefault(config.dragon, "breath_type", "lightning")
setDefault(config.dragon, "default_goal", "dragon_devour")
setDefault(config.dragon, "devour_threshold", 6.0)

config.profiles = config.profiles or {}
config.profiles.duel = config.profiles.duel or { mode = "auto", goal = "limbprep" }
config.profiles.group = config.profiles.group or { mode = "auto", goal = "pressure" }

config.replay = config.replay or {}
setDefault(config.replay, "prompt_pattern", "^%d+h, %d+m")
setDefault(config.replay, "auto_tick", true)

config.safety = config.safety or {}
setDefault(config.safety, "deny_send_when_stopped", true)

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
