# RWDA Command List

Auto-generated from rwda/ui/commands.lua.

Last generated: 2026-02-28 (updated manually — builder/strategy commands added)

## Runtime Commands

| Command | What It Does | Notes |
|---|---|---|
| rwda on | Enable RWDA offense engine. | - |
| rwda off | Disable RWDA offense engine. | - |
| rwda stop | Emergency stop; halts planner/executor and can clear queue. | - |
| rwda resume | Resume execution after stop. | - |
| rwda reload | Reload RWDA modules from disk. | - |
| rwda status | Print current runtime state snapshot. | - |
| rwda doctor | Run Legacy/backend/handler diagnostics. | - |
| rwda explain | Show reason/code for last planned action. | - |
| rwda tick | Run one planning/execution cycle immediately. | Equivalent alias: rwda attack. |
| rwda engage <name> | Set target, enable offense, and fire the first tick in one command. | Shorthand for rwda target + rwda on + rwda tick. |
| rwda selftest | Run built-in offline planner regression tests. | - |
| rwda target <name> | Set combat target name. | - |
| rwda mode <auto|human|dragon> | Force or auto-select combat mode. | - |
| rwda goal <pressure|limbprep|impale_kill|dragon_devour> | Set planner goal. | - |
| rwda profile <duel|group> | Apply profile presets for mode/goal. | - |
| rwda debug <on|off> | Toggle verbose trace logging. | - |
| rwda retaliate <on|off> | Toggle auto-retaliation target lock on aggressor hits. | - |
| rwda execute <on|off> | Toggle auto execute/finisher lifecycle automation. | - |
| rwda builder open | Open the combat strategy popout UI. | Requires Geyser (Mudlet). |
| rwda builder close | Close the combat strategy popout UI. | - |
| rwda strategy show | Print active strategy profile summary (live config). | - |
| rwda strategy apply | Apply pending builder changes to live config. | - |
| rwda strategy save | Apply and persist strategy to disk. | - |
| rwda strategy load | Load strategy from disk and apply to state. | - |
| rwda set breath <type> | Set dragon summon breath type. | - |
| rwda set venoms <main> <off> | Set primary DSL venom pair. | - |
| rwda set autostart <on|off> | Toggle auto-enable with LegacyLoaded. | - |
| rwda set followlegacytarget <on|off> | Toggle RWDA target-follow from Legacy/global target feeds. | - |
| rwda set prompttick <on|off> | Toggle automatic tick on prompt. | - |
| rwda set retalockms <ms> | Set retaliation lock duration in milliseconds. | - |
| rwda set retaldebounce <ms> | Set minimum milliseconds between retaliation target swaps. | - |
| rwda set retalminconf <0-1> | Set minimum aggressor detection confidence for auto-retaliation. | - |
| rwda set executecooldown <ms> | Set execute attempt cooldown in milliseconds. | - |
| rwda set executefallbackwindow <ms> | Set fallback forcing window after failed execute. | - |
| rwda set executetimeout <disembowel|devour> <ms> | Set execute timeout per finisher action. | - |
| rwda set executefallback <human|dragon> <block_id> | Set fallback strategy block ID for human/dragon execute failure. | - |
| rwda set capture <on|off> | Toggle unmatched-line capture logging. | - |
| rwda set captureprompts <on|off> | Include prompt lines in unmatched capture log. | - |
| rwda set capturepath <path> | Set unmatched capture log file path. | - |
| rwda show config | Print current live RWDA config highlights. | - |
| rwda save config | Persist current RWDA config to disk. | - |
| rwda load config | Load persisted RWDA config from disk. | - |
| rwda line <text> | Feed one raw combat line into parser. | - |
| rwda replay <file> | Replay a combat log file through parser/planner. | - |
| rwda replayassert <file> <expected_last_action> [min_actions] | Replay with assertions and fail details. | - |
| rwda replaysuite <suite_file> | Run a multi-case replay assertion suite file. | - |
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
