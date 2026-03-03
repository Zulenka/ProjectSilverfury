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
          { id = "assess_target", enabled = true, priority = 30, when = { "target.limb_stale" } },
          { id = "limbprep_dsl", enabled = true, priority = 20, when = { "always" } },
        },
      },
      dragon = {
        blocks = {
          { id = "summon_breath",           enabled = true,  priority = 100, when = { "not me.dragon.breath_summoned" } },
          { id = "dragon_shield_curse",     enabled = true,  priority = 96,  when = { "target.def.shield" } },
          { id = "dragon_strip_shield",     enabled = false, priority = 95,  when = { "target.def.shield" } },
          { id = "dragon_strip_rebounding", enabled = true,  priority = 94,  when = { "target.def.rebounding" } },
          { id = "dragon_lyred_blast",      enabled = true,  priority = 93,  when = { "target.lyred" } },
          { id = "dragon_flying_becalm",    enabled = true,  priority = 92,  when = { "target.flying" } },
          { id = "dragon_curse_gut",        enabled = true,  priority = 86,  when = { "not target.prone" } },
          { id = "dragon_force_prone",      enabled = false, priority = 85,  when = { "not target.prone" } },
          { id = "dragon_bite",             enabled = true,  priority = 79,  when = { "target.prone" } },
          { id = "devour_window",           enabled = true,  priority = 80,  when = { "goal.dragon_devour", "state.can_devour" } },
          { id = "dragon_torso_pressure",   enabled = true,  priority = 70,  when = { "not target.limb.torso.broken" } },
          { id = "dragon_limb_pressure",    enabled = true,  priority = 20,  when = { "always" } },
        },
      },
    },
    group = {
      runewarden = {
        blocks = {
          { id = "strip_rebounding", enabled = true, priority = 100, when = { "target.def.rebounding" } },
          { id = "strip_shield", enabled = true, priority = 95, when = { "target.def.shield" } },
          { id = "assess_target", enabled = true, priority = 30, when = { "target.limb_stale" } },
          { id = "limbprep_dsl", enabled = true, priority = 20, when = { "always" } },
        },
      },
      dragon = {
        blocks = {
          { id = "summon_breath",           enabled = true,  priority = 100, when = { "not me.dragon.breath_summoned" } },
          { id = "dragon_shield_curse",     enabled = true,  priority = 96,  when = { "target.def.shield" } },
          { id = "dragon_strip_shield",     enabled = false, priority = 95,  when = { "target.def.shield" } },
          { id = "dragon_strip_rebounding", enabled = true,  priority = 94,  when = { "target.def.rebounding" } },
          { id = "dragon_lyred_blast",      enabled = true,  priority = 93,  when = { "target.lyred" } },
          { id = "dragon_flying_becalm",    enabled = true,  priority = 92,  when = { "target.flying" } },
          { id = "dragon_curse_gut",        enabled = true,  priority = 86,  when = { "not target.prone" } },
          { id = "dragon_force_prone",      enabled = false, priority = 85,  when = { "not target.prone" } },
          { id = "dragon_bite",             enabled = true,  priority = 79,  when = { "target.prone" } },
          { id = "dragon_torso_pressure",   enabled = true,  priority = 70,  when = { "not target.limb.torso.broken" } },
          { id = "dragon_limb_pressure",    enabled = true,  priority = 20,  when = { "always" } },
        },
      },
    },

    -- ── Kena lock ─────────────────────────────────────────────────────────────
    -- Runelore profile focused on delivering impatience via the empowered Kena
    -- configuration rune, then finishing with BISECT once health is ≤20%.
    -- Prerequisite: hugalaz core rune + kena configuration rune on the runeblade.
    kena_lock = {
      runewarden = {
        blocks = {
          { id = "strip_rebounding", enabled = true,  priority = 100, when = { "target.def.rebounding" } },
          -- Fire bisect when target health is ≤20% (bypasses rebounding, instant kill).
          { id = "bisect_window",    enabled = true,  priority = 99,  when = { "runelore.bisect_ready", "target.health_low" } },
          { id = "strip_shield",     enabled = true,  priority = 95,  when = { "target.def.shield" } },
          { id = "assess_target",    enabled = true,  priority = 30,  when = { "target.limb_stale" } },
          -- Always attack head with kelp venoms to maximise Kena/Pithakhan attunement.
          { id = "head_focus_dsl",   enabled = true,  priority = 20,  when = { "always" } },
        },
      },
      dragon = {
        blocks = {
          { id = "summon_breath",           enabled = true,  priority = 100, when = { "not me.dragon.breath_summoned" } },
          { id = "dragon_shield_curse",     enabled = true,  priority = 96,  when = { "target.def.shield" } },
          { id = "dragon_strip_rebounding", enabled = true,  priority = 94,  when = { "target.def.rebounding" } },
          { id = "dragon_curse_gut",        enabled = true,  priority = 86,  when = { "not target.prone" } },
          { id = "dragon_force_prone",      enabled = false, priority = 85,  when = { "not target.prone" } },
          { id = "dragon_bite",             enabled = true,  priority = 79,  when = { "target.prone" } },
          { id = "devour_window",           enabled = true,  priority = 80,  when = { "goal.dragon_devour", "state.can_devour" } },
          { id = "dragon_torso_pressure",   enabled = true,  priority = 70,  when = { "not target.limb.torso.broken" } },
          { id = "dragon_limb_pressure",    enabled = true,  priority = 20,  when = { "always" } },
        },
      },
    },

    -- ── Head focus ────────────────────────────────────────────────────────────
    -- Runelore profile that drives all damage to the head to ensure Pithakhan
    -- guaranteed proc rate and build toward a bisect finisher.
    -- Pithakhan always fires on a damaged head (July 2022); at 13% drain on
    -- broken head (Dec 2025) this creates significant mana pressure.
    head_focus = {
      runewarden = {
        blocks = {
          { id = "strip_rebounding", enabled = true,  priority = 100, when = { "target.def.rebounding" } },
          { id = "bisect_window",    enabled = false, priority = 99,  when = { "runelore.bisect_ready", "target.health_low" } },
          { id = "strip_shield",     enabled = true,  priority = 95,  when = { "target.def.shield" } },
          { id = "assess_target",    enabled = true,  priority = 30,  when = { "target.limb_stale" } },
          { id = "head_focus_dsl",   enabled = true,  priority = 20,  when = { "always" } },
        },
      },
      dragon = {
        blocks = {
          { id = "summon_breath",           enabled = true,  priority = 100, when = { "not me.dragon.breath_summoned" } },
          { id = "dragon_shield_curse",     enabled = true,  priority = 96,  when = { "target.def.shield" } },
          { id = "dragon_strip_rebounding", enabled = true,  priority = 94,  when = { "target.def.rebounding" } },
          { id = "dragon_curse_gut",        enabled = true,  priority = 86,  when = { "not target.prone" } },
          { id = "dragon_force_prone",      enabled = false, priority = 85,  when = { "not target.prone" } },
          { id = "dragon_bite",             enabled = true,  priority = 79,  when = { "target.prone" } },
          { id = "dragon_torso_pressure",   enabled = true,  priority = 70,  when = { "not target.limb.torso.broken" } },
          { id = "dragon_limb_pressure",    enabled = true,  priority = 20,  when = { "always" } },
        },
      },
    },
  },
}
