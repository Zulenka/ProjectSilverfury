# RWDA (Runewarden + Silver Dragon AI)

This directory contains a Mudlet Lua combat brain that runs alongside Legacy.

Project log:
- `RWDA_Dev_Test_Log.md` at repo root tracks commands, configuration decisions, feature milestones, and test outcomes.

## What it includes
- Canonical state model (`rwda/state/*`) for self, target, cooldowns, and runtime flags.
- Data dictionaries (`rwda/data/*`) for core afflictions, defences, abilities, and venoms.
- Engine modules (`rwda/engine/*`) for events, parsing, planning, server-queue execution, and safety controls.
- Strategy-driven planner core (`rwda/engine/strategy.lua`) with profile/mode block selection.
- Finisher lifecycle engine (`rwda/engine/finisher.lua`) with timeout/fallback routing for disembowel/devour attempts.
- Integrations (`rwda/integrations/*`) for Legacy (primary), AK/lb limb feeds, and group/Legacy target sync.
- Command UI (`rwda/ui/commands.lua`) with `rwda` alias controls.
- Combat builder UI (`rwda/ui/combat_builder.lua` + `rwda/ui/combat_builder_state.lua`) — Geyser popout with Runewarden/Dragon/Shared/Safety tabs for live strategy editing.
- Replay harness (`rwda/engine/replay.lua`) for log-driven parser/planner validation.

## Legacy integration (primary)
The Legacy adapter is read-only by default and uses runtime state/events present in Legacy:
- Globals: `Legacy`, `Legacy.Curing.Affs`, `Legacy.Curing.Defs.current`, `Legacy.Curing.bal`
- Events: `LegacyLoaded`, `gmcp.Char.Afflictions.Add/Remove`, `gmcp.Char.Defences.Add/Remove`, `gmcp.Char.Vitals`
- Optional target-follow input: Legacy/global `target`, `gmcp.IRE.Target.Set/Info`, and group-target events.

RWDA does not replace Legacy curing/defence logic; it uses Legacy as state source and handles offense planning/execution.
RWDA does not send herb/salve/sip cures while Legacy integration is active.

## Loading in Mudlet
1. Ensure these files are available in your profile/module sync path.
2. Load `rwda/init.lua` (or create a Mudlet script item that executes `dofile([[...\\rwda\\init.lua]])`).
3. Confirm bootstrap output in your main console.
4. RWDA auto-registers:
   - GMCP vitals + prompt handlers,
   - data receive handlers (`sysDataReceived`/`sysDataReceive`),
   - and a temp catch-all regex trigger for line parsing (configurable in `rwda.config.parser`).

## Offline replay testing
- CLI helper: `rwda/tools/replay_cli.lua`
- Example:
  - `lua rwda\\tools\\replay_cli.lua C:\\path\\to\\combat.log TargetName`
- A tiny sample file is included at `rwda/tools/sample_replay.log`.
- Sample assertion suite file: `rwda/tools/sample_replay_suite.lua`

## Packaging
- Build Mudlet bootstrap package:
  - `pwsh -File rwda/tools/build_mpackage.ps1`
- Output:
  - `dist/RWDA_Bootstrap.mpackage`
- Import that `.mpackage` in Mudlet. It installs `RWDA_Bootstrap.xml`, which loads `rwda/init.lua` from your configured filesystem paths.

## Commands
- `rwda on`
- `rwda off`
- `rwda stop`
- `rwda resume`
- `rwda reload`
- `rwda target <name>`
- `rwda mode <auto|human|dragon>`
- `rwda goal <pressure|limbprep|impale_kill|dragon_devour>`
- `rwda status`
- `rwda doctor`
- `rwda explain`
- `rwda tick`
- `rwda retaliate <on|off>`
- `rwda execute <on|off>`
- `rwda builder open`
- `rwda builder close`
- `rwda strategy show`
- `rwda strategy apply`
- `rwda strategy save`
- `rwda strategy load`
- `rwda selftest`
- `rwda show config`
- `rwda set breath <type>`
- `rwda set venoms <main> <off>`
- `rwda set autostart <on|off>`
- `rwda set followlegacytarget <on|off>`
- `rwda set prompttick <on|off>`
- `rwda set retalockms <ms>`
- `rwda set retaldebounce <ms>`
- `rwda set retalminconf <0-1>`
- `rwda set executecooldown <ms>`
- `rwda set executefallbackwindow <ms>`
- `rwda set executetimeout <disembowel|devour> <ms>`
- `rwda set executefallback <human|dragon> <block_id>`
- `rwda set capture <on|off>`
- `rwda set captureprompts <on|off>`
- `rwda set capturepath <path>`
- `rwda queue clear`
- `rwda save config`
- `rwda load config`
- `rwda line <raw combat line>`
- `rwda replay <path-to-log-file>`
- `rwda replayassert <path> <expected_last_action> [min_actions]`
- `rwda replaysuite <path-to-suite-file>`
- `rwda clear target`
- `rwda reset`

## Operational notes
- Planner mode automatically follows form: human mode for Runewarden, dragon mode for dragonform.
- Execution defaults to Achaea server queueing (`queue addclear`), with `freestand` used for devour attempts.
- `rwda stop` sets a kill switch and can clear all server queues.
- `rwda explain` reports the last planned/sent action, while `rwda status` reports current tracked state (including target shield/rebounding flags).
- `rwda status` includes `tsrc` to show where target selection is currently coming from (`manual` vs `external`).
- Defence inference can mark uncertain drops as inactive with confidence; these display as `0(x.xx)` in `rwda status`.
- `rwda doctor` prints backend/handler diagnostics for Legacy wiring and parser capture settings.
- Planner decisions now route through strategy profiles (`duel`/`group`) with legacy fallbacks if strategy is disabled.
- Retaliation engine tracks all active aggressors: if two or more people are attacking simultaneously it holds the current target (no churn).  When the current target dies it automatically switches to whoever is still attacking.  Configure aggressor expiry with `config.retaliation.aggressor_ttl_ms` (default 20 s).
- Finisher engine tracks execute attempts (`disembowel`, `devour`), applies timeout/failure cooldown, and can force a configured fallback block for recovery.

## Known next steps
- Tune exact combat-line patterns from your own logs for highest-confidence limb and defence updates.
- Expand AK/group adapters once the exact API names are confirmed in your local packages.
- Package this into `.mpackage` from Mudlet once script order is verified in your profile.
- Run `rwda replaysuite tools/suite_strategy_retal_finisher.lua` against live Mudlet environment to confirm log patterns match your server output.
