-- Silverfury/dragon/matchups.lua
-- Per-class counterstrategy table for Silver Dragon PvP.
-- All entries are Silver-legal (lightning breath default).
-- Illegal actions for Silver (acid/ice/psi/dragonfire) are NOT listed.
-- Generic multi-dragon guide advice is annotated but excluded from planner logic.

Silverfury        = Silverfury or {}
Silverfury.dragon = Silverfury.dragon or {}

local matchups = {}
Silverfury.dragon.matchups = matchups

-- ── Matchup data ──────────────────────────────────────────────────────────────
-- Fields:
--   breath            string   override breath type (always "lightning" for Silver)
--   abort_in_grove    boolean  leave room immediately if target is Sylvan/Druid in grove
--   say_trigger_words boolean  say common hypnosis trigger words immediately
--   use_breathstorm   boolean  prioritize breathstorm to reveal/disrupt
--   high_threat       boolean  adversary requires extra-cautious play
--   notes             string   human-readable strategy notes (not used by planner)

local DATA = {
  Serpent = {
    breath            = "lightning",
    say_trigger_words = true,
    use_breathstorm   = true,
    high_threat       = true,
    notes = "Sileris mandatory. Breathstorm to reveal from stealth. "
         .. "Say trigger words immediately: yes/no/ok/hi/hello/your name.",
  },
  Sylvan = {
    breath         = "lightning",
    abort_in_grove = true,
    high_threat    = true,
    notes = "NEVER fight in Grove — leave immediately. Caloric salve mandatory "
         .. "against Weatherweaving storms.",
  },
  Druid = {
    breath         = "lightning",
    abort_in_grove = true,
    notes = "Leave Grove environment immediately. Standard kill path elsewhere.",
  },
  Apostate = {
    breath      = "lightning",
    high_threat = true,
    notes = "Cure their stack, Breathstorm the summoned Daemon. "
         .. "Apply pressure to disrupt Vivisect setup.",
  },
  Blademaster = {
    breath      = "lightning",
    high_threat = true,
    notes = "Keep Restoration/Mending ready. Tailsweep to disrupt balance rhythm. "
         .. "Fast balance recovery is dangerous.",
  },
  Depthswalker = {
    breath      = "lightning",
    high_threat = true,
    notes = "Prioritize curing Aeon (Elm/Cinnabar smoke) immediately. "
         .. "Aggressive pressure to prevent Terminus setup.",
  },
  Jester = {
    breath = "lightning",
    notes  = "Dragonflex immediately on puppet strings. Standard kill path otherwise.",
  },
  Bard = {
    breath = "lightning",
    notes  = "Block to prevent kiting. Tailsweep to interrupt Bladedance combos.",
  },
  Shaman = {
    breath      = "lightning",
    high_threat = true,
    notes = "Close the gap fast. Attacking directly breaks Vodun doll concentration. "
         .. "Maintain pressure.",
  },
  Monk = {
    breath = "lightning",
    notes  = "Standard kill path. Monitor Kai energy pressure.",
  },
  Runewarden = {
    breath = "lightning",
    notes  = "Avoid ground-sketched runes. Maintain movement before engaging.",
  },
  Magi = {
    breath          = "lightning",
    use_breathstorm = true,
    notes = "Breathstorm to shatter crystalline room utility.",
  },
  Alchemist = {
    breath = "lightning",
    notes  = "Monitor own fluid levels (Ginger/Antimony) to prevent organ failure.",
  },
  Infernal = {
    breath = "lightning",
    notes  = "Standard kill path.",
  },
  Sentinel = {
    breath          = "lightning",
    use_breathstorm = true,
    notes = "Block at all times — high mobility. Breathstorm to clear summoned creatures.",
  },
  Unnamable = {
    breath = "lightning",
    notes  = "Standard Block + Tailsweep pinning approach.",
  },
}

-- ── Public API ────────────────────────────────────────────────────────────────

-- Case-insensitive lookup.
function matchups.get(class_name)
  if not class_name then return nil end
  for k, v in pairs(DATA) do
    if k:lower() == class_name:lower() then return v end
  end
  return nil
end

function matchups.shouldAbortInGrove(class_name)
  local m = matchups.get(class_name)
  return m ~= nil and m.abort_in_grove == true
end

function matchups.shouldSayTriggerWords(class_name)
  local m = matchups.get(class_name)
  return m ~= nil and m.say_trigger_words == true
end

function matchups.shouldBreathstorm(class_name)
  local m = matchups.get(class_name)
  return m ~= nil and m.use_breathstorm == true
end

-- Returns the appropriate breath type for this class.
-- Silver Dragon always defaults to lightning; matchup entries may override.
function matchups.breath(class_name)
  local m    = matchups.get(class_name)
  local over = m and m.breath
  return over or Silverfury.config.get("dragon.breath_type") or "lightning"
end

-- Returns the strategy notes string for display.
function matchups.notes(class_name)
  local m = matchups.get(class_name)
  return m and m.notes or "No specific Silver Dragon guidance — standard Devour path."
end
