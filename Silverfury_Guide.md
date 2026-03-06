# Silverfury — User Guide

Silverfury is an automated combat system for Achaea running in Mudlet. It sits **on top of** your Legacy curing package — Legacy handles all curing and defence upkeep, Silverfury handles offense, venom selection, runelore, and combat logging.

---

## Installation

1. Place the `Silverfury/` folder inside your Mudlet profile directory.
2. In Mudlet, create a Script item containing:
   ```lua
   dofile(getMudletHomeDir() .. "/Silverfury/init.lua")
   ```
3. Make sure Legacy loads **before** Silverfury.
4. Silverfury will print `[SF/INFO] Silverfury v1.0.0 ready.` when it boots.

---

## How it works

Every time a prompt fires (`LPrompt` from Legacy), Silverfury runs one **tick**:

1. Checks safety — are you in danger? Is the system armed?
2. Checks if a scenario (venomlock, runelore kill) is active and asks it for the next step.
3. If no scenario, picks the best free-form attack based on the target's current state.
4. Sends **one** command through the throttle queue.
5. Writes a snapshot to the combat log.

Silverfury never acts more than once per prompt cycle, so it cannot out-race Legacy's curing.

---

## Quick start

```
sf target Sarapis       -- set who you want to fight
sf on                   -- arm the system (required before any offense)
sf attack on            -- enable automatic attacking
sf status               -- check everything looks right
sf off                  -- disarm immediately
sf abort                -- emergency full stop
```

---

## All Commands

### System Control

| Command | What it does |
|---|---|
| `sf on` | Arms the system. Offense will fire each prompt tick. |
| `sf off` | Disarms. No attacks will be sent. |
| `sf abort` | Emergency stop. Clears queue, aborts any active scenario, sets panic flag. |
| `sf resume` | Clears the panic flag set by abort. Lets you re-arm after an emergency stop. |
| `sf tick` | Manually fire one decision cycle right now. |

---

### Target

| Command | What it does |
|---|---|
| `sf target <name>` | Set the attack target. Resets venom tracking for a fresh state. |
| `sf t <name>` | Shortcut for `sf target`. |
| `sf cleartarget` | Clear the current target and flush the queue. |
| `sf ct` | Shortcut for `sf cleartarget`. |

Silverfury tracks whether your target is in the room via GMCP. If they leave, offense automatically pauses until they return or you set a new target.

---

### Attack Toggle

| Command | What it does |
|---|---|
| `sf attack on` | Enable automatic attacking each tick. |
| `sf attack off` | Disable auto-attacking (system stays armed for scenarios/manual). |
| `sf attack` | (no subcommand) — fires a single manual tick. |

---

### Auto-Retaliate

Automatically sets your target to whoever just attacked you.

| Command | What it does |
|---|---|
| `sf retal on` | Enable auto-retaliate. |
| `sf retal off` | Disable auto-retaliate. |
| `sf retal` | Show retaliation status (current aggressors, lock timer). |

**How it works:**
- When an incoming attack line is parsed, the attacker's name is captured.
- If you have no current target, it is set immediately.
- If you have a target and the lock has expired (default 8s), it switches to the new attacker.
- When the lock expires, your previous target is optionally restored.
- Non-player attackers (guards, denizens) are ignored by default.

**Relevant `sf set` options:** `retallock`, `retaldebounce`, `retalprev` (see Set Commands below).

---

### Execute Scenarios

Scenarios are automated kill sequences with defined phases: **Setup → Maintain → Execute → Done**.

| Command | What it does |
|---|---|
| `sf exec venomlock` | Start the venom-lock scenario. |
| `sf exec runelore` | Start the runelore-assisted kill scenario. |
| `sf exec dragon` | Start the Silver Dragon guided kill scenario. |
| `sf exec stop` | Stop the active scenario (returns to free-form attack). |

#### Venomlock Scenario
Builds the 4-aff lock stack (asthma + slickness + anorexia + paralysis) while prepping legs. Once legs are broken and the lock stack is confirmed, automatically transitions to impale → disembowel.

#### Runelore Kill Scenario
Focuses on pithakhan mana drain + kena/sleizak empower pressure. Continues empowering configuration runes as their conditions are met while prepping limbs. Transitions to impale → disembowel when lock affs and leg breaks align.

#### Silver Dragon Devour Scenario
Guided kill sequence for dragon form. Phases: **LOCATE → PIN → GROUND → PRESSURE → TORSO\_FOCUS → DEVOUR**. Keeps target grounded, pressures legs then torso, and fires Devour when the timing estimator says the window is safe (default: ≤ 5.7 seconds estimated remaining). See **Dragon Combat** section below.

---

### Dragon Combat

Used when you are in dragon form (`dragonform` / `lesserform`). The planner switches automatically when `me.form == "dragon"`.

#### Commands

| Command | What it does |
|---|---|
| `sf dragon status` | Full dragon status: form, armour, breath, torso, devour estimate, current phase. |
| `sf dragon on` | Enable the dragon combat module. |
| `sf dragon off` | Disable dragon combat (system returns to humanoid planner). |
| `sf dragon form` | Send `dragonform` to transform. |
| `sf dragon lesserform` | Send `lesserform` to revert. |
| `sf dragon breath <type>` | Set breath type (`lightning` — Silver Dragon only). |
| `sf dragon mode <mode>` | Set combat mode (`devour` is the only current mode). |
| `sf dragon armour on/off` | Toggle auto-dragonarmour upkeep. |
| `sf dragon summon` | Manually summon the configured breath weapon. |
| `sf dragon devour` | Show current Devour timing estimate and breakdown. |
| `sf dragon threshold <s>` | Set the safe Devour threshold in seconds (default: 5.7). |
| `sf dragon debug` | Print per-class matchup notes for the current target. |
| `sf dr ...` | Shortcut for `sf dragon`. |

#### Dragon scenario phases

| Phase | What happens |
|---|---|
| **LOCATE** | Target not in room — sends `TRACK <target>` each tick. |
| **PIN** | Target in room — becalm fliers, block escape routes, enmesh. |
| **GROUND** | Strip shield (tailsmash) / rebounding (breathstrip), then breathgust or tailsweep to prone. |
| **PRESSURE** | Target prone — alternates rend/bite on the weaker leg until `dragon.leg_prep_pct` (default 70%) is hit. |
| **TORSO\_FOCUS** | Swipe (leg+torso simultaneously) then gut until torso is broken. |
| **EXECUTE** | Estimator says safe → DEVOUR fires. Falls back to TORSO\_FOCUS if window closes. |

#### Devour estimator

The estimator approximates remaining Devour duration using heuristic weights:

| Condition | Reduction |
|---|---|
| Torso broken | −3.5 s |
| Head broken | −0.7 s |
| Leg broken (each) | −0.8 s |
| Arm broken (each) | −0.5 s |
| Torso damaged ≥ 50% | −0.8 s |
| Leg damaged ≥ 50% | −0.4 s |
| Head damaged ≥ 50% | −0.2 s |

Base Devour duration: **10 seconds**. The scenario fires Devour when the estimate is below `devour_safe_threshold` (default **5.7 s**). Every outcome is logged as `DEVOUR_OUTCOME` for future calibration.

Run `sf dragon devour` to see a live breakdown.

#### Matchup overrides

| Class | Override |
|---|---|
| Serpent | `breathstorm` to reveal from hiding; say trigger words. |
| Magi | `breathstorm` to shatter crystalline room. |
| Sentinel | `breathstorm` to clear summoned creatures. |
| Sylvan / Druid | Abort if target is in a grove. |
| Apostate / Blademaster / Depthswalker / Shaman | Flagged high-threat — expect extended fight. |

View notes for the current target with `sf dragon debug`.

#### Dragon fight flow

```
dragonform                    ← transform (or use sf dragon form)
sf target Kard
sf on
sf attack on
sf exec dragon                ← start scenario: LOCATE → PIN → GROUND → PRESSURE → TORSO → DEVOUR
sf dragon status              ← check phase, armour, breath summon, devour estimate
sf off                        ← done
```

The system auto-enables dragonarmour and summons the breath weapon during SETUP before the scenario begins attacking.

#### Dragon config options (`sf set` / config.lua)

| Key | Default | What it does |
|---|---|---|
| `dragon.enabled` | `true` | Master toggle for dragon planner. |
| `dragon.breath_type` | `"lightning"` | Silver Dragon only has lightning. |
| `dragon.auto_dragonarmour` | `true` | Automatically apply dragonarmour if it drops. |
| `dragon.auto_summon_breath` | `true` | Automatically summon breath if not ready. |
| `dragon.auto_becalm` | `true` | Becalm flying targets in PIN phase. |
| `dragon.use_enmesh` | `true` | Enmesh target to prevent fleeing. |
| `dragon.prefer_breathgust` | `true` | Use breathgust (eq) to prone instead of tailsweep (bal) when possible. |
| `dragon.prefer_tailsweep` | `true` | Fall back to tailsweep if breathgust unavailable. |
| `dragon.control_block_dirs` | `true` | Block the last direction the target fled. |
| `dragon.devour_safe_threshold` | `5.7` | Fire Devour when estimate is below this (seconds). |
| `dragon.leg_prep_pct` | `70` | Move from PRESSURE to TORSO\_FOCUS when best leg hits this damage %. |
| `dragon.torso_focus_pct` | `60` | Use swipe (leg+torso) until torso reaches this %, then switch to gut. |

---

### Runelore

Manages runeblade attunement and the empower queue.

| Command | What it does |
|---|---|
| `sf runelore status` | Show runeblade core, config runes, attunement state, and empower queue. |
| `sf runelore empower [rune]` | Manually trigger an empower (omit rune to use auto-priority). |
| `sf runelore core <rune>` | Set the core rune (pithakhan / nairat / eihwaz / hugalaz). |
| `sf runelore config <r1> [r2] ...` | Set the list of configuration runes to use. |
| `sf runelore autoempower on/off` | Toggle automatic empower trigger when conditions are met. |
| `sf runelore priority <r1> [r2] ...` | Set the order runes are empowered in. |
| `sf rl ...` | Shortcut for `sf runelore`. |

**Core runes:**

| Rune | Effect |
|---|---|
| `pithakhan` | Drains mana on each hit. More drain when head is damaged/broken. |
| `nairat` | Chance to freeze target on hit. |
| `eihwaz` | Masks venoms (conceals what you're applying). |
| `hugalaz` | Hail effect + enables the BISECT ability. |

**Configuration runes (attune + empower on weapon):**

| Rune | Triggers when | Effect |
|---|---|---|
| `kena` | Target mana < 40% | Inflicts impatience |
| `inguz` | Target paralysed | Cracks ribs |
| `fehu` | Target prone + no insomnia | Sleep |
| `sleizak` | Target weary/lethargic | Nausea / voyria |
| `wunjo` | Target shivering | Rib-burst |
| `sowulu` | Limb damaged | Healthleech / fracture |
| `mannaz` | Target off focus | Blocks mana regeneration |
| `isaz` | Target engaged, can't escape | Epilepsy |
| `tiwaz` | Target off salve, no restore | Breaks arms |
| `loshre` | Target addicted | Eating punishment |

---

### Set Commands

Fine-tune behaviour at runtime without editing any files.

#### Venoms & Attacks

| Command | What it does |
|---|---|
| `sf set venoms <v1> [v2] ...` | Set venom lock-priority list (first is highest priority). |
| `sf set kelpcycle <v1> [v2]` | Set venoms used to bypass slickness via kelp cycle. |
| `sf set limbs <l1> [l2] ...` | Set the limb prep order (e.g. `left_leg right_leg torso`). |
| `sf set rewield <command>` | Set the command sent to re-wield weapons when not wielded. |
| `sf set template <key> <value>` | Set an attack template. Keys: `dsl`, `raze`, `razeslash`, `impale`, `disembowel`. |

**Default venom lock priority:** kalmia → gecko → slike → curare
*(asthma → slickness → anorexia → paralysis)*

**Template placeholders:** `{target}` `{venom1}` `{venom2}` `{limb}` `{rune}`

Example: `sf set template dsl dsl {target} {limb} {venom1} {venom2}`

#### Safety

| Command | What it does |
|---|---|
| `sf set hpfloor <pct>` | Pause offense when HP drops below this percent (default: 30). |
| `sf set mpfloor <pct>` | Pause offense when MP drops below this percent (default: 15). |

#### Retaliation Tuning

| Command | What it does |
|---|---|
| `sf set retallock <ms>` | How long (ms) to hold a retaliation target lock (default: 8000). |
| `sf set retaldebounce <ms>` | Minimum gap (ms) between target switches (default: 1500). |

#### Queue / Timing

| Command | What it does |
|---|---|
| `sf set antispam <ms>` | Minimum milliseconds between sent commands (default: 275). |
| `sf set serverqueue on/off` | Use Achaea's server-side queue instead of Mudlet `send()`. Off by default (client send lets aliases expand). |

---

### Combat Logging

All combat activity is written to timestamped JSON Lines files inside your Mudlet profile:
```
getMudletHomeDir()/Silverfury/logs/YYYY-MM-DD/HHMMSS_targetname.jsonl
```

Each line is a JSON record with a timestamp, record type, and snapshots of your state and the target's state at that moment.

**Record types logged:** `PROMPT_SNAPSHOT`, `OUTGOING_COMMAND`, `INCOMING_ATTACK`, `AFF_GAINED`, `AFF_CURED`, `DEF_GAINED`, `DEF_LOST`, `RUNE_ACTION`, `MODE_CHANGE`, `TARGET_CHANGE`, `SAFETY_PAUSE`, `ABORT`, `LOG_*`.

| Command | What it does |
|---|---|
| `sf log on` | Enable combat logging. |
| `sf log off` | Disable combat logging. |
| `sf log folder` | Open the log folder in your system file explorer. |
| `sf log` | Show log status and current file path. |

---

### UI Window

| Command | What it does |
|---|---|
| `sf ui` | Open or close the configuration popup window. |

The window has six tabs:

| Tab | Contents |
|---|---|
| **Status** | Live view: armed state, HP/MP, target info, current venoms, last action. |
| **Venoms** | Lock priority list, kelp cycle venoms, repeat-avoid timer. |
| **Runelore** | Core rune, config runes, empower priority, auto-empower toggle. |
| **Scenarios** | Start/stop venomlock and runelore kill scenarios, view phase. |
| **Safety** | HP floor, MP floor, danger affs list, retaliation settings. |
| **Logging** | Enable/disable logging, open log folder button. |

---

### Config Persistence

| Command | What it does |
|---|---|
| `sf save` | Save current config to `silverfury_config.lua` in your profile dir. |
| `sf load` | Load config from that file, overriding current values. |

Config auto-loads on boot if the file exists. All `sf set` changes are **in-memory only** until you run `sf save`.

---

### Debug / Status

| Command | What it does |
|---|---|
| `sf status` | Full status panel: armed, HP/MP, target, venoms, scenario, runelore state. |
| `sf debug on` | Switch log level to `trace` — prints every decision made each tick. |
| `sf debug off` | Switch log level back to `info`. |
| `sf help` | Print command reference in-game. |

---

## Safety system

The safety system **automatically pauses offense** when:
- HP is below the configured floor (default 30%).
- MP is below the configured floor (default 15%).
- You have a danger affliction (paralysis, sleep, confusion by default).
- The deadman timer fires (if configured — fires if no prompt tick received for N ms).

When paused, no attacks are sent but the system stays armed. Offense resumes automatically on the next prompt tick once conditions clear.

`sf abort` additionally sets a **panic flag** that prevents re-arming until you run `sf resume`. Use it when you need a hard stop that won't auto-resume.

---

## Venom selection logic

Each tick, Silverfury picks two venoms for the attack:

1. **Slot 1:** Work through the lock priority list. Skip any venom whose target affliction the target already has (confirmed within the repeat-avoid window). If the target has slickness (and gecko venom is blocked), switch to the kelp cycle venoms instead.
2. **Slot 2:** Same logic as slot 1, but skip whatever was chosen for slot 1.

The result feeds into the `{venom1}` and `{venom2}` placeholders in your attack template.

---

## Integration with Legacy

Silverfury reads from Legacy but **never modifies it**:
- Listens for `LegacyLoaded` to know Legacy is ready before arming itself.
- Listens for `LPrompt` as its main heartbeat.
- Reads affliction and defence state from Legacy's tables to stay in sync.
- Receives HP/MP/balance updates from `gmcp.Char.Vitals`.

If Legacy is not detected, Silverfury falls back to GMCP-only state tracking.

---

## Typical fight flow

```
sf target Kard
sf on
sf attack on
                  ← system fires on every prompt
                  ← strips shield (razeslash), then rebounding (raze)
                  ← DSL with kalmia/gecko working toward asthma+slickness
sf exec venomlock ← switch to scenario: builds full lock, then impale/disembowel
sf off            ← done, disarm
```
