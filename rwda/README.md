# RWDA (Runewarden + Silver Dragon AI)

This directory contains a Mudlet Lua combat brain that runs alongside Legacy.

Project log:
- `RWDA_Dev_Test_Log.md` at repo root tracks commands, configuration decisions, feature milestones, and test outcomes.

## What it includes
- Canonical state model (`rwda/state/*`) for self, target, cooldowns, and runtime flags.
- Data dictionaries (`rwda/data/*`) for core afflictions, defences, abilities, and venoms.
- Engine modules (`rwda/engine/*`) for events, parsing, planning, server-queue execution, and safety controls.
- Integrations (`rwda/integrations/*`) for Legacy (primary), AK limb tracker (adapter stub), and group combat target sync (adapter stub).
- Command UI (`rwda/ui/commands.lua`) with `rwda` alias controls.
- Replay harness (`rwda/engine/replay.lua`) for log-driven parser/planner validation.

## Legacy integration (primary)
The Legacy adapter is read-only by default and uses runtime state/events present in Legacy:
- Globals: `Legacy`, `Legacy.Curing.Affs`, `Legacy.Curing.Defs.current`, `Legacy.Curing.bal`
- Events: `LegacyLoaded`, `gmcp.Char.Afflictions.Add/Remove`, `gmcp.Char.Defences.Add/Remove`, `gmcp.Char.Vitals`

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
- `rwda explain`
- `rwda tick`
- `rwda selftest`
- `rwda show config`
- `rwda set breath <type>`
- `rwda set venoms <main> <off>`
- `rwda set autostart <on|off>`
- `rwda set prompttick <on|off>`
- `rwda queue clear`
- `rwda save config`
- `rwda load config`
- `rwda line <raw combat line>`
- `rwda replay <path-to-log-file>`
- `rwda clear target`
- `rwda reset`

## Operational notes
- Planner mode automatically follows form: human mode for Runewarden, dragon mode for dragonform.
- Execution defaults to Achaea server queueing (`queue addclear`), with `freestand` used for devour attempts.
- `rwda stop` sets a kill switch and can clear all server queues.
- `rwda explain` reports the last planned/sent action, while `rwda status` reports current tracked state (including target shield/rebounding flags).
- Defence inference can mark uncertain drops as inactive with confidence; these display as `0(x.xx)` in `rwda status`.

## Known next steps
- Tune exact combat-line patterns from your own logs for highest-confidence limb and defence updates.
- Expand AK/group adapters once the exact API names are confirmed in your local packages.
- Package this into `.mpackage` from Mudlet once script order is verified in your profile.
