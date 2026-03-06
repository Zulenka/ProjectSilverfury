-- Silverfury/dragon/devour.lua
-- Devour timing estimator.
--
-- Stage 1: heuristic weights derived from the guide's 6-second rule and the
-- confirmed priority of torso breaks. Start conservative; tune from fight logs.
-- Stage 2: calibrate weights from logged outcomes (devour_estimate vs result).

Silverfury        = Silverfury or {}
Silverfury.dragon = Silverfury.dragon or {}

local devour = {}
Silverfury.dragon.devour = devour

-- ── Constants ─────────────────────────────────────────────────────────────────

-- Baseline Devour time (seconds) with no limb damage. Conservative estimate.
local BASE_SECONDS = 10.0

-- Reduction weights (seconds) per state.
-- Torso break = largest single reduction per guide.
-- Other broken limbs = meaningful but smaller.
-- Damaged (>=50%, not broken) = minor contribution.
local W = {
  torso_broken   = 3.5,
  torso_damaged  = 1.5,   -- 50%+ but not broken
  head_broken    = 0.7,
  leg_broken     = 0.8,   -- per leg
  arm_broken     = 0.5,   -- per arm
  leg_damaged    = 0.3,   -- per leg, 50%+ not broken
  arm_damaged    = 0.2,   -- per arm, 50%+ not broken
  target_prone   = 0.2,   -- small bonus when prone during devour windup
}

-- Damage threshold for "damaged but not broken" credit.
local DAMAGED_PCT_THRESHOLD = 50

-- ── Public API ────────────────────────────────────────────────────────────────

-- Returns:
--   {
--     total_seconds  number   — estimated completion time
--     safe           boolean  — total < configured threshold
--     threshold      number   — safe threshold in seconds
--     reason         string   — human-readable summary
--     breakdown      table    — list of strings showing each reduction
--   }
function devour.estimate()
  local tgt       = Silverfury.state.target
  local limbs     = tgt.limbs or {}
  local breakdown = {}
  local reduction = 0

  local function addw(label, w)
    reduction          = reduction + w
    breakdown[#breakdown+1] = string.format("%s: -%.1fs", label, w)
  end

  local function lstate(name)
    local l = limbs[name]
    if not l then return nil end
    return { broken = l.broken or false, pct = l.damage_pct or 0 }
  end

  -- Torso (highest value limb)
  local torso = lstate("torso")
  if torso then
    if torso.broken then
      addw("torso broken", W.torso_broken)
    elseif torso.pct >= DAMAGED_PCT_THRESHOLD then
      addw(string.format("torso %d%%", torso.pct), W.torso_damaged)
    end
  end

  -- Head
  local head = lstate("head")
  if head and head.broken then
    addw("head broken", W.head_broken)
  end

  -- Legs
  for _, lname in ipairs({ "left_leg", "right_leg" }) do
    local l = lstate(lname)
    if l then
      if l.broken then
        addw(lname .. " broken", W.leg_broken)
      elseif l.pct >= DAMAGED_PCT_THRESHOLD then
        addw(string.format("%s %d%%", lname, l.pct), W.leg_damaged)
      end
    end
  end

  -- Arms
  for _, lname in ipairs({ "left_arm", "right_arm" }) do
    local l = lstate(lname)
    if l then
      if l.broken then
        addw(lname .. " broken", W.arm_broken)
      elseif l.pct >= DAMAGED_PCT_THRESHOLD then
        addw(string.format("%s %d%%", lname, l.pct), W.arm_damaged)
      end
    end
  end

  -- Prone bonus
  if tgt.prone then
    addw("target prone", W.target_prone)
  end

  local total     = math.max(BASE_SECONDS - reduction, 0.5)
  local threshold = Silverfury.config.get("dragon.devour_safe_threshold") or 5.7
  local safe      = total < threshold

  local reason
  if safe then
    reason = string.format("%.1fs — SAFE (< %.1fs)", total, threshold)
  else
    reason = string.format("%.1fs — NOT SAFE (>= %.1fs)", total, threshold)
  end

  return {
    total_seconds = total,
    safe          = safe,
    threshold     = threshold,
    reason        = reason,
    breakdown     = breakdown,
  }
end

-- Log a Devour attempt result for future calibration.
-- Call this from the incoming parser when Devour succeeds or is interrupted.
function devour.logOutcome(success, elapsed_s)
  local est = devour.estimate()
  Silverfury.logging.logger.write("DEVOUR_OUTCOME", {
    estimated_s = est.total_seconds,
    actual_s    = elapsed_s,
    success     = success,
    breakdown   = est.breakdown,
  })
  Silverfury.log.info("Devour outcome: %s  estimated=%.1fs  actual=%s",
    success and "SUCCESS" or "INTERRUPTED",
    est.total_seconds,
    elapsed_s and string.format("%.1fs", elapsed_s) or "unknown")
end
