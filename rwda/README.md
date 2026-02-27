# RWDA (Runewarden + Silver Dragon AI)

This directory contains a Mudlet Lua combat brain that runs alongside SVO.

## What it includes
- Canonical state model (`rwda/state/*`) for self, target, cooldowns, and runtime flags.
- Data dictionaries (`rwda/data/*`) for core afflictions, defences, abilities, and venoms.
- Engine modules (`rwda/engine/*`) for events, parsing, planning, server-queue execution, and safety controls.
- Integrations (`rwda/integrations/*`) for SVO (active), AK limb tracker (adapter stub), and group combat target sync (adapter stub).
- Command UI (`rwda/ui/commands.lua`) with `rwda` alias controls.
- Replay harness (`rwda/engine/replay.lua`) for log-driven parser/planner validation.

## SVO integration
The SVO adapter is read-only by default and uses globals/events present in your package:
- Globals: `affl`, `defc`, `bals`
- Events: `svo got aff`, `svo lost aff`, `svo got def`, `svo lost def`, `svo got balance`, `svo lost balance`, `svo got dragonform`, `svo lost dragonform`

RWDA does not send herb/salve/sip cures when SVO is active.

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

## Commands
- `rwda on`
- `rwda off`
- `rwda stop`
- `rwda resume`
- `rwda target <name>`
- `rwda mode <auto|human|dragon>`
- `rwda goal <pressure|limbprep|impale_kill|dragon_devour>`
- `rwda status`
- `rwda explain`
- `rwda tick`
- `rwda queue clear`
- `rwda line <raw combat line>`
- `rwda replay <path-to-log-file>`
- `rwda clear target`
- `rwda reset`

## Operational notes
- Planner mode automatically follows form: human mode for Runewarden, dragon mode for dragonform.
- Execution defaults to Achaea server queueing (`queue addclear`), with `freestand` used for devour attempts.
- `rwda stop` sets a kill switch and can clear all server queues.

## Known next steps
- Tune exact combat-line patterns from your own logs for highest-confidence limb and defence updates.
- Expand AK/group adapters once the exact API names are confirmed in your local packages.
- Package this into `.mpackage` from Mudlet once script order is verified in your profile.
