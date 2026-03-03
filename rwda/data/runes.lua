rwda = rwda or {}
rwda.data = rwda.data or {}
rwda.data.runes = rwda.data.runes or {}

local runes = rwda.data.runes

-- ─────────────────────────────────────────────
-- Rune Categories
-- ─────────────────────────────────────────────

runes.CATEGORY = {
  GROUND        = "ground",
  TOTEM         = "totem",
  WEAPON        = "weapon",
  PERSON        = "person",
  ARMOUR        = "armour",
  CORE_RUNEBLADE = "core",
  CONFIGURATION = "config",
}

-- ─────────────────────────────────────────────
-- Attunement Condition Keys
-- ─────────────────────────────────────────────

runes.ATTUNE = {
  MANA_BELOW_40           = "mana_below_40",
  TARGET_PARALYSED        = "target_paralysed",
  TARGET_SHIVERING        = "target_shivering",
  LIMB_DAMAGED            = "limb_damaged",
  PRONE_OR_NO_INSOMNIA    = "prone_or_no_insomnia",
  OFF_FOCUS_BALANCE       = "off_focus_balance",
  ENGAGE_PREVENTS_ESCAPE  = "engage_prevents_escape",
  OFF_SALVE_NO_RESTORE    = "off_salve_no_restore",
  TARGET_ADDICTED         = "target_addicted",
  TARGET_WEARY_LETHARGIC  = "target_weary_lethargic",
}

-- ─────────────────────────────────────────────
-- Empower Effect Keys
-- ─────────────────────────────────────────────

runes.EMPOWER = {
  IMPATIENCE          = "impatience",
  CRACKED_RIBS        = "cracked_ribs",
  CRACKED_RIBS_DAMAGE = "cracked_ribs_damage",
  EPILEPSY            = "epilepsy",
  MANA_REGEN_BLOCK    = "mana_regen_block",
  BREAK_ARMS          = "break_arms",
  HEALTHLEECH_FRACTURE = "healthleech_fracture",
  NAUSEA_OR_VOYRIA    = "nausea_voyria",
  EATING_PUNISHMENT   = "eating_punishment",
  SLEEP               = "sleep",
}

-- ─────────────────────────────────────────────
-- Rune Definitions
-- ─────────────────────────────────────────────

runes.definitions = {

  -- ╔══════════════════════════════════════╗
  -- ║  CORE RUNEBLADE RUNES               ║
  -- ╚══════════════════════════════════════╝

  pithakhan = {
    name       = "Pithakhan",
    symbol     = "Square Box",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.WEAPON, runes.CATEGORY.CORE_RUNEBLADE },
    ink        = { red = 1 },
    balance_cost = 2.0,
    ground_effect  = "Attacks enemy mana on sight (not blind people)",
    weapon_effect  = "Occasionally drains mana from target (runeblade only)",
    -- July 2022 rework: always fires on damaged head
    damaged_head_guaranteed = true,
    -- Dec 2025 classleads
    drain_broken_head_pct  = 0.13,
    drain_normal_pct       = 0.10,
  },

  nairat = {
    name       = "Nairat",
    symbol     = "Butterfly",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.WEAPON, runes.CATEGORY.CORE_RUNEBLADE },
    ink        = { yellow = 1 },
    balance_cost = 2.0,
    ground_effect  = "Entangles enemy who sees it",
    weapon_effect  = "Randomly FREEZEs target (runeblade only)",
  },

  eihwaz = {
    name       = "Eihwaz",
    symbol     = "Yew",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.WEAPON, runes.CATEGORY.CORE_RUNEBLADE },
    ink        = { blue = 1, yellow = 1 },
    balance_cost = 4.0,
    ground_effect  = "Dampens non-protected crystalline vibrations",
    weapon_effect  = "Randomly masks venom effects (runeblade only)",
  },

  hugalaz = {
    name       = "Hugalaz",
    symbol     = "Ball of Ice",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.WEAPON, runes.CATEGORY.CORE_RUNEBLADE },
    ink        = { blue = 1 },
    balance_cost = 3.0,
    ground_effect  = "Hailstorm damages enemies",
    weapon_effect  = "Chance for additional hail damage (runeblade only)",
    enables_bisect = true,   -- Required for BISECT ability
  },

  -- ╔══════════════════════════════════════╗
  -- ║  CONFIGURATION RUNES                ║
  -- ╚══════════════════════════════════════╝

  kena = {
    name       = "Kena",
    symbol     = "Nightmare",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { red = 1 },
    balance_cost = 2.0,
    ground_effect       = "Inspires fear in enemy who sees it",
    -- Dec 2025: threshold raised from 20% to 40%
    attune_condition    = runes.ATTUNE.MANA_BELOW_40,
    attune_description  = "Runeblade strikes target with <40% mana",
    empower_effect      = runes.EMPOWER.IMPATIENCE,
    empower_description = "Delivers impatience",
    lock_priority       = 1,   -- Highest priority in lock path
  },

  inguz = {
    name       = "Inguz",
    symbol     = "Stickman",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { red = 1 },
    balance_cost = 2.0,
    ground_effect       = "Paralyses enemy who sees it",
    attune_condition    = runes.ATTUNE.TARGET_PARALYSED,
    attune_description  = "Runeblade strikes a paralysed target",
    empower_effect      = runes.EMPOWER.CRACKED_RIBS,
    empower_description = "Gives one stack of cracked ribs",
    lock_priority       = 3,
  },

  wunjo = {
    name       = "Wunjo",
    symbol     = "Open Eye",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { red = 1 },
    balance_cost = 2.0,
    ground_effect       = "Returns sight to enemy who sees it",
    attune_condition    = runes.ATTUNE.TARGET_SHIVERING,
    attune_description  = "Runeblade strikes a shivering target",
    empower_effect      = runes.EMPOWER.CRACKED_RIBS_DAMAGE,
    empower_description = "Deals damage based on cracked rib stacks",
  },

  sowulu = {
    name       = "Sowulu",
    symbol     = "Nail",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { red = 1 },
    balance_cost = 2.0,
    ground_effect       = "Damages opponent who sees it (not deaf)",
    attune_condition    = runes.ATTUNE.LIMB_DAMAGED,
    attune_description  = "Runeblade strikes a limb needing restoration",
    empower_effect      = runes.EMPOWER.HEALTHLEECH_FRACTURE,
    empower_description = "Gives healthleech; fracture afflictions relapse",
  },

  fehu = {
    name       = "Fehu",
    symbol     = "Closed Eye",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { red = 1 },
    balance_cost = 2.0,
    ground_effect       = "Causes sleep or removes insomnia/kola",
    attune_condition    = runes.ATTUNE.PRONE_OR_NO_INSOMNIA,
    attune_description  = "Runeblade strikes someone prone or missing insomnia",
    empower_effect      = runes.EMPOWER.SLEEP,
    empower_description = "Puts target to sleep if missing insomnia defence",
  },

  mannaz = {
    name       = "Mannaz",
    symbol     = "Bell",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { red = 1 },
    balance_cost = 2.0,
    ground_effect       = "Returns hearing to enemy who sees it",
    attune_condition    = runes.ATTUNE.OFF_FOCUS_BALANCE,
    attune_description  = "Runeblade strikes target off focus balance",
    empower_effect      = runes.EMPOWER.MANA_REGEN_BLOCK,
    empower_description = "Timed affliction disabling all mana regeneration",
  },

  isaz = {
    name       = "Isaz",
    symbol     = "Flurry of Lightning Bolts",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.CONFIGURATION },
    ink        = { blue = 1, red = 1 },
    balance_cost = 4.0,
    ground_effect       = "Shockwave unbalances non-levitating or weary/lethargic enemies",
    attune_condition    = runes.ATTUNE.ENGAGE_PREVENTS_ESCAPE,
    attune_description  = "Engage prevents escape or Isaz disrupts enemy balance",
    empower_effect      = runes.EMPOWER.EPILEPSY,
    empower_description = "Delivers epilepsy",
  },

  tiwaz = {
    name       = "Tiwaz",
    symbol     = "Upwards-Pointing Arrow",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { blue = 1, red = 2 },
    balance_cost = 2.0,
    ground_effect       = "Strips a defence from enemy who sees it",
    attune_condition    = runes.ATTUNE.OFF_SALVE_NO_RESTORE,
    attune_description  = "Target off salve balance with no limbs needing restoration",
    empower_effect      = runes.EMPOWER.BREAK_ARMS,
    empower_description = "Breaks both of target's arms",
  },

  sleizak = {
    name       = "Sleizak",
    symbol     = "Viper",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { blue = 1 },
    balance_cost = 2.0,
    ground_effect       = "Infects with voyria if seen",
    attune_condition    = runes.ATTUNE.TARGET_WEARY_LETHARGIC,
    attune_description  = "Runeblade strikes a weary or lethargic target",
    empower_effect      = runes.EMPOWER.NAUSEA_OR_VOYRIA,
    empower_description = "Delivers nausea (or voyria if already nauseous)",
    lock_priority       = 2,
  },

  loshre = {
    name       = "Loshre",
    symbol     = "Apple Core",
    categories = { runes.CATEGORY.GROUND, runes.CATEGORY.TOTEM, runes.CATEGORY.CONFIGURATION },
    ink        = { blue = 1 },
    balance_cost = 2.0,
    ground_effect       = "Gives anorexia to those who see it",
    attune_condition    = runes.ATTUNE.TARGET_ADDICTED,
    attune_description  = "Runeblade strikes an addicted target",
    empower_effect      = runes.EMPOWER.EATING_PUNISHMENT,
    empower_description = "Timed affliction punishing ginseng/ferrum eating",
  },

  -- ╔══════════════════════════════════════╗
  -- ║  PERMANENT RUNEBLADE RUNES           ║
  -- ║  (Required for empowerment)          ║
  -- ╚══════════════════════════════════════╝

  lagul = {
    name       = "Lagul",
    symbol     = "Dirk",
    categories = { runes.CATEGORY.WEAPON },
    ink        = { purple = 1 },
    balance_cost = 4.0,
    weapon_effect          = "Inflicts more bleeding when striking",
    required_for_empower   = true,
  },

  lagua = {
    name       = "Lagua",
    symbol     = "Large Hammer",
    categories = { runes.CATEGORY.WEAPON },
    ink        = { purple = 1 },
    balance_cost = 4.0,
    weapon_effect          = "Magnified disembowel damage on internal trauma",
    required_for_empower   = true,
  },

  laguz = {
    name       = "Laguz",
    symbol     = "Long Slim Blade",
    categories = { runes.CATEGORY.WEAPON },
    ink        = { purple = 1 },
    balance_cost = 4.0,
    weapon_effect          = "Deals more damage to target's limbs",
    required_for_empower   = true,
  },

  -- ╔══════════════════════════════════════╗
  -- ║  UTILITY / GROUND RUNES             ║
  -- ╚══════════════════════════════════════╝

  uruz = {
    name       = "Uruz",
    symbol     = "Lightning Bolt",
    categories = { runes.CATEGORY.GROUND },
    ink        = { blue = 1, yellow = 1 },
    balance_cost = 5.0,
    ground_effect = "Heals you and allies",
  },

  jera = {
    name       = "Jera",
    symbol     = "Mighty Oak",
    categories = { runes.CATEGORY.PERSON },
    ink        = { purple = 1 },
    balance_cost = 4.0,
    person_effect = "Increases STR and CON by 1 while active",
  },

  algiz = {
    name       = "Algiz",
    symbol     = "Elk",
    categories = { runes.CATEGORY.PERSON },
    ink        = { green = 1 },
    balance_cost = 2.0,
    person_effect = "10% reduction to all damage types",
  },

  dagaz = {
    name       = "Dagaz",
    symbol     = "Rising Sun",
    categories = { runes.CATEGORY.GROUND },
    ink        = { green = 1, red = 1 },
    balance_cost = 5.0,
    ground_effect = "Cures random afflictions",
  },

  gular = {
    name       = "Gular",
    categories = { runes.CATEGORY.GROUND },
    ink        = { red = 1 },
    balance_cost = 2.0,
    ground_effect = "Raises or destroys stone wall in a direction",
  },

  raido = {
    name       = "Raido",
    symbol     = "Horse",
    categories = { runes.CATEGORY.GROUND },
    ink        = { green = 1 },
    balance_cost = 10.0,
    ground_effect = "Teleport-home rune (say 'ride home')",
  },

  thurisaz = {
    name       = "Thurisaz",
    symbol     = "Volcano",
    categories = { runes.CATEGORY.GROUND },
    ink        = { blue = 1, red = 1 },
    balance_cost = 3.0,
    ground_effect = "Molten lava spout damages target; prevents flooding",
  },

  nauthiz = {
    name       = "Nauthiz",
    symbol     = "Leech",
    categories = { runes.CATEGORY.GROUND },
    ink        = { blue = 1, yellow = 1 },
    balance_cost = 4.0,
    ground_effect = "Drains flood water, or sucks nourishment from enemies",
  },

  othala = {
    name       = "Othala",
    symbol     = "Mountain Range",
    categories = { runes.CATEGORY.GROUND },
    ink        = { red = 5 },
    balance_cost = 4.0,
    ground_effect = "Three eruptions destroying prismatic/shield or dealing damage",
  },

  berkana = {
    name       = "Berkana",
    symbol     = "Lion",
    categories = { runes.CATEGORY.PERSON },
    ink        = { yellow = 3 },
    balance_cost = 2.0,
    person_effect = "Health regeneration to bearer",
  },

  gebu = {
    name       = "Gebu",
    symbol     = "Shield",
    categories = { runes.CATEGORY.ARMOUR },
    ink        = { gold = 1 },
    balance_cost = 4.0,
    armour_effect                     = "Increases blunt protection",
    required_for_armour_empower       = true,
  },

  gebo = {
    name       = "Gebo",
    symbol     = "Chain",
    categories = { runes.CATEGORY.ARMOUR },
    ink        = { gold = 1 },
    balance_cost = 4.0,
    armour_effect                     = "Increases cutting protection",
    required_for_armour_empower       = true,
  },
}

-- ─────────────────────────────────────────────
-- Helper Functions
-- ─────────────────────────────────────────────

function runes.canBeInConfiguration(runeName)
  local def = runes.definitions[tostring(runeName):lower()]
  return def ~= nil and def.attune_condition ~= nil
end

function runes.getAttuneCondition(runeName)
  local def = runes.definitions[tostring(runeName):lower()]
  return def and def.attune_condition
end

function runes.getEmpowerEffect(runeName)
  local def = runes.definitions[tostring(runeName):lower()]
  return def and def.empower_effect
end

function runes.getCoreRunes()
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

function runes.getConfigurationRunes()
  local result = {}
  for name, def in pairs(runes.definitions) do
    if def.attune_condition then
      result[name] = def
    end
  end
  return result
end

-- Kelp-cure affliction venom map (asthma, weariness, clumsiness, sensitivity, healthleech)
runes.kelp_venoms = {
  kalmia   = "asthma",
  vernalius = "weariness",
  xentio   = "clumsiness",
  prefarar = "sensitivity",
  epteth   = "healthleech",
}

-- Venoms that trigger useful configuration attunements
runes.attune_venoms = {
  [runes.ATTUNE.TARGET_PARALYSED]       = "curare",
  [runes.ATTUNE.TARGET_WEARY_LETHARGIC] = "vernalius",
  [runes.ATTUNE.TARGET_ADDICTED]        = "vardrax",
}

return runes
