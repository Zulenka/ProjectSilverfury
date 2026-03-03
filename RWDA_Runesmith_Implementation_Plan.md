# RWDA Runesmith Implementation Plan

**Scope:** Automated weapon and armour empowerment workflows + named rune configuration presets tied to combat goals.

---

## Overview

Three interlocking additions:

1. **`data/rune_configs.lua`** — Named presets: each defines a core rune, configuration runes (= empower priority order), associated RWDA profile/goal, and ink costs.
2. **`engine/runesmith.lua`** — State-machine that issues `SKETCH` and `EMPOWER` commands with proper delays, waits for confirmation from the parser before advancing each step.
3. **Parser + commands wiring** — Confirmation patterns for sketch/empower success/failure; a `rwda runesmith` command tree to select presets and launch workflows.

---

## Phase 1 — `data/rune_configs.lua` (NEW FILE)

### Preset table structure

```lua
rune_configs.presets["kena_lock"] = {
  name           = "kena_lock",
  description    = "Pithakhan mana drain + Kena impatience lock",
  profile_hint   = "kena_lock",   -- RWDA profile to switch to when this config is applied
  goal_hint      = "impale_kill",
  core_rune      = "pithakhan",
  config_runes   = { "kena", "sleizak", "inguz" },  -- Also empower priority order
  weapon_runes   = { "lagul", "lagua", "laguz" },   -- Always required for runeblades
  notes          = "Wield in LEFT hand. Head-focused DSL for guaranteed Pithakhan proc.",
  ink_cost       = { red = 4, purple = 3 },         -- Pre-computed summary
}
```

### Presets to build

| Preset | Core | Config runes | Empower cascade | RWDA profile/goal | Ink (summary) |
|---|---|---|---|---|---|
| `kena_lock` | Pithakhan | Kena, Sleizak, Inguz | Impatience → nausea → cracked ribs | `kena_lock` / `impale_kill` | 3P 4R |
| `sleep_lock` | Pithakhan | Fehu, Kena, Inguz | Sleep → impatience → cracked ribs | `kena_lock` / `impale_kill` | 3P 3R |
| `mana_crush` | Pithakhan | Kena, Mannaz, Fehu | Impatience → mana regen block → sleep | `kena_lock` / `pressure` | 3P 3R |
| `fracture_drain` | Pithakhan | Sowulu, Kena, Inguz | Healthleech+fracture relapse → impatience → cracked ribs | `kena_lock` / `impale_kill` | 3P 3R |
| `ribs_burst` | Pithakhan | Inguz, Wunjo, Kena | Cracked ribs → rib-burst damage → impatience | `kena_lock` / `impale_kill` | 3P 3R |
| `arm_break` | Hugalaz | Tiwaz, Kena, Inguz | Break both arms → impatience → cracked ribs | `kena_lock` / `impale_kill` | 3P 1B 2R, 1B empower |
| `epilepsy_sleep` | Eihwaz | Isaz, Fehu, Kena | Epilepsy → sleep → impatience | `head_focus` / `pressure` | 3P+1B+1Y, 2B 2R |
| `voyria_pressure` | Nairat | Sleizak, Fehu, Kena | Nausea/voyria → sleep → impatience | `head_focus` / `pressure` | 3P 1Y 2B 1R |
| `bisect_finish` | Hugalaz | Kena, Inguz, Sleizak | Impatience → cracked ribs → nausea | `kena_lock` (bisect=on) / `impale_kill` | 3P 1B 4R 1B |
| `runicarmour` | *(armour, no core)* | *(none)* | n/a | n/a | 2 Gold |

> **Ink key:** R=red, B=blue, Y=yellow, P=purple, G=gold.

### Helper functions to expose

```lua
rune_configs.get(name)              -- returns preset table or nil
rune_configs.list()                 -- returns array of all preset names
rune_configs.inkCost(name)          -- returns {red=N, blue=N, ...} summary
rune_configs.forGoal(goal)          -- returns presets compatible with a goal
rune_configs.allWeaponRunes(name)   -- ordered list: lagul, lagua, laguz, core, config_runes
```

---

## Phase 2 — `engine/runesmith.lua` (NEW FILE)

### Responsibilities

- Issue `SKETCH` and `EMPOWER` commands in the correct order, one at a time, with configurable inter-step delays.
- Wait for parser confirmation before advancing (no blind timer spraying).
- Handle failure cases (missing ink, missing eq, wrong item).
- Emit `RUNESMITH_STEP_DONE`, `RUNESMITH_DONE`, and `RUNESMITH_FAILED` events so other systems can react.

### State machine

```
idle
  └─ beginWeapon(ref, configName)  ──►  sketching_baseline
                                            SKETCH LAGUL ON <ref>  ──► (confirm) ──►
                                            SKETCH LAGUA ON <ref>  ──► (confirm) ──►
                                            SKETCH LAGUZ ON <ref>  ──► (confirm) ──►
                                        sketching_core
                                            SKETCH <core> ON <ref>  ──► (confirm) ──►
                                        empowering_weapon
                                            EMPOWER <ref>  ──► (confirm) ──►
                                        sketching_config
                                            SKETCH CONFIGURATION <ref> <r1> <r2> <r3>  ──► (confirm) ──►
                                        setting_priority
                                            EMPOWER PRIORITY SET <r1> <r2> <r3>  ──► (confirm) ──►
                                        done

  └─ beginArmour(ref)  ──►           sketching_gebu
                                            SKETCH GEBU ON <ref>  ──► (confirm) ──►
                                        sketching_gebo
                                            SKETCH GEBO ON <ref>  ──► (confirm) ──►
                                        empowering_armour
                                            EMPOWER <ref>  ──► (confirm) ──►
                                        done

  └─ beginConfigure(ref, configName) ──► sketching_config  (skips baseline + empower)
                                            SKETCH CONFIGURATION <ref> <r1> <r2> <r3>  ──► (confirm) ──►
                                        setting_priority
                                            EMPOWER PRIORITY SET <r1> <r2> <r3>  ──► (confirm) ──►
                                        done
```

### Key internals

```lua
local sm = {
  state       = "idle",       -- current state machine step
  work_ref    = nil,          -- item reference string (e.g., "runeblade", "left", "scimitar")
  config_name = nil,          -- chosen preset name
  step_index  = 0,            -- index into pending steps table
  steps       = {},           -- ordered list of {cmd, confirm_pattern, fail_patterns}
  step_delay  = 0.8,          -- seconds between steps (configurable)
  _timer      = nil,          -- active tempTimer handle
}
```

Each step record:
```lua
{ cmd = "sketch lagul on runeblade",
  confirm = "You sketch the lagul rune onto",
  fail    = { "You need more equilibrium", "You don't have any purple ink", "You aren't holding" } }
```

The parser calls `runesmith.onLine(line)` each trigger. If the line matches the current step's `confirm`, advance. If it matches a `fail` pattern, call `runesmith.fail(reason)`.

### Public API

```lua
runesmith.beginWeapon(ref, configName)    -- full weapon workflow (sketch baseline → core → empower → configure)
runesmith.beginArmour(ref)                -- armour workflow (sketch gebu+gebo → empower)
runesmith.beginConfigure(ref, configName) -- config-only (for already-empowered runeblade)
runesmith.cancel()                        -- abort, clear timer
runesmith.status()                        -- print current state to RWDA log
runesmith.bootstrap()                     -- init (called from init.lua)
```

### Configuration defaults (`config.runesmith`)

```lua
config.runesmith = {
  step_delay_ms   = 800,    -- ms between sketch commands
  auto_switch_profile = true,  -- apply profile_hint from preset when done
  auto_sync_runelore  = true,  -- auto-call 'rwda runelore core/config' when done
}
```

---

## Phase 3 — `engine/parser.lua` modifications

### New patterns to add (at end of `handleLine`, before `captureUnmatchedLine`)

| Pattern | Handler |
|---|---|
| `"You sketch the (%a+) rune onto"` | `runesmith.onSketchConfirmed(rune)` |
| `"You empower your (%a+)"` | `runesmith.onEmpowerConfirmed(target)` |
| `"You set the empowerment priority"` | `runesmith.onPrioritySet()` |
| `"You don't have any (%a+) ink"` | `runesmith.onInkMissing(colour)` |
| `"You need more equilibrium"` | `runesmith.onEqNeeded()` |
| `"You aren't holding"` | `runesmith.onItemNotHeld()` |
| `"That is not a runeblade"` | `runesmith.onNotRuneblade()` |

All handlers resolve to `runesmith.onLine(line)` — the state machine checks whether the line matches the current step's confirm/fail rather than each handler being independently aware of step state.

---

## Phase 4 — `ui/commands.lua` additions

### New command tree: `rwda runesmith` (alias `rwda rs`)

| Command | What it does |
|---|---|
| `rwda runesmith list` | Print all preset names with core rune, goal hint, and ink cost |
| `rwda runesmith info <preset>` | Full detail: runes, empower order, ink cost, notes |
| `rwda runesmith weapon <ref> <preset>` | Start full weapon workflow (sketch baseline → core → empower → configure) |
| `rwda runesmith armour <ref>` | Start armour workflow (sketch gebu + gebo → empower) |
| `rwda runesmith configure <ref> <preset>` | Apply configuration to an already-empowered runeblade |
| `rwda runesmith status` | Print current workflow state and step |
| `rwda runesmith cancel` | Abort active workflow |

### Example usage flow

```
-- Build a kena_lock runeblade from scratch (holding the weapon as "runeblade"):
rwda runesmith weapon runeblade kena_lock

-- Apply a new configuration to an already-empowered blade:
rwda runesmith configure left arm_break

-- Empower your armour (holding it as "armour"):
rwda runesmith armour armour

-- Check what's happening mid-workflow:
rwda runesmith status

-- See all presets and their ink requirements:
rwda runesmith list

-- See full detail on a preset:
rwda runesmith info fracture_drain
```

---

## Phase 5 — Integration with existing systems

### Auto-sync runelore config on completion

When a weapon workflow finishes successfully, if `config.runesmith.auto_sync_runelore = true`:
- Automatically set `rwda.config.runelore.default_core` = preset's `core_rune`
- Automatically set `rwda.config.runelore.default_config_runes` = preset's `config_runes`
- Automatically set `rwda.config.runelore.empower_priority` = preset's `config_runes`
- Log "runelore config synced from runesmith preset <name>"

### Auto-switch profile on completion

If `config.runesmith.auto_switch_profile = true`:
- After runesmith finishes, call `rwda profile <preset.profile_hint>`
- Log "Profile switched to <profile_hint>"

### Save reminder

After completion, runesmith logs: `"Run: rwda save config — to persist this runesmith setup."`

---

## Phase 6 — `init.lua` wiring

### FILES list insertion

After `"data/runes.lua"`:
```lua
"data/rune_configs.lua",
```

After `"engine/runelore.lua"`:
```lua
"engine/runesmith.lua",
```

### Bootstrap call

After `rwda.engine.runelore.bootstrap()`:
```lua
if rwda.engine and rwda.engine.runesmith and rwda.engine.runesmith.bootstrap then
  rwda.engine.runesmith.bootstrap()
end
```

---

## Phase 7 — Persistence

Add to `exportPersistedConfig()` in `config.lua`:
```lua
runesmith = rwda.util.deepcopy(config.runesmith or {}),
```

---

## File change summary

| File | Action | What changes |
|---|---|---|
| `data/rune_configs.lua` | **NEW** | All 10 presets + helper functions |
| `engine/runesmith.lua` | **NEW** | State machine, step runner, cancel, bootstrap |
| `engine/parser.lua` | **MODIFY** | 7 new sketch/empower confirmation patterns |
| `ui/commands.lua` | **MODIFY** | `rwda runesmith` command tree (alias `rwda rs`) |
| `config.lua` | **MODIFY** | `config.runesmith` defaults + persistence export |
| `init.lua` | **MODIFY** | 2 file entries + 1 bootstrap call |

---

## Implementation order

1. `data/rune_configs.lua` — no dependencies, can be done standalone
2. `engine/runesmith.lua` — depends on rune_configs + config
3. `engine/parser.lua` — add `runesmith.onLine()` call in handleLine
4. `config.lua` — add `config.runesmith` block + persistence
5. `init.lua` — add file entries + bootstrap call
6. `ui/commands.lua` — add `rwda runesmith` / `rwda rs` command tree
