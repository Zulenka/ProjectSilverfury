# RWDA Runelore Integration Implementation Project

**Version 1.0** — Comprehensive Runewarden Runelore System  
**Target RWDA Version:** 0.3.0+  
**Date:** March 2026

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Phase 1: Data Layer - Rune Definitions](#phase-1-data-layer---rune-definitions)
3. [Phase 2: State Layer - Runeblade Configuration Tracking](#phase-2-state-layer---runeblade-configuration-tracking)
4. [Phase 3: Parser Layer - Rune Event Detection](#phase-3-parser-layer---rune-event-detection)
5. [Phase 4: Engine Layer - Attunement Logic](#phase-4-engine-layer---attunement-logic)
6. [Phase 5: Strategy Layer - Head Focus & Kelp Stack](#phase-5-strategy-layer---head-focus--kelp-stack)
7. [Phase 6: Planner Integration - Empower Decisions](#phase-6-planner-integration---empower-decisions)
8. [Phase 7: Executor Layer - Empower Command Execution](#phase-7-executor-layer---empower-command-execution)
9. [Phase 8: UI Layer - HUD & Commands](#phase-8-ui-layer---hud--commands)
10. [Phase 9: Testing & Validation](#phase-9-testing--validation)
11. [Appendix A: Rune Reference Data](#appendix-a-rune-reference-data)
12. [Appendix B: Kill Path Logic Reference](#appendix-b-kill-path-logic-reference)

---

## 1. Project Overview

### 1.1 Purpose

This project implements full Runelore integration into RWDA, enabling intelligent:
- **Runeblade configuration tracking** (which runes are sketched, attunement state)
- **Automatic empowerment decisions** based on attunement conditions
- **Head-focused strategy** to maximize Pithakhan procs and mana drain
- **Kena-based true lock path** exploiting the <40% mana threshold for impatience delivery
- **Kelp stack venom selection** to support affliction pressure toward locks

### 1.2 Key Mechanics (December 2025 Classleads)

| Mechanic | Old Value | New Value | Source |
|----------|-----------|-----------|--------|
| Kena attunement threshold | <20% mana | **<40% mana** | Dec 9, 2025 classleads |
| Pithakhan drain (broken head) | 10% | **13%** | Dec 9, 2025 classleads |
| Pithakhan guaranteed proc | — | **Damaged head** | July 3, 2022 rework |

### 1.3 Modern Kill Path Summary

```
1. Build kelp stack (asthma, weariness, sensitivity, clumsiness)
2. Target HEAD to damage/break it
3. Pithakhan procs reliably on damaged head, drains 13% mana on broken head
4. Push target below 40% mana
5. Kena attunes → Empower Kena → delivers IMPATIENCE
6. Impatience blocks focus → asthma sticks → paralysis sticks → TRUE LOCK
7. Execute finisher (BISECT at ≤20% health, or standard)
```

### 1.4 File Structure (New Files to Create)

```
rwda/
├── data/
│   └── runes.lua              # NEW: Rune definitions, attunement conditions, empower effects
├── state/
│   └── runeblade.lua          # NEW: Runeblade configuration state tracking
├── engine/
│   └── runelore.lua           # NEW: Attunement logic, empower decision engine
└── ui/
    └── commands.lua           # MODIFY: Add runelore commands
```

---

## Phase 1: Data Layer - Rune Definitions

### 1.1 Objective

Create `rwda/data/runes.lua` containing all Runelore rune definitions with:
- Rune name and symbol
- Sketch locations (ground, totem, weapon, person)
- Ink requirements
- Attunement conditions (for configuration runes)
- Empower effects
- Cooldowns

### 1.2 Implementation Steps

#### Step 1.2.1: Create the runes.lua file

Create file: `rwda/data/runes.lua`

```lua
rwda = rwda or {}
rwda.data = rwda.data or {}
rwda.data.runes = rwda.data.runes or {}

local runes = rwda.data.runes

-- Rune categories
runes.CATEGORY = {
  GROUND = "ground",           -- Can be sketched on ground
  TOTEM = "totem",             -- Can be sketched on totem
  WEAPON = "weapon",           -- Can be sketched on weapon (runeblade only)
  PERSON = "person",           -- Can be sketched on self or others
  ARMOUR = "armour",           -- Can be sketched on armour
  CORE_RUNEBLADE = "core",     -- Core runeblade rune (Pithakhan, Nairat, Eihwaz, Hugalaz)
  CONFIGURATION = "config",    -- Can be in configuration around core rune
}

-- Attunement condition types
runes.ATTUNE_CONDITION = {
  MANA_BELOW_40 = "mana_below_40",
  TARGET_PARALYSED = "target_paralysed",
  TARGET_SHIVERING = "target_shivering",
  LIMB_DAMAGED = "limb_damaged",
  TARGET_PRONE_OR_NO_INSOMNIA = "prone_or_no_insomnia",
  OFF_FOCUS_BALANCE = "off_focus_balance",
  ENGAGE_PREVENTS_ESCAPE = "engage_prevents",
  OFF_SALVE_NO_RESTORE_NEEDED = "off_salve_clean",
  TARGET_ADDICTED = "target_addicted",
  TARGET_WEARY_OR_LETHARGIC = "target_weary_lethargic",
}

-- Empower effect types
runes.EMPOWER_EFFECT = {
  IMPATIENCE = "impatience",
  CRACKED_RIBS = "cracked_ribs",
  CRACKED_RIBS_DAMAGE = "cracked_ribs_damage",
  EPILEPSY = "epilepsy",
  MANA_REGEN_BLOCK = "mana_regen_block",
  BREAK_ARMS = "break_arms",
  HEALTHLEECH_FRACTURE = "healthleech_fracture",
  NAUSEA_OR_VOYRIA = "nausea_voyria",
  EATING_PUNISHMENT = "eating_punishment",
  SLEEP = "sleep",
}

-- Full rune definitions
runes.definitions = {
  -- ═══════════════════════════════════════════════════════════════
  -- CORE RUNEBLADE RUNES (required for configuration)
  -- ═══════════════════════════════════════════════════════════════
  
  pithakhan = {
    name = "Pithakhan",
    symbol = "Square Box",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.WEAPON, runes.CATEGORY.CORE_RUNEBLADE },
    ink = { red = 1 },
    balance_cost = 2.0,
    weapon_effect = "Occasionally drains mana from target (runeblade only)",
    ground_effect = "Attacks enemy mana when encountered (not blind)",
    -- Special mechanics
    damaged_head_guaranteed_proc = true,  -- July 2022: always fires on damaged head
    broken_head_drain_percent = 13,       -- Dec 2025: increased from 10%
    normal_drain_percent = 10,
  },
  
  nairat = {
    name = "Nairat",
    symbol = "Butterfly",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.WEAPON, runes.CATEGORY.CORE_RUNEBLADE },
    ink = { yellow = 1 },
    balance_cost = 2.0,
    weapon_effect = "Randomly FREEZES target (runeblade only)",
    ground_effect = "Entangles enemy who sees it",
  },
  
  eihwaz = {
    name = "Eihwaz",
    symbol = "Yew",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.WEAPON, runes.CATEGORY.CORE_RUNEBLADE },
    ink = { blue = 1, yellow = 1 },
    balance_cost = 4.0,
    weapon_effect = "Randomly masks venom effects (runeblade only)",
    ground_effect = "Dampens non-protected crystalline vibrations",
  },
  
  hugalaz = {
    name = "Hugalaz",
    symbol = "Ball of Ice",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.WEAPON, runes.CATEGORY.CORE_RUNEBLADE },
    ink = { blue = 1 },
    balance_cost = 3.0,
    weapon_effect = "Chance for additional hail damage (runeblade only)",
    ground_effect = "Brings hailstorm upon enemies",
    enables_bisect = true,  -- Required for BISECT ability
  },
  
  -- ═══════════════════════════════════════════════════════════════
  -- CONFIGURATION RUNES (can be arranged around core runes)
  -- ═══════════════════════════════════════════════════════════════
  
  kena = {
    name = "Kena",
    symbol = "Nightmare",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { red = 1 },
    balance_cost = 2.0,
    ground_effect = "Inspires fear in enemy who sees it",
    -- CONFIGURATION MECHANICS (Dec 2025 update)
    attune_condition = runes.ATTUNE_CONDITION.MANA_BELOW_40,
    attune_description = "Runeblade strikes target with <40% mana",
    empower_effect = runes.EMPOWER_EFFECT.IMPATIENCE,
    empower_description = "Delivers impatience",
    -- This is THE key rune for true lock path
    priority_for_lock = 1,
  },
  
  inguz = {
    name = "Inguz",
    symbol = "Stickman",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { red = 1 },
    balance_cost = 2.0,
    ground_effect = "Paralyses enemy who sees it",
    attune_condition = runes.ATTUNE_CONDITION.TARGET_PARALYSED,
    attune_description = "Runeblade strikes a paralysed target",
    empower_effect = runes.EMPOWER_EFFECT.CRACKED_RIBS,
    empower_description = "Gives one stack of cracked ribs",
  },
  
  wunjo = {
    name = "Wunjo",
    symbol = "Open Eye",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { red = 1 },
    balance_cost = 2.0,
    ground_effect = "Returns sight to enemy who sees it",
    attune_condition = runes.ATTUNE_CONDITION.TARGET_SHIVERING,
    attune_description = "Runeblade strikes a shivering target",
    empower_effect = runes.EMPOWER_EFFECT.CRACKED_RIBS_DAMAGE,
    empower_description = "Damage based on cracked ribs stacks",
  },
  
  sowulu = {
    name = "Sowulu",
    symbol = "Nail",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { red = 1 },
    balance_cost = 2.0,
    ground_effect = "Damages opponent who sees it (not deaf)",
    attune_condition = runes.ATTUNE_CONDITION.LIMB_DAMAGED,
    attune_description = "Runeblade strikes a limb that is damaged (needs restoration)",
    empower_effect = runes.EMPOWER_EFFECT.HEALTHLEECH_FRACTURE,
    empower_description = "Gives healthleech; fractures relapse symptoms",
  },
  
  fehu = {
    name = "Fehu",
    symbol = "Closed Eye",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { red = 1 },
    balance_cost = 2.0,
    ground_effect = "Causes sleep or removes insomnia/kola",
    attune_condition = runes.ATTUNE_CONDITION.TARGET_PRONE_OR_NO_INSOMNIA,
    attune_description = "Runeblade strikes someone prone or missing insomnia",
    empower_effect = runes.EMPOWER_EFFECT.SLEEP,
    empower_description = "Puts target to sleep (if no insomnia defence)",
  },
  
  mannaz = {
    name = "Mannaz",
    symbol = "Bell",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { red = 1 },
    balance_cost = 2.0,
    ground_effect = "Returns hearing to enemy who sees it",
    attune_condition = runes.ATTUNE_CONDITION.OFF_FOCUS_BALANCE,
    attune_description = "Runeblade strikes target off focus balance",
    empower_effect = runes.EMPOWER_EFFECT.MANA_REGEN_BLOCK,
    empower_description = "Timed affliction disabling all mana regeneration",
  },
  
  isaz = {
    name = "Isaz",
    symbol = "Flurry of Lightning Bolts",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.CONFIGURATION },
    ink = { blue = 1, red = 1 },
    balance_cost = 4.0,
    ground_effect = "Shockwave unbalances enemies (if not levitating or has lethargy/weariness)",
    attune_condition = runes.ATTUNE_CONDITION.ENGAGE_PREVENTS_ESCAPE,
    attune_description = "Engage prevents escape, or Isaz disrupts enemy balance",
    empower_effect = runes.EMPOWER_EFFECT.EPILEPSY,
    empower_description = "Delivers epilepsy",
  },
  
  tiwaz = {
    name = "Tiwaz",
    symbol = "Upwards-Pointing Arrow",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { blue = 1, red = 2 },
    balance_cost = 2.0,
    ground_effect = "Strips defence from enemy who sees it",
    attune_condition = runes.ATTUNE_CONDITION.OFF_SALVE_NO_RESTORE_NEEDED,
    attune_description = "Target off restoration salve balance with no limbs needing restoration",
    empower_effect = runes.EMPOWER_EFFECT.BREAK_ARMS,
    empower_description = "Breaks both of target's arms",
  },
  
  sleizak = {
    name = "Sleizak",
    symbol = "Viper",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { blue = 1 },
    balance_cost = 2.0,
    ground_effect = "Infects with voyria if seen",
    attune_condition = runes.ATTUNE_CONDITION.TARGET_WEARY_OR_LETHARGIC,
    attune_description = "Runeblade strikes a weary or lethargic target",
    empower_effect = runes.EMPOWER_EFFECT.NAUSEA_OR_VOYRIA,
    empower_description = "Delivers nausea (or voyria if already nauseous)",
  },
  
  loshre = {
    name = "Loshre",
    symbol = "Apple Core",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink = { blue = 1 },
    balance_cost = 2.0,
    ground_effect = "Gives anorexia to those who see it",
    attune_condition = runes.ATTUNE_CONDITION.TARGET_ADDICTED,
    attune_description = "Runeblade strikes an addicted target",
    empower_effect = runes.EMPOWER_EFFECT.EATING_PUNISHMENT,
    empower_description = "Timed affliction punishing ginseng/ferrum eating",
  },
  
  -- ═══════════════════════════════════════════════════════════════
  -- PERMANENT RUNEBLADE RUNES (Lagul, Lagua, Laguz - required for empowerment)
  -- ═══════════════════════════════════════════════════════════════
  
  lagul = {
    name = "Lagul",
    symbol = "Dirk",
    categories = { runes.CATEGORY.WEAPON },
    ink = { purple = 1 },
    balance_cost = 4.0,
    weapon_effect = "Inflicts more bleeding when striking",
    required_for_empowerment = true,
  },
  
  lagua = {
    name = "Lagua",
    symbol = "Large Hammer",
    categories = { runes.CATEGORY.WEAPON },
    ink = { purple = 1 },
    balance_cost = 4.0,
    weapon_effect = "Magnified disembowel damage on internal trauma; or numbness on blunt",
    required_for_empowerment = true,
  },
  
  laguz = {
    name = "Laguz",
    symbol = "Long Slim Blade",
    categories = { runes.CATEGORY.WEAPON },
    ink = { purple = 1 },
    balance_cost = 4.0,
    weapon_effect = "Deals more damage to target's limbs",
    required_for_empowerment = true,
  },
  
  -- ═══════════════════════════════════════════════════════════════
  -- OTHER UTILITY RUNES
  -- ═══════════════════════════════════════════════════════════════
  
  uruz = {
    name = "Uruz",
    symbol = "Lightning Bolt",
    categories = { runes.CATEGORY.GROUND },
    ink = { blue = 1, yellow = 1 },
    balance_cost = 5.0,
    ground_effect = "Heals you and allies",
  },
  
  jera = {
    name = "Jera",
    symbol = "Mighty Oak",
    categories = { runes.CATEGORY.PERSON },
    ink = { purple = 1 },
    balance_cost = 4.0,
    person_effect = "Increases STR and CON by 1 while active",
  },
  
  algiz = {
    name = "Algiz",
    symbol = "Elk",
    categories = { runes.CATEGORY.PERSON },
    ink = { green = 1 },
    balance_cost = 2.0,
    person_effect = "10% reduction to all damage types",
  },
  
  dagaz = {
    name = "Dagaz",
    symbol = "Rising Sun",
    categories = { runes.CATEGORY.GROUND },
    ink = { green = 1, red = 1 },
    balance_cost = 5.0,
    ground_effect = "Heals afflictions randomly",
  },
  
  gular = {
    name = "Gular",
    symbol = "None",
    categories = { runes.CATEGORY.GROUND },
    ink = { red = 1 },
    balance_cost = 2.0,
    ground_effect = "Raises stone wall blocking exit (or destroys existing wall)",
  },
  
  raido = {
    name = "Raido",
    symbol = "Horse",
    categories = { runes.CATEGORY.GROUND },
    ink = { green = 1 },
    balance_cost = 10.0,
    ground_effect = "Teleport home rune (say 'ride home')",
  },
  
  thurisaz = {
    name = "Thurisaz",
    symbol = "Volcano",
    categories = { runes.CATEGORY.GROUND },
    ink = { blue = 1, red = 1 },
    balance_cost = 3.0,
    ground_effect = "Molten lava spout damages target; prevents flooding",
  },
  
  nauthiz = {
    name = "Nauthiz",
    symbol = "Leech",
    categories = { runes.CATEGORY.GROUND },
    ink = { blue = 1, yellow = 1 },
    balance_cost = 4.0,
    ground_effect = "Drains flood water, or sucks nourishment from enemies",
  },
  
  othala = {
    name = "Othala",
    symbol = "Mountain Range",
    categories = { runes.CATEGORY.GROUND },
    ink = { red = 5 },
    balance_cost = 4.0,
    ground_effect = "Three eruptions destroying prismatic/shield or dealing damage",
  },
  
  berkana = {
    name = "Berkana",
    symbol = "Lion",
    categories = { runes.CATEGORY.PERSON },
    ink = { yellow = 3 },
    balance_cost = 2.0,
    person_effect = "Health regeneration to bearer",
  },
  
  gebu = {
    name = "Gebu",
    symbol = "Shield",
    categories = { runes.CATEGORY.ARMOUR },
    ink = { gold = 1 },
    balance_cost = 4.0,
    armour_effect = "Increases blunt protection",
    required_for_armour_empowerment = true,
  },
  
  gebo = {
    name = "Gebo",
    symbol = "Chain",
    categories = { runes.CATEGORY.ARMOUR },
    ink = { gold = 1 },
    balance_cost = 4.0,
    armour_effect = "Increases cutting protection",
    required_for_armour_empowerment = true,
  },
}

-- Helper: Get configuration-eligible runes
function runes.getConfigurationRunes()
  local result = {}
  for name, def in pairs(runes.definitions) do
    if def.attune_condition then
      result[name] = def
    end
  end
  return result
end

-- Helper: Get core runeblade runes
function runes.getCoreRunebladeRunes()
  local result = {}
  for name, def in pairs(runes.definitions) do
    for _, cat in ipairs(def.categories or {}) do
      if cat == runes.CATEGORY.CORE_RUNEBLADE then
        result[name] = def
        break
      end
    end
  end
  return result
end

-- Helper: Check if rune can be in configuration
function runes.canBeInConfiguration(runeName)
  local def = runes.definitions[runeName:lower()]
  return def and def.attune_condition ~= nil
end

-- Helper: Get attunement condition for a rune
function runes.getAttuneCondition(runeName)
  local def = runes.definitions[runeName:lower()]
  return def and def.attune_condition
end

-- Helper: Get empower effect for a rune
function runes.getEmpowerEffect(runeName)
  local def = runes.definitions[runeName:lower()]
  return def and def.empower_effect
end

return runes
```

#### Step 1.2.2: Add runes.lua to init.lua FILES list

In `rwda/init.lua`, add to the FILES table:

```lua
local FILES = {
  "util.lua",
  "config.lua",
  "data/runes.lua",          -- ADD THIS LINE
  "state/me.lua",
  -- ... rest of files
}
```

---

## Phase 2: State Layer - Runeblade Configuration Tracking

### 2.1 Objective

Create `rwda/state/runeblade.lua` to track:
- Current runeblade configuration (core rune + config runes)
- Attunement state for each configured rune
- Empower priority queue
- Configuration activation delay/adapt state

### 2.2 Implementation Steps

#### Step 2.2.1: Create runeblade.lua state file

Create file: `rwda/state/runeblade.lua`

```lua
rwda = rwda or {}
rwda.state = rwda.state or {}
rwda.state.runeblade = rwda.state.runeblade or {}

local runeblade = rwda.state.runeblade

-- Default state structure
local DEFAULT_STATE = {
  -- Runeblade info
  wielded = {
    left = nil,   -- { id = number, name = string, type = "scimitar"|"battleaxe"|etc }
    right = nil,
  },
  
  -- Configuration on left-hand runeblade (standard for dual-cutting)
  configuration = {
    core_rune = nil,           -- "pithakhan", "nairat", "eihwaz", "hugalaz"
    config_runes = {},         -- { "kena", "inguz", ... } (up to 3 with core)
    active = false,            -- Configuration is active (past activation delay)
    activated_at = nil,        -- When configuration became active
  },
  
  -- Attunement tracking
  attunement = {
    -- [rune_name] = { attuned = bool, attuned_at = timestamp, can_empower = bool }
  },
  
  -- Empower priority (auto-empower order)
  empower_priority = {},       -- { "kena", "inguz", "sowulu" } in priority order
  
  -- Permanent runeblade runes (Lagul, Lagua, Laguz)
  permanent_runes = {
    lagul = false,
    lagua = false,
    laguz = false,
  },
  
  -- Is the blade empowered (has Lagul+Lagua+Laguz and was EMPOWERed)
  empowered = false,
  empowered_until = nil,       -- Achaean month expiry
  
  -- Adapt mechanic tracking
  adapt = {
    last_swap_at = nil,
    can_skip_delay = false,
    cooldown_until = nil,      -- ~10 second cooldown on adapt
  },
}

-- Current state (will be reset on bootstrap)
runeblade._state = nil

function runeblade.bootstrap()
  runeblade._state = rwda.util.deepCopy(DEFAULT_STATE)
  
  -- Load from config if available
  local cfg = rwda.config and rwda.config.runeblade or {}
  if cfg.default_configuration then
    runeblade.setConfiguration(
      cfg.default_configuration.core,
      cfg.default_configuration.config_runes or {}
    )
  end
  if cfg.empower_priority then
    runeblade.setEmpowerPriority(cfg.empower_priority)
  end
end

function runeblade.reset()
  runeblade._state = rwda.util.deepCopy(DEFAULT_STATE)
end

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION MANAGEMENT
-- ═══════════════════════════════════════════════════════════════

function runeblade.setConfiguration(coreRune, configRunes)
  local s = runeblade._state
  if not s then return false end
  
  -- Validate core rune
  local validCores = { pithakhan = true, nairat = true, eihwaz = true, hugalaz = true }
  coreRune = coreRune and coreRune:lower() or nil
  if coreRune and not validCores[coreRune] then
    rwda.util.log("warn", "Invalid core rune: %s", tostring(coreRune))
    return false
  end
  
  s.configuration.core_rune = coreRune
  s.configuration.config_runes = {}
  
  -- Add config runes (validate each)
  for _, rune in ipairs(configRunes or {}) do
    rune = rune:lower()
    if rwda.data.runes.canBeInConfiguration(rune) then
      table.insert(s.configuration.config_runes, rune)
    else
      rwda.util.log("warn", "Rune '%s' cannot be in configuration", rune)
    end
  end
  
  -- Reset attunement when configuration changes
  s.attunement = {}
  s.configuration.active = false
  s.configuration.activated_at = nil
  
  return true
end

function runeblade.getConfiguration()
  local s = runeblade._state
  if not s then return nil end
  return s.configuration
end

function runeblade.isConfigurationActive()
  local s = runeblade._state
  return s and s.configuration.active
end

function runeblade.activateConfiguration()
  local s = runeblade._state
  if not s or not s.configuration.core_rune then return false end
  
  s.configuration.active = true
  s.configuration.activated_at = rwda.util.now()
  
  -- Initialize attunement for all configured runes
  for _, rune in ipairs(s.configuration.config_runes) do
    s.attunement[rune] = s.attunement[rune] or {
      attuned = false,
      attuned_at = nil,
      can_empower = false,
    }
  end
  
  rwda.util.log("info", "Configuration activated: %s + %s",
    s.configuration.core_rune,
    table.concat(s.configuration.config_runes, ", "))
  
  return true
end

-- ═══════════════════════════════════════════════════════════════
-- ATTUNEMENT TRACKING
-- ═══════════════════════════════════════════════════════════════

function runeblade.setAttuned(runeName, attuned)
  local s = runeblade._state
  if not s then return false end
  
  runeName = runeName:lower()
  s.attunement[runeName] = s.attunement[runeName] or {}
  s.attunement[runeName].attuned = attuned
  s.attunement[runeName].can_empower = attuned
  
  if attuned then
    s.attunement[runeName].attuned_at = rwda.util.now()
    rwda.util.log("debug", "Rune %s is now ATTUNED", runeName)
  end
  
  return true
end

function runeblade.isAttuned(runeName)
  local s = runeblade._state
  if not s then return false end
  
  local att = s.attunement[runeName:lower()]
  return att and att.attuned
end

function runeblade.canEmpower(runeName)
  local s = runeblade._state
  if not s then return false end
  
  local att = s.attunement[runeName:lower()]
  return att and att.can_empower
end

function runeblade.getAttunedRunes()
  local s = runeblade._state
  if not s then return {} end
  
  local result = {}
  for rune, state in pairs(s.attunement) do
    if state.attuned then
      table.insert(result, rune)
    end
  end
  return result
end

function runeblade.consumeEmpower(runeName)
  local s = runeblade._state
  if not s then return false end
  
  runeName = runeName:lower()
  local att = s.attunement[runeName]
  if att then
    att.attuned = false
    att.can_empower = false
    return true
  end
  return false
end

-- ═══════════════════════════════════════════════════════════════
-- EMPOWER PRIORITY
-- ═══════════════════════════════════════════════════════════════

function runeblade.setEmpowerPriority(priority)
  local s = runeblade._state
  if not s then return false end
  
  s.empower_priority = {}
  for _, rune in ipairs(priority or {}) do
    table.insert(s.empower_priority, rune:lower())
  end
  
  rwda.util.log("info", "Empower priority set: %s", table.concat(s.empower_priority, " > "))
  return true
end

function runeblade.getEmpowerPriority()
  local s = runeblade._state
  return s and s.empower_priority or {}
end

function runeblade.getNextEmpowerableRune()
  local s = runeblade._state
  if not s then return nil end
  
  -- Check priority order first
  for _, rune in ipairs(s.empower_priority) do
    if runeblade.canEmpower(rune) then
      return rune
    end
  end
  
  -- Fall back to any attuned rune
  for rune, state in pairs(s.attunement) do
    if state.can_empower then
      return rune
    end
  end
  
  return nil
end

-- ═══════════════════════════════════════════════════════════════
-- WIELDED WEAPON TRACKING
-- ═══════════════════════════════════════════════════════════════

function runeblade.setWielded(hand, weapon)
  local s = runeblade._state
  if not s then return false end
  
  hand = hand:lower()
  if hand ~= "left" and hand ~= "right" then return false end
  
  local oldWeapon = s.wielded[hand]
  s.wielded[hand] = weapon
  
  -- Check for adapt mechanic (different weapon type on swap)
  if hand == "left" and oldWeapon and weapon then
    if oldWeapon.type ~= weapon.type then
      runeblade.triggerAdapt()
    end
  end
  
  return true
end

function runeblade.triggerAdapt()
  local s = runeblade._state
  if not s then return false end
  
  local now = rwda.util.now()
  
  -- Check if adapt is on cooldown (~10 seconds)
  if s.adapt.cooldown_until and now < s.adapt.cooldown_until then
    return false
  end
  
  s.adapt.last_swap_at = now
  s.adapt.can_skip_delay = true
  s.adapt.cooldown_until = now + 10.0
  
  -- Immediately activate configuration if swapping to configured blade
  if s.configuration.core_rune and not s.configuration.active then
    runeblade.activateConfiguration()
    rwda.util.log("info", "ADAPT triggered - configuration immediately active")
  end
  
  return true
end

-- ═══════════════════════════════════════════════════════════════
-- SERIALIZATION
-- ═══════════════════════════════════════════════════════════════

function runeblade.serialize()
  local s = runeblade._state
  if not s then return nil end
  
  return {
    configuration = s.configuration,
    empower_priority = s.empower_priority,
    permanent_runes = s.permanent_runes,
    empowered = s.empowered,
  }
end

function runeblade.deserialize(data)
  if not data then return false end
  
  local s = runeblade._state
  if not s then return false end
  
  if data.configuration then
    s.configuration = data.configuration
  end
  if data.empower_priority then
    s.empower_priority = data.empower_priority
  end
  if data.permanent_runes then
    s.permanent_runes = data.permanent_runes
  end
  if data.empowered ~= nil then
    s.empowered = data.empowered
  end
  
  return true
end

return runeblade
```

#### Step 2.2.2: Add runeblade.lua to init.lua FILES list

In `rwda/init.lua`, add to the FILES table:

```lua
"state/runeblade.lua",       -- ADD after state/store.lua
```

#### Step 2.2.3: Call runeblade.bootstrap() in rwda.bootstrap()

In `rwda/init.lua`, in the `rwda.bootstrap()` function, add after `rwda.state.bootstrap()`:

```lua
if rwda.state.runeblade and rwda.state.runeblade.bootstrap then
  rwda.state.runeblade.bootstrap()
end
```

---

## Phase 3: Parser Layer - Rune Event Detection

### 3.1 Objective

Extend `rwda/engine/parser.lua` to detect:
- Attunement messages ("Your X rune becomes attuned")
- Empower execution messages ("You empower your X rune")
- Pithakhan proc messages (mana drain confirmation)
- Configuration activation messages
- Weapon wield/unwield for adapt tracking

### 3.2 Implementation Steps

#### Step 3.2.1: Add rune-related regex patterns to parser.lua

Add these patterns to the parser's pattern definitions:

```lua
-- ═══════════════════════════════════════════════════════════════
-- RUNELORE PATTERNS
-- ═══════════════════════════════════════════════════════════════

-- Attunement detection
-- Example: "Your kena rune becomes attuned."
RUNE_ATTUNED = {
  pattern = "^Your (%w+) rune becomes attuned%.$",
  handler = "onRuneAttuned",
},

-- Attunement lost
-- Example: "Your kena rune is no longer attuned."
RUNE_ATTUNE_LOST = {
  pattern = "^Your (%w+) rune is no longer attuned%.$",
  handler = "onRuneAttuneLost",
},

-- Empower execution
-- Example: "You empower your kena rune against Target."
RUNE_EMPOWERED = {
  pattern = "^You empower your (%w+) rune",
  handler = "onRuneEmpowered",
},

-- Configuration activation
-- Example: "Your runic configuration upon your scimitar activates."
CONFIG_ACTIVATED = {
  pattern = "^Your runic configuration upon your (%w+) activates%.$",
  handler = "onConfigActivated",
},

-- Pithakhan mana drain
-- Example: "Your pithakhan rune drains mana from Target."
PITHAKHAN_DRAIN = {
  pattern = "^Your pithakhan rune drains mana from (%w+)%.$",
  handler = "onPithakhanDrain",
},

-- Weapon wield (for adapt tracking)
-- Example: "You wield a Dwarf-crafted scimitar in your left hand."
WIELD_WEAPON = {
  pattern = "^You wield .+ in your (%w+) hand%.$",
  handler = "onWeaponWield",
},
```

#### Step 3.2.2: Add handler functions for rune events

```lua
function parser.onRuneAttuned(matches)
  local runeName = matches[2]:lower()
  if rwda.state.runeblade then
    rwda.state.runeblade.setAttuned(runeName, true)
  end
  
  -- Raise event for auto-empower logic
  if rwda.engine.runelore then
    rwda.engine.runelore.onRuneAttuned(runeName)
  end
end

function parser.onRuneAttuneLost(matches)
  local runeName = matches[2]:lower()
  if rwda.state.runeblade then
    rwda.state.runeblade.setAttuned(runeName, false)
  end
end

function parser.onRuneEmpowered(matches)
  local runeName = matches[2]:lower()
  if rwda.state.runeblade then
    rwda.state.runeblade.consumeEmpower(runeName)
  end
  
  -- Log the empower for combat tracking
  rwda.util.log("combat", "EMPOWERED %s", runeName:upper())
end

function parser.onConfigActivated(matches)
  local weaponType = matches[2]:lower()
  if rwda.state.runeblade then
    rwda.state.runeblade.activateConfiguration()
  end
end

function parser.onPithakhanDrain(matches)
  local targetName = matches[2]
  -- Track mana drain event for strategy decisions
  if rwda.engine.runelore then
    rwda.engine.runelore.onPithakhanDrain(targetName)
  end
end
```

---

## Phase 4: Engine Layer - Attunement Logic

### 4.1 Objective

Create `rwda/engine/runelore.lua` containing:
- Attunement condition checking (predictive, based on target state)
- Auto-empower decision logic
- Pithakhan head-focus intelligence
- Kena mana threshold tracking

### 4.2 Implementation Steps

#### Step 4.2.1: Create runelore.lua engine file

Create file: `rwda/engine/runelore.lua`

```lua
rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.runelore = rwda.engine.runelore or {}

local runelore = rwda.engine.runelore

-- Configuration
local config = {
  auto_empower = true,                    -- Automatically empower when conditions met
  empower_on_attune = true,               -- Empower immediately when rune attunes
  kena_mana_threshold = 0.40,             -- 40% mana (Dec 2025)
  pithakhan_broken_head_drain = 0.13,     -- 13% drain on broken head
  pithakhan_normal_drain = 0.10,          -- 10% normal drain
}

-- ═══════════════════════════════════════════════════════════════
-- ATTUNEMENT CONDITION CHECKING
-- ═══════════════════════════════════════════════════════════════

-- Check if a specific attunement condition is currently met
function runelore.checkAttuneCondition(condition)
  local target = rwda.state.target
  local me = rwda.state.me
  local runes = rwda.data.runes
  
  if condition == runes.ATTUNE_CONDITION.MANA_BELOW_40 then
    -- Kena: target mana < 40%
    local manaPercent = target.getManaPercent and target.getManaPercent() or 1.0
    return manaPercent < config.kena_mana_threshold
    
  elseif condition == runes.ATTUNE_CONDITION.TARGET_PARALYSED then
    -- Inguz: target has paralysis
    return target.hasAff and target.hasAff("paralysis")
    
  elseif condition == runes.ATTUNE_CONDITION.TARGET_SHIVERING then
    -- Wunjo: target is shivering
    return target.hasAff and target.hasAff("shivering")
    
  elseif condition == runes.ATTUNE_CONDITION.LIMB_DAMAGED then
    -- Sowulu: target has a limb needing restoration
    return runelore.targetHasDamagedLimb()
    
  elseif condition == runes.ATTUNE_CONDITION.TARGET_PRONE_OR_NO_INSOMNIA then
    -- Fehu: target prone or missing insomnia
    local prone = target.hasAff and target.hasAff("prone")
    local noInsomnia = not (target.hasDef and target.hasDef("insomnia"))
    return prone or noInsomnia
    
  elseif condition == runes.ATTUNE_CONDITION.OFF_FOCUS_BALANCE then
    -- Mannaz: target off focus balance
    return target.balances and target.balances.focus == false
    
  elseif condition == runes.ATTUNE_CONDITION.TARGET_ADDICTED then
    -- Loshre: target has addiction
    return target.hasAff and target.hasAff("addiction")
    
  elseif condition == runes.ATTUNE_CONDITION.TARGET_WEARY_OR_LETHARGIC then
    -- Sleizak: target has weariness or lethargy
    local weary = target.hasAff and target.hasAff("weariness")
    local lethargic = target.hasAff and target.hasAff("lethargy")
    return weary or lethargic
    
  elseif condition == runes.ATTUNE_CONDITION.OFF_SALVE_NO_RESTORE_NEEDED then
    -- Tiwaz: off salve balance AND no limbs need restoration
    local offSalve = target.balances and target.balances.salve == false
    local noRestoreNeeded = not runelore.targetHasDamagedLimb()
    return offSalve and noRestoreNeeded
  end
  
  return false
end

-- Check if target has any limb that needs restoration (damaged/broken)
function runelore.targetHasDamagedLimb()
  local target = rwda.state.target
  if not target.limbs then return false end
  
  for _, limb in ipairs({ "head", "torso", "left_arm", "right_arm", "left_leg", "right_leg" }) do
    local state = target.limbs[limb]
    if state and (state.damaged or state.broken or state.mangled) then
      return true
    end
  end
  
  return false
end

-- ═══════════════════════════════════════════════════════════════
-- PREDICTIVE ATTUNEMENT (will condition be met after this attack?)
-- ═══════════════════════════════════════════════════════════════

function runelore.predictAttuneAfterAttack(runeName, attackPlan)
  local runes = rwda.data.runes
  local def = runes.definitions[runeName:lower()]
  if not def or not def.attune_condition then return false end
  
  local condition = def.attune_condition
  local target = rwda.state.target
  
  -- Kena: will attack push mana below 40%?
  if condition == runes.ATTUNE_CONDITION.MANA_BELOW_40 then
    local currentMana = target.getManaPercent and target.getManaPercent() or 1.0
    local expectedDrain = runelore.estimatePithakhanDrain()
    return (currentMana - expectedDrain) < config.kena_mana_threshold
  end
  
  -- Inguz: will attack deliver paralysis?
  if condition == runes.ATTUNE_CONDITION.TARGET_PARALYSED then
    if attackPlan and attackPlan.venoms then
      for _, venom in ipairs(attackPlan.venoms) do
        if venom == "curare" then
          return not (target.hasAff and target.hasAff("paralysis"))
        end
      end
    end
  end
  
  -- Sowulu: will attack damage a limb?
  if condition == runes.ATTUNE_CONDITION.LIMB_DAMAGED then
    if attackPlan and attackPlan.target_limb then
      return true  -- Attacking a limb will damage it
    end
  end
  
  -- Sleizak: will attack deliver weariness/lethargy?
  if condition == runes.ATTUNE_CONDITION.TARGET_WEARY_OR_LETHARGIC then
    if attackPlan and attackPlan.venoms then
      for _, venom in ipairs(attackPlan.venoms) do
        if venom == "vernalius" then
          return not (target.hasAff and target.hasAff("weariness"))
        end
      end
    end
  end
  
  return runelore.checkAttuneCondition(condition)
end

-- Estimate Pithakhan mana drain based on head state
function runelore.estimatePithakhanDrain()
  local target = rwda.state.target
  if not target.limbs then return 0 end
  
  local headState = target.limbs.head
  if headState then
    if headState.broken then
      return config.pithakhan_broken_head_drain  -- 13%
    elseif headState.damaged then
      return config.pithakhan_normal_drain       -- 10% but guaranteed
    end
  end
  
  -- Unreliable proc if head not damaged
  return config.pithakhan_normal_drain * 0.3  -- ~3% effective
end

-- ═══════════════════════════════════════════════════════════════
-- PITHAKHAN INTELLIGENCE
-- ═══════════════════════════════════════════════════════════════

-- Is head damaged enough for guaranteed Pithakhan procs?
function runelore.isPithakhanReliable()
  local target = rwda.state.target
  if not target.limbs then return false end
  
  local headState = target.limbs.head
  return headState and (headState.damaged or headState.broken or headState.mangled)
end

-- Is head broken for maximum Pithakhan drain?
function runelore.isPithakhanMaxDrain()
  local target = rwda.state.target
  if not target.limbs then return false end
  
  local headState = target.limbs.head
  return headState and headState.broken
end

-- Should strategy focus head to enable Pithakhan?
function runelore.shouldFocusHead()
  -- If Pithakhan is not yet reliable, recommend head focus
  if not runelore.isPithakhanReliable() then
    return true, "pith_unreliable"
  end
  
  -- If target mana is close to Kena threshold, maximize drain
  local target = rwda.state.target
  local manaPercent = target.getManaPercent and target.getManaPercent() or 1.0
  
  if manaPercent > config.kena_mana_threshold and manaPercent < 0.60 then
    if not runelore.isPithakhanMaxDrain() then
      return true, "push_for_kena"
    end
  end
  
  return false, nil
end

-- ═══════════════════════════════════════════════════════════════
-- KENA / TRUE LOCK INTELLIGENCE
-- ═══════════════════════════════════════════════════════════════

-- Is target in Kena-eligible mana range?
function runelore.isKenaEligible()
  local target = rwda.state.target
  local manaPercent = target.getManaPercent and target.getManaPercent() or 1.0
  return manaPercent < config.kena_mana_threshold
end

-- How far from Kena threshold?
function runelore.getKenaDistance()
  local target = rwda.state.target
  local manaPercent = target.getManaPercent and target.getManaPercent() or 1.0
  return manaPercent - config.kena_mana_threshold
end

-- Is target in a lockable state? (has key afflictions)
function runelore.isNearLock()
  local target = rwda.state.target
  if not target.hasAff then return false, {} end
  
  local lockAffs = {
    asthma = target.hasAff("asthma"),
    slickness = target.hasAff("slickness"),
    anorexia = target.hasAff("anorexia"),
    paralysis = target.hasAff("paralysis"),
    impatience = target.hasAff("impatience"),
  }
  
  local count = 0
  local missing = {}
  for aff, has in pairs(lockAffs) do
    if has then
      count = count + 1
    else
      table.insert(missing, aff)
    end
  end
  
  return count >= 3, missing
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO-EMPOWER LOGIC
-- ═══════════════════════════════════════════════════════════════

function runelore.onRuneAttuned(runeName)
  if not config.auto_empower or not config.empower_on_attune then
    return
  end
  
  -- Check if this is the highest priority attuned rune
  local nextRune = rwda.state.runeblade.getNextEmpowerableRune()
  if nextRune == runeName then
    runelore.queueEmpower(runeName)
  end
end

function runelore.queueEmpower(runeName)
  if not rwda.engine.executor then return end
  
  local cmd = string.format("empower %s", runeName)
  rwda.engine.executor.queue({
    type = "empower",
    command = cmd,
    priority = 100,  -- High priority
    requires = {},   -- No balance required for empower
  })
  
  rwda.util.log("combat", "Queuing EMPOWER %s", runeName:upper())
end

function runelore.shouldEmpower()
  if not config.auto_empower then return false, nil end
  
  local nextRune = rwda.state.runeblade.getNextEmpowerableRune()
  return nextRune ~= nil, nextRune
end

function runelore.onPithakhanDrain(targetName)
  -- Track drain for mana estimation
  local target = rwda.state.target
  if target.name and target.name:lower() == targetName:lower() then
    -- Record drain event
    target.last_pithakhan_drain = rwda.util.now()
    
    -- Update mana estimate if we track it
    if target.mana_percent then
      local drain = runelore.isPithakhanMaxDrain() 
        and config.pithakhan_broken_head_drain 
        or config.pithakhan_normal_drain
      target.mana_percent = math.max(0, target.mana_percent - drain)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════

function runelore.setAutoEmpower(enabled)
  config.auto_empower = enabled
  rwda.util.log("info", "Auto-empower %s", enabled and "enabled" or "disabled")
end

function runelore.setEmpowerOnAttune(enabled)
  config.empower_on_attune = enabled
end

function runelore.getConfig()
  return config
end

-- ═══════════════════════════════════════════════════════════════
-- RECOMMENDED CONFIGURATION FOR LOCK PATH
-- ═══════════════════════════════════════════════════════════════

-- Returns the recommended configuration for the Pith+Kena lock path
function runelore.getRecommendedLockConfig()
  return {
    core_rune = "pithakhan",
    config_runes = { "kena", "sleizak", "inguz" },
    empower_priority = { "kena", "sleizak", "inguz" },
    strategy_notes = {
      "1. Focus HEAD until damaged for reliable Pithakhan procs",
      "2. Apply kelp-cure venoms (kalmia, vernalius, xentio, prefarar)",
      "3. Pithakhan drains mana; 13% on broken head",
      "4. When mana < 40%, Kena attunes → Empower for IMPATIENCE",
      "5. Impatience blocks focus → asthma sticks → true lock",
      "6. BISECT at ≤20% health for instant kill",
    },
  }
end

return runelore
```

#### Step 4.2.2: Add runelore.lua to init.lua FILES list

```lua
"engine/runelore.lua",       -- ADD after engine/finisher.lua
```

---

## Phase 5: Strategy Layer - Head Focus & Kelp Stack

### 5.1 Objective

Add new strategy blocks to `rwda/data/strategy_presets.lua`:
- `head_focus`: Prioritize head damage for Pithakhan reliability
- `kelp_stack`: Venom selection optimized for kelp-cure afflictions
- `kena_lock`: Full lock path strategy combining head focus + kelp + Kena

### 5.2 Implementation Steps

#### Step 5.2.1: Add new strategy presets

Add to `rwda/data/strategy_presets.lua`:

```lua
-- ═══════════════════════════════════════════════════════════════
-- RUNELORE LOCK PATH STRATEGIES
-- ═══════════════════════════════════════════════════════════════

presets.head_focus = {
  name = "Head Focus (Pithakhan)",
  description = "Prioritize head damage for reliable Pithakhan procs and maximum mana drain",
  version = 1,
  
  -- Limb targeting priority
  limb_priority = { "head", "torso", "left_arm", "right_arm" },
  
  -- Focus head until broken, then maintain
  limb_logic = {
    phase_1 = {
      name = "Break Head",
      target = "head",
      until_condition = "limb_broken",
      then_phase = "phase_2",
    },
    phase_2 = {
      name = "Maintain + Torso",
      target = "torso",
      maintain_limbs = { "head" },  -- Re-target head if it heals
    },
  },
  
  -- Venom priority (standard + kelp focus)
  venom_priority = {
    "kalmia",     -- asthma (kelp)
    "gecko",      -- slickness
    "curare",     -- paralysis
    "vernalius",  -- weariness (kelp)
    "xentio",     -- clumsiness (kelp)
    "prefarar",   -- sensitivity (kelp)
    "epteth",     -- healthleech (kelp)
    "slike",      -- anorexia
  },
  
  -- When to use this strategy
  triggers = {
    pithakhan_unreliable = true,  -- Use when Pith isn't proccing reliably
  },
}

presets.kelp_stack = {
  name = "Kelp Stack",
  description = "Maximize kelp-cure affliction pressure to overwhelm curing",
  version = 1,
  
  -- Kelp-cure venoms in priority order
  venom_priority = {
    "kalmia",     -- asthma (blocks breathing cures)
    "vernalius",  -- weariness (slows balance recovery)
    "xentio",     -- clumsiness (random balance loss)
    "prefarar",   -- sensitivity (increases damage taken)
    "epteth",     -- healthleech (passive damage)
    "gecko",      -- slickness (blocks tree)
    "curare",     -- paralysis
    "slike",      -- anorexia
  },
  
  -- Stack count goal: want 3+ kelp affs at once
  kelp_affs = { "asthma", "weariness", "clumsiness", "sensitivity", "healthleech" },
  target_stack_count = 3,
  
  -- Limb targeting: flexible
  limb_priority = { "head", "left_arm", "right_arm", "torso" },
}

presets.kena_lock = {
  name = "Kena Lock Path",
  description = "Full Pith+Kena true lock strategy: head focus → mana pressure → impatience → lock",
  version = 1,
  
  -- Phase-based strategy
  phases = {
    {
      name = "Phase 1: Head Break",
      description = "Damage head for reliable Pithakhan",
      target_limb = "head",
      until_condition = "head_damaged",
      venom_priority = { "kalmia", "gecko", "curare", "vernalius" },
    },
    {
      name = "Phase 2: Mana Pressure",
      description = "Drain mana below 40% for Kena attunement",
      target_limb = "head",  -- Keep hitting head for max drain
      until_condition = "mana_below_40",
      venom_priority = { "kalmia", "vernalius", "xentio", "prefarar", "gecko", "curare" },
      maintain_limbs = { "head" },
    },
    {
      name = "Phase 3: Lock Setup",
      description = "Kena delivers impatience; stack lock afflictions",
      target_limb = "torso",
      until_condition = "near_lock",
      venom_priority = { "kalmia", "curare", "gecko", "slike" },
      auto_empower = { "kena" },  -- Empower Kena when attuned
    },
    {
      name = "Phase 4: Execute",
      description = "Finish with BISECT or standard execute",
      execute_type = "bisect",  -- Use BISECT if hugalaz available
      health_threshold = 0.20,
    },
  },
  
  -- Global settings
  auto_phase_advance = true,
  track_kena_attunement = true,
  prioritize_head_if_healing = true,
  
  -- Empower priority
  empower_priority = { "kena", "sleizak", "inguz" },
}

-- Aggressive mana pressure variant
presets.mana_pressure = {
  name = "Mana Pressure",
  description = "Aggressive mana drain focus for quick Kena setup",
  version = 1,
  
  -- Always target head for maximum Pithakhan drain
  limb_priority = { "head" },
  
  -- Venoms that support mana pressure or lock
  venom_priority = {
    "kalmia",     -- blocks breathing cures
    "vernalius",  -- weariness slows recovery
    "gecko",      -- slickness blocks tree
    "curare",     -- paralysis
    "epteth",     -- healthleech
    "xentio",     -- clumsiness
  },
  
  -- Break and maintain head
  maintain_head_break = true,
  
  -- Transition to lock when ready
  transition_to_lock_at_mana = 0.40,
}
```

#### Step 5.2.2: Add strategy selection logic to planner

In `rwda/engine/planner.lua`, add strategy recommendation:

```lua
-- Should we recommend switching to head_focus or kena_lock?
function planner.recommendRuneloreStrategy()
  if not rwda.engine.runelore then return nil end
  
  local runelore = rwda.engine.runelore
  
  -- If Pithakhan unreliable, recommend head focus
  local shouldHead, reason = runelore.shouldFocusHead()
  if shouldHead then
    if reason == "pith_unreliable" then
      return "head_focus", "Pithakhan not proccing reliably - switch to head_focus strategy"
    elseif reason == "push_for_kena" then
      return "mana_pressure", "Close to Kena threshold - maximize mana drain"
    end
  end
  
  -- If already in Kena range, recommend lock strategy
  if runelore.isKenaEligible() then
    return "kena_lock", "Target below 40% mana - switch to kena_lock for true lock path"
  end
  
  return nil
end
```

---

## Phase 6: Planner Integration - Empower Decisions

### 6.1 Objective

Modify `rwda/engine/planner.lua` to:
- Include empower recommendations in attack plans
- Factor in attunement prediction when selecting venoms
- Coordinate phase transitions based on Kena eligibility

### 6.2 Implementation Steps

#### Step 6.2.1: Add empower consideration to plan generation

Add to `rwda/engine/planner.lua`:

```lua
-- Add empower recommendation to plan
function planner.addEmpowerToPlan(plan)
  if not rwda.engine.runelore then return plan end
  
  local runelore = rwda.engine.runelore
  local shouldEmpower, runeName = runelore.shouldEmpower()
  
  if shouldEmpower then
    plan.empower = {
      rune = runeName,
      priority = 100,
      reason = string.format("%s is attuned and ready", runeName),
    }
  end
  
  return plan
end

-- Factor attunement prediction into venom selection
function planner.selectVenomsForAttunement(plan, strategy)
  if not rwda.engine.runelore then return plan end
  
  local runelore = rwda.engine.runelore
  local runeblade = rwda.state.runeblade
  
  if not runeblade then return plan end
  
  local config = runeblade.getConfiguration()
  if not config or not config.core_rune then return plan end
  
  -- Check what attunements we want to trigger
  for _, runeName in ipairs(config.config_runes) do
    local def = rwda.data.runes.definitions[runeName]
    if def and def.attune_condition then
      -- If this rune isn't attuned, see if we can trigger it
      if not runeblade.isAttuned(runeName) then
        local venomSuggestion = planner.getVenomForAttunement(def.attune_condition)
        if venomSuggestion and not plan.venoms_locked then
          -- Suggest venom that helps attunement
          plan.suggested_venoms = plan.suggested_venoms or {}
          table.insert(plan.suggested_venoms, {
            venom = venomSuggestion,
            reason = string.format("Triggers %s attunement", runeName),
          })
        end
      end
    end
  end
  
  return plan
end

-- Get venom that helps trigger a specific attunement condition
function planner.getVenomForAttunement(condition)
  local runes = rwda.data.runes
  
  if condition == runes.ATTUNE_CONDITION.TARGET_PARALYSED then
    return "curare"
  elseif condition == runes.ATTUNE_CONDITION.TARGET_WEARY_OR_LETHARGIC then
    return "vernalius"
  elseif condition == runes.ATTUNE_CONDITION.TARGET_ADDICTED then
    return "vardrax"  -- addiction venom
  end
  
  return nil
end
```

---

## Phase 7: Executor Layer - Empower Command Execution

### 7.1 Objective

Modify `rwda/engine/executor.lua` to:
- Handle empower commands with proper timing
- Execute empower after weaponmastery attacks resolve (per game rules)
- Support priority-based empower queue

### 7.2 Implementation Steps

#### Step 7.2.1: Add empower execution support

Add to `rwda/engine/executor.lua`:

```lua
-- Execute an empower command
function executor.executeEmpower(empowerPlan)
  if not empowerPlan or not empowerPlan.rune then return false end
  
  local cmd = string.format("empower %s", empowerPlan.rune)
  
  -- Empower executes after attack resolves, so we can queue it
  executor.send(cmd)
  
  rwda.util.log("combat", "EMPOWER %s", empowerPlan.rune:upper())
  return true
end

-- Modified tick to include empower
function executor.tickWithEmpower()
  -- Standard tick
  local plan = executor.tick()
  
  -- Check for pending empower
  if plan and not plan.empower then
    local runelore = rwda.engine.runelore
    if runelore then
      local shouldEmpower, runeName = runelore.shouldEmpower()
      if shouldEmpower then
        plan.empower = { rune = runeName }
      end
    end
  end
  
  -- Execute empower if pending
  if plan and plan.empower then
    executor.executeEmpower(plan.empower)
  end
  
  return plan
end
```

---

## Phase 8: UI Layer - HUD & Commands

### 8.1 Objective

Add UI elements for:
- Attunement status display on HUD
- Empower priority configuration commands
- Configuration setup commands
- Strategy switching commands

### 8.2 Implementation Steps

#### Step 8.2.1: Add runelore commands to commands.lua

Add to `rwda/ui/commands.lua`:

```lua
-- ═══════════════════════════════════════════════════════════════
-- RUNELORE COMMANDS
-- ═══════════════════════════════════════════════════════════════

commands.handlers.config = function(args)
  local runeblade = rwda.state.runeblade
  if not runeblade then
    tell("Runeblade state not loaded.")
    return
  end
  
  local words = splitWords(args)
  local subCmd = words[1] and words[1]:lower() or "show"
  
  if subCmd == "show" then
    local cfg = runeblade.getConfiguration()
    if not cfg or not cfg.core_rune then
      tell("No configuration set. Use: rwda config set <core> <rune1> [rune2] [rune3]")
      return
    end
    tell(string.format("Configuration: %s + %s",
      cfg.core_rune:upper(),
      table.concat(cfg.config_runes, ", "):upper()))
    tell(string.format("Active: %s", cfg.active and "YES" or "NO"))
    
    local attuned = runeblade.getAttunedRunes()
    if #attuned > 0 then
      tell(string.format("Attuned: %s", table.concat(attuned, ", "):upper()))
    else
      tell("Attuned: (none)")
    end
    
  elseif subCmd == "set" then
    -- rwda config set pithakhan kena sleizak inguz
    local core = words[2]
    local configRunes = {}
    for i = 3, #words do
      table.insert(configRunes, words[i])
    end
    
    if not core then
      tell("Usage: rwda config set <core> <rune1> [rune2] [rune3]")
      tell("Core runes: pithakhan, nairat, eihwaz, hugalaz")
      return
    end
    
    local ok = runeblade.setConfiguration(core, configRunes)
    if ok then
      tell(string.format("Configuration set: %s + %s", core:upper(), table.concat(configRunes, ", "):upper()))
    else
      tell("Failed to set configuration. Check rune names.")
    end
    
  elseif subCmd == "lock" then
    -- Shortcut for recommended lock configuration
    local recommended = rwda.engine.runelore.getRecommendedLockConfig()
    runeblade.setConfiguration(recommended.core_rune, recommended.config_runes)
    runeblade.setEmpowerPriority(recommended.empower_priority)
    tell("Lock configuration applied: PITHAKHAN + KENA, SLEIZAK, INGUZ")
    tell("Empower priority: KENA > SLEIZAK > INGUZ")
    for _, note in ipairs(recommended.strategy_notes) do
      tell("  " .. note)
    end
    
  else
    tell("Unknown subcommand. Use: config show|set|lock")
  end
end

commands.handlers.empower = function(args)
  local runeblade = rwda.state.runeblade
  local runelore = rwda.engine.runelore
  
  if not runeblade or not runelore then
    tell("Runelore not loaded.")
    return
  end
  
  local words = splitWords(args)
  local subCmd = words[1] and words[1]:lower() or "auto"
  
  if subCmd == "auto" then
    local shouldEmpower, runeName = runelore.shouldEmpower()
    if shouldEmpower then
      runelore.queueEmpower(runeName)
      tell(string.format("Queueing EMPOWER %s", runeName:upper()))
    else
      tell("No runes currently attuned for empowerment.")
    end
    
  elseif subCmd == "priority" then
    -- rwda empower priority kena sleizak inguz
    local priority = {}
    for i = 2, #words do
      table.insert(priority, words[i])
    end
    
    if #priority == 0 then
      local current = runeblade.getEmpowerPriority()
      tell(string.format("Empower priority: %s", table.concat(current, " > ")))
      tell("Set with: rwda empower priority <rune1> <rune2> ...")
    else
      runeblade.setEmpowerPriority(priority)
      tell(string.format("Empower priority set: %s", table.concat(priority, " > ")))
    end
    
  elseif subCmd == "on" then
    runelore.setAutoEmpower(true)
    tell("Auto-empower ENABLED")
    
  elseif subCmd == "off" then
    runelore.setAutoEmpower(false)
    tell("Auto-empower DISABLED")
    
  else
    -- Manual empower of specific rune
    local runeName = subCmd
    if runeblade.canEmpower(runeName) then
      runelore.queueEmpower(runeName)
      tell(string.format("Queueing EMPOWER %s", runeName:upper()))
    else
      tell(string.format("Cannot empower %s - not attuned or not in configuration", runeName:upper()))
    end
  end
end

commands.handlers.attune = function(args)
  local runeblade = rwda.state.runeblade
  if not runeblade then
    tell("Runeblade state not loaded.")
    return
  end
  
  local attuned = runeblade.getAttunedRunes()
  if #attuned == 0 then
    tell("No runes currently attuned.")
    tell("Attunement conditions:")
    local cfg = runeblade.getConfiguration()
    if cfg and cfg.config_runes then
      for _, rune in ipairs(cfg.config_runes) do
        local def = rwda.data.runes.definitions[rune]
        if def then
          tell(string.format("  %s: %s", rune:upper(), def.attune_description or "unknown"))
        end
      end
    end
  else
    tell(string.format("ATTUNED: %s", table.concat(attuned, ", "):upper()))
    tell("Use 'rwda empower' to trigger empowerment.")
  end
end

commands.handlers.kena = function(args)
  local runelore = rwda.engine.runelore
  local target = rwda.state.target
  
  if not runelore then
    tell("Runelore not loaded.")
    return
  end
  
  local manaPercent = target.getManaPercent and target.getManaPercent() or nil
  local eligible = runelore.isKenaEligible()
  local distance = runelore.getKenaDistance()
  
  tell("=== KENA STATUS ===")
  tell(string.format("Threshold: <40%% mana"))
  if manaPercent then
    tell(string.format("Target mana: %.1f%%", manaPercent * 100))
    tell(string.format("Kena eligible: %s", eligible and "YES" or "NO"))
    if not eligible then
      tell(string.format("Distance to threshold: %.1f%%", distance * 100))
    end
  else
    tell("Target mana: unknown")
  end
  
  local nearLock, missing = runelore.isNearLock()
  tell(string.format("Near lock: %s", nearLock and "YES" or "NO"))
  if #missing > 0 then
    tell(string.format("Missing for lock: %s", table.concat(missing, ", ")))
  end
end

-- Add to help text
commands.handlers.runelore = function(args)
  tell("=== RUNELORE COMMANDS ===")
  tell("rwda config show       - Show current runeblade configuration")
  tell("rwda config set <core> <r1> [r2] [r3] - Set configuration")
  tell("rwda config lock       - Apply recommended Pith+Kena lock config")
  tell("")
  tell("rwda empower           - Auto-empower highest priority attuned rune")
  tell("rwda empower <rune>    - Empower specific rune")
  tell("rwda empower priority <r1> <r2> ... - Set empower priority")
  tell("rwda empower on|off    - Toggle auto-empower")
  tell("")
  tell("rwda attune            - Show attunement status and conditions")
  tell("rwda kena              - Show Kena/lock status")
  tell("")
  tell("=== QUICK SETUP ===")
  tell("rwda config lock       - Full lock path setup (Pith+Kena)")
  tell("rwda strat kena_lock   - Switch to lock path strategy")
end
```

#### Step 8.2.2: Add attunement display to HUD

In `rwda/ui/hud.lua`, add attunement panel:

```lua
-- Add to hud.update():
function hud.updateAttunement()
  local runeblade = rwda.state.runeblade
  if not runeblade then return end
  
  local cfg = runeblade.getConfiguration()
  if not cfg or not cfg.core_rune then return end
  
  local lines = {}
  table.insert(lines, string.format("<b>Config:</b> %s", cfg.core_rune:upper()))
  
  for _, rune in ipairs(cfg.config_runes) do
    local attuned = runeblade.isAttuned(rune)
    local status = attuned and "<green>ATTUNED</green>" or "<dim>waiting</dim>"
    table.insert(lines, string.format("  %s: %s", rune:upper(), status))
  end
  
  -- Kena status
  local runelore = rwda.engine.runelore
  if runelore then
    local eligible = runelore.isKenaEligible()
    local status = eligible and "<yellow>ELIGIBLE</yellow>" or ""
    if status ~= "" then
      table.insert(lines, string.format("<b>Kena:</b> %s", status))
    end
  end
  
  hud.setPanel("attunement", table.concat(lines, "\n"))
end
```

---

## Phase 9: Testing & Validation

### 9.1 Selftest Additions

Add to `rwda/engine/selftest.lua`:

```lua
-- Runelore module tests
function selftest.testRunelore()
  local results = { passed = 0, failed = 0, errors = {} }
  
  -- Test rune definitions loaded
  local runes = rwda.data.runes
  if runes and runes.definitions and runes.definitions.kena then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "Rune definitions not loaded")
  end
  
  -- Test attunement conditions
  local kenaCondition = runes.getAttuneCondition("kena")
  if kenaCondition == runes.ATTUNE_CONDITION.MANA_BELOW_40 then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "Kena attunement condition incorrect")
  end
  
  -- Test runeblade state
  local runeblade = rwda.state.runeblade
  if runeblade and runeblade.setConfiguration then
    runeblade.setConfiguration("pithakhan", { "kena", "inguz" })
    local cfg = runeblade.getConfiguration()
    if cfg.core_rune == "pithakhan" then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "Configuration not set correctly")
    end
  end
  
  -- Test runelore engine
  local runelore = rwda.engine.runelore
  if runelore and runelore.getRecommendedLockConfig then
    local recommended = runelore.getRecommendedLockConfig()
    if recommended.core_rune == "pithakhan" then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "Recommended config incorrect")
    end
  end
  
  return results
end
```

### 9.2 Manual Test Checklist

```
[ ] 1. Load RWDA and verify no errors
[ ] 2. Run: rwda doctor
     - Verify runelore module appears
[ ] 3. Run: rwda selftest
     - Verify runelore tests pass
[ ] 4. Run: rwda config lock
     - Verify configuration set to Pith+Kena
[ ] 5. Run: rwda attune
     - Verify attunement conditions listed
[ ] 6. In combat, verify:
     - Head targeting when Pith unreliable
     - Kena status updates at 40% mana threshold
     - Auto-empower triggers when runes attune
[ ] 7. Run: rwda kena
     - Verify mana tracking and lock status
[ ] 8. Verify HUD shows attunement panel
```

---

## Appendix A: Rune Reference Data

### A.1 Configuration-Eligible Runes

| Rune | Attune Condition | Empower Effect |
|------|-----------------|----------------|
| **Kena** | Target mana <40% | Impatience |
| Inguz | Target paralysed | Cracked ribs (1 stack) |
| Wunjo | Target shivering | Damage based on cracked ribs |
| Sowulu | Limb damaged (needs resto) | Healthleech + fracture relapse |
| Fehu | Target prone or no insomnia | Sleep |
| Mannaz | Target off focus balance | Block mana regen (timed) |
| Isaz | Engage prevents escape | Epilepsy |
| Tiwaz | Off salve + no limbs need resto | Break both arms |
| Sleizak | Target weary or lethargic | Nausea (or voyria if nauseous) |
| Loshre | Target addicted | Punish ginseng/ferrum eating |

### A.2 Core Runeblade Runes

| Rune | Special Mechanic |
|------|-----------------|
| **Pithakhan** | Mana drain; guaranteed on damaged head; 13% on broken head |
| Nairat | Random FREEZE |
| Eihwaz | Mask venom effects |
| Hugalaz | Hail damage proc; enables BISECT |

### A.3 Kelp-Cure Afflictions

| Venom | Affliction | Cure |
|-------|-----------|------|
| Kalmia | Asthma | Kelp/Aurum |
| Vernalius | Weariness | Kelp/Aurum |
| Xentio | Clumsiness | Kelp/Aurum |
| Prefarar | Sensitivity | Kelp/Aurum |
| Epteth | Healthleech | Kelp/Aurum |

---

## Appendix B: Kill Path Logic Reference

### B.1 Modern Runewarden Lock Path (Dec 2025)

```
┌─────────────────────────────────────────────────────────────┐
│                    PHASE 1: HEAD BREAK                      │
├─────────────────────────────────────────────────────────────┤
│ Goal: Damage head to make Pithakhan procs reliable          │
│ Target: HEAD                                                │
│ Venoms: kalmia, gecko, curare, vernalius                    │
│ Exit: Head is DAMAGED or BROKEN                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 PHASE 2: MANA PRESSURE                      │
├─────────────────────────────────────────────────────────────┤
│ Goal: Push target below 40% mana for Kena eligibility       │
│ Target: HEAD (maximize Pith drain - 13% if broken)          │
│ Venoms: kalmia, vernalius, xentio, prefarar (kelp stack)    │
│ Exit: Target mana < 40%                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  PHASE 3: KENA ATTUNES                      │
├─────────────────────────────────────────────────────────────┤
│ Trigger: Attack lands while target mana < 40%               │
│ Action: EMPOWER KENA → delivers IMPATIENCE                  │
│ Effect: Target cannot FOCUS (goldenseal cure)               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   PHASE 4: TRUE LOCK                        │
├─────────────────────────────────────────────────────────────┤
│ Impatience + Asthma + Paralysis = LOCK                      │
│ - Impatience blocks FOCUS (can't cure paralysis)            │
│ - Asthma blocks herb eating                                 │
│ - Paralysis prevents actions                                │
│ Venoms: curare, kalmia, gecko                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    PHASE 5: EXECUTE                         │
├─────────────────────────────────────────────────────────────┤
│ If target health ≤ 20%: BISECT (instant kill)               │
│ Requires: Hugalaz rune on runeblade                         │
│ Otherwise: Standard damage/execute                          │
└─────────────────────────────────────────────────────────────┘
```

### B.2 Key Thresholds

| Threshold | Value | Source |
|-----------|-------|--------|
| Kena attune | <40% mana | Dec 2025 classleads |
| Pith drain (normal) | 10% | Base mechanic |
| Pith drain (broken head) | 13% | Dec 2025 classleads |
| Pith guaranteed proc | Damaged head | July 2022 rework |
| BISECT instant kill | ≤20% health | Runelore ability |

---

## Implementation Checklist

### Files to Create
- [ ] `rwda/data/runes.lua`
- [ ] `rwda/state/runeblade.lua`
- [ ] `rwda/engine/runelore.lua`

### Files to Modify
- [ ] `rwda/init.lua` - Add new files to FILES list
- [ ] `rwda/engine/parser.lua` - Add rune event patterns
- [ ] `rwda/engine/planner.lua` - Add empower integration
- [ ] `rwda/engine/executor.lua` - Add empower execution
- [ ] `rwda/data/strategy_presets.lua` - Add lock strategies
- [ ] `rwda/ui/commands.lua` - Add runelore commands
- [ ] `rwda/ui/hud.lua` - Add attunement display
- [ ] `rwda/engine/selftest.lua` - Add runelore tests

### Testing Sequence
1. [ ] Unit tests pass (`rwda selftest`)
2. [ ] Doctor shows runelore loaded (`rwda doctor`)
3. [ ] Configuration commands work (`rwda config`)
4. [ ] Attunement tracking works in combat
5. [ ] Auto-empower triggers correctly
6. [ ] Strategy transitions work
7. [ ] HUD displays attunement
8. [ ] Full lock path successful in Bellatorium

---

*Document Version: 1.0*  
*Last Updated: March 2026*  
*Based on: December 9, 2025 Achaea Classleads, July 3, 2022 Runelore Rework*
