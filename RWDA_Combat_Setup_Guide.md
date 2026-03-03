# RWDA Combat Setup Guide

**Version 0.2.0** — Runewarden/Dragon Action System

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [First-Time Verification](#2-first-time-verification)
3. [Core Weapon & Venom Config](#3-core-weapon--venom-config)
4. [Dragon Config](#4-dragon-config)
5. [Retaliation Setup](#5-retaliation-setup)
6. [Auto-Execute (Finisher) Setup](#6-auto-execute-finisher-setup)
7. [Strategy Profiles](#7-strategy-profiles)
8. [Runelore Setup (Runewarden)](#8-runelore-setup-runewarden)
9. [Integration Settings](#9-integration-settings)
10. [Starting a Fight](#10-starting-a-fight)
11. [Saving & Loading Your Settings](#11-saving--loading-your-settings)
12. [Full Setup Command Cheatsheet](#12-full-setup-command-cheatsheet)

---

## 1. Prerequisites

Before running any setup commands, ensure the following are loaded in Mudlet:

| Package | Purpose |
|---|---|
| `RWDA_Bootstrap.xml` | Core RWDA system (parser, planner, executor, strategy, HUD) |
| `WolfUI.xml` | GUIframe panel system (HUD renders into this) |
| Legacy (SVO replacement) | Combat queue backend — RWDA requires Legacy |
| `limb_1.2.mpackage` *(optional)* | Provides `lb` global for precise limb damage % tracking |

**Load order matters.** WolfUI and Legacy must be loaded before RWDA bootstraps, otherwise the HUD won't attach to the panel and Legacy integration won't register.

After loading, Mudlet's main window should show the RWDA log line:
```
[RWDA] RWDA bootstrap complete (version 0.2.0).
```

---

## 2. First-Time Verification

Run the doctor to confirm everything is wired up before touching any settings:

```
rwda doctor
```

Expected output for a healthy setup:
```
doctor legacy_present=yes legacy_curing=yes ... ak=yes ...
doctor hud: initialized=yes visible=yes polling=yes
doctor assess: enabled=yes ...
doctor strategy enabled=yes version=1 profile=duel
doctor retaliation enabled=no ...
doctor finisher enabled=yes ...
```

**If you see `legacy_present=no`:** Legacy hasn't loaded or registered yet. Trigger a prompt (press Enter in-game) and re-run `rwda doctor`. RWDA detects Legacy on the first prompt after bootstrap.

**If you see `ak=no`:** The `limb_1.2.mpackage` isn't installed. Limb tracking falls back to the `assess_target` strategy block (automatic) — you're not missing anything critical, but the lb integration gives better real-time accuracy.

**If you see `hud: initialized=no`:** The HUD Geyser panel didn't build. Usually means WolfUI wasn't loaded first. Reload WolfUI, then run `rwda reload`.

Run the engine selftest to confirm logic is healthy:
```
rwda selftest
```

Run the UI selftest to confirm HUD and builder modules are loaded:
```
rwda selftest ui
```

Both should report `failed=0`.

---

## 3. Core Weapon & Venom Config

### DSL (Dual-Slash) Venoms

RWDA applies two venoms per dual-slash attack. The planner picks from your priority list, selecting whichever two venoms the target is most missing.

**Set your primary venoms** (the default starting pair):
```
rwda set venoms curare gecko
```
- First argument = mainhand venom
- Second argument = offhand venom

**Default:** `curare / gecko`

**The full venom priority list** (order = most-wanted first) controls which venoms get selected each tick. To change it, edit `config.runewarden.lock_venom_priority` in a saved config file (see Section 10), or adjust the defaults in `rwda/config.lua`.

Default priority:
```
kalmia → gecko → slike → curare → epteth → vernalius → xentio → prefarar → euphorbia → aconite → larkspur
```

### Limb Prep Sequence

The sequence RWDA breaks limbs in. Default (causes prone → disembowel kill):
```
left_leg → torso → right_leg
```
This is set in `config.runewarden.prep_limbs`. Change it by editing the saved config file after doing a first save (Section 10).

### Near-Break Threshold

When a limb reaches **75% damage** (default), RWDA switches from balanced spread-damage to focused sequential breaking. To change:
```lua
-- In Mudlet's Lua console:
rwda.config.runewarden.near_break_pct = 80
rwda config.savePersisted()
```

---

## 4. Dragon Config

### Breath Type

Sets which breath type you use in dragon form:
```
rwda set breath lightning
```
Other valid values: `fire`, `ice`, `poison`, `mist`, `sand`, `lightning` (check Achaea for your actual breath skill).

**Default:** `lightning`

### Curse Priority

Order in which the dragon curse is chosen each tick:
```
rwda set cursepriority impatience asthma paralysis stupidity
```
List as many as you want — the system picks whichever the target is missing most.

**Default order:** `impatience → asthma → paralysis → stupidity`

### Gut Venom Priority

Venoms used with the `gut` dragon command (applied to bite + breathgust combos):
```
rwda set gutvenompriority curare kalmia gecko slike aconite
```

**Default order:** `curare → kalmia → gecko → slike → aconite`

### Devour Threshold

Minimum time (seconds) the target must have been prone before RWDA attempts devour. Prevents premature devour attempts:
```lua
-- In Mudlet's Lua console:
rwda.config.dragon.devour_threshold = 6.0
```

**Default:** `6.0` seconds

---

## 5. Retaliation Setup

Auto-retaliation switches your target automatically when someone attacks you. It can be toggled at any time mid-fight.

### Enable/Disable

```
rwda retaliate on
rwda retaliate off
```

**Default:** `off` (must be explicitly enabled)

### Lock Duration

How long (in ms) retaliation holds you on the new attacker before reverting to your original target:
```
rwda set retalockms 8000
```
**Default:** `8000` ms (8 seconds)

### Debounce

Minimum time between target swaps. Prevents rapid flipping when multiple people hit you simultaneously:
```
rwda set retaldebounce 1500
```
**Default:** `1500` ms

### Confidence Threshold

Minimum confidence (0.0–1.0) required before a hit is considered an "aggressor" hit:
```
rwda set retalminconf 0.65
```
**Default:** `0.65`

### Restore Previous Target

After the retaliation lock expires, return to whoever you were targeting before:
```lua
-- Open builder → Shared tab → toggle "restore prev target"
-- Or in Lua console:
rwda.config.retaliation.restore_previous_target = true
```

**Default:** `true`

### Ignore Non-Players

Ignore mob attacks (only retarget on player-looking names):

Open `rwda builder` → **Shared** tab → toggle **ignore non-players**.

**Default:** `true`

---

## 6. Auto-Execute (Finisher) Setup

The finisher watches for the right kill window and automatically sends `disembowel` (human) or `devour` (dragon) when conditions are met.

### Enable/Disable

```
rwda execute on
rwda execute off
```

**Default:** `on`

### Cooldown Between Attempts

Minimum time between two finisher attempts (prevents spam on immediate fails):
```
rwda set executecooldown 1500
```
**Default:** `1500` ms

### Fallback Window

How long after a finisher attempt the system waits for confirmation before routing to the fallback action:
```
rwda set executefallbackwindow 6000
```
**Default:** `6000` ms

### Per-Finisher Timeouts

How long to wait for a `disembowel` or `devour` confirmation line before giving up:
```
rwda set executetimeout disembowel 2500
rwda set executetimeout devour 8000
```
**Defaults:** `2500` ms (disembowel) / `8000` ms (devour)

### Fallback Blocks

Which strategy block to resume with after a failed finisher attempt:
```
rwda set executefallback human limbprep_dsl
rwda set executefallback dragon dragon_force_prone
```
**Defaults:** `limbprep_dsl` (human) / `dragon_force_prone` (dragon)

---

## 7. Strategy Profiles

RWDA ships with four built-in profiles that control the strategy block priority lists.

### Profiles

| Profile | Use Case |
|---|---|
| `duel` | 1v1 — full impale/disembowel kill chain |
| `group` | Group fights — limb pressure + stripping, no kill chain |
| `kena_lock` | Runelore: head-focused DSL + BISECT finisher (requires hugalaz core + kena config rune) |
| `head_focus` | Runelore: head-focused DSL + Pithakhan mana drain (no BISECT; use with pithakhan/nairat/eihwaz core) |

### Switch Profile

```
rwda profile duel
rwda profile group
rwda profile kena_lock
rwda profile head_focus
```

### View Current Strategy

```
rwda strategy show
```

### Runewarden Blocks (duel profile defaults)

| Block | Priority | Fires when |
|---|---|---|
| `strip_rebounding` | 100 | Target has rebounding |
| `strip_shield` | 95 | Target has shield |
| `impale_window` | 92 | goal=impale_kill, target prone, both legs broken, not yet impaled |
| `disembowel_followup` | 91 | goal=impale_kill, target impaled |
| `intimidate_lock` | 90 | goal=impale_kill, target prone, both legs broken |
| `assess_target` | 30 | Limb data is stale (>7s since last assess) |
| `limbprep_dsl` | 20 | Always (fallback attack) |

### Runewarden Blocks (kena_lock profile)

| Block | Priority | Fires when |
|---|---|---|
| `strip_rebounding` | 100 | Target has rebounding |
| `bisect_window` | 99 | hugalaz core + `bisect on` + target health ≤ 20% |
| `strip_shield` | 95 | Target has shield |
| `assess_target` | 30 | Limb data is stale |
| `head_focus_dsl` | 20 | Always — always DSLs **head** limb |

The `bisect_window` block is skipped entirely unless `rwda runelore bisect on` is set and the core rune is `hugalaz`. The `head_focus` profile is identical but ships with `bisect_window` disabled — use it with Pithakhan, Nairat, or Eihwaz core runes.

### Dragon Blocks (duel profile defaults)

| Block | Priority | Fires when |
|---|---|---|
| `summon_breath` | 100 | Breath not summoned |
| `dragon_shield_curse` | 96 | Target has shield |
| `dragon_strip_rebounding` | 94 | Target has rebounding |
| `dragon_lyred_blast` | 93 | Target is lyred |
| `dragon_flying_becalm` | 92 | Target is flying |
| `dragon_curse_gut` | 86 | Target not prone |
| `dragon_bite` | 79 | Target prone |
| `devour_window` | 80 | goal=dragon_devour, devour conditions met |
| `dragon_torso_pressure` | 70 | Torso not broken |
| `dragon_limb_pressure` | 20 | Always (fallback) |

### Runelore Profile Setup

See [Section 8](#8-runelore-setup-runewarden) for the full Runelore configuration flow before switching to `kena_lock` or `head_focus`.

### Modify Blocks via Builder

Open the visual editor:
```
rwda builder open
```

- Click a tab: **Runewarden**, **Dragon**, **Shared**, **Safety**
- Click **[ON]** / **[OFF]** to toggle individual blocks
- Click **+** / **-** to adjust priority in steps of 5
- Click **Apply** to push changes to the live system
- Click **Save** to persist to disk immediately

Close:
```
rwda builder close
```

### Modify Blocks via Command

```
rwda strategy apply
rwda strategy save
rwda strategy load
```

---

## 8. Runelore Setup (Runewarden)

RWDA integrates with the Runelore skill to automate rune empowering, track attunement, and fire BISECT at the right moment. Setup takes about 30 seconds after your first run.

### Step 1 — Declare your runeblade configuration

```
rwda runelore core pithakhan             -- or: hugalaz, nairat, eihwaz
rwda runelore config kena,sleizak,inguz  -- comma-separated, no spaces
```

This tells RWDA what runes your runeblade actually has. It does not send any in-game commands — it just configures the tracker.

### Step 2 — Enable auto-empower

```
rwda runelore autoempower on
```

When a configuration rune attunes (RWDA detects the game message), it immediately sends `EMPOWER <rune>`. If multiple runes attune on the same tick, empower priority determines which fires first.

### Step 3 — Set empower priority (optional)

```
rwda runelore priority kena inguz sleizak
```

Default order matches the kena lock path: Kena gets empowered first (delivers impatience at <40% mana), then Inguz (paralysis when target is paralysed), then Sleizak.

### Step 4 — Switch profile

```
rwda profile kena_lock     -- head DSL + BISECT (hugalaz core)
rwda profile head_focus    -- head DSL only (pithakhan/nairat/eihwaz core)
```

### Step 5 — Enable BISECT (hugalaz only)

If your core rune is **hugalaz**, enable the BISECT finisher:

```
rwda runelore core hugalaz
rwda runelore bisect on
```

RWDA will automatically fire `BISECT <target>` as a freestand action the moment target health drops to ≤ 20%. BISECT bypasses rebounding — no need to strip first.

### Verify the setup

```
rwda runelore status
```

Expected output:
```
[Runelore] core=hugalaz  config=kena,sleizak,inguz
attuned=none  empowered=no  auto_empower=on  bisect_enabled=on
empower_priority: kena > inguz > sleizak
```

### How the Kena lock path works

```
Head attack every tick
  → Pithakhan fires (guaranteed proc when head is broken)
  → Target mana falls below 40%
  → Kena attunes
  → RWDA auto-sends EMPOWER kena
  → Impatience delivered
  → Impatience blocks FOCUS
  → Asthma/paralysis sticks → true lock
  → Health reaches ≤20% → BISECT (if hugalaz)
```

### Attunement Conditions (Dec 2025 classleads)

| Rune | Attunes when |
|---|---|
| **Kena** | Target mana < 40% |
| **Inguz** | Target is paralysed |
| **Sleizak** | Target is weary or lethargic |
| **Fehu** | Target is prone or missing insomnia |
| **Sowulu** | Struck limb is damaged |
| **Mannaz** | Target is off focus balance |
| **Wunjo** | Target is shivering |
| **Isaz** | Engage prevents escape |
| **Tiwaz** | Off salve balance + no restoration needed |
| **Loshre** | Target is addicted |

### Save your Runelore config

```
rwda save config
```

All runelore settings (`core`, `config`, `auto_empower`, `bisect_enabled`, `empower_priority`) are included in the saved config and restored on next load.

---

## 9. Integration Settings

### Auto-Enable with Legacy

RWDA automatically enables itself when it detects Legacy is active:
```lua
-- In builder → Shared tab → toggle "auto-enable with Legacy"
-- Default: ON
```

### Follow Legacy Target

Sync RWDA's target from Legacy's `target` global:
```lua
-- In builder → Shared tab → toggle "follow Legacy target"
-- Default: ON
```

### Tick on Each Prompt

Fire a combat tick on every `sysPrompt` event (replaces the timer-based tick):
```lua
-- In builder → Shared tab → toggle "tick on each prompt"
-- Default: OFF (recommended to leave OFF — GMCP vitals drive ticks by default)
```

### Auto-Goal Escalation (Runewarden only)

Automatically escalates goal from `limbprep` → `impale_kill` when both legs are broken, and reverts back to `limbprep` if the legs recover before impale lands:
```
rwda set autogoal on
rwda set autogoal off
```
**Default:** `on`

> **Dragon has no auto-goal.** Dragon strategy blocks are fully condition-driven — `devour_window` fires automatically when `state.can_devour` is true regardless of goal. To enable or suppress devour attempts, set the goal manually:
> ```
> rwda goal dragon_devour   -- devour_window block active
> rwda goal pressure        -- damage pressure only, no devour attempt
> ```

---

## 10. Starting a Fight

### Quick Attack (engage + enable in one command)

```
att Enemyname
```
This sets the target, enables RWDA, and plans the first action immediately.

### Manual Engage Flow

```
rwda target Enemyname    -- set target without enabling
rwda on                  -- enable offense
```

### Switch Mode Mid-Fight

```
rwda mode auto           -- auto-selects human or dragon based on form
rwda mode human          -- force human (Runewarden) blocks
rwda mode dragon         -- force dragon blocks
```

### Change Goal Mid-Fight

```
rwda goal limbprep       -- break limbs toward impale setup
rwda goal impale_kill    -- impale + disembowel kill
rwda goal pressure       -- general limb pressure (group fights)
rwda goal dragon_devour  -- dragon devour kill chain
```

### Stop Immediately

```
rwda stop
```
Disables offense, clears the server queue, and halts all pending actions. Also accessible from `rwda builder` → **Safety** tab → **[STOP NOW]**.

### Resume After Stop

```
rwda resume
```

### Reload After Config Changes

```
rwda reload
```
Reloads all RWDA files and re-detects Legacy/AK. Run this after installing `limb_1.2.mpackage` or making manual changes to Lua files.

---

## 11. Saving & Loading Your Settings

### What Gets Saved

`rwda save config` writes a `rwda_config.lua` file to your Mudlet profile home directory. It captures:

- Logging settings
- Integration flags (auto-enable, follow Legacy target, group target events)
- Combat flags (auto-tick, auto-goal, room presence requirements)
- Retaliation settings (enabled, lock ms, debounce, confidence, restore-prev, ignore non-players)
- Finisher settings (enabled, cooldown, fallback window, timeouts, fallback blocks)
- Parser settings (capture flags, form detection phrases)
- Runewarden config (prep limbs, near-break %, venom priorities, DSL venoms)
- Dragon config (breath type, default goal, devour threshold)
- Strategy profiles (all blocks with enabled/priority, active profile)

> **Note:** `swords_wielded` is runtime state, not saved — it resets to `true` on each reload (assumed wielded at start).

> **Runelore**: `core`, `config runes`, `auto_empower`, `bisect_enabled`, and `empower_priority` are all included in the saved config.

### Save Config

```
rwda save config
```

You'll see a log line confirming the file path:
```
[RWDA] saved to C:\Users\...\Mudlet\profiles\<yourprofile>\rwda_config.lua
```

**Do this after every setup session.**

### Load Config

```
rwda load config
```

Loads `rwda_config.lua` from the same default path and merges it into the live config. Runs automatically on bootstrap if the file exists (controlled by `config.persistence.auto_load = true`).

### Save From the Builder

Click **Save** (blue button) in `rwda builder open` — this applies pending changes AND writes to disk in one step.

### Save to a Custom Path

```lua
-- In Mudlet's Lua console:
rwda.config.savePersisted("C:\\MyBackups\\rwda_config_duel.lua")
```

### Load From a Custom Path

```lua
-- In Mudlet's Lua console:
rwda.config.loadPersisted("C:\\MyBackups\\rwda_config_duel.lua")
```

### Backup Your Profile

Copy the saved `rwda_config.lua` from your Mudlet profile directory to a safe location. This file is plain Lua — you can open it in any text editor to inspect or tweak values directly.

**Default save path:**
```
C:\Users\<you>\AppData\Roaming\Mudlet\profiles\<profilename>\rwda_config.lua
```

### Verify After Load

After loading, run:
```
rwda show config
rwda doctor
```
to confirm all settings came back as expected.

---

## 12. Full Setup Command Cheatsheet

```
-- Verification
rwda doctor
rwda selftest
rwda selftest ui
rwda selftest runelore            -- Runelore engine tests only
rwda show config
rwda status

-- Core config
rwda set venoms <main> <off>            -- e.g. rwda set venoms curare gecko
rwda set breath <type>                  -- e.g. rwda set breath lightning
rwda set cursepriority <v1> <v2> ...    -- dragon curse order
rwda set gutvenompriority <v1> <v2> ... -- dragon gut venom order
rwda set autogoal on|off

-- Retaliation
rwda retaliate on|off
rwda set retalockms <ms>
rwda set retaldebounce <ms>
rwda set retalminconf <0.0-1.0>

-- Finisher (auto-execute)
rwda execute on|off
rwda set executecooldown <ms>
rwda set executefallbackwindow <ms>
rwda set executetimeout disembowel <ms>
rwda set executetimeout devour <ms>
rwda set executefallback human <block_id>
rwda set executefallback dragon <block_id>

-- Profile & strategy
rwda profile duel|group|kena_lock|head_focus
rwda mode auto|human|dragon
rwda goal limbprep|impale_kill|pressure|dragon_devour
rwda strategy show
rwda builder open|close

-- Runelore (Runewarden)
rwda runelore status                      -- view core, config runes, attunement
rwda runelore core <rune>                 -- pithakhan, hugalaz, nairat, eihwaz
rwda runelore config <r1,r2,r3>           -- comma-separated config runes
rwda runelore autoempower on|off          -- auto-EMPOWER on attunement
rwda runelore bisect on|off               -- enable BISECT at ≤20% (hugalaz only)
rwda runelore empower <rune>              -- manually dispatch EMPOWER <rune>
rwda runelore priority <r1> <r2> ...      -- empower priority order

-- Save & load
rwda save config
rwda load config
rwda reload

-- Combat
att <name>                    -- engage + enable
rwda target <name>
rwda on
rwda off
rwda stop
rwda resume

-- HUD
rwda hud show|hide|refresh
```
