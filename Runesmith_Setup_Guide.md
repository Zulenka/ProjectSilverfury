# Runeblade & Runicarmour Setup Guide

Quick reference for manually setting up runeblades/runicarmour, and automating it with RWDA's runesmith system.

---

## Ink Costs at a Glance

| Colour  | Approx. Price | Used For                        |
|---------|---------------|---------------------------------|
| Purple  | 250gp         | Lagul, Lagua, Laguz (baseline)  |
| Red     | 10gp          | Pithakhan (core rune)           |
| Blue    | 40gp          | Hugalaz, Eihwaz (core rune)     |
| Yellow  | 80gp          | Eihwaz, Nairat (core rune)      |
| Gold    | 400gp         | Gebu, Gebo (armour only)        |

Store all inks in your Rift (`INR <colour> ink`). They are Rift-compatible.

---

## Runicarmour

Adds dual physical resist (blunt + cutting) for 100 Achaean months. Binds to you on empower — cannot be traded after.

**What you need:**
- 2x Gold Ink
- 2000 mana
- The armour you intend to keep

**Manual commands:**
```
SKETCH GEBU ON <armour>
SKETCH GEBO ON <armour>
EMPOWER <armour>
```

**With RWDA (automated):**
```
rwda rs armour <ref>
```
Example: `rwda rs armour armour`

---

## Runeblade Setup

A runeblade requires three phases: **baseline sketch → core rune → empower**. Then optionally a **configuration** for combat procs.

### Phase 1 — Baseline (every runeblade)

Sketches the three weapon runes that make a blade a runeblade. Costs **3 Purple Ink**.

```
SKETCH LAGUL ON <weapon>
SKETCH LAGUA ON <weapon>
SKETCH LAGUZ ON <weapon>
```

### Phase 2 — Core Rune (choose one)

This slot defines your runeblade's "always-on" passive. Sketch **after** the baseline, **before** empowering.

| Core Rune   | Ink Cost | Effect                                |
|-------------|----------|---------------------------------------|
| Pithakhan   | 1 Red    | Mana drain procs on hit               |
| Hugalaz     | 1 Blue   | Bonus hail damage chance + enables BISECT |
| Eihwaz      | 1 Blue + 1 Yellow | Masks venoms, complicates curing |
| Nairat      | 1 Yellow | Random freeze proc                    |

```
SKETCH <core_rune> ON <weapon>
```

### Phase 3 — Empower

Costs **2000 mana** and 10s equilibrium. Lock in baseline + core for 100 months.

```
EMPOWER <weapon>
```

### Phase 4 — Configuration (optional, combat procs)

After empowering, sketch 2–3 config runes around your core rune. These **attune** during combat under specific conditions, then you **empower** them for on-hit effects.

```
SKETCH CONFIGURATION <weapon/LEFT/RIGHT> <rune1> <rune2> [rune3]
EMPOWER PRIORITY SET <rune1> <rune2> <rune3>
```

> **Dual-wield tip:** Wield your configured runeblade in the **LEFT hand**. Configuration attunement is checked only on the **first hit** of multi-hit attacks.

To remove a config rune and redo it:
```
SMUDGE <weapon> <rune>
```

---

## RWDA Runesmith — Full Automation

The `rwda runesmith` system (`rwda rs`) handles the entire sketch→empower→configure sequence automatically, waiting for each confirmation before sending the next command.

### Quick Commands

| Command | What it does |
|---|---|
| `rwda rs list` | Show all presets with ink cost |
| `rwda rs list <goal>` | Filter by goal (`pressure`, `impale_kill`) |
| `rwda rs info <preset>` | Full detail on a preset |
| `rwda rs weapon <ref> <preset>` | Full weapon workflow (sketch all runes → empower → configure) |
| `rwda rs armour <ref>` | Armour workflow (sketch gebu+gebo → empower) |
| `rwda rs configure <ref> <preset>` | Configure-only on an already-empowered blade |
| `rwda rs status` | Show current workflow progress |
| `rwda rs cancel` | Abort active workflow |

### Built-in Presets

#### Pithakhan Core (mana drain, 3P + 4R ink)

| Preset | Config Runes | Goal | BISECT | Notes |
|---|---|---|---|---|
| `kena_lock` | kena → sleizak → inguz | impale_kill | — | Primary lock path. Wield LEFT. |
| `kena_bisect` | kena → sleizak → inguz | impale_kill | ✓ | Full kill flow: head attack → mana drain → Kena attunes → impatience → lock → BISECT at ≤20% health. |
| `sleep_lock` | fehu → kena → inguz | impale_kill | — | Opens sleep window during lock. |
| `mana_crush` | kena → mannaz → fehu | pressure | — | Extended mana denial, blocks regen. |
| `fracture_drain` | sowulu → kena → inguz | impale_kill | — | Best vs targets running restoration. |
| `ribs_burst` | inguz → wunjo → kena | impale_kill | — | Stack ribs via paralysis, burst with Wunjo. |

#### Hugalaz Core (hail + BISECT, 3P + 2B + 4R ink)

| Preset | Config Runes | Goal | BISECT | Notes |
|---|---|---|---|---|
| `arm_break` | tiwaz → kena → inguz | impale_kill | — | Breaks both arms when off salve bal. |
| `bisect_finish` | kena → inguz → sleizak | impale_kill | ✓ | Auto-enables BISECT at ≤20% health. |

#### Eihwaz Core (venom masking, 3P + 3B + 1Y + 4R ink)

| Preset | Config Runes | Goal | BISECT | Notes |
|---|---|---|---|---|
| `epilepsy_sleep` | isaz → fehu → kena | pressure | — | Epilepsy when engage blocks escape. |

#### Nairat Core (freeze proc, 3P + 1B + 1Y + 4R ink)

| Preset | Config Runes | Goal | BISECT | Notes |
|---|---|---|---|---|
| `voyria_pressure` | sleizak → fehu → kena | pressure | — | Group/skirmish. Freeze + affliction cascade. |

#### Armour (2G ink)

| Preset | Goal | Notes |
|---|---|---|
| `runicarmour` | — | Dual physical resist, 100 months, binds to you. |

---

## Typical Workflow Examples

### Full kill flow — `kena_bisect` (recommended starting point)

Head attack every tick → Pithakhan mana drain → Kena attunes at ≤20% mana → RWDA auto-empowers Kena → impatience delivered → blocks FOCUS → lock → BISECT at ≤20% health.

```
rwda rs info kena_bisect          -- review ink cost and rune order
rwda rs weapon left kena_bisect   -- start automated workflow
rwda profile kena_lock            -- activate the matching strategy profile
rwda goal impale_kill
```

RWDA will:
1. Sketch `lagul`, `lagua`, `laguz` (baseline)
2. Sketch `pithakhan` (core)
3. `EMPOWER` the weapon
4. Sketch `CONFIGURATION left kena sleizak inguz`
5. Set `EMPOWER PRIORITY` to `kena sleizak inguz`
6. Auto-enable `rwda runelore bisect on`

On completion it auto-syncs your `rwda runelore` config and switches to the `kena_lock` profile.

### Lock without bisect — `kena_lock`

```
rwda rs info kena_lock          -- review ink cost and rune order
rwda rs weapon left kena_lock   -- start automated workflow
rwda rs status                  -- check progress mid-sequence
```

Same as above but bisect is not enabled — use when you want the impatience lock path without committing to a bisect finish.

---

## Common Mistakes

| Problem | Fix |
|---|---|
| Empower fails — missing runes | `OUTR ink` from Rift; re-sketch missing rune |
| Wrong config runes | `SMUDGE <weapon> <rune>`, then re-run `rwda rs configure` |
| Runeblade effects not firing | Ensure weapon is empowered BEFORE sketching config |
| Armour no longer tradeable | By design — empower only armour you plan to keep |
| Proc not triggering in dual-wield | Move configured blade to LEFT hand |
