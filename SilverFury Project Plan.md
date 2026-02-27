[Download the MD file](sandbox:/mnt/data/RWDragonAI_Codex_Plan.md)

```markdown
# Achaea Runewarden + Silver Dragon Automated Combat System (Lua/Mudlet) — Codex Build Plan

This document is written to be handed directly to **ChatGPT Codex** as an implementation specification for a **Mudlet Lua** automated combat system for **Achaea: Dreams of Divine Lands**, focused on:
- **Runewarden** in **Dual Cutting** (two scimitars), and
- **Greater Dragon (Silver)** form via **Dragoncraft**.

It is designed to **build on Svof’s defence/curing foundation** (rather than rewriting every cure/def), while adding a clearer internal architecture, stronger state modeling (afflictions + limb damage + defenses + balances), and a customizable offense “brain” that can swap between **human** and **dragon** modes.

> Compliance note: Achaea explicitly describes systems/macros/triggers as a normal part of combat play, while also warning there are “many things it’s illegal to use triggers for,” such as automating actions that generate resources like gold or experience. Keep this system strictly combat/reactive and avoid out-of-combat resource automation. citeturn9view0

## Goals and constraints

### Primary goals
Create a Lua system that:
- Tracks **your state**: balance, equilibrium, health/mana, defenses, afflictions, limb damage, mobility status (prone, webbed, transfixed), and form (human vs dragon).
- Tracks **target state**: defenses (shield/rebounding/etc), limb damage, afflictions you have reasonably confirmed.
- Selects **optimal next actions** for:
  - **Human Runewarden (Dual Cutting)** with two scimitars (venom delivery, raze/razeslash, limb prep/break lines, impale/disembowel/intimidate).
  - **Silver Dragon** (summoned lightning breath, breathstrip, rend/swipe limb pressure, devour finisher).
- Integrates your supplied tooling:
  - **Svof** (defence/curing tracker and related mechanisms).
  - **AK Limb Tracker** (as a reference/optional limb engine).
  - **Group combat aliases/scripts/triggers** (as an optional “party layer” for target announcements, assist calls, etc.).

### Key game mechanics this system must model
Achaea combat revolves around:
- **Balance** (physical recovery) and **Equilibrium** (mental recovery). Many offensive abilities require both; physical attacks typically consume balance, “magical-ish” abilities consume equilibrium. citeturn9view0
- **Affliction “give-and-take”**: afflictions are applied rapidly; most affliction cures (herbs/salves) can generally be used about once per second, while health/mana elixirs are slower (about once per 5 seconds). citeturn9view0
- **Defences**: you can list them with `DEF`/`DEFENCES`, one per line. citeturn14view0
- **Limb damage**: broken/crippled limbs are cured by **mending**, mangled/damaged limbs by **restoration**. citeturn4view2

### Platform assumptions
- **Mudlet** client, Lua scripting.
- You can use **GMCP** if available, but the system should not depend exclusively on GMCP (some states are still best inferred from text triggers).
- You will run **Svof** alongside this system (recommended), either as:
  - A dependency you call into, or
  - A set of enabled modules you let run curing/defences while your system runs offense and higher-level decisioning.

## Combat knowledge extraction

This section is the “mechanics backbone” Codex will use when coding the data tables and decision engine.

### Balance, equilibrium, and prompt parsing
- Combat actions are throttled by **balance** and **equilibrium**; offensive abilities commonly require both. citeturn9view0
- `PROMPT STATS` displays whether you currently have equilibrium (`e`) and balance (`x`). citeturn9view0

**Implementation requirement**
- Track `me.bal` and `me.eq` as booleans + timestamps (`last_balance_loss`, `last_eq_loss`) to support predicted recovery windows.
- Maintain “cooldown channels” for cures: herb, salve, smoke, sip, focus, etc. (Svof already does this; if not using Svof curing, you must implement timers).

### Core curing map (afflictions → cures)
Use the AchaeaWiki **Curing** table as your base mapping for “what cures what.” citeturn4view3turn20search1

Examples that matter for Runewarden/Dragon:
- **Anorexia**: cannot eat/drink; cured with **epidermal** salve. citeturn16search3turn20search1
- **Slickness**: cannot apply salves; cured by **bloodroot** or smoking **valerian**. citeturn15search1turn20search1
- **Impatience**: prevents focusing; cured by **goldenseal**. citeturn15search7turn20search1
- **Epilepsy**: seizures can **cost balance**; cured by **goldenseal**. citeturn15search8turn17search19turn20search1
- **Weariness**: increases endurance use, increases cutting/blunt damage taken, slows some delayed movement; fitness can block it, but weariness also prevents fitness. citeturn16search11turn20search1
- **Paralysis**: muscles lock up; cured by **bloodroot**. citeturn16search1turn20search1
- **Recklessness**: hides how low your health/mana are; cured by **lobelia**. citeturn16search2turn20search1
- **Confusion**: prevents focusing; makes mental afflictions harder to cure; cured by **prickly ash**. citeturn18search11turn20search1
- **Transfix / Transfixed**: victim is “unable to do much” until they **writhe** free; blindness prevents falling into transfix. citeturn18search4turn19search2turn20search1
- **Webbed**: cured by **writhe**. citeturn20search1

**Implementation requirement**
- Build a normalized affliction dictionary:
  - `afflictions[id] = { cures = {...}, tags = {...}, blocks = {...}, priority = n }`
- Tags must include “blocks” relationships (e.g., anorexia blocks eat/drink; slickness blocks apply; impatience/confusion block focus). Those are the core logic links that make curing “connected.”

### Defences critical to Runewarden + Dragon
Your offense must continuously adapt to the target’s defenses, especially:
- **Aura of weapons rebounding**: reflects *weapon* attacks back at attacker; generated by smoking skullcap/malachite; takes ~7 seconds to take effect; aggressive action dissipates it but moving does not. citeturn14view1turn9view0
- **Magical shield**: protects from most attacks; generated by shield tattoo and some skills; dissolves when bearer **moves or performs an aggressive act**; hammer tattoo shatters it. citeturn14view2turn14view3turn9view0

**Implementation requirement**
- Maintain `target.defs.shield`, `target.defs.rebounding` as first-class booleans.
- Maintain a “defence confidence” model:
  - Some defences are **observed** (message confirmed).
  - Others are **assumed** (e.g., you saw them touch shield earlier but might have attacked since).
  - Each defence should have `last_seen` timestamp and `confidence` score.

### Limb damage model
Achaea distinguishes:
- **Crippled/broken limb** → cured with **mending** salve.
- **Damaged/mangled limb** → cured with **restoration** salve. citeturn4view2turn9view0

**Implementation requirement**
Build a unified limb model with:
- Parts: `head`, `torso`, `left_arm`, `right_arm`, `left_leg`, `right_leg` (mirrors common combat targeting patterns and dragon abilities like `SWIPE <limb> <HEAD|TORSO>`). citeturn11view0turn9view0
- Per limb fields:
  - `damage_pct` (0–100+ estimate),
  - `broken` (mending-needed),
  - `mangled` (restoration-needed),
  - `fractures` (if you decide to model fracture mechanics later; dual cutting itself is less fracture-centric than dual blunt, but it matters vs opponents).

Because exact limb damage is not trivially visible, design the tracker around **estimation + confirmation**, using:
- “Your hit did X to their limb” parsing,
- “Their limb breaks” confirmations,
- Optional `PREDICT <target>` ability in Dual Cutting to “determine approximately when blows will cause limbs to break.” citeturn12view0

## Class kit mapping

### Runewarden essentials
Runewardens use **Weaponmastery, Runelore, and Discipline**. citeturn6view0turn4view1turn8view0

#### Weaponmastery: Dual Cutting (two scimitars)
Dual cutting is for wielding “two cutting weapons,” typically **scimitars or battle axes**, emphasizing swift strikes and venoms. citeturn4view1turn12view0

Key abilities your automation must reason about:
- **ENVENOM**: venoms layer on edged weapons; on hit, one venom is delivered and removed; ordering is **last-on, first-off** (stack semantics). citeturn12view0
- **RAZE**: attacks defenses that keep your weapons out (notably shield/rebounding). citeturn5view0turn12view0
- **DSL** (Duality): wield/use two weapons simultaneously; can optionally specify **limb** and **venoms**. citeturn5view0turn12view0
- **RAZESLASH**: raze + slash simultaneously, commonly used to strip shield and still hit. citeturn5view2turn12view0
- **IMPALE**: only on a prone victim; pins them so they can’t move, but you also can’t move; escape is slower if they have **two broken legs**. citeturn5view0turn12view0
- **DISEMBOWEL**: only after impale; more damage if target has internal bleeding. citeturn12view0
- **INTIMIDATE**: requires target prone with **both legs broken**; makes tumbling attempts longer; can be used without balance but requires equilibrium. citeturn12view0
- **UNDERCUT**: with battleaxe (you may not use it with scimitars, but include as an optional config if user swaps weapons); always breaks leg if above 90% damaged, no venom. citeturn5view2turn12view0
- **CONCUSS**: on a downed opponent; delivers blackout. citeturn12view0

**Implementation requirement**
- The offense engine must be able to pick between:
  - `RAZE`/`RAZESLASH` when shield/rebounding inferred,
  - `DSL` limb-targeting when prepping/breaking key limbs,
  - `IMPALE` line when kill conditions are met (prone + leg breaks, etc.).

#### Runelore (runes and totems)
Runelore revolves around **sketching runes** and building **totems** with up to six runes that trigger in sequence on enemies entering. citeturn6view1

Your combat system does not need to automate complex totem strategy initially, but it must support:
- Pre-fight rune prep (optional).
- Basic rune effect tracking because several runes apply critical afflictions/defence strip:
  - **Tiwaz** removes enemy defences. citeturn6view2
  - **Loshr(e)** afflicts with **anorexia**. citeturn6view2turn16search3
  - **Sleizak** afflicts with **voyria** poison. citeturn6view2turn20search1
  - **Nairat** can beguile/transfix. citeturn6view2turn18search4
  - **Inguz** paralyses. citeturn6view2turn16search1

#### Discipline (Runewarden chivalry)
The system should model at least these:
- **ENGAGE**: once engaged, if target tries to leave and is otherwise unhindered, you get an extra strike even without balance/eq. citeturn8view0
- **FITNESS**: cures asthma. citeturn8view0turn20search1
- **RAGE**: cures pacifying afflictions normally cured by bellwort. citeturn8view0turn20search1
- **BLOCK/UNBLOCK** and movement control tools (for room control). citeturn8view0

### Dragoncraft essentials (Silver dragon)
Dragoncraft is available to level 99+ adventurers; it includes the ability to **DRAGONFORM** and many dragon-only abilities. citeturn4view0turn11view0

Key dragon abilities for automation:
- **DRAGONFORM / LESSERFORM** (form switch). citeturn11view0
- **DRAGONHEAL**: purges multiple afflictions; cannot be activated if you have both **weariness** and **recklessness** simultaneously. citeturn11view0turn16search11turn16search2
- **SUMMON <breath>**: each dragon color has distinct breath; **Silver is Lightning with a high chance of epilepsy**. citeturn10view0turn15search8
- **BLAST**: unleash breath (requires summoned breath). citeturn10view0
- **BREATHSTRIP**: strips target defences (requires summoned breath). citeturn10view0
- **REND**: claw limb targeting, can add venom; faster when not targeting limb or vs denizen. citeturn11view0
- **SWIPE**: multi-limb split damage pattern. citeturn11view0
- **CLAWPARRY**: parry via claws (dragon defensive behavior). citeturn11view0
- **DEVOUR**: execution; faster based on victim’s **restoration broken limbs**, with **damaged torso** accelerating it more; if total devour time < 6s, it becomes hard to interrupt by common methods. citeturn11view0turn4view2
- **DRAGONCURSE**: random masked afflictions or specified affliction after a delay; valid afflictions include paralysis, impatience, sensitivity, asthma, stupidity, weariness, recklessness. citeturn11view0turn16search1turn15search7turn16search11turn16search2
- **TAILSMASH**: shatters magical shield. citeturn11view0turn14view2

**Implementation requirement**
- Dragon mode must own a separate offense plan (breath-enabled defence strip + epilepsy pressure + limb-rend into devour).
- Dragon mode must also own a separate defence model (clawparry, dragonarmour upkeep, etc.) without interfering with Svof’s core defences.

## System architecture

### High-level approach
Build a **new Mudlet package** named something like `RWDragonAI` that:
- Loads **after** Svof (if present).
- Uses Svof’s state (affs/defs/bal/eq) whenever possible, but maintains its own **combat model** to support planning and explanation.
- Provides:
  - A stable internal API for offense/defense decisions,
  - A “reasoning” log for debugging,
  - A configuration UI (simple command-based config is fine at first).

### Recommended module layout

Create a folder-like module layout (Mudlet scripts can `dofile` or `require` with package paths depending on your loader setup):

- `rwda/init.lua`
  - Bootstraps the system, registers event handlers, detects Svof, loads config.
- `rwda/config.lua`
  - User settings, weapon item IDs/names, default venoms, target preferences, mode toggles.
- `rwda/state/`
  - `me.lua` (your vitals, affs, defs, balances, form state)
  - `target.lua` (target tracking: defs, affs, limb damage)
  - `room.lua` (room states like indoors/outdoors if needed, who is present)
- `rwda/data/`
  - `afflictions.lua` (affliction effects + cures + blockers)
  - `defences.lua` (defence definitions, how they’re gained/lost, confidence decay)
  - `venoms.lua` (venom metadata: affliction delivered, cure channel blocked, priority)
  - `abilities.lua` (human/dragon ability specs: costs, requires, effects)
- `rwda/engine/`
  - `events.lua` (event bus and normalization layer)
  - `timers.lua` (cooldowns; wrappers that defer to Svof if possible)
  - `parser.lua` (text trigger handlers; prompt parsing; attack confirmations)
  - `planner.lua` (core decision engine: choose next action)
  - `executor.lua` (queues/sends commands safely, respecting balances and priorities)
- `rwda/integrations/`
  - `svof.lua` (read Svof state, register hooks, avoid double-curing)
  - `aklimb.lua` (optional limb input adapter)
  - `groupcombat.lua` (optional: bridge to supplied group aliases/triggers)
- `rwda/ui/`
  - `commands.lua` (aliases like `rwda on`, `rwda mode dragon`, `rwda venom set`, `rwda debug`)
  - `display.lua` (optional: mini console output, prompt tags)

### Integration with Svof

#### Why integrate instead of rewriting cure/defence
Svof is an open-source AI system with adaptable curing and defence raising. citeturn21search0turn21search9  
It supports configured defence lists (defup/keepup) via commands like:
- `vshow defup`, `vshow keepup`
- `vdefup`, `vkeep`
- `vcreate defmode` citeturn21search20

Svof docs also discuss interactions with **server-side curing/defences**; notably, serverside will try to do things even if “not possible,” so cure-blocking afflictions can need to be above what they block in serverside priorities—whereas Svof is more conservative about only doing possible actions. citeturn21search1

#### Concrete integration requirements
- Detect Svof with something like:
  - `_G.svo`, `_G.svof`, or a known global table (Codex should inspect Svof runtime globals).
- Create an adapter layer `rwda/integrations/svof.lua` that can:
  - Read: `me.affs`, `me.defs`, `me.bal/eq`, current curing mode, etc.
  - Subscribe: if Svof exposes event hooks, register callbacks; otherwise, read state on each prompt.
  - Respect: if Svof is curing, `rwda` must **not** issue duplicate cure commands. Instead, it should:
    - Only request *strategic* cures (e.g., “use DRAGONHEAL if conditions”), or
    - Adjust Svof’s priority sets/modes, if you choose to automate that.
- Expose an option:
  - `rwda.curing = "svof"` (default) vs `rwda.curing = "custom"`
  - `rwda.defences = "svof"` (default) vs `rwda.defences = "custom"`

### Unified internal state model
Codex must implement a *single* canonical `State` object, even if it reads from Svof:
- `State.me`
- `State.target`
- `State.flags` (mode toggles)
- `State.cooldowns`

Design principle:
- Svof provides **facts** when available.
- `rwda` provides **explanations** and **planning decisions** based on those facts.

### Decision engine design

#### Planner responsibilities
`planner.choose()` should output:
- `action.commands`: a list of game commands (strings)
- `action.reason`: a structured reason object (for debug UI)
- `action.requires`: `bal`, `eq`, and any other prerequisites
- `action.risk`: optional risk score (e.g., “may hit into rebounding”)

#### Planner inputs
- `State.me.affs/defs/bal/eq/hp/mp/form`
- `State.target.defs/limbs/affs/position`
- Weapon state:
  - what you wield (two scimitars vs none in dragon form)
  - what venoms are loaded where (human weapons vs claw venoms)
- Combat goals (`rwda.goal`):
  - `pressure` (affliction momentum)
  - `limbprep` (prep legs)
  - `impale_kill` (impale → disembowel)
  - `dragon_devour` (prep restoration breaks → devour)

#### Suggested core “modes”
Implement explicit modes:
- `human_dualcut`
- `dragon_silver`

Switching must be automatic based on parsing:
- On `DRAGONFORM` success → set mode dragon.
- On `LESSERFORM` success → set mode human. citeturn11view0

### Offense logic spec

This section is deliberately explicit so Codex can code it as deterministic rules before adding more advanced heuristics.

#### Human dual cutting: baseline sequence
**Primary tactical themes**
- Keep target’s **shield/rebounding down** (raze/razeslash).
- Build a **limb state advantage** (break legs) to:
  - Keep them prone / limit escape → enable impale lines.
- Use venom delivery with DSL and envenom stacks to create cure pressure.

**Rule set sketch**
1) If `target.defs.rebounding == true`:
   - Prefer `RAZE <target> REBOUNDING` (or `RAZESLASH` if you can safely follow with damage and your own defenses allow it). citeturn12view0turn14view1
2) Else if `target.defs.shield == true`:
   - Use `RAZE <target> SHIELD` or `RAZESLASH`. citeturn12view0turn14view2
3) Else if you are pursuing leg breaks:
   - Use `DSL <target> <left_leg> <venom1> <venom2>` (exact syntax may vary; implement as configurable templates) and alternate legs to avoid parry.
   - Periodically `PREDICT <target>` to calibrate limb estimates. citeturn12view0
4) If target is **prone** and both legs are **broken**:
   - Evaluate `IMPALE <target>` as a lock/kill enabler. citeturn12view0turn17search0
5) After a successful impale:
   - Consider `DISEMBOWEL <target>` for high damage. citeturn12view0
6) If target prone + both legs broken but you can’t/won’t impale:
   - Consider `INTIMIDATE <target>` to worsen tumbling attempts (eq-based). citeturn12view0

#### Dragon silver: baseline sequence
**Primary tactical themes**
- Ensure breath is summoned (`SUMMON LIGHTNING` or whatever the in-game type name is configured to; Dragoncraft notes silver breath is lightning and is “high chance of epilepsy”). citeturn10view0turn15search8
- Use breath to:
  - Strip defences (`BREATHSTRIP`) and/or
  - Apply pressure (`BLAST`) with epilepsy likelihood.
- Use claw limb damage to create restoration-break conditions for **DEVOUR** speed-up. citeturn11view0turn4view2
- Use `TAILSMASH` as an on-demand shield breaker where appropriate. citeturn11view0turn14view2

**Rule set sketch**
1) If breath not active:
   - `SUMMON <silver_breath_type>` (configured). citeturn10view0
2) If target has shield/rebounding (or unknown but likely):
   - `BREATHSTRIP <target>` and/or `TAILSMASH <target>` for magical shield. citeturn10view0turn11view0turn14view2
3) Else:
   - `BLAST <target>` to apply damage + epilepsy pressure. citeturn10view0turn15search8
4) For limb work:
   - Use `REND <target> <limb> [venom]` to prep key limbs directly. citeturn11view0
   - Use `SWIPE` when you want split damage across a limb + head/torso. citeturn11view0
5) Finisher evaluation:
   - If target has sufficient **restoration broken limbs** (and/or damaged torso) such that devour is plausibly fast, attempt `DEVOUR <target>`. citeturn11view0turn4view2

**Dragon affliction tools**
- `DRAGONCURSE` can apply random masked afflictions or targeted delayed afflictions from a specific list. citeturn11view0  
  Use it as a tactical add-on when it does not conflict with your core breath/limb plan.

### Curing and healing strategy

If you rely on Svof curing, your system should:
- Never send herb/salve/sip commands directly unless the user explicitly enables `rwda.curing = "custom"`.
- Instead, provide:
  - Emergency overrides (e.g., “use DRAGONHEAL when aff stacked and allowed”).
  - “Cure pressure awareness”: if you afflict the target with anorexia, you can expect reduced eat/drink cures. citeturn16search3

Important Dragon-specific healing:
- `DRAGONHEAL` cures multiple afflictions but fails if you have both weariness and recklessness. citeturn11view0turn16search11turn16search2

## Codex implementation roadmap

### Phase setup
- Create a new Mudlet package (`.mpackage`) containing all `rwda/*` scripts and triggers.
- Ensure it loads after Svof.

### Phase foundation
Build the skeleton:
- `rwda/init.lua` sets up globals: `_G.rwda = {}` and loads modules.
- Add an event bus (`rwda.engine.events`) with:
  - `on(event, fn)`
  - `emit(event, payload)`
- Add a debug log utility with severity levels: `trace`, `info`, `warn`, `error`.

**Acceptance tests**
- Running `rwda on` prints “RWDA enabled” and shows detected integration state (`Svof found: yes/no`).

### Phase state modeling
Implement:
- `State.me` + `State.target`.
- Form detection:
  - Trigger on dragonform/lesserform success text and set `State.me.form = "dragon"|"human"`.
- Prompt parsing:
  - Track eq/bal and vitals (hp/mp) using either GMCP or regex prompt.

**Acceptance tests**
- Toggle dragonform; state flips correctly.
- Bal/eq flags flip correctly on known balance-using commands.

### Phase data dictionaries
Implement the initial `rwda/data/afflictions.lua` seeded with:
- The core cures from the Curing table citeturn20search1
- Effect tags for at least:
  - anorexia, slickness, paralysis, impatience, epilepsy, weariness, confusion, transfixed/webbed, prone.

Implement `rwda/data/defences.lua` with:
- shield, rebounding, their loss conditions, confidence decay.

Implement `rwda/data/abilities.lua` with:
- human dual cutting: raze, razeslash, dsl, envenom, impale, disembowel, intimidate
- dragon: summon, blast, breathstrip, rend, swipe, devour, tailsmash, dragonheal, dragoncurse

### Phase parser and confirmation triggers
Build a `rwda.engine.parser` that updates state via events:
- `AFF_GAINED`, `AFF_CURED`
- `DEF_GAINED`, `DEF_LOST`
- `LIMB_DAMAGE`, `LIMB_BROKEN`, `LIMB_MANGLED`
- `TARGET_PRONE`, `TARGET_STOOD`
- `FORM_CHANGED`
- `BAL_LOST`, `BAL_GAINED`, `EQ_LOST`, `EQ_GAINED`

Use a layered confidence system:
- If you see “shield shimmers around X” → `DEF_GAINED(shield, confidence=1.0)`.
- If you see “shield dissolves” or you see them perform an aggressive act and you assume shield drops → decay it rather than hard remove (configurable).

### Phase planner and executor
Implement:
- `planner.choose()` using the rule sets in this doc.
- `executor.send(action)`:
  - If action requires balance/eq and you don’t have it, queue it.
  - Provide a `rwda.queue` with priorities:
    - emergency defense overrides
    - offense
    - utility (diagnose, assess, etc.)

**Acceptance tests**
- With target shield true, planner picks raze/razeslash.
- With target no shield and goal limbprep, planner picks dsl limb target.
- In dragon mode with no summoned breath flag, planner picks summon.

### Phase Svof integration layer
Implement `rwda/integrations/svof.lua`:
- Read-only mapping:
  - `rwda.State.me.affs = svof_state.affs` (or merged)
  - `rwda.State.me.defs = svof_state.defs`
- Optional “control” mapping:
  - allow `rwda` to call Svof commands like `vshow keepup` for introspection. citeturn21search20
- Provide a **compatibility switch**:
  - `rwda.use_svof_curing = true` (default)
  - `rwda.use_svof_defences = true` (default)

### Phase AK limb tracker and group combat integration
- Wrap your supplied AK Limb Tracker into an adapter that can:
  - Accept limb updates and merge into `State.target.limbs`.
- Integrate group combat “targeting layer”:
  - If group scripts expose a target variable or an event when target changes, map it to `State.target.name`.
  - Add optional “announce” functions (send messages to party channel when target is prepped).

### Phase polish and usability
Implement:
- `rwda status` command showing:
  - mode, target, key defences, key affs, limb status, queued action.
- `rwda explain` command showing the last `action.reason` tree.
- Profile support:
  - `rwda profile duel`
  - `rwda profile group`
  - Each profile chooses a goal strategy and a venom set.

## Testing and validation

### Log replay harness
Create a “log replay” mode:
- Feed past combat logs line-by-line into your parser.
- Compare state outputs to expected outcomes (limb breaks, shield drops, etc.).
- This is essential because combat systems are mostly about correct parsing and timers. citeturn9view0

### Safety checks
- Hard fail-safe:
  - `rwda stop` immediately disables offense sending.
- Anti-spam:
  - Ensure every outgoing command is rate-limited and respects bal/eq gating.
- Avoid illegal automation:
  - Do not add “resource farming” loops; keep to combat reactions only. citeturn9view0

## Deliverables checklist for Codex

Codex should produce:
- A Mudlet package (`RWDragonAI.mpackage`) containing:
  - Scripts + triggers + aliases.
- A README inside the package with:
  - install steps
  - how to enable/disable Svof integration
  - how to set scimitar item names/ids
  - how to set dragon breath type string
- A `rwda/config.lua` template with:
  - `weapons.mainhand`, `weapons.offhand`
  - venom sets for DSL
  - dragon breath type for `SUMMON`
  - default profiles

End state: You can fight as dual scimitars, then `DRAGONFORM` and seamlessly continue fighting as a silver dragon, with the system adapting to the different available abilities, defenses, curing constraints, and kill routes.
```