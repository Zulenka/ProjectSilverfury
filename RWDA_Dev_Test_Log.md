# RWDA Development and Test Log

Last updated: 2026-02-27

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

## Open Tuning Items
- Adjust line patterns against your exact in-game output for:
  - defence text variants,
  - limb messaging variants,
  - kill/death announcements.
- Add “target present in room” guard (optional) to avoid queuing attacks on absent targets.

## Update Protocol (for future iterations)
For each new feature/test cycle, append:
1. Date.
2. What changed (files + behavior).
3. Commands used for test.
4. Expected vs actual result.
5. Follow-up actions.
