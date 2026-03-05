-- Silverfury/data/afflictions.lua
-- Affliction → cure mapping. Data only — no logic, no side effects.
-- Source: Afflictions.txt (full Achaea table).
--
-- AFFS key format: lowercase, underscores for spaces.
-- cure_item: the lowest-level named cure (herb/salve/smoke name, lowercase).
-- cure_channel: "herb" | "salve" | "smoke" | "sip" | "writhe" | "clot" | "compose"

Silverfury = Silverfury or {}
Silverfury.data = Silverfury.data or {}

local affs_mod = {}
Silverfury.data.afflictions = affs_mod

-- ── AFFS table ────────────────────────────────────────────────────────────────
-- aff_name -> { display, cure_item, cure_channel, alt_cure_item, alt_cure_channel }
-- alt_* only present when a secondary cure exists (e.g. slickness).

affs_mod.AFFS = {
  -- ── Kelp-cured (herb) ─────────────────────────────────────────────────────
  asthma         = { display="Asthma",       cure_item="kelp",       cure_channel="herb" },
  clumsiness     = { display="Clumsiness",   cure_item="kelp",       cure_channel="herb" },
  health_leech   = { display="Health Leech", cure_item="kelp",       cure_channel="herb" },
  hypochondria   = { display="Hypochondria", cure_item="kelp",       cure_channel="herb" },
  sensitivity    = { display="Sensitivity",  cure_item="kelp",       cure_channel="herb" },
  weariness      = { display="Weariness",    cure_item="kelp",       cure_channel="herb" },

  -- ── Bloodroot-cured (herb) ────────────────────────────────────────────────
  paralysis      = { display="Paralysis",    cure_item="bloodroot",  cure_channel="herb" },
  -- slickness: primary smoke/valerian; also bloodroot (herb)
  slickness      = { display="Slickness",    cure_item="valerian",   cure_channel="smoke",
                     alt_cure_item="bloodroot", alt_cure_channel="herb" },

  -- ── Goldenseal-cured (herb) ───────────────────────────────────────────────
  dissonance     = { display="Dissonance",   cure_item="goldenseal", cure_channel="herb" },
  dizziness      = { display="Dizziness",    cure_item="goldenseal", cure_channel="herb" },
  epilepsy       = { display="Epilepsy",     cure_item="goldenseal", cure_channel="herb" },
  impatience     = { display="Impatience",   cure_item="goldenseal", cure_channel="herb" },
  shyness        = { display="Shyness",      cure_item="goldenseal", cure_channel="herb" },
  stupidity      = { display="Stupidity",    cure_item="goldenseal", cure_channel="herb" },

  -- ── Ginseng-cured (herb) ──────────────────────────────────────────────────
  addiction      = { display="Addiction",    cure_item="ginseng",    cure_channel="herb" },
  darkshade      = { display="Darkshade",    cure_item="ginseng",    cure_channel="herb" },
  haemophilia    = { display="Haemophilia",  cure_item="ginseng",    cure_channel="herb" },
  lethargy       = { display="Lethargy",     cure_item="ginseng",    cure_channel="herb" },
  nausea         = { display="Nausea",       cure_item="ginseng",    cure_channel="herb" },
  scytherus      = { display="Scytherus",    cure_item="ginseng",    cure_channel="herb" },

  -- ── Epidermal-cured (salve) ───────────────────────────────────────────────
  anorexia       = { display="Anorexia",     cure_item="epidermal",  cure_channel="salve" },
  blindness      = { display="Blindness",    cure_item="epidermal",  cure_channel="salve" },
  deafness       = { display="Deafness",     cure_item="epidermal",  cure_channel="salve" },
  stuttering     = { display="Stuttering",   cure_item="epidermal",  cure_channel="salve" },

  -- ── Mending-cured (salve) ────────────────────────────────────────────────
  ablaze         = { display="Ablaze",        cure_item="mending",   cure_channel="salve" },
  crippled_limb  = { display="Crippled limb", cure_item="mending",   cure_channel="salve" },

  -- ── Restoration-cured (salve) ────────────────────────────────────────────
  concussion     = { display="Concussion",       cure_item="restoration", cure_channel="salve" },
  damaged_limb   = { display="Damaged limb",     cure_item="restoration", cure_channel="salve" },
  internal_trauma= { display="Internal Trauma",  cure_item="restoration", cure_channel="salve" },
  mangled_limb   = { display="Mangled limb",     cure_item="restoration", cure_channel="salve" },

  -- ── Caloric-cured (salve) ────────────────────────────────────────────────
  freezing       = { display="Freezing",     cure_item="caloric",    cure_channel="salve" },

  -- ── Lobelia-cured (herb) ─────────────────────────────────────────────────
  agoraphobia    = { display="Agoraphobia",  cure_item="lobelia",    cure_channel="herb" },
  claustrophobia = { display="Claustrophobia",cure_item="lobelia",   cure_channel="herb" },
  loneliness     = { display="Loneliness",   cure_item="lobelia",    cure_channel="herb" },
  masochism      = { display="Masochism",    cure_item="lobelia",    cure_channel="herb" },
  recklessness   = { display="Recklessness", cure_item="lobelia",    cure_channel="herb" },
  vertigo        = { display="Vertigo",      cure_item="lobelia",    cure_channel="herb" },

  -- ── Bellwort-cured (herb) ────────────────────────────────────────────────
  generosity     = { display="Generosity",     cure_item="bellwort", cure_channel="herb" },
  indifference   = { display="Indifference",   cure_item="bellwort", cure_channel="herb" },
  justice        = { display="Justice",        cure_item="bellwort", cure_channel="herb" },
  lovers_effect  = { display="Lover's Effect", cure_item="bellwort", cure_channel="herb" },
  pacifism       = { display="Pacifism",       cure_item="bellwort", cure_channel="herb" },
  peace          = { display="Peace",          cure_item="bellwort", cure_channel="herb" },

  -- ── Prickly ash-cured (herb) ─────────────────────────────────────────────
  confusion      = { display="Confusion",       cure_item="prickly_ash", cure_channel="herb" },
  dementia       = { display="Dementia",        cure_item="prickly_ash", cure_channel="herb" },
  hallucinations = { display="Hallucinations",  cure_item="prickly_ash", cure_channel="herb" },
  hypersomnia    = { display="Hypersomnia",     cure_item="prickly_ash", cure_channel="herb" },
  paranoia       = { display="Paranoia",        cure_item="prickly_ash", cure_channel="herb" },

  -- ── Valerian smoke-cured ─────────────────────────────────────────────────
  disfigurement  = { display="Disfigurement", cure_item="valerian", cure_channel="smoke" },
  hellsight      = { display="Hellsight",     cure_item="valerian", cure_channel="smoke" },
  mana_leech     = { display="Mana Leech",    cure_item="valerian", cure_channel="smoke" },

  -- ── Elm smoke-cured ──────────────────────────────────────────────────────
  aeon           = { display="Aeon",     cure_item="elm", cure_channel="smoke" },
  deadening      = { display="Deadening",cure_item="elm", cure_channel="smoke" },

  -- ── Miscellaneous ────────────────────────────────────────────────────────
  drowning       = { display="Drowning",          cure_item="pear",    cure_channel="herb" },
  tempered_humours={ display="Tempered Humours",   cure_item="ginger",  cure_channel="herb" },
  voyria         = { display="Voyria",             cure_item="immunity",cure_channel="sip" },

  -- ── Non-item cures ────────────────────────────────────────────────────────
  bleeding       = { display="Bleeding",   cure_item=nil, cure_channel="clot" },
  entangled      = { display="Entangled",  cure_item=nil, cure_channel="writhe" },
  fear           = { display="Fear",       cure_item=nil, cure_channel="compose" },
  transfixed     = { display="Transfixed", cure_item=nil, cure_channel="writhe" },
  webbed         = { display="Webbed",     cure_item=nil, cure_channel="writhe" },
}

-- ── CURE_BUCKETS ──────────────────────────────────────────────────────────────
-- Inverted mapping: cure_item -> { aff_name = true, ... }
-- Built automatically from AFFS so there's one source of truth.
-- Slickness appears in BOTH valerian and bloodroot buckets.

affs_mod.CURE_BUCKETS = {}

for aff_name, data in pairs(affs_mod.AFFS) do
  if data.cure_item then
    local b = affs_mod.CURE_BUCKETS[data.cure_item]
    if not b then
      b = {}
      affs_mod.CURE_BUCKETS[data.cure_item] = b
    end
    b[aff_name] = true
  end
  -- Secondary cure (e.g. slickness via bloodroot)
  if data.alt_cure_item then
    local b2 = affs_mod.CURE_BUCKETS[data.alt_cure_item]
    if not b2 then
      b2 = {}
      affs_mod.CURE_BUCKETS[data.alt_cure_item] = b2
    end
    b2[aff_name] = true
  end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Returns the set (table keyed by aff name) for a given cure item, or nil.
function affs_mod.getCureBucket(cure_item)
  return affs_mod.CURE_BUCKETS[cure_item]
end

-- Choose which aff to remove when the target uses cure_item.
-- strategy:
--   "lifo"     — remove the most recently seen aff (default).
--   "priority" — pass a priority list; remove first match found on target.
-- Returns aff_name or nil.
function affs_mod.chooseAffToClear(target, cure_item, strategy, priority_list)
  local bucket = affs_mod.CURE_BUCKETS[cure_item]
  if not bucket then return nil end
  strategy = strategy or "lifo"

  if strategy == "priority" and priority_list then
    for _, aff_name in ipairs(priority_list) do
      if bucket[aff_name] and target.hasAff(aff_name) then
        return aff_name
      end
    end
    return nil
  end

  -- LIFO: most recently tracked aff in this bucket.
  local best_name = nil
  local best_time = 0
  for aff_name in pairs(bucket) do
    local entry = target.affs and target.affs[aff_name]
    if entry and (entry.confidence or 0) > 0.3 then
      if (entry.last_seen or 0) > best_time then
        best_time = entry.last_seen
        best_name = aff_name
      end
    end
  end
  return best_name
end

-- How many affs in the given cure bucket does the target currently have?
function affs_mod.countBucket(target, cure_item)
  local bucket = affs_mod.CURE_BUCKETS[cure_item]
  if not bucket then return 0 end
  local n = 0
  for aff_name in pairs(bucket) do
    if target.hasAff(aff_name) then n = n + 1 end
  end
  return n
end
