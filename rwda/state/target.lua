rwda = rwda or {}
rwda.statebuilders = rwda.statebuilders or {}

local builders = rwda.statebuilders

local function newLimb()
  return {
    damage_pct = 0,
    broken = false,
    mangled = false,
    state = "ok",
    confidence = 0,
    last_updated = 0,
  }
end

local function newTargetDef()
  return {
    active = false,
    confidence = 0,
    source = "unknown",
    last_seen = 0,
  }
end

function builders.newTarget()
  return {
    name = nil,
    target_source = "unknown",
    class = nil,
    dead = false,
    available = true,
    unavailable_reason = nil,
    unavailable_since = 0,
    prone = false,
    flying = false,
    lyred = false,
    impaled = false,
    blocked_exit = nil,
    affs = {},
    defs = {
      shield = newTargetDef(),
      rebounding = newTargetDef(),
    },
    limbs = {
      head = newLimb(),
      torso = newLimb(),
      left_arm = newLimb(),
      right_arm = newLimb(),
      left_leg = newLimb(),
      right_leg = newLimb(),
    },
    stance = {
      standing = true,
    },
    available_source = "unknown",
    last_seen = 0,
    last_action_ms = 0,
    last_assess = 0,
  }
end
