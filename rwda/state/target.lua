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
    class = nil,
    dead = false,
    prone = false,
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
    last_seen = 0,
    last_action_ms = 0,
  }
end
