-- Replay suite: strategy blocks, retaliation, and finisher lifecycle.
-- Run with: rwda replaysuite rwda/tools/suite_strategy_retal_finisher.lua
--
-- Each case resets state before running.  pre_state applies per-case
-- goal/mode/retaliation/execute settings on top of the reset baseline.
--
-- Log file paths are relative to the Mudlet home directory or wherever
-- rwda is loaded from.  Adjust the prefix if your installation path differs.

local BASE = "rwda/tools/"

return {
  cases = {

    -- ── Dragon: shield detected → strip → pressure setup → devour success ────
    {
      name       = "dragon_shield_strip_to_devour",
      log        = BASE .. "replay_dragon_shield_to_devour.log",
      target     = "Bainz",
      pre_state  = { goal = "dragon_devour", execute = true },
      assertions = {
        expected_last_action = "devour",
        min_actions          = 3,
      },
    },

    -- ── Dragon: devour attempt fails → fallback forces prone (gust) ──────────
    {
      name       = "dragon_devour_fail_to_fallback",
      log        = BASE .. "replay_dragon_devour_fail.log",
      target     = "Bainz",
      pre_state  = { goal = "dragon_devour", execute = true },
      assertions = {
        expected_last_action = "gust",
        min_actions          = 3,
      },
    },

    -- ── Runewarden: impale window → disembowel success ───────────────────────
    {
      name       = "rw_impale_disembowel_success",
      log        = BASE .. "replay_rw_impale_disembowel.log",
      target     = "Bainz",
      pre_state  = { goal = "impale_kill", execute = true },
      assertions = {
        expected_last_action = "disembowel",
        min_actions          = 2,
      },
    },

    -- ── Runewarden: disembowel fails → limbprep_dsl fallback ─────────────────
    {
      name       = "rw_disembowel_fail_to_fallback",
      log        = BASE .. "replay_rw_disembowel_fail.log",
      target     = "Bainz",
      pre_state  = { goal = "impale_kill", execute = true },
      assertions = {
        expected_last_action = "dsl",
        min_actions          = 2,
      },
    },

    -- ── Auto-retaliation: incoming hit from non-target swaps target ──────────
    -- Start target = "Bainz", retaliation on; Raijin attacks → switch.
    -- First tick after switch should plan dsl against Raijin.
    {
      name       = "retaliation_target_switch",
      log        = BASE .. "replay_retaliation_switch.log",
      target     = "Bainz",
      pre_state  = { retaliate = true },
      assertions = {
        expected_last_action = "dsl",
        min_actions          = 1,
      },
    },

    -- ── Multi-attacker hold: two attackers → do not switch, hold on first ────
    -- Raijin attacks first (switches), then Kayde attacks.  With 2 aggressors
    -- active the system must hold on Raijin and not switch to Kayde.
    -- After the two prompts the last action should still target Raijin (dsl).
    {
      name       = "retaliation_multi_attacker_hold",
      log        = BASE .. "replay_retaliation_multi_attacker.log",
      target     = "Bainz",
      pre_state  = { retaliate = true },
      assertions = {
        expected_last_action = "dsl",
        min_actions          = 1,
      },
    },

    -- ── Target-dead switch: kill primary, auto-switch to remaining attacker ──
    -- Raijin and Kayde both attack; then Raijin is slain.  The system should
    -- automatically retarget Kayde (the only remaining active aggressor).
    {
      name       = "retaliation_dead_switch_to_remaining",
      log        = BASE .. "replay_retaliation_dead_switch.log",
      target     = "Bainz",
      pre_state  = { retaliate = true },
      assertions = {
        expected_last_action = "dsl",
        min_actions          = 1,
      },
    },

  },
}
