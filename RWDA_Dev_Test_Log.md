# RWDA Development and Test Log

Last updated: 2026-02-28 (multi-attacker retaliation)

## Purpose
This file is the persistent reference for:
- Commands we use regularly.
- Configuration assumptions currently in use.
- Feature changes that were implemented.
- Validation steps and outcomes.

Use this as the source of truth during iterative feature work and testing.

## Baseline Paths and Loader
- RWDA root folder: `C:\Users\jness\Documents\Project Silverfury\ProjectSilverfury\rwda`
- Main loader script: `rwda/init.lua`
- Mudlet bootstrap package: `RWDA_Bootstrap.xml`

## Canonical Runtime Commands
- `rwda on`
- `rwda off`
- `rwda stop`
- `rwda resume`
- `rwda reload`
- `rwda status`
- `rwda explain`
- `rwda tick`
- `rwda target <name>`
- `rwda mode <auto|human|dragon>`
- `rwda goal <pressure|limbprep|impale_kill|dragon_devour>`
- `rwda profile <duel|group>`
- `rwda debug <on|off>`
- `rwda retaliate <on|off>`
- `rwda execute <on|off>`
- `rwda builder open`
- `rwda builder close`
- `rwda strategy show`
- `rwda strategy apply`
- `rwda strategy save`
- `rwda strategy load`
- `rwda set retalockms <ms>`
- `rwda set retaldebounce <ms>`
- `rwda set retalminconf <0-1>`
- `rwda set executecooldown <ms>`
- `rwda set executefallbackwindow <ms>`
- `rwda set executetimeout <disembowel|devour> <ms>`
- `rwda set executefallback <human|dragon> <block_id>`
- `rwda line <raw combat line>`
- `rwda replay <path-to-log-file>`
- `rwda clear target`
- `rwda reset`
- `rwda queue clear`

Compatibility alias:
- Removed. Only `rwda ...` is supported.

## Mudlet Load Commands
If needed for manual reload in Mudlet:

```lua
lua dofile([[C:\Users\jness\Documents\Project Silverfury\ProjectSilverfury\rwda\init.lua]])
lua if rwda and rwda.reload then rwda.reload() end
```

## Current Behavior Notes
- `rwda explain` shows the last planned/sent action reason.
- `rwda status` shows current tracked state; includes target defence flags:
  - `tshield`
  - `trebound`
- Planner choosing `dsl` while target is absent is expected if no target defences are tracked and the target is not currently visible.

## Implemented Feature Milestones

### 2026-02-27 - Initial RWDA system scaffold
Implemented:
- Full module tree under `rwda/`:
  - `config`, `state`, `data`, `engine`, `integrations`, `ui`, `tools`.
- SVO read-only integration (`affl`, `defc`, `bals` + `svo got/lost ...` events).
- Planner for:
  - Human dual-cut flow (shield/rebounding strip, DSL limb prep, impale branch).
  - Silver dragon flow (summon, strip, prone setup, rend pressure, devour check).
- Executor:
  - Achaea server queue dispatch.
  - Balance/equilibrium gating.
  - Anti-spam dedupe.
  - Stop safety valve.

Validation:
- Lua compile check passed.
- Runtime smoke test passed.

### 2026-02-27 - Parser and replay expansion
Implemented:
- Parser coverage improvements:
  - Bal/eq recovery/loss variants.
  - Shield/rebounding gain/loss variants.
  - Prone/standing.
  - Dragon form and breath states.
  - Impale/unimpale.
  - Limb broken/mangled detection.
  - Target death/movement events.
- Auto registration for:
  - `gmcp.Char.Vitals`
  - `sysPrompt`
  - `sysDataReceived` and `sysDataReceive`
  - Catch-all line trigger (`tempRegexTrigger`) when enabled.
- Replay harness:
  - `rwda/engine/replay.lua`
  - CLI utility `rwda/tools/replay_cli.lua`
  - sample log `rwda/tools/sample_replay.log`

Validation:
- Lua compile check passed (`23` files).
- Replay run produced actions as expected.

### 2026-02-27 - Target matching and hot reload fixes
Implemented:
- Trimmed target names in state and command parsing to avoid trailing-space mismatches.
- Added `rwda reload` support for live file refresh.
- Extended status output with target defence visibility (`tshield`, `trebound`).
- Temporarily accepted both command prefixes (later reverted):
  - `rwda ...`
  - `rwd ...`

Validation:
- Local parser smoke test confirmed:
  - `A shimmering shield surrounds bainz.` sets shield state.
  - Planner switched to shield-strip action.

### 2026-02-27 - Live session note: reload command not present in client
Observed in Mudlet:
- `rwda reload` printed command help without `reload` in the list.

Interpretation:
- Client was still running an older loaded module set (pre-reload feature).

Recovery steps used:
```lua
lua rwda = nil
lua dofile([[C:\Users\jness\Documents\Project Silverfury\ProjectSilverfury\rwda\init.lua]])
```

Expected after recovery:
- `rwda reload` appears in help output and works.

### 2026-02-27 - Missing target anti-spam lock
Issue:
- `rwda tick` kept queuing offense when target was not present (`You cannot see that being here.`, `You detect nothing here by that name.`).

Implemented:
- Added target availability state:
  - `target.available`
  - `target.unavailable_reason`
  - `target.unavailable_since`
- Parser now marks target unavailable on common “not here” lines and on target leaving room.
- Planner now hard-gates offensive action when target is unavailable (`target_unavailable` reason).
- Optional queue clear on missing target is enabled by config:
  - `combat.clear_queue_when_target_missing = true`
- `rwda status` now reports:
  - `tavail=yes|no`
  - `treason=<reason>`

Expected behavior:
- After a “target not here” message, RWDA stops sending attack commands until target is seen again (or target is reset/reselected).

### 2026-02-27 - GMCP room-presence pre-check
Goal:
- Prevent first stale attack send when target is already out of room but no “not here” line has been processed yet.

Implemented:
- Added `combat.require_room_presence_when_gmcp = true` (default).
- Parser checks `gmcp.Room.Players` before planning/sending:
  - If target is not in room list: `tavail=no`, `treason=gmcp_not_in_room`, no action planned.
  - If target appears in room list: availability unlocks automatically.
- Registered GMCP room handlers:
  - `gmcp.Room.Players`
  - `gmcp.Room.AddPlayer`
  - `gmcp.Room.RemovePlayer`

Validation:
- Synthetic Lua test:
  - Players without target => action `nil`, reason `gmcp_not_in_room`.
  - Players containing target => planner resumed (`dsl`).

### 2026-02-27 - Reduced auto behavior defaults
Change:
- Set `combat.auto_tick_on_prompt = false` by default.
- Set `parser.use_temp_line_trigger = false` by default.

Reason:
- Keep RWDA in explicit/manual tick mode by default.
- Avoid potential side effects from a global catch-all line trigger in mixed-script profiles.

Result:
- Parsing still works through GMCP and data-receive event handlers.
- Offense only fires when user explicitly calls `rwda tick` (unless user enables auto tick).

### 2026-02-27 - Migration to Legacy-first integration
Context:
- User requested migration away from SVO-centric runtime due maintenance concerns.

Implemented:
- Added `rwda/integrations/legacy.lua` adapter.
- RWDA bootstrap now prefers Legacy integration (`use_legacy = true` by default).
- SVO integration remains available as optional fallback (`use_svof = false` default).
- Parallel Legacy+SVO syncing is disabled by default (`allow_parallel_backends = false`) to avoid mixed-state conflicts.
- Legacy sync sources:
  - `Legacy.Curing.Affs`
  - `Legacy.Curing.Defs.current` (with tracking fallback)
  - `Legacy.Curing.bal`
  - GMCP vitals/aff/def events
- Prompt/tick sync now pulls Legacy state first.
- Config module rebuilt with per-key defaults so old in-memory tables do not block newly added keys.
- `rwda status` now reports active backend (`legacy`, `svof`, or `none`).

Operational expectation:
- RWDA offense runs alongside Legacy curing/defence stack without requiring SVO.

### 2026-02-27 - Runtime incident: alias missing while engine still active
Symptoms:
- Entering `rwda ...` reached server (`I'm sorry, I don't know what "rwda" does.`).
- Offense still queued from old active handlers.

Emergency stop:
```lua
CLEARQUEUE ALL
lua if rwda and rwda.stop then rwda.stop() end
```

Full recovery sequence:
```lua
lua if rwda and rwda.shutdown then rwda.shutdown() end
lua rwda = nil
lua dofile([[C:\Users\jness\Documents\Project Silverfury\ProjectSilverfury\rwda\init.lua]])
lua if rwda and rwda.bootstrap then rwda.bootstrap({load_files=true, base_path=[[C:\Users\jness\Documents\Project Silverfury\ProjectSilverfury\rwda]]}) end
lua if rwda and rwda.ui and rwda.ui.commands and rwda.ui.commands.registerAlias then rwda.ui.commands.registerAlias() end
```

Post-recovery verification:
1. `rwda status`
2. Confirm `tavail` and `treason` fields appear in status line (new code loaded).

### 2026-02-27 - Legacy backend late-init auto-attach
Issue observed:
- `rwda status` showed `backend=none` after RWDA loaded before Legacy fully initialized.

Implemented:
- `rwda/init.lua`
  - Legacy handlers are now registered whenever Legacy integration is enabled, even if Legacy is not present yet at bootstrap.
  - This ensures RWDA can receive `LegacyLoaded` and attach later.
- `rwda/engine/parser.lua`
  - Prompt handler now attempts backend attachment (Legacy first, SVO fallback) when backend is missing.
  - RWDA logs backend attach once detected.
- `rwda/integrations/legacy.lua`
  - Detection now tolerates early Legacy table initialization before `Legacy.Curing` is fully populated.

Validation steps:
1. `rwda reload`
2. Wait for at least one prompt line.
3. `rwda status`

Expected:
- `backend=legacy` once Legacy has initialized in-session.

### 2026-02-27 - Auto dragon-form detection from transformation text
Implemented:
- Added configurable parser text detection for form changes:
  - `config.parser.form_detect.enabled`
  - `config.parser.form_detect.dragon_on` (substring list)
  - `config.parser.form_detect.dragon_off` (substring list)
- Parser now auto-switches `form=dragon|human` when incoming combat text matches configured transformation lines.

Defaults include common lines such as:
- `you assume the form of a dragon`
- `you are now in dragonform`
- `you return to your lesser form`
- `you are no longer in dragonform`

Validation steps:
1. `rwda reload`
2. Trigger real dragon transformation in-game.
3. `rwda status`

Expected:
- Status `form` updates automatically from line text without manual mode changes.

### 2026-02-27 - Auto-generated RWDA command reference
Implemented:
- Added generator script: `rwda/tools/generate_command_list.ps1`
- Added generated command doc: `RWDA Command List.md`
- Generator reads `rwda/ui/commands.lua` help string and writes command syntax + descriptions + notes.
- Includes hidden alias note for `rwda attack` and includes `rwda queue clear`.

Usage:
```powershell
pwsh -File rwda/tools/generate_command_list.ps1
```

### 2026-02-27 - Auto-start RWDA with Legacy on login
Implemented:
- Added config flag: `config.integration.auto_enable_with_legacy = true` (default).
- On `LegacyLoaded`, RWDA now auto-enables when this flag is true.
- During bootstrap, if Legacy is already present, RWDA also auto-enables.

Toggle:
```lua
lua rwda.config.integration.auto_enable_with_legacy = false
```

### 2026-02-27 - Command-based live config controls
Implemented:
- Added runtime command controls in `rwda/ui/commands.lua`:
  - `rwda show config`
- `rwda set breath <type>`
- `rwda set venoms <main> <off>`
- `rwda set autostart <on|off>`
- `rwda set followlegacytarget <on|off>`
- `rwda set prompttick <on|off>`
- Help text updated to include new commands.
- README command list updated.
- Command-list generator mapping updated and regenerated.

Validation steps:
1. `rwda reload`
2. `rwda show config`
3. `rwda set breath lightning`
4. `rwda set venoms curare epteth`
5. `rwda set autostart on`
6. `rwda set prompttick off`
7. `rwda show config`

Expected:
- Config changes are reflected immediately in `rwda show config`.

### 2026-02-27 - Persistent config save/load
Implemented:
- Added config persistence methods in `rwda/config.lua`:
  - `rwda.config.savePersisted()`
  - `rwda.config.loadPersisted()`
  - `rwda.config.persistedExists()`
- Added bootstrap auto-load of persisted config in `rwda/init.lua` (when file exists and persistence auto-load is enabled).
- Added new commands:
  - `rwda save config`
  - `rwda load config`

Default persistence path:
- `<MudletHome>\\rwda_config.lua`

Validation steps:
1. `rwda set breath lightning`
2. `rwda set venoms curare epteth`
3. `rwda save config`
4. `rwda reload`
5. `rwda load config` (optional, bootstrap auto-load also applies)
6. `rwda show config`

Expected:
- Saved settings remain after reload/reconnect.

### 2026-02-27 - Built-in offline selftest harness
Implemented:
- Added module: `rwda/engine/selftest.lua`
- Added command: `rwda selftest`
- Added selftest coverage for:
  - human shield-strip choice (`razeslash`)
  - dragon summon-first choice (`summon`)
  - dragon prone setup (`gust`)
  - dragon fast devour window (`devour`)
  - unavailable target offense hold (`target_unavailable`)

Usage:
```lua
rwda selftest
```

Expected:
- Command prints pass/fail counts and one line per test case.

### 2026-02-27 - Group target adapter event hooks
Implemented:
- Added configurable event names in `config.integration.group_target_events`.
- `rwda/integrations/groupcombat.lua` now supports:
  - `registerHandlers()`
  - `unregisterHandlers()`
  - event callback sync (`onTargetEvent`)
- Bootstrap now registers group handlers when group layer is enabled.
- Tick path now supports late attachment to group target backend and logs attach.

Default watched event names:
- `GroupTargetChanged`
- `group target changed`
- `gcom target changed`
- `ga target changed`

### 2026-02-27 - Mudlet package build script
Implemented:
- Added `rwda/tools/build_mpackage.ps1`.
- Script builds `dist/RWDA_Bootstrap.mpackage` from:
  - `RWDA_Bootstrap.xml`
  - generated package `config.lua` metadata

Usage:
```powershell
pwsh -File rwda/tools/build_mpackage.ps1
```

### 2026-02-27 - Defence confidence inference (assumed drops)
Implemented:
- Added parser inference controls in `rwda/config.lua`:
  - `config.parser.infer_defence_loss_on_aggressive = true`
  - `config.parser.infer_defence_loss_on_move = true`
  - `config.parser.inferred_defence_confidence = 0.35`
- Parser now infers defence loss when target performs likely aggressive acts:
  - drops shield/rebounding to inactive with partial confidence (source `assumed_aggressive`)
- Parser now infers shield loss on target movement lines (source `assumed_move`), while keeping rebounding active on move.
- `rwda status` now shows inactive defence confidence as `0(<confidence>)`.
- Defence confidence decay now applies to both active and inactive tracked defences over `decay_seconds`.

Validation:
- Extended `rwda selftest` with inference checks:
  - aggressive line drops shield/rebounding by assumption
  - move line drops shield but not rebounding

### 2026-02-28 - Legacy-only runtime (SVO removed)
Implemented:
- Removed SVO integration module from RWDA load graph.
- Deleted `rwda/integrations/svof.lua`.
- Removed SVO runtime attach/sync/unregister code paths from bootstrap/tick/prompt handlers.
- Removed SVO/parallel backend settings from active config surface.
- Forced `config.integration.use_legacy = true` after defaults and persisted config loads.
- Updated status/config output and README wording to Legacy-only behavior.

Result:
- RWDA now explicitly uses Legacy as the only backend source.

### 2026-02-28 - Diagnostics, unmatched capture logging, replay assertions
Implemented:
- Added diagnostics module: `rwda/engine/doctor.lua`
  - New command: `rwda doctor`
  - Reports Legacy presence, backend flags, handler registration counts, runtime status, and parser capture settings.
- Added parser unmatched-line capture:
  - Config:
    - `config.parser.capture_unmatched_lines`
    - `config.parser.capture_unmatched_path`
    - `config.parser.capture_unmatched_include_prompts`
  - New set commands:
    - `rwda set capture <on|off>`
    - `rwda set captureprompts <on|off>`
    - `rwda set capturepath <path>`
  - Unmatched lines are appended to configured file (`<MudletHome>\\rwda_unmatched.log` by default).
- Added replay assertion mode:
  - `rwda.engine.replay.runFileWithAssertions(...)`
  - New command:
    - `rwda replayassert <path> <expected_last_action> [min_actions]`

Validation:
- `luac -p` passed.
- CLI selftest passed.
- Replay CLI passed.

### 2026-02-28 - Replay assertion suite runner
Implemented:
- Added replay suite API:
  - `rwda.engine.replay.runSuite(path)`
- Added command:
  - `rwda replaysuite <path-to-suite-file>`
- Added sample suite file:
  - `rwda/tools/sample_replay_suite.lua`

Suite format:
- Lua file returning `{ cases = { ... } }`
- Per case:
  - `name`
  - `log`
  - `target` (optional)
  - `assertions` (optional)

Validation:
- Sample suite passes against `rwda/tools/sample_replay.log`.

### 2026-02-28 - Legacy target-follow hardening and AK/LB adapter expansion
Implemented:
- Added target source tracking in RWDA state (`target_source`) and surfaced it in:
  - `rwda status` as `tsrc=<manual|external>`
  - `rwda doctor` runtime line.
- Group/target adapter now ingests additional external target feeds:
  - Legacy/global `target`
  - `gmcp.IRE.Target.Set`
  - `gmcp.IRE.Target.Info`
  - `LPrompt` refresh events
  - existing group events.
- Added guard logic so external target sync will not override a manually diverged RWDA target unexpectedly.
- Added runtime toggle:
  - `rwda set followlegacytarget <on|off>`
  - persisted in config save/load.
- Expanded AK adapter coverage:
  - Detects `ak`, `aklimb`, and `lb`.
  - Imports target defence booleans from `ak.defs` (`shield`, `rebounding`).
  - Attempts limb snapshot ingest from multiple AK/LB table shapes and `lb.prompt()` key/value output.

Validation:
- `luac -p` passed all RWDA Lua files (`26` files).
- `rwda.engine.selftest.run()` passed (`9/9`).
- Replay assertion sample passed (`expected_last_action=dsl`, `min_actions=1`).
- Replay suite sample passed (`1/1`).

### 2026-02-28 - Phase A strategy core (schema + resolver + planner refactor)
Implemented:
- Added strategy preset data module:
  - `rwda/data/strategy_presets.lua`
  - Profiles: `duel`, `group`
  - Per-mode block lists: `runewarden`, `dragon` with priority + condition tokens.
- Added strategy resolver engine:
  - `rwda/engine/strategy.lua`
  - Bootstraps config strategy defaults from presets
  - Resolves profile based on runtime profile
  - Evaluates simple condition DSL tokens (`target.def.*`, `goal.*`, `not ...`, etc.)
  - Selects highest-priority enabled matching block.
- Refactored planner to strategy-driven selection:
  - `rwda/engine/planner.lua`
  - Human and dragon decision paths now select action block via strategy engine.
  - Existing behavior preserved by default strategy profile values.
  - Legacy fallback branch preserved when strategy is disabled or unresolved.
- Bootstrap/load graph updates:
  - `rwda/init.lua` now loads strategy preset/engine modules and bootstraps strategy state.
- Config persistence updates:
  - `rwda/config.lua` now persists `config.strategy`.
- Diagnostics updates:
  - `rwda/engine/doctor.lua` now reports strategy status/version/profile.
- Selftest updates:
  - Added checks for strategy block tagging and fallback behavior when strategy is disabled.

Validation:
- `luac -p` passed all RWDA Lua files (`28` files after module additions).
- `rwda.engine.selftest.run()` passed with strategy and fallback coverage.
- Replay assertion sample passed.
- Replay suite sample passed.

### 2026-02-28 - Phase B auto-retaliation engine and aggressor wiring
Implemented:
- Added retaliation engine:
  - `rwda/engine/retaliation.lua`
  - Event subscription to parser aggressor signal (`AGGRESSOR_HIT`)
  - Target lock state with:
    - lock duration (`lock_ms`)
    - swap debounce (`swap_debounce_ms`)
    - confidence gating (`min_confidence`)
    - optional previous-target restore on lock expiry.
- Added parser aggressor extraction:
  - `rwda/engine/parser.lua`
  - Emits `AGGRESSOR_HIT` on incoming hostile lines addressed to player.
  - Prompt loop now advances retaliation expiry/restore state.
- Runtime integration updates:
  - `rwda/init.lua` now loads/bootstraps retaliation engine.
  - Tick loop now calls retaliation update to handle lock expiry and restore.
  - Shutdown unregisters retaliation event handler.
- Config + persistence:
  - Added `config.retaliation` defaults and persistence in `rwda/config.lua`.
- Command surface additions:
  - `rwda retaliate <on|off>`
  - `rwda set retalockms <ms>`
  - `rwda set retaldebounce <ms>`
  - `rwda set retalminconf <0-1>`
- Diagnostics updates:
  - `rwda doctor` now prints retaliation status (enabled/locked/current aggressor/reason).
- Selftest expansion:
  - Added retaliation coverage:
    - retarget on aggressor
    - lock status accuracy
    - restore previous target after expiry
    - disabled-state guard (no target swap).

Validation:
- `luac -p` passed all RWDA Lua files.
- `rwda.engine.selftest.run()` passed with retaliation cases included.
- Replay assertion sample passed.
- Replay suite sample passed.

### 2026-02-28 - Phase C auto execute lifecycle + fallback routing
Implemented:
- Added/expanded finisher execution lifecycle (`rwda/engine/finisher.lua`):
  - Tracks `disembowel` and `devour` attempts from `ACTION_SENT`.
  - Marks success/failure from parser events.
  - Applies execute cooldown and fallback forcing windows after failure/timeout.
  - Clears fallback state when configured fallback block is sent.
- Planner integration:
  - `rwda/engine/planner.lua` now checks finisher fallback recommendations first for both human and dragon modes.
  - Selected fallback actions are tagged in reason payload (`finisher_fallback=true`).
- Prompt integration:
  - `rwda/engine/parser.lua` prompt handler now advances finisher state (`update()`).
- Config + persistence:
  - Added persisted `config.finisher` defaults and save/load support in `rwda/config.lua`.
- Command surface:
  - `rwda execute <on|off>`
  - `rwda set executecooldown <ms>`
  - `rwda set executefallbackwindow <ms>`
  - `rwda set executetimeout <disembowel|devour> <ms>`
  - `rwda set executefallback <human|dragon> <block_id>`
- Diagnostics:
  - `rwda status` now includes execute state flags (`execute`, `eactive`, `efallback`).
  - `rwda doctor` now includes finisher lifecycle status line.
- Selftest expansion:
  - Added execute/fallback cases for:
    - human disembowel failure forcing DSL fallback
    - fallback clear after fallback action send
    - dragon devour timeout forcing configured fallback
    - execute-disabled guard

### 2026-02-28 - Phase D popout combat builder UI + Phase E replay suite expansion

Implemented:
- Added combat builder view model: `rwda/ui/combat_builder_state.lua`
  - Open/close/apply/revert lifecycle around working copy of strategy/retaliation/finisher config.
  - Block enable/priority mutation helpers.
  - summaryLines() for strategy show command.
- Added combat builder Geyser UI: `rwda/ui/combat_builder.lua`
  - `Geyser.Window` (520×440px) with:
    - Close button, 4 tab headers (Runewarden / Dragon / Shared / Safety),
    - Action bar: Apply, Save, Revert buttons + live Retaliate/Execute toggles.
    - `Geyser.MiniConsole` content area; clickable [ON/OFF] and [+]/[-] per strategy block via `echoLink`.
  - Lazy init: no Geyser widgets created until `builder.open()` is first called (safe offline).
  - Shutdown method unregisters and clears all widget references.
- New commands:
  - `rwda builder open|close`
  - `rwda strategy show|apply|save|load`
- Bootstrap and shutdown wired into `rwda/init.lua`.
- `ui/combat_builder_state.lua` and `ui/combat_builder.lua` added to init FILES load list.
- Added `pre_state` case support to `rwda/engine/replay.lua` suite runner:
  - Per-case `goal`, `mode`, `retaliate`, `execute` settings applied after state reset.
- Added 5 new replay log files:
  - `rwda/tools/replay_dragon_shield_to_devour.log`
  - `rwda/tools/replay_dragon_devour_fail.log`
  - `rwda/tools/replay_rw_impale_disembowel.log`
  - `rwda/tools/replay_rw_disembowel_fail.log`
  - `rwda/tools/replay_retaliation_switch.log`
- Added new replay suite:
  - `rwda/tools/suite_strategy_retal_finisher.lua` — 5 cases covering the full strategy/finisher/retaliation feature surface.
- Updated docs:
  - `RWDA Command List.md` — builder and strategy rows added.
  - `rwda/README.md` — UI module mentioned, builder commands listed.

Validation steps (to run against live Mudlet):
1. `rwda reload`
2. `rwda selftest` — expect all tests to pass.
3. `rwda builder open` — expect popout UI to open with correct tab labels and block list.
4. Toggle a block in the Runewarden tab, click Apply, `rwda strategy show` — verify change.
5. `rwda replaysuite tools/suite_strategy_retal_finisher.lua` — expect 5/5 passed.
   (Note: log files use parser patterns that should match default config.  If any case fails
   with a wrong last_action, cross-check the line text against your in-game output and update
   the corresponding log file.)

### 2026-02-28 - Multi-attacker retaliation hold + target-dead auto-switch

Changed behavior in `rwda/engine/retaliation.lua`:

**Multi-attacker hold:**
- Retaliation now tracks every validated aggressor in `rt.active_aggressors[key] = { name, last_hit_ms }`.
- On each hit, stale entries (older than `aggressor_ttl_ms`, default 20 s) are pruned.
- If 2 or more unique aggressors are active, the system **suppresses target switching** (`last_reason = "multi_attacker_hold"`) and stays on the current target.
- Single attacker: existing debounce/lock behavior unchanged.

**Target-dead auto-switch:**
- Retaliation now subscribes to the `TARGET_DEAD` event (`onTargetDead`).
- On target death: dead player is removed from `active_aggressors`, lock is cleared, and the most-recently-hitting remaining aggressor is automatically retargeted.
- The dead player is NOT saved as `previous_target` (no restore-to-dead on lock expiry).

New config key:
- `config.retaliation.aggressor_ttl_ms` — time (ms) since last hit before an aggressor is pruned from the active list.  Default: `20000`.

New `rwda status` fields (from `retaliation.status()`):
- `active_aggressor_count` — count of currently active aggressors
- `active_aggressors` — sorted list of active aggressor names

Updated selftest: 2 new cases:
- `multi-attacker hold keeps current target`
- `target-dead switch auto-targets remaining aggressor`

New replay logs:
- `rwda/tools/replay_retaliation_multi_attacker.log`
- `rwda/tools/replay_retaliation_dead_switch.log`

Updated suite (`rwda/tools/suite_strategy_retal_finisher.lua`): now 7 cases (+2).

Validation steps:
1. `rwda reload`
2. `rwda selftest` — expect 2 additional passing cases
3. `rwda replaysuite tools/suite_strategy_retal_finisher.lua` — expect 7/7
4. In-game: have two players attack you — confirm RWDA holds on original target.
5. Kill primary; confirm RWDA auto-switches to the remaining attacker.

### 2026-03-01 - Live Mudlet validation: Phase E sign-off

Issues found and fixed during live testing:

**selftest: 4 retaliation cases failed in live Mudlet**
- Root cause: `ignore_non_players=true` (default) blocked fictional test names (Raijin, Kayde) because `gmcp.Room.Players` was a real table with real room data; `inRoomByGMCP` returned `false` → `not_in_room`.
- Fix: `resetBaseline()` in `selftest.lua` now sets `ignore_non_players = false` before each test.

**replaysuite path errors**
- `rwda replaysuite` and the log paths inside `suite_strategy_retal_finisher.lua` used `rwda/tools/` prefix, but `rwda.base_path` already points to the `rwda/` directory (doubling the prefix).
- Fix: `commands.lua` now resolves relative paths against `rwda.base_path`; suite `BASE` corrected to `"tools/"`.

**replaysuite: 0 actions per case (files opened but no ticks fired)**
- Root cause: `rwda.tick()` called `syncFromGlobals()` (clobbering replay state with live Legacy data) and `refreshTargetAvailabilityFromGMCP()` (marking replay targets unavailable since they weren't in the real room).
- Fix: `replay.runLines()` now uses a local `replayTick()` that bypasses all live-game state sync and GMCP checks, and saves/restores `require_room_presence_when_gmcp` and `ignore_non_players` for the duration of the replay.

**replaysuite: 2 fallback cases failed (action=devour/disembowel instead of fallback)**
- Root cause 1: `replayTick()` did not emit `ACTION_SENT`, so the finisher never started tracking the execute attempt and couldn't detect the failure line.
- Fix: `replayTick()` now emits `ACTION_SENT` after choosing an action.
- Root cause 2: Finisher fallback blocks in the planner had their condition evaluated; `dragon_force_prone` condition `not target.prone` was false (target already prone after the damage burst), so the fallback silently produced no action and normal strategy re-chose devour.
- Fix: Planner now force-sets `when = {"always"}` on the fallback block copy before passing it to the action builder, bypassing the condition unconditionally.

**Final validation results (2026-03-01)**
- `rwda selftest`: passed=23 failed=0 total=23
- `rwda replaysuite tools/suite_strategy_retal_finisher.lua`: passed=7 failed=0 total=7
- `rwda doctor`: Legacy/GMCP/strategy/retaliation/finisher all reporting correctly.
- `rwda builder open`: Geyser popout opened with correct tabs and block list.

Phase E complete. All automated tests passing in live Mudlet.

## Open Tuning Items
- Adjust line patterns against your exact in-game output for:
  - defence text variants,
  - limb messaging variants,
  - kill/death announcements.
- Capture one or two live dumps of `ak`/`lb` table shape to tighten limb adapter parsing confidence and key mapping.

## Update Protocol (for future iterations)
For each new feature/test cycle, append:
1. Date.
2. What changed (files + behavior).
3. Commands used for test.
4. Expected vs actual result.
5. Follow-up actions.
