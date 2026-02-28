# RWDA Command List

Auto-generated from rwda/ui/commands.lua.

Last generated: 2026-02-27 17:19:46 -05:00

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
| rwda target <name> | Set combat target name. | - |
| rwda mode <auto|human|dragon> | Force or auto-select combat mode. | - |
| rwda goal <pressure|limbprep|impale_kill|dragon_devour> | Set planner goal. | - |
| rwda profile <duel|group> | Apply profile presets for mode/goal. | - |
| rwda debug <on|off> | Toggle verbose trace logging. | - |
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
