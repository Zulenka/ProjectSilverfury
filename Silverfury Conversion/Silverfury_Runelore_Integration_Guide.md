# Silverfury.mpackage integration guide (Runewarden Runelore + “Pith + Kena” lock)

This document is written as **instructions for a coding agent/AI** to extend **Silverfury.mpackage** cleanly, using the supplied source documents as the “truth” for mechanics and the intended combat flow.

## What you’re implementing

You are adding a modern Runewarden line that:

- **Uses Pithakhan + Kena** to push/hold the target below a mana threshold and repeatedly punish them with **impatience** (focus denial).
- **Focuses head** because **Pithakhan reliably fires on damaged head** and drains *more* on **broken head**.
- **Builds a “kelp stack”** (apply multiple afflictions that are cured by **kelp**) before executing so the enemy’s herb channel is clogged.

You are also importing a **curing reference table** (affliction → cure) and a **Runelore ability reference** (rune syntax / triggers / empower effects) so Silverfury can reason about:
- which venoms to apply,
- which cures the target likely uses,
- which runes to empower and why,
- and which limb to prep/break at each step.

## Silverfury package map (where to add things)

Silverfury.mpackage currently contains these key Lua modules (inside `Silverfury.xml`):

### Core decision pipeline
- `SF: engine/planner`  
  Chooses the next action each tick. Must stay **pure**: it decides, it does not “discover” data by sending commands.
- `SF: engine/queue`  
  The only place that should send commands (`queue.send`, `queue.pend`, anti-spam).
- `SF: scenarios/*`  
  Finite-state “mode” logic: `SETUP → MAINTAIN → EXECUTE`. This is where the new “break leg → break head → break leg” flow belongs.

### Data-driven combat inputs
- `SF: offense/venoms`  
  Venom metadata (`venoms.DATA`) and `venoms.pick()` selection rules.
- `SF: runelore/runes`  
  Rune database (`runes.DATA`) and helper queries.
- `SF: runelore/core`  
  Tracks attunement/empower and provides condition evaluators for configuration runes.

### Parsing / state
- `SF: parser/incoming`  
  Converts incoming game text to events/state (already tracks pith-drain event + rune attunement lines).
- `SF: parser/outgoing`  
  Tracks outgoing commands and (limited) confirms; this is the best place to add *assumed* aff tracking from the venoms you just delivered.
- `SF: state/target`  
  Stores target limbs/affs/defs. It supports confidence decay, but currently very few things write affs.

## Clean architecture rule: separate “data”, “inference”, “decisions”
To keep the system maintainable:

1. **Data modules** only define tables: affliction cures, rune definitions, venom definitions.
2. **Inference modules** update target state from observations:
   - “we sent venom X” → assume aff Y
   - “target ate kelp” → remove one kelp-cured aff from target (best-guess)
3. **Decision modules** (planner/scenarios) read state + config and choose actions.

Do not put large static tables in the planner/scenarios.

---

# Part 1: Import the Affliction → Cure data

## Goal
Use the curing table to support:
- Correct metadata for venoms (so “kelp stack” is accurate).
- Cure-bucket inference (“they ate kelp, so one of the kelp affs cleared”).
- Better rune/venom strategy choices (e.g., apply more kelp-cured affs if kelp channel is “busy”).

## Implementation steps

### 1) Add a dedicated data module
Create a new script in the package:

**Name:** `SF: data/afflictions`  
**File header:** `-- Silverfury/data/afflictions.lua`

It should export two tables:

1. `Silverfury.data.afflictions.AFFS`  
   Mapping: `aff_name -> { action, herb, mineral }`

2. `Silverfury.data.afflictions.CURE_BUCKETS`  
   Inverted mapping: `cure_item -> { aff1=true, aff2=true, ... }`  
   (Separate buckets for `herb:` and `smoke:` if you want to disambiguate.)

**Normalization rules:**
- keys should be lowercase and snake_case if needed (e.g. `"cracked_ribs"`), but match the naming Silverfury uses for `target.hasAff("...")`.
- keep original “display name” in the record if you want UI output.

### 2) Populate AFFS from the provided table
Transcribe only what you need first (minimal viable set), then expand.

**Minimal set for Pith+Kena line:**
- asthma → kelp
- clumsiness → kelp
- sensitivity → kelp
- weariness → kelp
- paralysis → bloodroot
- impatience → goldenseal
- anorexia → epidermal (salve)
- slickness → bloodroot (and/or valerian smoke)
- nausea → ginseng
- addiction → ginseng
- crippled limb → mending (salve)

Later, expand to the full table.

### 3) Add helper functions (tiny, pure)
Add utility helpers to pick/remove affs by cure bucket:

- `getCureBucket(cure_item) -> set of affs`
- `chooseAffToClear(target, cure_item, strategy) -> aff_name|nil`  
  Strategy can be: newest-applied, highest-priority, confirmed-first, etc.

---

# Part 2: Fix and extend venom metadata + “kelp stack” selection

## What “kelp stack” means (operationally)
It means: before attempting to execute, **apply multiple kelp-cured afflictions** so the opponent must repeatedly eat kelp, slowing their ability to clear asthma and other key affs.

This is explicitly stated in the source conversation: “build a kelp stack meaning hit with venoms that need kelp to cure.” (Bisec Flow)

## Data changes in `SF: offense/venoms`

### 1) Correct venom → aff mapping to match the cure table
Update `venoms.DATA` so each venom includes:
- `aff` (existing)
- `cure_item` (NEW: the specific herb/salve/smoke)
- `cure_channel` (optional: herb/salve/smoke/focus/sip)
- `tags` (existing)

Example (illustrative, adjust to your naming):

```lua
kalmia   = { aff="asthma",     cure_item="kelp",      cure_channel="herb",  tags={"lock","kelp"} },
xentio   = { aff="clumsiness", cure_item="kelp",      cure_channel="herb",  tags={"pressure","kelp"} },
prefarar = { aff="sensitivity",cure_item="kelp",      cure_channel="herb",  tags={"pressure","kelp"} },
vernalius= { aff="weariness",  cure_item="kelp",      cure_channel="herb",  tags={"pressure","kelp"} },
curare   = { aff="paralysis",  cure_item="bloodroot", cure_channel="herb",  tags={"lock"} },
slike    = { aff="anorexia",   cure_item="epidermal", cure_channel="salve", tags={"lock"} },
gecko    = { aff="slickness",  cure_item="bloodroot", cure_channel="herb",  tags={"lock"} },
```

### 2) Add config-driven “kelp stack” priorities
In `SF: config` add:

```lua
venoms = {
  -- ...
  kelp_stack_priority = { "kalmia", "vernalius", "xentio", "prefarar" },
  kelp_stack_target_count = 3,  -- how many kelp-cured affs we want before “execute”
}
```

### 3) Extend `venoms.pick()` with a strategy parameter
Add:

- `venoms.pick(mode)` where mode can be:
  - `"lock"` (existing behavior)
  - `"kelp_stack"` (favor kelp-cured venoms)
  - `"pressure"` (optional)

Pseudo-logic:

```text
if mode == "kelp_stack":
  choose 2 venoms from kelp_stack_priority that target does not already have
else:
  choose 2 venoms from lock_priority, with your existing bypass rules
```

Keep this change backwards compatible: if mode is nil, keep current behavior.

---

# Part 3: Add target aff tracking that is “good enough” for planning

Right now, Silverfury scenarios require target affs, but very little code actually adds them. You must add a minimal inference loop.

## 1) Assume affs when your attack confirms
In `SF: parser/outgoing`, when a DSL (or razeslash) confirm line triggers:

- extract the last-sent venoms from `_last_cmd` (you already do this on send)
- look up each venom’s `aff` in `venoms.DATA`
- call `Silverfury.state.target.addAff(aff, false)` (assumed, not confirmed)

This makes `target.hasAff("asthma")` etc work.

## 2) Remove affs when you observe a cure action
In `SF: parser/incoming`, add patterns like:

- `"(.-) eats some kelp"` → if that name is the current target, clear one aff from the **kelp** cure bucket.
- `"(.-) eats some bloodroot"` → clear one from bloodroot bucket (paralysis, etc).
- `"(.-) eats some goldenseal"` → clear one from goldenseal bucket (impatience, etc).
- `"(.-) applies an epidermal salve"` → clear anorexia (and other epidermal).
- `"(.-) focuses"` / `"(.-) uses focus"` → clear one focus-cured aff if you track those.

**Important:** Achaea curing can be ambiguous (one herb cures multiple affs). Your implementation should be a *best guess*, not certainty:
- remove the most recently applied aff in that bucket (LIFO), or
- remove the highest-priority aff for your lock plan (so your model is conservative).

---

# Part 4: Implement the Pith + Kena head-focus flow

## Mechanics you must encode
From the provided Runelore integration notes and official patch posts:

- **KENA fires** when the target’s mana is **below 40%** (changed from 20%).  
- **PITHAKHAN** drains more mana when the target’s **head is broken** (10% → 13%).  
- **PITHAKHAN always fires** when striking a target with a **damaged head**.

## Key combat plan (sequence)
The intended prep/break ordering from the source conversation:

1. **Prep 2 legs and head**.
2. **Break/prone with one leg**.
3. **Break head** (to make Pithakhan procs consistent and larger).
4. **Break the other leg** (maintain prone / finish setup).
5. Build kelp stack *before* the execution window; then execute.

## Where to implement: `SF: scenarios/runelore_kill`
Modify (or create a new scenario module) to explicitly manage **phases**:

### Recommended phase model
- `PHASE_BUILD_KELP`  
  Use `venoms.pick("kelp_stack")` and keep hitting until target has at least N kelp-cured affs (or until a timer, so you don’t get stuck).
- `PHASE_PREP_LIMBS`  
  Prep `leg1`, `head`, `leg2` to near-break thresholds.
- `PHASE_BREAK_LEG1`  
  Send `undercut` or `dsl` to finish the break on leg1 and get prone.
- `PHASE_BREAK_HEAD`  
  Switch limb targeting to head until broken.
- `PHASE_BREAK_LEG2`  
  Break the other leg.
- `PHASE_EXECUTE`  
  Continue your chosen finisher (impale/disembowel or other).

### Make limb choice deterministic
The current `planner._nextPrepLimb()` chooses the *highest damage* limb, which makes exact ordering hard. In this scenario, do not call `_nextPrepLimb()`. Instead:
- hard-select the limb based on phase, e.g. `limb="left_leg"`.

### Add templates you need
In `SF: config.attack.templates`, add:

- `undercut = "undercut {target} {limb} {venom1} {venom2}"` (adjust syntax to your in-game command)
- `dsl = ...` already exists

Then in the phase logic call `attacks.build("undercut", ...)` or fill template directly.

---

# Part 5: Expand Runelore rune data (so the AI has options)

## 1) Update `SF: runelore/runes` to match the ability file
For each rune listed in the Runelore ability reference:
- store **syntax** (how to sketch it)
- store **where it works** (ground/totem/weapon/person/armour/configuration)
- store **attune condition** (if configuration rune)
- store **empower effect** (if configuration rune)

Add any missing runes that you want the AI to be able to reason about.

### Suggested schema upgrade
Change each rune record to:

```lua
{
  category = "CONFIGURATION" | "CORE_RUNEBLADE" | ...,
  description = "...",
  syntax = { "SKETCH ...", "..." }, -- list for display + planning
  inks = { red=1, blue=0, yellow=0, purple=0, green=0, gold=0 }, -- optional
  attune_condition = "target_mana_low", -- optional
  empower_effect = { aff="impatience", ... } or "text", -- structured if possible
}
```

Structured empower effects (aff inflicted, limbs broken, etc.) lets Silverfury update target state after empower triggers.

## 2) Update `SF: runelore/core` attune condition evaluators
Right now several condition functions are placeholders. Replace them with functions that reflect actual triggers when you can observe them.

Example upgrades:
- For `target_mana_low`:
  - If you can parse “% mana” from prompts/diagnose/GMCP, use that.
  - Otherwise: infer mana_low if Pithakhan drain has procced repeatedly within a short window *and* head is damaged/broken.

- For `target_off_focus`:
  - Prefer parsing focus usage lines to maintain a cooldown timer rather than checking a fake “focus defence”.

Make all inference conservative (prefer false over true if uncertain).

---

# Part 6: Acceptance tests (what “done” looks like)

### Test A: Data integrity
- `sf rl status` shows configured runes correctly.
- `sf` console prints rune descriptions without “Unknown rune”.

### Test B: Kelp stack selection
- In debug logs, `venoms.pick("kelp_stack")` returns kelp-cured venoms until the target model contains N kelp affs.
- After you see “Target eats kelp”, one kelp-cured aff is removed from the model.

### Test C: Limb phase ordering
- Scenario sends commands in the expected order:
  1) prep leg/head/leg
  2) break leg1 (prone)
  3) break head
  4) break leg2
  5) proceed to finisher

### Test D: Runelore attunement loop
- When the game prints “You attune yourself to the rune of Kena.”, Silverfury records it and starts empowering Kena automatically if configured.

---

# Notes on constraints and safety
- Silverfury often lacks perfect information (no target mana by default). Prefer conservative, heuristic-driven decisions.
- Never hardcode mechanics in multiple places. Keep numbers (like 40% mana threshold) in config.
- When uncertain, allow the player to override via config or `sf runelore priority ...`.

End of guide.
