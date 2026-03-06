-- Silverfury/state/target.lua
-- Target state: limbs, affs, defences — with confidence tracking.

Silverfury = Silverfury or {}
Silverfury.state = Silverfury.state or {}

local NOW = function() return Silverfury.time.now() end

-- Confidence decays to 0 over this many ms without re-confirmation.
local DECAY_MS = 30000

-- ── Limb factory ─────────────────────────────────────────────────────────────

local function newLimb()
  return {
    damage_pct = 0,
    broken     = false,
    mangled    = false,
    confidence = 0,     -- 0–1
    last_seen  = 0,
  }
end

-- ── Aff tracker entry ────────────────────────────────────────────────────────
-- confirmed = true → we observed the application
-- assumed   = true → inferred from context
-- confidence = 0–1
-- last_seen  = epoch_ms of last observation

local function newAff(confirmed)
  return {
    confirmed  = confirmed or false,
    assumed    = not (confirmed or false),
    confidence = confirmed and 1.0 or 0.5,
    last_seen  = NOW(),
  }
end

-- ── Target table ─────────────────────────────────────────────────────────────

local function newTarget()
  return {
    name      = nil,
    in_room   = false,
    dead      = false,
    prone     = false,
    flying    = false,
    lyred     = false,
    impaled   = false,
    hp_pct         = nil,    -- 0.0-1.0 when known from parser, nil = unknown
    mana_pct       = nil,    -- 0.0-1.0 when known, nil = unknown

    -- Dragon-specific target state
    class          = nil,    -- detected class name string
    can_fly        = nil,    -- true/false/nil when unknown
    enmeshed       = false,  -- ethereal tendrils bound
    last_escape_dir = nil,   -- last direction target fled
    devour_estimate = nil,   -- most recent devour.estimate() result
    balance_hindered = false,
    eq_hindered      = false,

    -- Affs tracked: key = aff_name, val = newAff record
    affs = {},
    -- Defences: key = def_name, val = { active, last_seen, confidence }
    defs = {
      shield     = { active=false, last_seen=0, confidence=0 },
      rebounding = { active=false, last_seen=0, confidence=0 },
    },
    -- Limbs
    limbs = {
      head      = newLimb(),
      torso     = newLimb(),
      left_arm  = newLimb(),
      right_arm = newLimb(),
      left_leg  = newLimb(),
      right_leg = newLimb(),
    },
  }
end

Silverfury.state.target = newTarget()

-- ── Public API ────────────────────────────────────────────────────────────────

local tgt = Silverfury.state.target

function tgt.setName(name)
  local t = Silverfury.state.target
  if t.name == name then return end
  -- Reset state for new target but keep the table reference.
  local fresh = newTarget()
  fresh.name = name
  for k, v in pairs(fresh) do t[k] = v end
  Silverfury.log.info("Target set to: %s", tostring(name))
  raiseEvent("SF_TargetChanged", name)
end

function tgt.clear()
  local t = Silverfury.state.target
  local fresh = newTarget()
  for k, v in pairs(fresh) do t[k] = v end
  raiseEvent("SF_TargetChanged", nil)
end

function tgt.addAff(name, confirmed)
  local t = Silverfury.state.target
  if t.affs[name] then
    t.affs[name].last_seen  = NOW()
    t.affs[name].confidence = confirmed and 1.0 or math.max(t.affs[name].confidence, 0.6)
    if confirmed then t.affs[name].confirmed = true end
  else
    t.affs[name] = newAff(confirmed)
  end
end

function tgt.removeAff(name)
  Silverfury.state.target.affs[name] = nil
end

function tgt.hasAff(name)
  local a = Silverfury.state.target.affs[name]
  return a and a.confidence > 0.3
end

function tgt.setDef(name, active)
  local t = Silverfury.state.target
  local d = t.defs[name]
  if d then
    d.active     = active
    d.last_seen  = active and NOW() or d.last_seen
    d.confidence = active and 1.0 or 0
  else
    t.defs[name] = { active=active, last_seen=NOW(), confidence=active and 1.0 or 0 }
  end
end

function tgt.hasDef(name)
  local d = Silverfury.state.target.defs[name]
  return d and d.active and d.confidence > 0.4
end

function tgt.updateLimb(limb_name, damage_pct, broken, mangled)
  local t  = Silverfury.state.target
  local lb = t.limbs[limb_name]
  if not lb then return end
  lb.damage_pct = damage_pct or lb.damage_pct
  if broken  ~= nil then lb.broken  = broken  end
  if mangled ~= nil then lb.mangled = mangled end
  lb.confidence = 1.0
  lb.last_seen  = NOW()
end

-- Decay defence confidence over time.
function tgt.decayDefs()
  local t   = Silverfury.state.target
  local now = NOW()
  for _, d in pairs(t.defs) do
    if d.active and d.last_seen > 0 then
      local age = now - d.last_seen
      d.confidence = math.max(0, 1 - (age / DECAY_MS))
      if d.confidence <= 0 then
        d.active = false
      end
    end
  end
end

function tgt.reset()
  local t     = Silverfury.state.target
  local name  = t.name
  local fresh = newTarget()
  fresh.name  = name
  for k, v in pairs(fresh) do t[k] = v end
end

function tgt.isAvailable()
  local t = Silverfury.state.target
  return t.name ~= nil and t.in_room and not t.dead
end
