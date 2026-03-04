# RWDA Quick Start Guide

**Project Silverfury — v0.3.3**

Two paths covered here:
- [Path A — Runewarden: kena\_bisect](#path-a--runewarden-kena_bisect)
- [Path B — Silver Dragon](#path-b--silver-dragon)

---

## Path A — Runewarden: kena\_bisect

### What it does

`kena_bisect` is the primary Pithakhan kill preset:

1. **Lagul / Lagua / Laguz** sketched on the LEFT runeblade — enables Dual-Strike Language (DSL).
2. **Pithakhan** core rune — drains mana every successful head hit.
3. **Config runes** (priority order): `kena → sleizak → inguz`
   - Kena attunes at ≤ 20% mana → triggers impatience on proc.
   - Sleizak delivers nausea while target still has balance.
   - Inguz stacks cracked ribs for kill pressure.
4. **Bisect flag ON** — RWDA auto-triggers BISECT at ≤ 20% health.
5. **Kelp pressure cycle**: vernalius → xentio → prefarar on every pressure tick to burn the target's kelp supply. When impatience finally lands, FOCUS is blocked and asthma cannot be kelp-cured away.

**Kill flow:** head attacks → Pithakhan drains mana → Kena attunes at ≤ 20% → EMPOWER kena → impatience proc → lock → BISECT.

---

### Step 1 — Load check

```
rwda doctor
```

Confirm `legacy_present=yes` and `hud: initialized=yes`. If either fails, reload Legacy / WolfUI first.

---

### Step 2 — Sketch the runeblade (Runesmith)

The Runesmith engine handles all SKETCH and EMPOWER commands automatically.

> Make sure you are holding the correct runeblade before running this.

```
rwda runesmith weapon left kena_bisect
```

This sketches `lagul → lagua → laguz → pithakhan` on the LEFT runeblade, then empowers config runes `kena / sleizak / inguz` in priority order. RWDA will echo each step and confirm when the workflow is complete.

To check progress at any time:
```
rwda runesmith status
```

To abort:
```
rwda runesmith cancel
```

> **Ink cost:** 3 Purple + 4 Red

---

### Step 3 — Verify runelore config

After the Runesmith workflow finishes, it auto-syncs your runelore config (`auto_sync_runelore` is on by default). Confirm with:

```
rwda runelore status
```

Expected output:
```
[Runelore] bisect=ON  core=pithakhan  config=kena,sleizak,inguz
```

If `bisect=OFF` for any reason, force it on:
```
rwda runelore bisect on
```

---

### Step 4 — Venom setup

Set your DSL venom slots. The planner uses a two-tier system automatically:

- **Tier 1 (core lock)** — kalmia → gecko → slike → curare (hardcoded, always first)
- **Tier 2 (kelp pressure)** — vernalius → xentio → prefarar (auto-applied after core affs land)

Set the base mainhand / offhand starting venoms:
```
rwda venoms main kalmia
rwda venoms off gecko
```

Confirm the kelp pressure cycle is set (Runesmith should have applied it automatically from the preset):
```
rwda status
```

If you need to set it manually:
```
rwda set venomcycle vernalius xentio prefarar
```

---

### Step 5 — Strategy and goal

`kena_bisect` uses the `kena_lock` profile and `impale_kill` goal:
```
rwda goal impale_kill
rwda set prompttick on
```

---

### Step 6 — Fury (v0.3.3+)

Fury is on by default and fires automatically on engage. No setup required. To confirm:
```
rwda fury status
```

To adjust the willpower floor for re-activation (default 1500):
```
rwda fury minwp 1200
```

---

### Step 7 — Fight

```
rwda engage <target>
rwda retaliate on
```

`rwda engage` in one shot:
- Sets and locks target
- Fires FALCON SLAY + TRACK
- Sends FURY ON (free first-use slot)
- Fires the first combat tick

Watch the HUD — it shows current goal, last action, limb state, and fury/willpower.

To force a manual tick:
```
rwda tick
```

To stop immediately:
```
rwda stop
```

---

### kena\_bisect cheatsheet

```
-- One-time setup
rwda runesmith weapon left kena_bisect   -- sketch + empower LEFT blade
rwda venoms main kalmia
rwda venoms off gecko
rwda goal impale_kill
rwda set prompttick on

-- Each fight
rwda engage <target>
rwda retaliate on

-- Diagnostics
rwda doctor
rwda runelore status
rwda fury status
rwda selftest
```

---

## Path B — Silver Dragon

### What it does

Dragon form uses a separate strategy block set. The planner prioritises:

| Priority | Block | Fires when... |
|---|---|---|
| 100 | `summon_breath` | Breath not yet summoned |
| 96 | `dragon_shield_curse` | Target has shield |
| 94 | `dragon_strip_rebounding` | Target has rebounding |
| 93 | `dragon_lyred_blast` | Target is lyred |
| 92 | `dragon_flying_becalm` | Target is flying |
| 86 | `dragon_curse_gut` | Target not prone |
| 80 | `devour_window` | Goal = dragon\_devour + can\_devour |
| 79 | `dragon_bite` | Target prone |
| 70 | `dragon_torso_pressure` | Torso not broken |
| 20 | `dragon_limb_pressure` | Always |

**Kill flow:** Curse gut venoms until prone → bite → crack torso → DEVOUR when health threshold is met.

---

### Step 1 — Set breath type

```
rwda dragon breath lightning
```

Other valid values: `fire`, `ice`, `venom`, `lightning`, `mana`.

---

### Step 2 — Set goal and profile

```
rwda goal dragon_devour
rwda profile duel
rwda set prompttick on
```

Use `rwda profile group` when fighting alongside others — the group profile uses a lighter block set.

---

### Step 3 — Devour threshold

Devour fires when the target's health falls to the configured threshold. Default is 6%.

To change:
```
rwda set devour 8.0
```

---

### Step 4 — Fury

Same as Runewarden — fires automatically on engage. No setup needed. Dragon form drains endurance faster so watch the HUD.

```
rwda fury status
rwda fury minwp 1200    -- lower the willpower floor if needed
```

If endurance is a concern mid-fight, raise the floor:
```
rwda fury off
```

---

### Step 5 — Fight

```
rwda engage <target>
rwda retaliate on
```

The first tick sends `summon_breath` automatically if breath is not already summoned. After that, the planner cycles curse → gut → prone → bite until devour fires.

---

### Dragon cheatsheet

```
-- One-time setup
rwda dragon breath lightning
rwda goal dragon_devour
rwda profile duel
rwda set prompttick on
rwda set devour 6.0

-- Each fight
rwda engage <target>
rwda retaliate on

-- Diagnostics
rwda doctor
rwda selftest
rwda fury status
rwda explain           -- see why last action was chosen
```

---

## Common commands (both paths)

| Command | What it does |
|---|---|
| `rwda status` | Full state snapshot |
| `rwda explain` | Explain last planner decision |
| `rwda doctor` | Health check — Legacy, HUD, all modules |
| `rwda selftest` | Logic engine self-test |
| `rwda stop` | Emergency halt — clears queue |
| `rwda resume` | Resume after stop |
| `rwda save` | Persist current config to disk |
| `rwda fury status` | Show fury state + willpower + endurance |
| `rwda falcon status` | Show falcon slay / track state |
| `rwda runesmith status` | Show active sketch/empower workflow |
| `rwda runelore status` | Show current rune config |
