-- Silverfury/runelore/runes.lua
-- Data-driven rune definitions for the Runewarden class.
-- Schema: { category, description, syntax, inks, attune_condition, empower_effect }
-- empower_effect: string (description) or table { aff, limb_break, ... } for structured use.

Silverfury = Silverfury or {}
Silverfury.runelore = Silverfury.runelore or {}

local runes = {}
Silverfury.runelore.runes = runes

-- ── Rune database ─────────────────────────────────────────────────────────────
-- Categories: CORE_RUNEBLADE | CONFIGURATION | WEAPON | ARMOUR | GROUND | PERSON

runes.DATA = {
  -- ── Core runes (one per runeblade) ─────────────────────────────────────────
  pithakhan = {
    category         = "CORE_RUNEBLADE",
    description      = "Mana drain on hit. Fires on damaged head; 13% drain on broken head.",
    syntax           = { "SKETCH PITHAKHAN ON <weapon>", "SKETCH PITHAKHAN ON GROUND/<totem>" },
    inks             = { red=1 },
    empower_effect   = { description="Drains target mana each hit (scales with head damage)" },
    is_core          = true,
  },
  nairat = {
    category         = "CORE_RUNEBLADE",
    description      = "Chance to freeze target on hit; entangles on ground/totem.",
    syntax           = { "SKETCH NAIRAT ON <weapon>", "SKETCH NAIRAT ON GROUND/<totem>" },
    inks             = { yellow=1 },
    empower_effect   = { description="Freeze proc on target" },
    is_core          = true,
  },
  eihwaz = {
    category         = "CORE_RUNEBLADE",
    description      = "Masks venoms delivered by the weapon at random.",
    syntax           = { "SKETCH EIHWAZ ON <weapon>", "SKETCH EIHWAZ ON GROUND" },
    inks             = { blue=1, yellow=1 },
    empower_effect   = { description="Randomly hide venoms from target" },
    is_core          = true,
  },
  hugalaz = {
    category         = "CORE_RUNEBLADE",
    description      = "Enables BISECT finisher (kills at <=20% HP); hail proc on hit.",
    syntax           = { "SKETCH HUGALAZ ON <weapon>", "SKETCH HUGALAZ ON GROUND" },
    inks             = { blue=1 },
    empower_effect   = { description="Enable bisect + hail proc on hit" },
    is_core          = true,
  },

  -- ── Configuration runes (attune + empower for triggered effects) ───────────
  kena = {
    category         = "CONFIGURATION",
    description      = "Delivers impatience when target mana < threshold (40% since Dec 2025).",
    syntax           = { "SKETCH KENA ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> kena [rune2] [rune3]" },
    inks             = { red=1 },
    attune_condition = "target_mana_low",
    empower_effect   = { aff="impatience", description="Impatience on mana threshold cross" },
  },
  inguz = {
    category         = "CONFIGURATION",
    description      = "Paralyses on ground; delivers cracked ribs via empower on paralysed target.",
    syntax           = { "SKETCH INGUZ ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> inguz [rune2] [rune3]" },
    inks             = { red=1 },
    attune_condition = "target_paralysed",
    empower_effect   = { aff="cracked_ribs", description="Cracked ribs stack on paralysis" },
  },
  sleizak = {
    category         = "CONFIGURATION",
    description      = "Voyria on ground; empower delivers nausea, or voyria if already nauseated.",
    syntax           = { "SKETCH SLEIZAK ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> sleizak [rune2] [rune3]" },
    inks             = { blue=1 },
    attune_condition = "target_weary",
    empower_effect   = { aff="nausea", alt_aff="voyria",
                         description="Nausea; voyria if already nauseous" },
  },
  fehu = {
    category         = "CONFIGURATION",
    description      = "Sleeps target on ground; empower sleeps prone/no-insomnia targets.",
    syntax           = { "SKETCH FEHU ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> fehu [rune2] [rune3]" },
    inks             = { red=1 },
    attune_condition = "target_prone_no_insomnia",
    empower_effect   = { aff="sleep", description="Sleep on prone target missing insomnia" },
  },
  wunjo = {
    category         = "CONFIGURATION",
    description      = "Restores sight on ground; empower bursts ribs on shivering target.",
    syntax           = { "SKETCH WUNJO ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> wunjo [rune2] [rune3]" },
    inks             = { red=1 },
    attune_condition = "target_shivering",
    empower_effect   = { rib_burst=true,
                         description="Rib burst: damage scaled by cracked rib count" },
  },
  mannaz = {
    category         = "CONFIGURATION",
    description      = "Returns hearing on ground; empower blocks mana regen when target off focus.",
    syntax           = { "SKETCH MANNAZ ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> mannaz [rune2] [rune3]" },
    inks             = { red=1 },
    attune_condition = "target_off_focus",
    empower_effect   = { description="Timed mana regen block when focus balance is down" },
  },
  isaz = {
    category         = "CONFIGURATION",
    description      = "Balance disruption on ground; empower delivers epilepsy on engaged target.",
    syntax           = { "SKETCH ISAZ ON GROUND",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> isaz [rune2] [rune3]" },
    inks             = { blue=1, red=1 },
    attune_condition = "target_engaged",
    empower_effect   = { aff="epilepsy", description="Epilepsy while target is engaged" },
  },
  tiwaz = {
    category         = "CONFIGURATION",
    description      = "Strips defences on ground; empower breaks both arms when target off salve.",
    syntax           = { "SKETCH TIWAZ ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> tiwaz [rune2] [rune3]" },
    inks             = { blue=1, red=2 },
    attune_condition = "target_off_salve",
    empower_effect   = { limb_break={ "left_arm", "right_arm" },
                         description="Break both arms when salve balance is down" },
  },
  sowulu = {
    category         = "CONFIGURATION",
    description      = "Damages on ground; empower gives healthleech and triggers fracture relapse.",
    syntax           = { "SKETCH SOWULU ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> sowulu [rune2] [rune3]" },
    inks             = { red=1 },
    attune_condition = "target_limb_damaged",
    empower_effect   = { aff="health_leech", fracture_relapse=true,
                         description="Healthleech; fracture relapse on damaged limbs" },
  },
  loshre = {
    category         = "CONFIGURATION",
    description      = "Anorexia on ground; empower punishes ginseng eating on addicted target.",
    syntax           = { "SKETCH LOSHRE ON GROUND/<totem>",
                         "SKETCH CONFIGURATION <blade/LEFT/RIGHT/WIELDED> loshre [rune2] [rune3]" },
    inks             = { blue=1 },
    attune_condition = "target_addicted",
    empower_effect   = { description="Eating punishment: drain HP/mana on ginseng while afflicted" },
  },

  -- ── Baseline weapon runes (required for EMPOWER) ───────────────────────────
  lagul = {
    category    = "WEAPON",
    description = "Baseline rune (required for empower). Increases bleeding on hit.",
    syntax      = { "SKETCH LAGUL ON <weapon>" },
    inks        = { purple=1 },
  },
  lagua = {
    category    = "WEAPON",
    description = "Baseline rune (required for empower). Magnifies disembowel on internal trauma.",
    syntax      = { "SKETCH LAGUA ON <weapon>" },
    inks        = { purple=1 },
  },
  laguz = {
    category    = "WEAPON",
    description = "Baseline rune (required for empower). Increases limb damage.",
    syntax      = { "SKETCH LAGUZ ON <weapon>" },
    inks        = { purple=1 },
  },

  -- ── Armour runes ───────────────────────────────────────────────────────────
  gebu = {
    category    = "ARMOUR",
    description = "Increases blunt damage protection.",
    syntax      = { "SKETCH GEBU ON <armour>" },
    inks        = { gold=1 },
  },
  gebo = {
    category    = "ARMOUR",
    description = "Increases cutting damage protection.",
    syntax      = { "SKETCH GEBO ON <armour>" },
    inks        = { gold=1 },
  },

  -- ── Ground / utility runes ─────────────────────────────────────────────────
  uruz = {
    category    = "GROUND",
    description = "Heals you and allies in the room.",
    syntax      = { "SKETCH URUZ ON GROUND" },
    inks        = { blue=1, yellow=1 },
  },
  jera = {
    category    = "PERSON",
    description = "Increases bearer strength and constitution by 1 for its duration.",
    syntax      = { "SKETCH JERA ON ME/<target>" },
    inks        = { purple=1 },
  },
  algiz = {
    category    = "PERSON",
    description = "Reduces all damage types by 10% for bearer.",
    syntax      = { "SKETCH ALGIZ ON ME/<target>" },
    inks        = { green=1 },
  },
  dagaz = {
    category    = "GROUND",
    description = "Cures one random affliction from yourself.",
    syntax      = { "SKETCH DAGAZ ON GROUND" },
    inks        = { green=1, red=1 },
  },
  raido = {
    category    = "GROUND",
    description = "Teleport home via rune anchor. Use: SKETCH RAIDO, then SAY RIDE HOME.",
    syntax      = { "SKETCH RAIDO ON GROUND", "SAY RIDE HOME" },
    inks        = { green=1 },
  },
  thurisaz = {
    category    = "GROUND",
    description = "Molten lava eruption on target; also prevents room flooding.",
    syntax      = { "SKETCH THURISAZ ON GROUND FOR <target>" },
    inks        = { blue=1, red=1 },
  },
  nauthiz = {
    category    = "GROUND",
    description = "Drains nourishment from enemies; drains flood water if in flooded room.",
    syntax      = { "SKETCH NAUTHIZ ON GROUND" },
    inks        = { blue=1, yellow=1 },
  },
  othala = {
    category    = "GROUND",
    description = "Triple lava eruption: destroys barriers/shields then damages all enemies.",
    syntax      = { "SKETCH OTHALA ON GROUND" },
    inks        = { red=5 },
  },
  berkana = {
    category    = "PERSON",
    description = "Health regeneration for bearer.",
    syntax      = { "SKETCH BERKANA ON ME/<target>" },
    inks        = { yellow=3 },
  },
  gular = {
    category    = "GROUND",
    description = "Stone wall blocking a direction (or destroys existing wall).",
    syntax      = { "SKETCH GULAR ON GROUND <direction>" },
    inks        = { red=1 },
  },
}

-- ── Helper queries ────────────────────────────────────────────────────────────

function runes.getCoreRunes()
  local out = {}
  for name, data in pairs(runes.DATA) do
    if data and data.is_core then out[#out+1] = name end
  end
  return out
end

function runes.getConfigurationRunes()
  local out = {}
  for name, data in pairs(runes.DATA) do
    if data and data.category == "CONFIGURATION" then out[#out+1] = name end
  end
  return out
end

function runes.isValid(name)
  return runes.DATA[name] ~= nil
end

function runes.describe(name)
  local d = runes.DATA[name]
  if not d then return "Unknown rune: " .. tostring(name) end
  return string.format("[%s] %s — %s", d.category, name, d.description)
end

-- Returns ink cost as readable string, e.g. "1 Red, 2 Blue".
function runes.inkCost(name)
  local d = runes.DATA[name]
  if not d or not d.inks then return "none" end
  local parts = {}
  local order = { "red", "blue", "yellow", "purple", "green", "gold" }
  for _, col in ipairs(order) do
    local n = d.inks[col]
    if n and n > 0 then
      parts[#parts+1] = n .. " " .. col:sub(1,1):upper() .. col:sub(2)
    end
  end
  return #parts > 0 and table.concat(parts, ", ") or "none"
end
