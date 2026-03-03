# Runeblades and Runicarmour in Achaea: Authoritative How‑To, Mechanics, Costs, and Practical PvP Use

## Executive summary

Runeblades (often loosely called “runeweapons”) and runicarmour are long-duration empowerments available through **Runelore**, the signature skill of the **Runewarden** class. Runelore allows you to **sketch runes** onto the ground, people, weapons, and armour; for weapons and armour specifically, **sketched runes “work automatically”** (i.e., they confer their effects without needing to be “triggered” like many ground runes). citeturn35view0

A **runeblade** is created by sketching a **specific set of weapon runes** onto a knight weapon and then using **EMPOWER <weapon>**. The empowerment lasts **100 Achaean months**, during which certain runes will not fade; additionally, the empowered runeblade can carry **one** of a short list of “core” runeblade runes as an extra enhancement. citeturn32view2

**Runicarmour** is created by sketching **Gebu + Gebo** (the armour protection runes) onto a suit of armour and then using **EMPOWER <armour>**. This also lasts **100 Achaean months** and **binds the armour to the empowerer** (usable only by the person who empowered it). citeturn32view2

A major modern extension of runeblade play is **CONFIGURATION**: you can sketch a runic “configuration” on your runeblade (about a “core runeblade rune”), then wait for those configuration runes to become **attuned under specific combat conditions**, and finally **EMPOWER** them to produce additional on-hit effects. This system was introduced as a major Runelore change in the **Runelore rework** classleads round. citeturn27search1turn24view0

Key practical takeaway for dual wielders: **configuration conditions are only checked on the first hit** of multi-hit attacks, and **dual cutting / dual blunt Runewardens are advised to wield their configured runeblade in the left hand**. citeturn24view0

## Core concepts and prerequisites

Runeblades/runicarmour sit at the intersection of: (a) **your class and skill access**, (b) **inks as consumable reagents**, and (c) **the specific rune “goes on” restrictions and empowerment requirements**.

**Class and skill access.** Runelore is the Runewarden’s distinctive runic skill; it explicitly supports sketching on **weapons or armour**, and these item runes “work automatically.” citeturn35view0turn9view0 The official Runewarden class page also lists **Runeblades** and **Runicarmour** as Runelore abilities. citeturn31view0

**Inks (reagents) and where they come from.** Official help states that inks are used for tattoos and for sketching Runelore runes. citeturn20view0 AchaeaWiki (official community wiki) provides the “usual prices” for ink colours (useful for budgeting, though treat as secondary to in-game shop pricing): red 10gp, blue 40gp, yellow 80gp, green 160gp, purple 250gp, gold 400gp. citeturn26search0

**Rune placement rules (weapon vs armour).** The official “Rune List” help file shows (as a partial list) that **Lagul/Lagua/Laguz** are weapon runes and **Gebu/Gebo** are armour runes, including their broad effect categories (bleeding, damage vs trauma / bypass rebounding chance, limb damage; blunt/cutting protection). citeturn17view0

**Storage considerations.** The official Rift help file states the Rift is for “certain items” and explicitly lists **inks** among what goes into the Rift (along with herbs, minerals, commodities, etc.), with `INR`/`OUTR` commands to deposit/withdraw. It does **not** list weapons/armour as Rift items. citeturn28view0 (Inference: plan to store inks in the Rift, but keep runeblades and armour in inventory/containers/lockers rather than expecting Rift storage.)

**“Scribing” vs “sketching” terminology.** Runelore’s rune application verb is **SKETCH**, and the primary command patterns are like `SKETCH <RUNE> ON <TARGET/ITEM>`. citeturn35view0turn23view0 (If you see players say “scribe” casually, they’re usually referring to sketching in Runelore context; the authoritative command name is SKETCH.)

## Converting a weapon into a runeblade

### What makes a weapon a runeblade

A “runeblade” is a **knight weapon** that has been prepared with the proper runes and then **empowered**. The Runelore ability description (AchaeaWiki transcription of the ability text) states you can “craft any knight’s weapon into a powerful Runeblade,” instructing you to first sketch **Lagul, Lagua, Laguz** and then **EMPOWER** the blade; empowerment lasts **100 Achaean months** and prevents those runes from fading during that time. citeturn32view2

In addition, the empowered runeblade may have **one other rune** sketched upon it—**Pithakhan, Nairat, Eihwaz, or Hugalaz only**—to further enhance it. citeturn32view2

### Prerequisites checklist for runeblades

You should treat the following as required unless your in-game `AB RUNELORE RUNEBLADES` says otherwise:

You must be a Runewarden with Runelore access (Runelore is a Runewarden skill). citeturn9view0turn35view0

You need ink reagents for the specific runes you will sketch. For the “baseline” runeblade runes:
- `SKETCH LAGUL ON <weapon>` requires **1 Purple Ink**. citeturn23view0  
- `SKETCH LAGUA ON <weapon>` requires **1 Purple Ink**. citeturn32view0  
- `SKETCH LAGUZ ON <weapon>` requires **1 Purple Ink**. citeturn32view1  

If adding a “core” runeblade rune as the one allowed extra enhancement, budget inks accordingly. For example:
- `SKETCH HUGALAZ ON <weapon>` requires **1 Blue Ink** and requires the weapon be a runeblade (i.e., runeblade context). citeturn32view0  
- `SKETCH EIHWAZ ON <weapon>` requires **1 Blue Ink + 1 Yellow Ink** and requires the weapon be a runeblade. citeturn32view2  
- `SKETCH NAIRAT ON <weapon>` requires **1 Yellow Ink** and requires the weapon be a runeblade. citeturn32view1  
- `SKETCH PITHAKHAN ON <weapon>` requires **1 Red Ink**, and its weapon effect applies only if the weapon is a runeblade. citeturn24view3  

You need mana for empowerment: `EMPOWER <weapon>` for Runeblades requires **2000 mana** and costs equilibrium (listed as 10 seconds equilibrium cooldown in the ability text). citeturn24view3

### Step-by-step procedures for a runeblade

The following sequence is the most defensible “canonical” procedure based on the runeblade ability text:

Acquire (or forge) the intended **knight weapon** you intend to keep as your runeblade. (Weapon type restrictions beyond “knight weapon” are not specified in the sources gathered here.) citeturn32view2

Stock inks (commonly via shops; inks are explicitly used in rune sketching). citeturn20view0turn26search0

Sketch the three required weapon runes onto the weapon:
- `SKETCH LAGUL ON <weapon>` citeturn23view0  
- `SKETCH LAGUA ON <weapon>` citeturn32view0  
- `SKETCH LAGUZ ON <weapon>` citeturn32view1  

Optionally, sketch **one** “core runeblade rune” to define the runeblade’s enhancer slot (choose exactly one: Pithakhan, Nairat, Eihwaz, or Hugalaz). citeturn32view2turn24view0  
- Example: `SKETCH PITHAKHAN ON <weapon>` to add mana-drain procs (only on a runeblade). citeturn24view3

Complete the transformation with: `EMPOWER <weapon>` (Runeblades). citeturn24view3  
On success, your weapon is empowered for **100 Achaean months** and the baseline runes will not fade during that period. citeturn32view2

If you intend to use **CONFIGURATION**, proceed to the configuration workflow section below (this is where many “modern runewarden kill setups” are built). citeturn24view0turn27search1

## Converting armour into runicarmour

### What runicarmour does

Runicarmour is created by empowering a suit of armour that has **Gebo + Gebu** sketched on it. The runicarmour text states: empowering is done via `EMPOWER <armour>`, costs **2000 mana**, lasts **100 months**, and makes the armour usable only by the empowerer. citeturn24view2turn32view2

The relevant rune effects (as described in rune entries and the official rune list) are:
- Gebu increases blunt protection of armour. citeturn23view0turn17view0  
- Gebo increases cutting protection of armour. citeturn23view0turn17view0  

### Prerequisites checklist for runicarmour

You must have armour you intend to use long-term.

You must be able to sketch the two required armour runes:
- `SKETCH GEBU ON <armour>` requires **1 Gold Ink**. citeturn23view0  
- `SKETCH GEBO ON <armour>` requires **1 Gold Ink**. citeturn23view0  

You must have mana for empowerment: `EMPOWER <armour>` requires **2000 mana** and costs equilibrium (10 seconds equilibrium cooldown stated). citeturn24view2turn32view2

### Step-by-step procedures for runicarmour

Acquire the armour suit you want to empower (often your main combat armour).

Stock at least **2 Gold Ink** (one for Gebu, one for Gebo). citeturn23view0turn26search0

Sketch both required runes:
- `SKETCH GEBU ON <armour>` citeturn23view0  
- `SKETCH GEBO ON <armour>` citeturn23view0  

Empower it:
- `EMPOWER <armour>` citeturn24view2  

Operational consequences: once empowered, the armour becomes usable only by you (the empowerer) and retains the defensive powers for **100 Achaean months**. citeturn32view2

## Configuration, attunement, and empowerment workflow

### Sketching vs configuration

**Sketching (baseline runes).** The simplest system is: `SKETCH <RUNE> ON <GROUND|PERSON|WEAPON|ARMOUR>`. Runelore states runes on weapons and armour “work automatically.” citeturn35view0turn23view0

**Configuration (runeblade-only advanced system).** Configuration is a special Runelore ability that lets you sketch up to three runes *in a configuration* on your runeblade. Its syntax includes:
- `SKETCH CONFIGURATION <runeblade/LEFT/RIGHT/WIELDED> <rune1> <rune2> [rune3]`
- `SMUDGE <runeblade> <rune in configuration>`
- `EMPOWER <rune>`
- `EMPOWER PRIORITY SET <rune1> <rune2> <rune3>` and `EMPOWER PRIORITY CLEAR`. citeturn24view0

### Core runeblade runes and “allowed” configuration runes

Configuration runes must be drawn **about one of the “core runeblade runes”**:
- **Nairat, Hugalaz, Eihwaz, or Pithakhan**. citeturn24view0turn32view2

Which runes are “allowed” as configuration runes is not given as one consolidated list in the configuration text; instead, it points you to each rune’s ability file entry for its “In configuration” clause. citeturn24view0turn23view0  
From the Runelore ability-text page, examples of runes that explicitly have configuration behavior include (non-exhaustive, but directly evidenced):
- **Kena** (attunes when you strike a target at ≤20% mana; empowered effect delivers impatience). citeturn23view0  
- **Fehu** (attunes when striking someone missing insomnia or who is prone; empowered effect can put them to sleep if missing insomnia defense). citeturn23view0  
- **Inguz** (attunes when striking a paralysed target; empowered effect adds cracked ribs stack). citeturn23view0  
- **Wunjo** (attunes vs a shivering target; empowered effect does damage scaled by cracked ribs). citeturn23view0  
- **Sowulu** (attunes when striking a damaged limb; empowered grants healthleech and can relapse fracture symptoms). citeturn24view0  
- **Isaz** (attunes via engage prevention or isaz ground disruption; empowered delivers epilepsy). citeturn24view3  
- **Mannaz** (attunes when striking a target off focus balance; empowered disables mana regeneration for a time). citeturn32view0  
- **Sleizak** (attunes when striking weary or lethargic; empowered delivers nausea or voyria). citeturn32view0  
- **Tiwaz** (attunes when target is off restoration balance and has no limbs needing restoration; empowered breaks both arms). citeturn32view0  
- **Loshre** (attunes on addicted target; empowered delivers a timed “trap” affliction tied to eating ginseng/ferrum). citeturn24view0  

### Timing and hand considerations

Empowered configuration runes resolve **after a successful weaponmastery attack completes**; for multi-hit attacks (e.g., doubleslash/combination), the empowered rune effect occurs after the *entire* attack completes. citeturn24view0

Configuration attunement conditions are checked only on the **first hit** of multi-hit attacks; therefore dual cutting / dual blunt Runewardens are advised to wield their configured runeblade in the **left hand**. citeturn24view0

### Workflow diagram

```mermaid
flowchart TD
  A[Acquire inks + weapon/armour] --> B[SKETCH required baseline runes]
  B --> C{Making runeblade?}
  C -- Yes --> D[SKETCH Lagul + Lagua + Laguz]
  D --> E[Optionally SKETCH one core rune: Pithakhan/Nairat/Eihwaz/Hugalaz]
  E --> F[EMPOWER weapon]
  F --> G{Use CONFIGURATION?}
  G -- Yes --> H[SKETCH CONFIGURATION around core rune<br/> (2-3 config runes)]
  H --> I[Combat events cause config runes to ATTUNE]
  I --> J[EMPOWER the attuned rune(s)<br/>or set EMPOWER PRIORITY]
  J --> K[On-hit: empowered rune effect fires after attack resolves]
  C -- No (armour) --> L[SKETCH Gebu + Gebo]
  L --> M[EMPOWER armour]
  M --> N[Runicarmour lasts 100 months; bound to empowerer]
```
citeturn32view2turn24view0turn35view0

## Costs, failure modes, rune maintenance, and example configurations

### Costs and resource planning

The most “load-bearing” costs for building and maintaining rune equipment are **inks** and **mana**.

Inks are the core consumable for sketching runes (officially used for Runelore rune sketching). citeturn20view0turn35view0 AchaeaWiki’s “usual prices” provide order-of-magnitude budgeting guidance. citeturn26search0

Mana costs for empowerment are high:
- Runeblade empowerment: **2000 mana** (`EMPOWER <weapon>`). citeturn24view3turn32view2  
- Runicarmour empowerment: **2000 mana** (`EMPOWER <armour>`). citeturn24view2turn32view2  

(Any additional gold cost beyond inks is **unspecified** in the sources examined here.)

### Common failure modes and “fixes”

If you are missing inks, sketching fails (implicit from runes listing “Required: … Ink” for rune sketch commands). citeturn23view0  
Fix: stock inks; store excess inks safely in the Rift (explicitly supports inks). citeturn28view0

If you attempt to empower armour without the required runes **Gebo + Gebu**, the Runicarmour ability text indicates empowerment is only possible “upon which the runes gebo and gebu have been sketched.” citeturn32view2  
Fix: sketch both runes first (each requires gold ink). citeturn23view0

If you attempt to use weapon-only rune effects without a runeblade, some rune entries explicitly warn their weapon effects require the weapon to be a runeblade (e.g., Nairat/Eihwaz/Hugalaz/Pithakhan weapon behaviors). citeturn32view0turn32view1turn24view3  
Fix: ensure the weapon is empowered as a runeblade (and then re-sketch if needed). citeturn32view2

If you misconfigure a configuration rune set, the explicit tool for removal is `SMUDGE <runeblade> <rune in configuration>`. citeturn24view0  
Fix: smudge the specific configuration rune, then re-sketch configuration. citeturn24view0

If you empower armour and later want to trade it: empowerment binds it to the empowerer (“usable only by he who empowered it”). citeturn32view2  
Fix: operationally, plan empowerment only for armour you intend to keep. A “reversal” method is **unspecified** in the sources reviewed.

### Example configuration tables

These examples are meant to be *representative* “popular patterns” grounded in documented mechanics: baseline runeblade/runicarmour requirements + configuration attunement/empower effects. Where “popularity” is inferred from community conversation or narrative examples, that is noted.

#### Weapon examples

| Build concept | Required runes on weapon | Optional core rune | Example configuration runes | What it’s trying to do | Evidence |
|---|---|---|---|---|---|
| Baseline “true runeblade” setup | Lagul + Lagua + Laguz, then `EMPOWER <weapon>` | One of Pithakhan/Nairat/Eihwaz/Hugalaz | None | Establish a runeblade for sustained bleeding/limb/trauma synergies and enable the “core rune” slot | Runeblade procedure + duration + allowed extra rune. citeturn32view2 |
| “Hugalaz proc” runeblade | Lagul + Lagua + Laguz | Hugalaz | None | Add a chance for bonus hail damage on weapon strikes | Hugalaz weapon effect requires runeblade; runeblade can carry Hugalaz as the one extra core rune. citeturn32view0turn32view2 |
| “Mana pressure + impatience” framework | Lagul + Lagua + Laguz | Pithakhan | Kena (plus 1–2 others as preferred) | Use Pithakhan for mana drain procs and Kena configuration to deliver impatience when the attune condition is met | Pithakhan weapon behavior (runeblade only) + Kena configuration attune/empower behavior + configuration core runes. citeturn24view3turn23view0turn24view0 |
| Canonical narrative configuration example | (Runeblade implied) | Hugalaz | Kena + Fehu + Tiwaz | Shows a “three-rune circle” around Hugalaz; mechanically these are configuration-capable runes with combat-linked effects | Official event narrative explicitly: “Kena… Fehu… Tiwaz… sketched in a circular configuration around… Hugalaz.” citeturn30view0 + Configuration mechanics. citeturn24view0turn23view0 |

#### Armour examples

| Build concept | Runes on armour | Empowered? | What it’s trying to do | Evidence |
|---|---|---|---|---|
| Temporary blunt resist | Gebu | No | Increase blunt protection (duration behavior not specified here) | Gebu increases blunt protection; sketch syntax requires gold ink. citeturn23view0turn17view0 |
| Temporary cutting resist | Gebo | No | Increase cutting protection (duration behavior not specified here) | Gebo increases cutting protection; sketch syntax requires gold ink. citeturn23view0turn17view0 |
| Standard runicarmour | Gebu + Gebo | Yes (`EMPOWER <armour>`) | Long-duration (100 months) dual physical resist suite; armour becomes bound to empowerer | Runicarmour requires both runes; costs 2000 mana; lasts 100 months; bound to empowerer. citeturn32view2turn24view2 |

### Practical PvP implementation notes

Keep inks in the Rift, not in normal inventory: inks are explicitly Rift-storable, and the Rift is intended to prevent important consumables from “falling out” when you leave the realms. citeturn28view0

When building dual-wield Runewarden setups around configuration procs, prefer the configured runeblade in the **left hand** (dual cutting/blunt guidance) and remember configuration checks occur on the **first hit** only for multi-hit attacks. citeturn24view0

If your combat plan depends on a specific configuration proc, consider using `EMPOWER PRIORITY SET …` so the game automatically attempts empowerment as runes become attuned (as described in configuration text). citeturn24view0

When choosing your core rune, align it with the kind of value you want “always on” rather than conditional: Pithakhan for mana drain pressure (runeblade-only), Nairat for random freeze (runeblade-only), Eihwaz for masking venoms (runeblade-only), Hugalaz for bonus hail damage chance. citeturn24view3turn32view1turn32view0turn32view2

## Source index with direct URLs

Official Achaea help and posts are listed first; AchaeaWiki and community sources follow.

| Type | What it supports | Direct URL |
|---|---|---|
| Official help file | Runelore overview; confirms runes can be sketched on weapons/armour and that item runes work automatically | `https://www.achaea.com/game-help?what=runelore` citeturn35view0 |
| Official help file | Partial rune list showing which runes go on weapons vs armour, and inks colour shorthand | `https://www.achaea.com/game-help?what=rune-list` citeturn17view0 |
| Official help file | Inks are used for tattoos and for sketching runes | `https://www.achaea.com/game-help?what=inks-and-their-uses` citeturn20view0 |
| Official help file | Rift storage: explicitly includes inks; provides INR/OUTR commands | `https://www.achaea.com/game-help?what=the-rift` citeturn28view0 |
| Official class page | Confirms Runicarmour and Runeblades are Runelore abilities; contextualizes Runewarden | `https://www.achaea.com/classes/runewardens` citeturn31view0 |
| Official classleads/patch notes | Runelore rework: introduced CONFIGURATION and adjusted runeblade proc behavior | `https://www.achaea.com/2022/07/03/classleads-106-runelore-rework` citeturn27search1 |
| Official event/lore post | Provides a concrete example of configuration: Kena+Fehu+Tiwaz around Hugalaz | `https://www.achaea.com/2022/07/06/a-runic-revelation` citeturn30view0 |
| AchaeaWiki (secondary but detailed) | Full Runelore ability text including Runeblades/Runicarmour/Configuration syntax, mana costs, duration, attune/empower notes | `https://wiki.achaea.com/Runelore` citeturn23view0turn24view0turn32view2 |
| AchaeaWiki (secondary) | Ink price reference (“usual prices”) | `https://wiki.achaea.com/Inks` citeturn26search0 |

If you want, I can also extract and format a “copy/paste command script” section (pure commands, no commentary) for (a) runeblade creation, (b) runicarmour creation, and (c) a few standard configuration loadouts—each annotated with the rune ink requirements and the exact cited source line that justifies it.