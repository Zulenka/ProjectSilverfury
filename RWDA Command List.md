# RWDA Command List

Auto-generated from rwda/ui/commands.lua.

Last generated: 2026-02-27 23:37:02 -05:00

## Runtime Commands

| Command | What It Does | Notes |
|---|---|---|
| rwda on | Enable RWDA offense engine. | - |
| rwda off | Disable RWDA offense engine. | - |
| rwda stop | Emergency stop; halts planner/executor and can clear queue. | - |
| rwda resume | Resume execution after stop. | - |
| rwda reload | Reload RWDA modules from disk. | - |
| rwda status | Print current runtime state snapshot. | - |
| rwda explain | Show reason/code for last planned action. | - |
| rwda tick | Run one planning/execution cycle immediately. | Equivalent alias: rwda attack. |
| rwda selftest | Run built-in offline planner regression tests. | - |
| rwda target <name> | Set combat target name. | - |
| rwda mode <auto|human|dragon> | Force or auto-select combat mode. | - |
| rwda goal <pressure|limbprep|impale_kill|dragon_devour> | Set planner goal. | - |
| rwda profile <duel|group> | Apply profile presets for mode/goal. | - |
| rwda debug <on|off> | Toggle verbose trace logging. | - |
| rwda set breath <type> | Set dragon summon breath type. | - |
| rwda set venoms <main> <off> | Set primary DSL venom pair. | - |
| rwda set autostart <on|off> | Toggle auto-enable with LegacyLoaded. | - |
| rwda set prompttick <on|off> | Toggle automatic tick on prompt. | - |
| rwda show config | Print current live RWDA config highlights. | - |
| rwda save config | Persist current RWDA config to disk. | - |
| rwda load config | Load persisted RWDA config from disk. | - |
| rwda line <text> | Feed one raw combat line into parser. | - |
| rwda replay <file> | Replay a combat log file through parser/planner. | - |
| rwda clear target | Clear target state and availability locks. | - |
| rwda reset | Reset RWDA state to defaults. | - |
| rwda queue clear | Clear all queued server commands. | Clears Achaea server queue (clearqueue all). |

## Extra Aliases

| Command | What It Does | Notes |
|---|---|---|
| rwda attack | Alias for rwda tick. | Hidden alias (not shown in help string). |

## Regenerate

Run:

~~~powershell
pwsh -File rwda/tools/generate_command_list.ps1
~~~

## Policy

- Supported alias prefix is rwda only.
- If a new command appears with "Description pending", add its description in rwda/tools/generate_command_list.ps1.
