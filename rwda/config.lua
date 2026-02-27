rwda = rwda or {}
rwda.config = rwda.config or {}

local config = rwda.config

config.logging = config.logging or {
  enabled = true,
  level = "info",
}

config.integration = config.integration or {
  use_svof = true,
  svof_control_mode = false,
  use_aklimb = true,
  use_group_layer = true,
}

config.combat = config.combat or {
  enabled = false,
  mode = "auto",
  goal = "limbprep",
  profile = "duel",
  target = nil,
  anti_spam_ms = 250,
  auto_tick_on_prompt = true,
}

config.parser = config.parser or {
  use_temp_line_trigger = true,
  use_data_events = true,
  decay_target_defences = true,
}

config.weapons = config.weapons or {
  mainhand = "scimitar",
  offhand = "scimitar",
}

config.executor = config.executor or {
  use_server_queue = true,
  clear_on_stop = true,
  queue_type_default = "bal",
  queue_kill_moves_as_freestand = true,
}

config.runewarden = config.runewarden or {
  default_goal = "limbprep",
  prep_limbs = { "left_leg", "right_leg", "torso" },
  venoms = {
    dsl_main = { "curare", "gecko" },
    dsl_off = { "epteth", "kalmia" },
  },
}

config.dragon = config.dragon or {
  breath_type = "lightning",
  default_goal = "dragon_devour",
  devour_threshold = 6.0,
}

config.profiles = config.profiles or {
  duel = {
    mode = "auto",
    goal = "limbprep",
  },
  group = {
    mode = "auto",
    goal = "pressure",
  },
}

config.replay = config.replay or {
  prompt_pattern = "^%d+h, %d+m",
  auto_tick = true,
}

config.safety = config.safety or {
  deny_send_when_stopped = true,
}
