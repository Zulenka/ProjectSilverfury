rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.runelore = rwda.engine.runelore or {}

local runelore = rwda.engine.runelore

-- ─────────────────────────────────────────────
-- Constants (Dec 2025 classleads)
-- ─────────────────────────────────────────────

local KENA_MANA_THRESHOLD          = 0.40   -- <40% mana triggers Kena
local PITH_DRAIN_NORMAL            = 0.10   -- 10% mana drain baseline
local PITH_DRAIN_BROKEN_HEAD       = 0.13   -- 13% on broken head (Dec 2025)
local EMPOWER_AFTER_ATTACK_DELAY_MS = 100   -- Send empower after tick resolves

-- ─────────────────────────────────────────────
-- Internal config (mutable via commands)
-- ─────────────────────────────────────────────

local cfg = {
  auto_empower      = true,
  empower_on_attune = true,
}

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function target()
  return rwda.state and rwda.state.target
end

local function runebladeState()
  return rwda.state and rwda.state.runeblade
end

local function limbState(limbName)
  local t = target()
  return t and t.limbs and t.limbs[limbName]
end

local function targetHasAff(affName)
  local t = target()
  if not t or not t.affs then return false end
  local a = t.affs[affName]
  return a ~= nil and (a == true or (type(a) == "table" and a.active))
end

local function targetHasDef(defName)
  local t = target()
  if not t or not t.defs then return false end
  local d = t.defs[defName]
  return d ~= nil and d.active
end

local function targetManaPercent()
  local t = target()
  if not t then return 1.0 end
  -- Check GMCP fields if available
  if t.mp and t.maxmp and t.maxmp > 0 then
    return t.mp / t.maxmp
  end
  -- Fall back to a tracked field set by parser
  if type(t.mana_percent) == "number" then
    return t.mana_percent
  end
  return 1.0
end

-- ─────────────────────────────────────────────
-- Attunement Condition Checks
-- ─────────────────────────────────────────────

local ATTUNE = nil   -- Lazy-load from runes.ATTUNE

local function attune()
  if not ATTUNE then
    ATTUNE = rwda.data and rwda.data.runes and rwda.data.runes.ATTUNE
  end
  return ATTUNE
end

function runelore.checkAttuneCondition(condition)
  local A = attune()
  if not A then return false end

  if condition == A.MANA_BELOW_40 then
    return targetManaPercent() < KENA_MANA_THRESHOLD

  elseif condition == A.TARGET_PARALYSED then
    return targetHasAff("paralysis")

  elseif condition == A.TARGET_SHIVERING then
    return targetHasAff("shivering")

  elseif condition == A.LIMB_DAMAGED then
    return runelore.targetHasDamagedLimb()

  elseif condition == A.PRONE_OR_NO_INSOMNIA then
    local t = target()
    local prone = t and t.prone
    local noInsomnia = not targetHasDef("insomnia")
    return prone or noInsomnia

  elseif condition == A.OFF_FOCUS_BALANCE then
    local t = target()
    return t and t.balances and t.balances.focus == false

  elseif condition == A.TARGET_ADDICTED then
    return targetHasAff("addiction")

  elseif condition == A.TARGET_WEARY_LETHARGIC then
    return targetHasAff("weariness") or targetHasAff("lethargy")

  elseif condition == A.OFF_SALVE_NO_RESTORE then
    local t = target()
    local offSalve = t and t.balances and t.balances.salve == false
    return offSalve and not runelore.targetHasDamagedLimb()
  end

  return false
end

-- ─────────────────────────────────────────────
-- Head / Pithakhan Intelligence
-- ─────────────────────────────────────────────

function runelore.targetHasDamagedLimb()
  local heads = { "head", "torso", "left_arm", "right_arm", "left_leg", "right_leg" }
  for _, limb in ipairs(heads) do
    local l = limbState(limb)
    if l and (l.damaged or l.broken or l.mangled or (l.damage_pct and l.damage_pct >= 30)) then
      return true
    end
  end
  return false
end

function runelore.isPithakhanReliable()
  local head = limbState("head")
  return head ~= nil and (head.damaged or head.broken or head.mangled or (head.damage_pct and head.damage_pct >= 30))
end

function runelore.isPithakhanMaxDrain()
  local head = limbState("head")
  return head ~= nil and head.broken
end

function runelore.estimatePithakhanDrain()
  if runelore.isPithakhanMaxDrain() then
    return PITH_DRAIN_BROKEN_HEAD
  elseif runelore.isPithakhanReliable() then
    return PITH_DRAIN_NORMAL
  end
  -- Unreliable proc: rough expected value
  return PITH_DRAIN_NORMAL * 0.3
end

-- Should the strategy focus head right now?
-- Returns: bool, string reason
function runelore.shouldFocusHead()
  if not runelore.isPithakhanReliable() then
    return true, "pith_unreliable"
  end

  local mana = targetManaPercent()
  if mana > KENA_MANA_THRESHOLD and mana < 0.60 then
    if not runelore.isPithakhanMaxDrain() then
      return true, "push_for_kena"
    end
  end

  return false, nil
end

-- ─────────────────────────────────────────────
-- Kena / Lock Path Intelligence
-- ─────────────────────────────────────────────

function runelore.isKenaEligible()
  return targetManaPercent() < KENA_MANA_THRESHOLD
end

function runelore.isHugalazCoreEnabled()
  local rb = runebladeState()
  if not rb or not rb.getConfiguration then return false end
  local cfg = rb.getConfiguration()
  return cfg and cfg.core_rune == "hugalaz"
end

function runelore.getKenaDistance()
  return math.max(0, targetManaPercent() - KENA_MANA_THRESHOLD)
end

-- Returns: nearLock (bool), missingAffs (table)
function runelore.isNearLock()
  local lockAffs = { "asthma", "slickness", "anorexia", "paralysis", "impatience" }
  local count = 0
  local missing = {}
  for _, aff in ipairs(lockAffs) do
    if targetHasAff(aff) then
      count = count + 1
    else
      table.insert(missing, aff)
    end
  end
  return count >= 3, missing
end

-- ─────────────────────────────────────────────
-- Auto-Empower
-- ─────────────────────────────────────────────

function runelore.shouldEmpower()
  if not cfg.auto_empower then return false, nil end
  local rb = runebladeState()
  if not rb then return false, nil end
  local next = rb.getNextEmpowerRune()
  return next ~= nil, next
end

function runelore.onRuneAttuned(runeName)
  if not cfg.empower_on_attune then return end

  local rb = runebladeState()
  if not rb then return end

  local next = rb.getNextEmpowerRune()
  if next == runeName then
    runelore.queueEmpower(runeName)
  end
end

function runelore.queueEmpower(runeName)
  if type(send) ~= "function" and type(sendAll) ~= "function" then return end

  -- Small delay so the attack output has resolved server-side before empower
  if type(tempTimer) == "function" then
    tempTimer(EMPOWER_AFTER_ATTACK_DELAY_MS / 1000, function()
      local cmd = "empower " .. runeName
      if type(send) == "function" then send(cmd) end
    end)
  else
    local cmd = "empower " .. runeName
    if type(send) == "function" then send(cmd) end
  end

  if rwda.util then
    rwda.util.log("combat", "EMPOWER %s queued", runeName:upper())
  end
end

-- ─────────────────────────────────────────────
-- Event Handlers (called from parser)
-- ─────────────────────────────────────────────

function runelore.onRuneAttuned_event(runeName)
  runeName = tostring(runeName):lower()
  local rb = runebladeState()
  if rb then rb.setAttuned(runeName, true) end
  runelore.onRuneAttuned(runeName)
end

function runelore.onRuneAttuneLost_event(runeName)
  runeName = tostring(runeName):lower()
  local rb = runebladeState()
  if rb then rb.setAttuned(runeName, false) end
end

function runelore.onRuneEmpowered_event(runeName)
  runeName = tostring(runeName):lower()
  local rb = runebladeState()
  if rb then rb.consumeEmpower(runeName) end
  if rwda.util then
    rwda.util.log("combat", "EMPOWERED %s confirmed", runeName:upper())
  end
end

function runelore.onConfigActivated_event()
  local rb = runebladeState()
  if rb then rb.activateConfiguration() end
end

function runelore.onPithakhanDrain_event(targetName)
  -- Update estimated mana based on head state
  local t = target()
  if not t then return end

  local drain = runelore.estimatePithakhanDrain()
  if type(t.mana_percent) == "number" then
    t.mana_percent = math.max(0, t.mana_percent - drain)
    t.last_pithakhan_drain = rwda.util and rwda.util.now() or 0
    return
  end

  if type(t.mp) == "number" and type(t.maxmp) == "number" and t.maxmp > 0 then
    local loss = math.floor((drain * t.maxmp) + 0.5)
    t.mp = math.max(0, t.mp - loss)
    t.mana_percent = t.mp / t.maxmp
    t.last_pithakhan_drain = rwda.util and rwda.util.now() or 0
    return
  end

  t.last_pithakhan_drain = rwda.util and rwda.util.now() or 0
end

-- ─────────────────────────────────────────────
-- Configuration commands
-- ─────────────────────────────────────────────

function runelore.setAutoEmpower(enabled)
  cfg.auto_empower = not not enabled
  if rwda.util then
    rwda.util.log("info", "Auto-empower: %s", cfg.auto_empower and "ON" or "OFF")
  end
end

function runelore.setEmpowerOnAttune(enabled)
  cfg.empower_on_attune = not not enabled
end

function runelore.getConfig()
  return cfg
end

-- ─────────────────────────────────────────────
-- Recommended lock config reference
-- ─────────────────────────────────────────────

function runelore.getRecommendedLockConfig()
  return {
    core_rune        = "pithakhan",
    config_runes     = { "kena", "sleizak", "inguz" },
    empower_priority = { "kena", "sleizak", "inguz" },
    notes = {
      "1. Focus HEAD until damaged for reliable Pithakhan procs",
      "2. Apply kelp-cure venoms: kalmia, vernalius, xentio, prefarar",
      "3. Pithakhan drains mana - 13% per tick on a broken head",
      "4. When target mana < 40%, Kena attunes -> EMPOWER for IMPATIENCE",
      "5. Impatience blocks FOCUS -> asthma sticks -> true lock",
      "6. Use BISECT at <=20% health for instant kill",
    },
  }
end

-- ─────────────────────────────────────────────
-- Status summary
-- ─────────────────────────────────────────────

function runelore.statusLines()
  local lines = {}
  local rb = runebladeState()

  local function add(s) table.insert(lines, "[Runelore] " .. s) end

  if rb then
    local cfgState = rb.getConfiguration()
    if cfgState and cfgState.core_rune then
      add(string.format("config: %s + [%s] active=%s",
        cfgState.core_rune:upper(),
        table.concat(cfgState.config_runes, ","):upper(),
        cfgState.active and "yes" or "no"))

      local attuned = rb.getAttunedRunes()
      if #attuned > 0 then
        add("attuned: " .. table.concat(attuned, ", "):upper())
      else
        add("attuned: (none)")
      end
    else
      add("no configuration set")
    end
  end

  add(string.format("kena_eligible=%s  pith_reliable=%s  pith_max_drain=%s",
    runelore.isKenaEligible() and "yes" or "no",
    runelore.isPithakhanReliable() and "yes" or "no",
    runelore.isPithakhanMaxDrain() and "yes" or "no"))

  local nearLock, missing = runelore.isNearLock()
  add(string.format("near_lock=%s  missing_affs=%s",
    nearLock and "yes" or "no",
    #missing > 0 and table.concat(missing, ",") or "none"))

  return lines
end

-- ─────────────────────────────────────────────
-- Bootstrap
-- ─────────────────────────────────────────────

function runelore.bootstrap()
  -- Sync runtime cfg from rwda.config.runelore (defaults set in config.lua).
  local rlCfg = rwda.config and rwda.config.runelore or {}
  if type(rlCfg.auto_empower) == "boolean" then
    cfg.auto_empower = rlCfg.auto_empower
  end
  cfg.empower_on_attune = cfg.auto_empower

  if rwda.util then
    rwda.util.log("info",
      "Runelore bootstrapped (auto_empower=%s bisect=%s kena_threshold=%.0f%%)",
      tostring(cfg.auto_empower),
      tostring(rlCfg.bisect_enabled == true),
      (rlCfg.kena_mana_threshold or KENA_MANA_THRESHOLD) * 100)
  end
end

-- ─────────────────────────────────────────────
-- Manual empower dispatch
-- ─────────────────────────────────────────────

-- Called by: rwda runelore empower <rune>
function runelore.manualEmpower(runeName)
  if not runeName or runeName == "" then return end
  runeName = tostring(runeName):lower()
  runelore.queueEmpower(runeName)
end

return runelore

