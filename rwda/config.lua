rwda = rwda or {}
rwda.config = rwda.config or {}

local config = rwda.config

local function setDefault(tbl, key, value)
  if tbl[key] == nil then
    tbl[key] = value
  end
end

config.logging = config.logging or {}
setDefault(config.logging, "enabled", true)
setDefault(config.logging, "level", "info")

config.integration = config.integration or {}
setDefault(config.integration, "use_legacy", true)
setDefault(config.integration, "legacy_control_mode", false)
setDefault(config.integration, "use_svof", false)
setDefault(config.integration, "svof_control_mode", false)
setDefault(config.integration, "allow_parallel_backends", false)
setDefault(config.integration, "use_aklimb", true)
setDefault(config.integration, "use_group_layer", true)

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
