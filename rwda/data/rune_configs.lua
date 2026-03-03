rwda = rwda or {}
rwda.data = rwda.data or {}
rwda.data.rune_configs = rwda.data.rune_configs or {}

local rune_configs = rwda.data.rune_configs

-- ─────────────────────────────────────────────────────────────────────────────
-- Preset table
--
-- Each entry defines:
--   name          string  Identifier, must match the key.
--   description   string  One-line human summary.
--   profile_hint  string  RWDA profile to switch to on completion.
--   goal_hint     string  RWDA goal to set on completion.
--   core_rune     string  The "core" runeblade rune (pithakhan / nairat /
--                         eihwaz / hugalaz).  nil = armour preset.
--   config_runes  table   Ordered list: [1]=highest empower priority.
--   weapon_runes  table   Baseline sketch runes required for a runeblade.
--                         Always lagul + lagua + laguz.
--   armour        bool    true = runicarmour workflow (no core / config).
--   bisect        bool    Set rwda.config.runelore.bisect_enabled on apply.
--   notes         string  Practical tooltip.
--   ink_cost      table   Pre-computed total ink requirements.
-- ─────────────────────────────────────────────────────────────────────────────

rune_configs.presets = {}

-- ── Weapon presets (Pithakhan core) ──────────────────────────────────────────

rune_configs.presets["kena_lock"] = {
  name         = "kena_lock",
  description  = "Pithakhan mana drain → Kena impatience → Sleizak nausea → Inguz cracked ribs",
  profile_hint = "kena_lock",
  goal_hint    = "impale_kill",
  core_rune    = "pithakhan",
  config_runes = { "kena", "sleizak", "inguz" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  notes        = "Primary lock path. Wield in LEFT hand. Use head_focus_dsl profile for guaranteed Pithakhan proc.",
  ink_cost     = { red = 4, purple = 3 },
}

rune_configs.presets["sleep_lock"] = {
  name         = "sleep_lock",
  description  = "Pithakhan mana drain → Fehu sleep → Kena impatience → Inguz cracked ribs",
  profile_hint = "kena_lock",
  goal_hint    = "impale_kill",
  core_rune    = "pithakhan",
  config_runes = { "fehu", "kena", "inguz" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  notes        = "Fehu attuning before kena opens a sleep window while victim is locked.",
  ink_cost     = { red = 4, purple = 3 },
}

rune_configs.presets["mana_crush"] = {
  name         = "mana_crush",
  description  = "Pithakhan mana drain → Kena impatience → Mannaz mana regen block → Fehu sleep",
  profile_hint = "kena_lock",
  goal_hint    = "pressure",
  core_rune    = "pithakhan",
  config_runes = { "kena", "mannaz", "fehu" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  notes        = "Extended mana denial path. Mannaz fires when target goes off focus balance after impatience.",
  ink_cost     = { red = 4, purple = 3 },
}

rune_configs.presets["fracture_drain"] = {
  name         = "fracture_drain",
  description  = "Pithakhan mana drain → Sowulu healthleech+fracture relapse → Kena impatience → Inguz cracked ribs",
  profile_hint = "kena_lock",
  goal_hint    = "impale_kill",
  core_rune    = "pithakhan",
  config_runes = { "sowulu", "kena", "inguz" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  notes        = "Best vs targets running restoration. Sowulu attunes on any damaged limb.",
  ink_cost     = { red = 4, purple = 3 },
}

rune_configs.presets["ribs_burst"] = {
  name         = "ribs_burst",
  description  = "Pithakhan mana drain → Inguz cracked ribs stacks → Wunjo rib-burst damage → Kena impatience",
  profile_hint = "kena_lock",
  goal_hint    = "impale_kill",
  core_rune    = "pithakhan",
  config_runes = { "inguz", "wunjo", "kena" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  notes        = "Stack cracked ribs via paralysis, then burst with Wunjo. Kena as safety lock finisher.",
  ink_cost     = { red = 4, purple = 3 },
}

-- ── Weapon presets (Hugalaz core — enables BISECT) ────────────────────────────

rune_configs.presets["arm_break"] = {
  name         = "arm_break",
  description  = "Hugalaz hail → Tiwaz break both arms → Kena impatience → Inguz cracked ribs",
  profile_hint = "kena_lock",
  goal_hint    = "impale_kill",
  core_rune    = "hugalaz",
  config_runes = { "tiwaz", "kena", "inguz" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  notes        = "Tiwaz fires when target is off salve bal and no limbs need restore — breaks both arms, enables impale window.",
  ink_cost     = { red = 4, blue = 2, purple = 3 },
}

rune_configs.presets["bisect_finish"] = {
  name         = "bisect_finish",
  description  = "Hugalaz hail → Kena impatience → Inguz cracked ribs → BISECT at ≤20% health",
  profile_hint = "kena_lock",
  goal_hint    = "impale_kill",
  core_rune    = "hugalaz",
  config_runes = { "kena", "inguz", "sleizak" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  bisect       = true,
  notes        = "Standard hugalaz lock path with instant-kill BISECT; rwda runelore bisect on is auto-applied.",
  ink_cost     = { red = 4, blue = 2, purple = 3 },
}

-- ── Weapon presets (Eihwaz core — venom masking) ─────────────────────────────

rune_configs.presets["epilepsy_sleep"] = {
  name         = "epilepsy_sleep",
  description  = "Eihwaz venom masking → Isaz epilepsy → Fehu sleep → Kena impatience",
  profile_hint = "head_focus",
  goal_hint    = "pressure",
  core_rune    = "eihwaz",
  config_runes = { "isaz", "fehu", "kena" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  notes        = "Isaz delivers epilepsy when engage prevents escape. Eihwaz masks venoms to complicate curing.",
  ink_cost     = { red = 4, blue = 3, yellow = 1, purple = 3 },
}

-- ── Weapon presets (Nairat core — freeze proc) ───────────────────────────────

rune_configs.presets["voyria_pressure"] = {
  name         = "voyria_pressure",
  description  = "Nairat random freeze → Sleizak nausea/voyria → Fehu sleep → Kena impatience",
  profile_hint = "head_focus",
  goal_hint    = "pressure",
  core_rune    = "nairat",
  config_runes = { "sleizak", "fehu", "kena" },
  weapon_runes = { "lagul", "lagua", "laguz" },
  notes        = "Group/skirmish pressure. Freeze proc from Nairat stacks on top of affliction cascade.",
  ink_cost     = { red = 4, blue = 1, yellow = 1, purple = 3 },
}

-- ── Armour preset ─────────────────────────────────────────────────────────────

rune_configs.presets["runicarmour"] = {
  name         = "runicarmour",
  description  = "Standard runicarmour: Gebu (blunt) + Gebo (cutting) dual physical resist, 100 months",
  profile_hint = nil,
  goal_hint    = nil,
  core_rune    = nil,
  config_runes = {},
  weapon_runes = {},
  armour       = true,
  notes        = "Binds the armour to you. Costs 2000 mana and 2 Gold Ink. Cannot be traded after empowerment.",
  ink_cost     = { gold = 2 },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper functions
-- ─────────────────────────────────────────────────────────────────────────────

--- Return a preset by name, or nil.
function rune_configs.get(name)
  return rune_configs.presets[tostring(name or ""):lower()]
end

--- Return sorted array of all preset names.
function rune_configs.list()
  local names = {}
  for k in pairs(rune_configs.presets) do
    names[#names + 1] = k
  end
  table.sort(names)
  return names
end

--- Return the ink cost table for a named preset.
function rune_configs.inkCost(name)
  local p = rune_configs.get(name)
  if not p then return nil end
  -- Deep copy so callers cannot mutate the preset.
  local out = {}
  for colour, qty in pairs(p.ink_cost or {}) do
    out[colour] = qty
  end
  return out
end

--- Return all presets whose goal_hint matches the given goal string.
function rune_configs.forGoal(goal)
  local out = {}
  for _, p in pairs(rune_configs.presets) do
    if p.goal_hint == goal then
      out[#out + 1] = p
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

--- Return the full ordered sketch sequence for a weapon preset:
--- lagul, lagua, laguz, then the core rune (if any).
function rune_configs.allWeaponRunes(name)
  local p = rune_configs.get(name)
  if not p or p.armour then return {} end
  local out = {}
  for _, r in ipairs(p.weapon_runes or { "lagul", "lagua", "laguz" }) do
    out[#out + 1] = r
  end
  if p.core_rune then
    out[#out + 1] = p.core_rune
  end
  return out
end

--- Format ink cost as a human-readable string (e.g. "3P 4R 1B").
local COLOUR_SHORT = { red = "R", blue = "B", yellow = "Y", purple = "P", gold = "G", green = "Gr" }
function rune_configs.inkCostString(name)
  local cost = rune_configs.inkCost(name)
  if not cost then return "?" end
  local parts = {}
  -- Deterministic order
  for _, colour in ipairs({ "purple", "red", "blue", "yellow", "gold", "green" }) do
    if (cost[colour] or 0) > 0 then
      parts[#parts + 1] = tostring(cost[colour]) .. (COLOUR_SHORT[colour] or colour)
    end
  end
  if #parts == 0 then return "none" end
  return table.concat(parts, " ")
end
