# RWDA User Guide

**Runewarden + Silver Dragon AI — Project Silverfury**
Last updated: 2026-03-02

---

## Table of Contents

1. [What RWDA Does](#what-rwda-does)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Core Concepts](#core-concepts)
5. [All Commands](#all-commands)
6. [Auto-Retaliation](#auto-retaliation)
7. [Auto-Execute (Finisher)](#auto-execute-finisher)
8. [Runelore Integration](#runelore-integration)
9. [Combat Builder UI](#combat-builder-ui)
10. [Combat HUD](#combat-hud)
11. [Strategy Profiles and Blocks](#strategy-profiles-and-blocks)
12. [Reading `rwda status`](#reading-rwda-status)
13. [Reading `rwda explain`](#reading-rwda-explain)
14. [Safety Features](#safety-features)
15. [Starburst Tattoo Handling](#starburst-tattoo-handling)
16. [Persistent Config](#persistent-config)
17. [Troubleshooting](#troubleshooting)

---

## What RWDA Does

RWDA is an offense-only combat brain for Mudlet. It runs alongside **Legacy** curing — it does not replace or interfere with Legacy's healing, curative, or defence logic. RWDA handles only:

- Deciding **what attack to send** each tick
- Managing **target selection** (including auto-retaliation)
- Detecting **execute windows** and dispatching finishers (disembowel / devour)
- Recovering from **failed execute attempts** via fallback blocks

RWDA reads your current state (balances, form, target defences, limb state) and picks the highest-priority valid action from your configured strategy. Every decision is recorded and visible via `rwda explain`.

RWDA does **not** send attacks itself — it queues them each tick. Ticks fire automatically on every server prompt when `rwda set prompttick on` is enabled, or you can fire one manually with `rwda tick`.

---

## Installation

1. In Mudlet: **Package Manager → Install → `dist\RWDA_Bootstrap.mpackage`**
2. If you already have an older version installed, remove it first.
3. On your next login (or immediately), the `sysLoadEvent` fires and RWDA loads automatically.
4. Verify with: `rwda status`

The loader tries these paths for `init.lua` in order:
- `C:\Users\jness\Documents\Project Silverfury\ProjectSilverfury\rwda\init.lua`
- `<MudletHome>\rwda\init.lua`
- File dialog (prompts you if neither is found)

If RWDA loads correctly you will see `[RWDA] bootstrap complete` in the main console.

---

## Quick Start

### Starting a fight

```
rwda engage Bainz
```

`rwda engage <name>` is the single command to start combat — it sets the target, enables offense, and fires the first tick in one shot. From there, enable prompt ticking so RWDA attacks automatically on every server prompt:

```
rwda set prompttick on
```

### Full automation setup (recommended)

```
rwda engage Bainz               -- start fighting
rwda goal impale_kill           -- or: dragon_devour, limbprep, pressure
rwda retaliate on               -- auto-target aggressors who hit you
rwda execute on                 -- auto-dispatch disembowel / devour
```

### Runelore / Kena lock setup

If your runeblade has a **Pithakhan** core rune + **Kena**, **Sleizak**, and **Inguz** configuration runes:

```
rwda runelore core pithakhan                    -- confirm core rune
rwda runelore config kena,sleizak,inguz         -- confirm config runes
rwda runelore autoempower on                    -- auto-send EMPOWER when a rune attunes
rwda profile kena_lock                          -- switch to head-focused profile
rwda engage Bainz
```

For a **Hugalaz** core (enables BISECT at ≤20% health):

```
rwda runelore core hugalaz
rwda runelore bisect on                         -- unlock bisect_window block
rwda profile kena_lock
rwda engage Bainz
```

RWDA will automatically:
1. Attack **head** every tick (maximises Pithakhan mana drain — guaranteed proc on damaged head)
2. Detect when a configuration rune attunes and immediately send `EMPOWER <rune>`
3. Deliver **impatience** via Kena when target mana drops below 40%
4. Fire **BISECT** at ≤20% target health (if hugalaz + `bisect on`)

### Stop everything immediately

```
rwda stop                       -- kill switch: halts offense and clears all server queues
```

---

## Core Concepts

### How RWDA Decides What to Send

RWDA does not react to what you type. It reads your actual in-game state each tick:
- Your current **form** (human or dragon) — detected from server text, no manual switch needed
- Target **defences** (shield, rebounding)
- Target **limb state** (broken, mangled)
- Your own **balances** (bal, eq)
- Your current **goal**

It then evaluates your strategy blocks top-down by priority and sends the first one whose condition is true.

### Goals

The **goal** tells the planner what outcome you are working toward.

| Goal | Description |
|---|---|
| `pressure` | General pressure: afflictions + limb damage |
| `limbprep` | Priority limb breaking to set up an execute window |
| `impale_kill` | Runewarden: break legs → impale → disembowel |
| `dragon_devour` | Dragon: break limbs + prone → devour |

Change with: `rwda goal <name>`

### Modes

The **mode** controls which planner logic runs: Runewarden or Dragon. In `auto` mode RWDA follows your actual form — no command needed when you shift.

| Mode | Description |
|---|---|
| `auto` | Follows your current in-game form automatically (recommended) |
| `human` | Forces Runewarden logic regardless of form |
| `dragon` | Forces Dragon logic regardless of form |

Change with: `rwda mode <auto\|human\|dragon>`

Form changes are detected from combat text (e.g. `"You assume the form of a dragon."`).

### Strategy Profiles

A **profile** is a named set of strategy blocks. Four profiles are built in:

| Profile | Use case |
|---|---|
| `duel` | 1v1 combat — aggressive single-target pressure |
| `group` | Group combat — conservative, safer target churn |
| `kena_lock` | Runelore: head-focused DSL + BISECT finisher (requires hugalaz + kena config rune) |
| `head_focus` | Runelore: head-focused DSL pressure + Pithakhan mana drain (no BISECT) |

Switch with `rwda profile <duel\|group\|kena_lock\|head_focus>` or via the Combat Builder UI.

### Strategy Blocks

Each profile contains ordered **blocks** per mode. Each block has:
- A unique **id** (e.g. `strip_shield`, `dragon_force_prone`, `limbprep_dsl`)
- A **priority** (higher number = checked first)
- A **condition** (e.g. `target.def.shield`, `not target.prone`, `always`)
- An **action** (e.g. `razeslash`, `gust`, `dsl`)
- An **enabled** flag

Blocks are evaluated top-down by priority. The first enabled block whose condition is true wins.

---

## All Commands

### Combat

| Command | What it does |
|---|---|
| `rwda engage <name>` | **Start fighting**: sets target, enables offense, fires first tick |
| `rwda stop` | **Hard kill switch**: disables offense AND clears all server queues immediately |
| `rwda tick` | Manually force one planning + execution cycle (alias: `rwda attack`) |

### Engine Control

| Command | What it does |
|---|---|
| `rwda on` | Enable offense — RWDA will send attacks on each tick |
| `rwda off` | Disable offense — RWDA stops attacking but keeps state |
| `rwda resume` | Re-enable after `rwda off` or `rwda stop` |
| `rwda reload` | Hot-reload all Lua files without restarting Mudlet |
| `rwda reset` | Wipe all runtime state (target, limbs, defences, balances) back to defaults |

### Targeting

| Command | What it does |
|---|---|
| `rwda target <name>` | Manually set your attack target (does not enable or tick) |
| `rwda clear target` | Remove the current target (stop attacking) |

### Mode and Goal

| Command | What it does |
|---|---|
| `rwda mode <auto\|human\|dragon>` | Set planner mode |
| `rwda goal <pressure\|limbprep\|impale_kill\|dragon_devour>` | Set combat goal |

### Automation Toggles

| Command | What it does |
|---|---|
| `rwda retaliate <on\|off>` | Enable/disable auto-retaliation (auto-target aggressors) |
| `rwda execute <on\|off>` | Enable/disable auto-finisher dispatch (disembowel / devour) |

### Diagnostics

| Command | What it does |
|---|---|
| `rwda status` | Print current tracked state: target, form, balances, defences, limbs, retaliation/execute flags |
| `rwda explain` | Print the last planned action with its reason code and strategy block |
| `rwda doctor` | Full diagnostic report: Legacy wiring, handler counts, strategy status, retaliation/finisher state |
| `rwda selftest` | Run the offline test suite — prints pass/fail for all engine cases |
| `rwda selftest runelore` | Run the Runelore-specific test suite only |

### Runelore

| Command | What it does |
|---|---|
| `rwda runelore status` | Show current runeblade configuration, attunement state, and auto-empower flag |
| `rwda runelore core <rune>` | Set the core runeblade rune (`pithakhan`, `nairat`, `eihwaz`, `hugalaz`) |
| `rwda runelore config <r1,r2,r3>` | Set configuration runes (comma-separated, up to 3) |
| `rwda runelore autoempower on\|off` | Auto-send `EMPOWER <rune>` immediately when a configuration rune attunes |
| `rwda runelore bisect on\|off` | Enable the `bisect_window` block (instant kill at ≤20% health, requires hugalaz) |
| `rwda runelore empower <rune>` | Manually dispatch `EMPOWER <rune>` |
| `rwda runelore priority <r1> <r2>` | Set the empower priority order |

### Configuration (set)

| Command | What it does |
|---|---|
| `rwda show config` | Print the current config table |
| `rwda set breath <type>` | Set your dragon breath type (e.g. `lightning`) |
| `rwda set venoms <main> <off>` | Set main and off-hand venom |
| `rwda set autostart <on\|off>` | Auto-enable RWDA when Legacy loads |
| `rwda set followlegacytarget <on\|off>` | Mirror Legacy's target into RWDA |
| `rwda set prompttick <on\|off>` | Fire a tick automatically on every server prompt |
| `rwda set autogoal <on\|off>` | Toggle automatic goal escalation as the fight progresses |
| `rwda set cursepriority <c1> [c2...]` | Set dragon curse application priority (impatience, asthma, paralysis, stupidity) |
| `rwda set gutvenompriority <v1> [v2...]` | Set dragon gut venom priority (curare, kalmia, gecko, slike, aconite) |
| `rwda set retalockms <ms>` | How long (ms) a retaliation lock lasts before expiring |
| `rwda set retaldebounce <ms>` | Minimum time (ms) between retaliation target swaps |
| `rwda set retalminconf <0-1>` | Minimum confidence before a retaliation swap fires |
| `rwda set executecooldown <ms>` | Cooldown after a failed execute before retrying |
| `rwda set executefallbackwindow <ms>` | How long the fallback block is forced after a failure |
| `rwda set executetimeout <disembowel\|devour> <ms>` | Max time to wait for confirmation before treating as timed out |
| `rwda set executefallback <human\|dragon> <block_id>` | Which strategy block to force after execute failure |
| `rwda set capture <on\|off>` | Log unmatched combat lines to a file (for tuning patterns) |
| `rwda set captureall <on\|off>` | Log ALL incoming lines to the capture file (full combat dump) |
| `rwda set captureprompts <on\|off>` | Also capture prompt lines in the unmatched log |
| `rwda set capturepath <path>` | Set the path for the unmatched line log file |

### Config Persistence

| Command | What it does |
|---|---|
| `rwda save config` | Write current config to disk |
| `rwda load config` | Load config from disk |

Config is saved to `<MudletHome>\rwda_config.lua` and auto-loaded on bootstrap.

### Strategy

| Command | What it does |
|---|---|
| `rwda strategy show` | Print a summary of the current strategy profile's blocks |
| `rwda strategy apply` | Apply the working copy from the Combat Builder to the live config |
| `rwda strategy save` | Apply + save to disk |
| `rwda strategy load` | Load strategy from disk config |

### Combat Builder UI

| Command | What it does |
|---|---|
| `rwda builder open` | Open the Geyser popout combat editor |
| `rwda builder close` | Close the popout |

### Combat HUD

| Command | What it does |
|---|---|
| `rwda hud show` | Show the passive combat HUD panel (default state) |
| `rwda hud hide` | Hide the HUD panel |
| `rwda hud refresh` | Force an immediate HUD redraw |

### Replay and Testing

Paths are relative to the `rwda/` directory (i.e. relative to `rwda.base_path`).

| Command | What it does |
|---|---|
| `rwda replay <path>` | Replay a combat log file through the parser/planner pipeline |
| `rwda replayassert <path> <action> [min]` | Replay a log and assert the last action and minimum action count |
| `rwda replaysuite <path>` | Run a multi-case assertion suite (`.lua` file) |
| `rwda line <text>` | Feed a single raw combat line into the parser manually |

Example:
```
rwda replaysuite tools/suite_strategy_retal_finisher.lua
```

### Queue

| Command | What it does |
|---|---|
| `rwda queue clear` | Clear all pending server queues (`CLEARQUEUE ALL`) |

---

## Runelore Integration

RWDA has built-in support for the Runelore skill's runeblade configuration system.

### How It Works

The game sends text messages when your runeblade runes attune, detune, or get empowered. RWDA's parser watches for these messages and routes them to the Runelore engine, which:

1. Tracks which configuration runes are currently **attuned**
2. Optionally auto-sends `EMPOWER <rune>` immediately on attunement (when `autoempower on`)
3. Empower priority is configurable — if multiple runes attune on the same tick, the highest-priority one is empowered first

### Attunement Conditions (Dec 2025 classleads)

| Rune | Attunes when | Empower effect |
|---|---|---|
| **Kena** | Target mana < **40%** (raised from 20%) | Impatience |
| **Inguz** | Target is paralysed | Cracked ribs |
| **Wunjo** | Target is shivering | Cracked ribs damage |
| **Sowulu** | Struck limb is damaged | Healthleech + fracture relapse |
| **Fehu** | Target is prone or missing insomnia | Sleep |
| **Mannaz** | Target is off focus balance | Mana regen block |
| **Isaz** | Engage prevents escape | Epilepsy |
| **Tiwaz** | Off salve balance + no restoration needed | Break both arms |
| **Sleizak** | Target is weary or lethargic | Nausea / voyria |
| **Loshre** | Target is addicted | Eating punishment |

### Pithakhan (Core Rune) Mechanics

| Condition | Drain |
|---|---|
| Normal proc | 10% of target's max mana |
| Head is **damaged** | Guaranteed proc (always fires) — July 2022 rework |
| Head is **broken** | 13% drain per proc — Dec 2025 classlead (was 10%) |

Focusing head attacks therefore converts Pithakhan from a random proc to a guaranteed 13% mana drain every attack tick — the foundation of the Kena lock path.

### Kena Lock Path

```
Focus head  ─►  Pithakhan fires (guaranteed)  ─►  Mana drops below 40%
  ─►  Kena attunes  ─►  EMPOWER Kena  ─►  Impatience delivered
  ─►  Impatience blocks FOCUS  ─►  Asthma/paralysis sticks  ─►  True lock
```

Recommended runeblade setup: **Pithakhan** core + **Kena**, **Sleizak**, **Inguz** configuration.

### BISECT

`BISECT` is an instant-kill ability that fires when:
- Your runeblade has **Hugalaz** as the core rune (edged weapon)
- Target health is ≤ **20%**
- Bypasses rebounding — no need to strip first

In RWDA, the `bisect_window` strategy block handles this. Enable it with:

```
rwda runelore core hugalaz
rwda runelore bisect on
```

The `kena_lock` profile includes the `bisect_window` block at priority 99 (second only to strip-rebounding). With `bisect on`, RWDA will automatically fire `BISECT <target>` as a freestand action the moment health drops to ≤20%.

### Dual-Cutting with a Configured Runeblade

When dual-cutting, the **configured runeblade goes in the LEFT hand**. RWDA sends the standard `dsl <target> <limb> <v1> <v2>` command — Legacy handles which hand attacks which limb. No RWDA config change is needed for dual-cutting.

### Setup Commands

```
rwda runelore status                      -- view current config + attunement
rwda runelore core pithakhan              -- set core rune
rwda runelore config kena,sleizak,inguz   -- set config runes
rwda runelore autoempower on              -- enable auto-empower
rwda runelore priority kena inguz sleizak -- empower in this order when multiple attune
rwda profile kena_lock                    -- switch to Runelore head-focus profile
```

Configuration persists via `rwda save config` / `rwda load config`.

---

## Auto-Retaliation

Auto-retaliation automatically switches your attack target when someone hits you.

### Enable

```
rwda retaliate on
```

### How It Works

1. The parser detects incoming attack lines addressed to you (e.g. `"Raijin slashes you."`)
2. The aggressor's name is validated: must be a likely player name and present in the GMCP room list (when available)
3. If valid, RWDA checks how many **active aggressors** are currently tracked

### Multi-Attacker Hold

If **two or more** people are actively attacking you, RWDA **does not switch targets**. You stay focused on your current target — bouncing between attackers wastes your offense. The reason code `multi_attacker_hold` is set in status.

- Each validated hit updates an internal `active_aggressors` table with a timestamp
- Aggressors who haven't hit in the last 20 seconds (configurable) are pruned and no longer count
- If the count drops back to 1, normal retaliation resumes

### Target-Dead Auto-Switch

When your current target **dies**:

- If other aggressors are still active, RWDA automatically switches to the one who most recently hit you
- If no other aggressors are active, the target is **cleared** entirely (you stop attacking)

### Lock Expiry

A retaliation lock has a duration (default 8 seconds, `rwda set retalockms`). When it expires, RWDA restores your previous manually-set target (if `restore_previous_target` is enabled).

### Configuration

| Config key | Command | Default | Description |
|---|---|---|---|
| `retaliation.enabled` | `rwda retaliate on/off` | `false` | Master toggle |
| `retaliation.lock_ms` | `rwda set retalockms` | `8000` | Lock duration |
| `retaliation.swap_debounce_ms` | `rwda set retaldebounce` | `1500` | Minimum ms between swaps |
| `retaliation.min_confidence` | `rwda set retalminconf` | `0.65` | Minimum confidence score |
| `retaliation.aggressor_ttl_ms` | *(config file only)* | `20000` | Time before an inactive aggressor expires |
| `retaliation.restore_previous_target` | *(config file only)* | `true` | Restore old target after lock expires |

---

## Auto-Execute (Finisher)

The execute engine manages the full lifecycle of a kill-attempt: dispatch, confirmation, failure handling, and recovery.

### Enable

```
rwda execute on
```

### Runewarden: Impale → Disembowel

Goal: `impale_kill`

1. Planner breaks both legs and knocks target prone (via strategy blocks)
2. Once legs are broken and target is prone, the `impale_window` block fires `impale`
3. On the next tick with `target.impaled` true, the `disembowel_followup` block fires `disembowel`
4. Parser watches for:
   - `"You disembowel..."` → **success**, finisher clears
   - `"You fail to disembowel..."` / `"You are not impaling..."` → **failure**, fallback fires

### Dragon: Devour

Goal: `dragon_devour`

1. Planner breaks torso and limbs, forces prone (via strategy blocks)
2. The devour readiness score is computed from limb damage and time estimates
3. When the score is within the threshold (`config.finisher.devour_threshold_ms`, default 8000 ms), the `devour_window` block fires `devour`
4. Parser watches for:
   - `"You devour..."` / `"You have devoured..."` → **success**
   - `"You fail to devour..."` / `"You cease trying to devour..."` → **failure**, fallback fires

### Fallback Behavior

After a **failure or timeout**:

1. A cooldown window is applied (`executecooldown` ms) — no execute attempt during this window
2. A fallback window activates (`executefallbackwindow` ms) — the planner **forces** the configured fallback block, bypassing its normal condition
3. The fallback block re-establishes the conditions needed for the next attempt (e.g. limb re-prime, re-prone)
4. After the fallback window closes, normal strategy evaluation resumes and the execute will be attempted again

The fallback block's condition is **always bypassed** when forced — it fires unconditionally regardless of the current target state.

### Configuration

| Command | Default | Description |
|---|---|---|
| `rwda execute on/off` | `off` | Master toggle |
| `rwda set executecooldown <ms>` | `1500` | Cooldown after failure before retrying |
| `rwda set executefallbackwindow <ms>` | `6000` | How long fallback block is forced |
| `rwda set executetimeout disembowel <ms>` | `2500` | Timeout waiting for disembowel confirmation |
| `rwda set executetimeout devour <ms>` | `8000` | Timeout waiting for devour confirmation |
| `rwda set executefallback human <block_id>` | `limbprep_dsl` | Fallback block after disembowel failure |
| `rwda set executefallback dragon <block_id>` | `dragon_force_prone` | Fallback block after devour failure |

---

## Combat Builder UI

The Combat Builder is a live Geyser popout window for editing your strategy without leaving the game.

### Open and Close

```
rwda builder open
rwda builder close
```

### Layout

```
┌─────────────────────────────────────────────┐
│  RWDA Combat Builder                    [X]  │
│  [Runewarden] [Dragon] [Shared] [Safety]     │
├─────────────────────────────────────────────┤
│  (block list for active tab)                 │
│  strip_shield    pri:100  [ON]  [+] [-]      │
│  force_prone     pri: 80  [ON]  [+] [-]      │
│  limbprep_dsl    pri: 70  [ON]  [+] [-]      │
│  ...                                         │
├─────────────────────────────────────────────┤
│  [Apply] [Save] [Revert]  Retal:[ON] Exec:[ON]│
└─────────────────────────────────────────────┘
```

### Tabs

| Tab | What you can edit |
|---|---|
| **Runewarden** | Human-mode strategy blocks (shield strip, DSL, impale, disembowel) |
| **Dragon** | Dragon-mode strategy blocks (tailsmash, gust, bite, devour) |
| **Shared** | Targeting behavior, follow-Legacy-target toggle |
| **Safety** | Emergency stop behavior, ignore filters |

### Buttons

| Button | Action |
|---|---|
| **Apply** | Push the working copy changes into the live planner immediately |
| **Save** | Apply + write to disk config |
| **Revert** | Discard working copy changes and reload from live config |
| **[ON]/[OFF]** (per block) | Toggle a block enabled/disabled |
| **[+]/[-]** (per block) | Raise or lower a block's priority |
| **Retal** toggle | Enable/disable auto-retaliation |
| **Exec** toggle | Enable/disable auto-execute |

Changes made in the UI take effect only after clicking **Apply** or **Save**. Before that they are held in a working copy and do not affect the live planner.

---

## Combat HUD

The Combat HUD is a passive, always-on overlay that shows live combat state without requiring any user interaction.

### Layout

```
┌──────────────────────────────────────────┐
│  [ON] dragon devour duel RETAL:on EXEC:on │   ← Status strip
│  Form:dragon  Breath:ready               │
├──────────────────────────────────────────┤
│  Aerenna  [available]                    │   ← Target panel
│  Prone:Y  Shield:N  Reb:Y  Fly:N  Lyrd:N│
│  LA:████░  RA:░░░░░  LL:█████  RL:███░░  │
│  Hd:░░░░░  To:████░                     │
│  Affs: impaled, asthma                   │
├──────────────────────────────────────────┤
│  Last Actions:                           │   ← Action log
│  > gut Aerenna curare | tailsmash Aerenna│
│    [strip_shield combo]                  │
│  > devour Aerenna                        │
│    [devour_window]                       │
└──────────────────────────────────────────┘
```

### Panels

| Panel | Content |
|---|---|
| **Status strip** | Engine on/off, mode, goal, profile, retaliation and execute states, form, dragon breath |
| **Target panel** | Target name and availability, status badges (Prone/Shield/Reb/Flying/Lyred), limb damage bars (5-char, each block = 20%), active afflictions |
| **Action log** | Last 5 `ACTION_SENT` events — commands sent + strategy block reason |

### Limb Bar Colors

| Color | Damage level |
|---|---|
| Green | < 50% |
| Yellow | 50–79% |
| Tomato/Red | ≥ 80% |

### Visibility

The HUD is initialized automatically at bootstrap (requires Mudlet with Geyser). If WolfUI / GUIframe is present, the HUD registers as a right-side panel via `GUIframe.addWindow()`. Otherwise it creates a standalone docked `UserWindow` at the right edge.

Toggle with `rwda hud show` and `rwda hud hide`. The HUD refreshes every 0.5 seconds via a self-rescheduling timer, and immediately on each `ACTION_SENT` event.

---

## Strategy Profiles and Blocks

### Viewing the Current Strategy

```
rwda strategy show
```

Prints each block for the active profile and mode with: id, priority, enabled, condition, action.

### Default Runewarden Blocks (duel profile)

| Block ID | Priority | Condition | Action |
|---|---|---|---|
| `strip_rebounding` | 100 | `target.def.rebounding` | `raze` |
| `strip_shield` | 95 | `target.def.shield` | `razeslash` |
| `impale_window` | 92 | `target.legs_broken and target.prone and not target.impaled` | `impale` |
| `disembowel_followup` | 91 | `target.impaled` | `disembowel` |
| `intimidate_lock` | 90 | `target.impaled` | `intimidate` |
| `assess_target` | 30 | `target.limb_stale` | `assess` |
| `limbprep_dsl` | 20 | `always` | `dsl` |

### Runelore Runewarden Blocks (kena_lock profile)

| Block ID | Priority | Condition | Action |
|---|---|---|---|
| `strip_rebounding` | 100 | `target.def.rebounding` | `raze` |
| `bisect_window` | 99 | `runelore.bisect_ready and target.health_low` | `bisect` |
| `strip_shield` | 95 | `target.def.shield` | `razeslash` |
| `assess_target` | 30 | `target.limb_stale` | `assess` |
| `head_focus_dsl` | 20 | `always` | `dsl` (head) |

The `bisect_window` block is only enabled when `rwda runelore bisect on` **and** the core rune is `hugalaz`. Without that it is skipped and `head_focus_dsl` always fires.

The `head_focus` profile is identical but ships with `bisect_window` disabled — use it when your core rune is Pithakhan/Nairat/Eihwaz and you just want reliable head pressure.

### Default Dragon Blocks (duel profile)

| Block ID | Priority | Condition | Action |
|---|---|---|---|
| `summon_breath` | 100 | `not me.dragon.breath_summoned` | `summon` |
| `dragon_strip_shield` | 95 | `target.def.shield` | `tailsmash` |
| `dragon_strip_rebounding` | 94 | `target.def.rebounding` | `tailsmash` |
| `dragon_force_prone` | 85 | `not target.prone` | `gust` |
| `devour_window` | 80 | `state.can_devour` | `devour` |
| `dragon_torso_pressure` | 70 | `always` | `rend` |
| `dragon_limb_pressure` | 20 | `always` | `bite` |

### Condition DSL Tokens

Conditions use simple space-separated tokens. `not` negates the next token.

| Token | True when |
|---|---|
| `always` | Always (unconditional block) |
| `target.def.shield` | Target has shield active |
| `target.def.rebounding` | Target has rebounding active |
| `target.prone` | Target is prone |
| `target.available` | Target is in room and attackable |
| `target.impaled` | Target is currently impaled |
| `target.legs_broken` | Both legs are broken |
| `target.limb.<name>.broken` | Named limb is broken (`left_leg`, `right_arm`, `torso`, etc.) |
| `target.limb_stale` | Limb data is older than `assess_stale_ms` or no assess has fired within `assess_interval_ms` |
| `goal.<name>` | Current goal matches (e.g. `goal.dragon_devour`) |
| `me.form.dragon` | You are in dragon form |
| `me.form.human` | You are in human form |
| `me.dragon.breath_summoned` | Dragon breath is currently summoned |
| `state.can_devour` | Devour readiness score is within the configured threshold |
| `target.health_low` | Target health is ≤ 20% (used by `bisect_window`) |
| `runelore.bisect_ready` | Core rune is `hugalaz`, `bisect_enabled=true`, and target health is ≤ 20% |

---

## Reading `rwda status`

Example output:

```
[RWDA] on | tgt=Bainz (retaliation) | avail=yes | dead=no
form=dragon | bal=yes | eq=yes
tshield=no | trebound=no | tprone=yes
limbs: torso=broken left_leg=broken right_leg=broken
retal=on locked=Bainz until=3420ms reason=retaliation_lock active_aggressors=2 [Bainz,Raijin]
execute=on active=no fallback=no
```

| Field | Meaning |
|---|---|
| `on/off` | Whether RWDA offense is enabled |
| `tgt=` | Current target name and source (`manual`, `retaliation`, `external`) |
| `avail=yes/no` | Whether the target is considered reachable |
| `dead=yes/no` | Whether the target has been confirmed dead |
| `form=` | Your current form (`dragon`/`human`) |
| `bal=/eq=` | Balance and equilibrium state |
| `tshield=` | Whether target's shield is tracked as active |
| `trebound=` | Whether target's rebounding is tracked as active |
| `tprone=` | Whether target is prone |
| `limbs:` | Broken/mangled limb summary |
| `retal=` | Retaliation enabled/disabled |
| `locked=` | Current retaliation lock target and time remaining |
| `reason=` | Last retaliation decision reason code |
| `active_aggressors=` | Count and names of currently tracked attackers |
| `execute=` | Execute engine enabled/disabled |
| `active=` | Whether a finisher attempt is in progress |
| `fallback=` | Whether the fallback block is currently being forced |

---

## Reading `rwda explain`

Example output:

```
Last action: dsl
  mode: human_dualcut
  block: limbprep_dsl
  condition: always
  profile: duel
  reason: strategy_block
```

This tells you exactly which strategy block was chosen and why. If a fallback was forced:

```
Last action: dsl
  finisher_fallback: true
  finisher_fallback_block: limbprep_dsl
  reason: finisher_fallback
```

---

## Safety Features

### Hard Stop

```
rwda stop
```

Sets a kill switch that immediately:
- Disables offense
- Clears all server queues (`CLEARQUEUE ALL`)

Nothing sends until you `rwda on`, `rwda resume`, or `rwda engage <name>`.

### Target Availability Guard

RWDA will not attack if the target:
- Is not in the GMCP room player list
- Has triggered a "not here" / "cannot see" error message
- Is marked dead

### Anti-Spam

- Balance and equilibrium are gated — actions only send when both are up (unless the action type doesn't require them)
- The executor deduplicates: the same command will not re-queue if it was just sent
- Retaliation has debounce: rapid hits from the same or different player cannot cause target thrash faster than `swap_debounce_ms`

### Aggressor Filters

| Config | Default | Description |
|---|---|---|
| `retaliation.ignore_non_players` | `true` | Skip aggressors that don't appear to be player names or aren't in the GMCP room list |

---

## Starburst Tattoo Handling

A starburst tattoo resurrects a player immediately after death. Without special handling, RWDA would clear the target on the kill line and stop attacking.

RWDA detects the line:

```
A starburst tattoo flares and bathes <Name> in red light
```

If `<Name>` matches your current or most recently cleared target, RWDA:
1. Calls `state.setTarget(Name)` — resets `dead=false`, `available=true`
2. Emits a `TARGET_ALIVE` event
3. Continues attacking as normal on the next tick

This is fully automatic. No command needed.

---

## Persistent Config

RWDA saves and loads config from `<MudletHome>\rwda_config.lua`.

```
rwda save config    -- write current settings to disk
rwda load config    -- load settings from disk
```

Auto-load on bootstrap is enabled by default. To disable:

```lua
lua rwda.config.persistence.auto_load = false
rwda save config
```

Settings that are persisted include: strategy profile, retaliation settings, finisher settings, breath/venom preferences, and all `rwda set ...` values.

---

## Troubleshooting

### RWDA isn't sending attacks

1. `rwda status` — check `on/off`, `avail`, and `dead` fields
2. `rwda explain` — check the reason code:
   - `target_unavailable` — target isn't in your room
   - `no_balance` / `no_equilibrium` — waiting for balance to return
   - `target_dead` — target confirmed dead, waiting for you to set a new target
   - `stopped` — `rwda stop` was called; use `rwda on` or `rwda engage <name>` to resume
3. `rwda doctor` — full backend diagnostics

### Target won't switch / sticks on wrong person

- Check `rwda status` for `retal=`, `locked=`, `reason=`
- `multi_attacker_hold` means 2+ people are attacking — this is intentional
- Use `rwda target <name>` or `rwda engage <name>` to manually override at any time
- `rwda clear target` to stop attacking entirely

### Devour / disembowel never fires

- Confirm `rwda execute on`
- Check `rwda status` for `execute=on` and that `goal` is set correctly (`dragon_devour` or `impale_kill`)
- `rwda explain` should show `block=devour_window` or `block=disembowel_followup` — if it shows something else, the preconditions aren't met yet
- For devour: check that `tprone=yes` and enough limbs are broken (`state.can_devour` condition)
- For disembowel: check that `target.impaled=yes`

### Patterns not matching your server output

Enable unmatched line capture to see what lines RWDA isn't parsing:

```
rwda set capture on
```

Lines are written to `<MudletHome>\rwda_unmatched.log`. Check that file against the parser patterns and update as needed.

To capture **every** incoming line (not just unmatched ones) for a full combat dump:

```
rwda set captureall on
```

This is useful for building new replay logs or reproducing hard-to-reproduce fights. Disable after capturing to avoid large log files.

### Emergency recovery

If RWDA is broken and attacking or stuck:

```
CLEARQUEUE ALL
lua if rwda and rwda.stop then rwda.stop() end
```

Full restart:

```lua
lua if rwda and rwda.shutdown then rwda.shutdown() end
lua rwda = nil
lua dofile([[C:\Users\jness\Documents\Project Silverfury\ProjectSilverfury\rwda\init.lua]])
```

Then:
```
rwda status
rwda doctor
```
