rwda = rwda or {}
rwda.data = rwda.data or {}
rwda.data.strategy_presets = rwda.data.strategy_presets or {
  version = 1,
  profiles = {
    duel = {
      runewarden = {
        blocks = {
          { id = "strip_rebounding", enabled = true, priority = 100, when = { "target.def.rebounding" } },
          { id = "strip_shield", enabled = true, priority = 95, when = { "target.def.shield" } },
          { id = "impale_window", enabled = true, priority = 92, when = { "goal.impale_kill", "target.prone", "target.legs_broken", "not target.impaled" } },
          { id = "disembowel_followup", enabled = true, priority = 91, when = { "goal.impale_kill", "target.impaled" } },
          { id = "intimidate_lock", enabled = true, priority = 90, when = { "goal.impale_kill", "target.prone", "target.legs_broken" } },
          { id = "limbprep_dsl", enabled = true, priority = 20, when = { "always" } },
        },
      },
      dragon = {
        blocks = {
          { id = "summon_breath", enabled = true, priority = 100, when = { "not me.dragon.breath_summoned" } },
          { id = "dragon_strip_shield", enabled = true, priority = 95, when = { "target.def.shield" } },
          { id = "dragon_strip_rebounding", enabled = true, priority = 94, when = { "target.def.rebounding" } },
          { id = "dragon_force_prone", enabled = true, priority = 85, when = { "not target.prone" } },
          { id = "devour_window", enabled = true, priority = 80, when = { "goal.dragon_devour", "state.can_devour" } },
          { id = "dragon_torso_pressure", enabled = true, priority = 70, when = { "not target.limb.torso.broken" } },
          { id = "dragon_limb_pressure", enabled = true, priority = 20, when = { "always" } },
        },
      },
    },
    group = {
      runewarden = {
        blocks = {
          { id = "strip_rebounding", enabled = true, priority = 100, when = { "target.def.rebounding" } },
          { id = "strip_shield", enabled = true, priority = 95, when = { "target.def.shield" } },
          { id = "limbprep_dsl", enabled = true, priority = 20, when = { "always" } },
        },
      },
      dragon = {
        blocks = {
          { id = "summon_breath", enabled = true, priority = 100, when = { "not me.dragon.breath_summoned" } },
          { id = "dragon_strip_shield", enabled = true, priority = 95, when = { "target.def.shield" } },
          { id = "dragon_strip_rebounding", enabled = true, priority = 94, when = { "target.def.rebounding" } },
          { id = "dragon_force_prone", enabled = true, priority = 85, when = { "not target.prone" } },
          { id = "dragon_torso_pressure", enabled = true, priority = 70, when = { "not target.limb.torso.broken" } },
          { id = "dragon_limb_pressure", enabled = true, priority = 20, when = { "always" } },
        },
      },
    },
  },
}
