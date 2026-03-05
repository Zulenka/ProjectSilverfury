-- Silverfury/runelore/core.lua
-- Runeblade attunement tracking and empower automation.
-- Coordinates sketch/apply/confirm routing with the offense queue.

Silverfury = Silverfury or {}
Silverfury.runelore = Silverfury.runelore or {}

local core = {}
Silverfury.runelore.core = core

-- ── Runeblade live state ──────────────────────────────────────────────────────

local _state = {
  core_rune         = nil,       -- active core rune name
  config_runes      = {},        -- list of active config rune names
  attuned           = {},        -- key = rune, val = true (attuned rune)
  empowered         = false,     -- is the weapon currently empowered?
  empower_next      = nil,       -- which config rune fires next (empowered slot)
  last_drain        = 0,         -- epoch_ms of last pithakhan proc observation
  last_focus        = 0,         -- epoch_ms of last observed target focus use
  last_empower_rune = nil,       -- name of rune last sent for empowerment
}

-- ── Initialise from config ────────────────────────────────────────────────────

function core.init()
  _state.core_rune    = Silverfury.config.get("runelore.core_rune")    or "pithakhan"
  _state.config_runes = Silverfury.config.get("runelore.config_runes") or { "kena", "sleizak", "inguz" }
  _state.attuned      = {}
  _state.empowered    = false
end

-- ── Attunement state setters ──────────────────────────────────────────────────

function core.setAttuned(rune_name, active)
  if active then
    _state.attuned[rune_name] = true
    Silverfury.log.info("Runelore: attuned to %s", rune_name)
  else
    _state.attuned[rune_name] = nil
    Silverfury.log.info("Runelore: attunement lost — %s", rune_name)
  end
end

function core.isAttuned(rune_name)
  return _state.attuned[rune_name] == true
end

function core.setEmpowered(active)
  _state.empowered = active
  if active then
    Silverfury.log.info("Runelore: weapon EMPOWERED.")
  else
    Silverfury.log.info("Runelore: empower consumed.")
  end
end

function core.isEmpowered()
  return _state.empowered
end

-- ── Bisect eligibility ────────────────────────────────────────────────────────
-- Bisect is the Hugalaz kill method: replaces impale→disembowel when:
--   • core rune is hugalaz
--   • bisect_enabled is true in config
--   • target HP% is at or below bisect_hp_threshold
-- Requires the target module to expose hpPct() (may be estimated or unavailable).

function core.canBisect()
  if not Silverfury.config.get("runelore.bisect_enabled") then return false end
  if _state.core_rune ~= "hugalaz" then return false end
  local threshold = Silverfury.config.get("runelore.bisect_hp_threshold") or 0.20
  local tgt = Silverfury.state.target
  -- Use target HP% if the parser has filled it in; fall back to false (safe).
  local hp_pct = tgt.hp_pct   -- nil when unknown
  if hp_pct == nil then return false end
  return hp_pct <= threshold
end

-- ── Attunement condition evaluation ──────────────────────────────────────────

local ATTUNE_CONDS = {
  -- target_mana_low:
  --   True if Pithakhan has drained within the configured observation window.
  --   This is a heuristic — we don't have direct mana readout by default.
  --   The window is configurable (runelore.pithakhan_drain_window_ms, default 10s).
  --   As Pithakhan fires more frequently (head damaged/broken), this stays true
  --   longer, which is accurate: mana is continuously dropping.
  target_mana_low = function()
    local window_ms = Silverfury.config.get("runelore.pithakhan_drain_window_ms") or 10000
    return (Silverfury.time.now() - _state.last_drain) < window_ms
  end,

  target_paralysed = function()
    return Silverfury.state.target.hasAff("paralysis")
  end,

  target_weary = function()
    return Silverfury.state.target.hasAff("weariness")
        or Silverfury.state.target.hasAff("lethargy")
  end,

  target_prone_no_insomnia = function()
    local tgt = Silverfury.state.target
    return tgt.prone and not tgt.hasDef("insomnia")
  end,

  target_shivering = function()
    return Silverfury.state.target.hasAff("shivering")
  end,

  -- target_off_focus:
  --   True if the target has recently used focus (starting a cooldown period).
  --   Focus in Achaea has roughly a 3-second balance cost.  When we observe the
  --   target "uses focus", we record the time; the condition fires for ~3s after.
  --   This is conservative: after the cooldown we assume focus is back (false).
  --   Config key: runelore.focus_cooldown_ms (default 3200ms to be safe).
  target_off_focus = function()
    if _state.last_focus == 0 then return false end
    local cooldown_ms = Silverfury.config.get("runelore.focus_cooldown_ms") or 3200
    return (Silverfury.time.now() - _state.last_focus) < cooldown_ms
  end,

  -- target_engaged: true when target is in the room and alive.
  target_engaged = function()
    return Silverfury.state.target.isAvailable()
  end,

  target_off_salve = function()
    return not Silverfury.state.target.hasDef("salve")
  end,

  target_limb_damaged = function()
    local tgt = Silverfury.state.target
    for _, lb in pairs(tgt.limbs) do
      if lb.damage_pct >= 30 then return true end
    end
    return false
  end,

  target_addicted = function()
    return Silverfury.state.target.hasAff("addiction")
  end,
}

function core.checkCondition(cond_name)
  local fn = ATTUNE_CONDS[cond_name]
  if fn then return fn() end
  return false
end

-- ── Auto-empower ──────────────────────────────────────────────────────────────

function core.shouldEmpower()
  if not Silverfury.config.get("runelore.auto_empower") then return false end
  if _state.empowered then return false end
  return core.nextEmpowerRune() ~= nil
end

function core.nextEmpowerRune()
  local priority = Silverfury.config.get("runelore.empower_priority") or {}
  for _, rname in ipairs(priority) do
    if core.isAttuned(rname) then
      -- Check attune condition to see if it's worth triggering.
      local rdata = Silverfury.runelore.runes.DATA[rname]
      if rdata and rdata.attune_condition then
        if core.checkCondition(rdata.attune_condition) then
          return rname
        end
      else
        return rname  -- no condition = always eligible
      end
    end
  end
  return nil
end

function core.empower(rune_name)
  if not rune_name then rune_name = core.nextEmpowerRune() end
  if not rune_name then
    Silverfury.log.warn("runelore.empower: no eligible rune")
    return
  end
  core.noteEmpowerSent(rune_name)
  tempTimer(0.1, function()
    Silverfury.engine.queue.send("empower " .. rune_name)
  end)
end

-- Record which rune was most recently sent for empowerment.
-- Call this whenever an empower command is dispatched (from here or the scenario).
function core.noteEmpowerSent(rune_name)
  _state.last_empower_rune = rune_name
  Silverfury.log.trace("Runelore: empower queued for %s", tostring(rune_name))
end

-- ── Runelore queue: sketch / smudge steps ────────────────────────────────────
-- Simple sequential queue driven by confirmation patterns.

local _rq = { steps={}, active=false, current_idx=0, on_done=nil }

function core.queueStep(cmd, confirm_pattern, label)
  _rq.steps[#_rq.steps+1] = {
    cmd             = cmd,
    confirm_pattern = confirm_pattern,
    label           = label or cmd,
    sent            = false,
    confirmed       = false,
  }
end

function core.runQueue(on_done)
  if _rq.active then
    Silverfury.log.warn("runelore queue already running")
    return
  end
  _rq.on_done    = on_done
  _rq.current_idx = 1
  _rq.active      = true
  core._runNextStep()
end

function core._runNextStep()
  if _rq.current_idx > #_rq.steps then
    _rq.active = false
    if _rq.on_done then _rq.on_done(true) end
    _rq.steps = {}
    return
  end
  local step = _rq.steps[_rq.current_idx]
  if not step.sent then
    step.sent = true
    local delay = (Silverfury.config.get("runelore.step_delay_ms") or 800) / 1000
    tempTimer(delay, function()
      Silverfury.engine.queue.send(step.cmd)
    end)
  end
end

function core.onLine(line)
  if not _rq.active then return end
  local step = _rq.steps[_rq.current_idx]
  if not step then return end
  if step.confirm_pattern and line:find(step.confirm_pattern) then
    step.confirmed = true
    Silverfury.log.trace("runelore confirm: %s", step.label)
    _rq.current_idx = _rq.current_idx + 1
    core._runNextStep()
  end
end

function core.cancelQueue()
  _rq.active      = false
  _rq.steps       = {}
  _rq.current_idx = 1
end

-- ── Event hooks ───────────────────────────────────────────────────────────────

local _handlers = {}

function core.registerHandlers()
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}

  -- Track pithakhan drain observations.
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_PithakhanDrain", function()
    _state.last_drain = Silverfury.time.now()
  end)

  -- Track target focus use (for target_off_focus condition).
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_TargetFocused", function()
    _state.last_focus = Silverfury.time.now()
    Silverfury.log.trace("Runelore: target focus recorded (off-focus window started)")
  end)

  -- Attunement confirmed from parser.
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_RuneAttuned", function(_, rune)
    core.setAttuned(rune, true)
  end)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_RuneAttuneLost", function(_, rune)
    core.setAttuned(rune, false)
  end)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_Empowered", function()
    core.setEmpowered(true)
  end)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_EmpowerConsumed", function()
    core.setEmpowered(false)
    -- Apply the empower_effect to the target model (assumed, not confirmed).
    local rname = _state.last_empower_rune
    if rname then
      local rdata = Silverfury.runelore.runes.DATA[rname]
      if rdata and rdata.empower_effect then
        local fx = rdata.empower_effect
        local tgt = Silverfury.state.target
        -- Aff delivery (single or conditional).
        if fx.aff then
          -- sleizak escalates to alt_aff if primary already present.
          local aff_to_apply = fx.aff
          if fx.alt_aff and tgt.hasAff(fx.aff) then
            aff_to_apply = fx.alt_aff
          end
          tgt.addAff(aff_to_apply, false)
          Silverfury.log.info("Runelore empower: assumed %s → %s on target",
            rname, aff_to_apply)
        end
        -- Limb break (tiwaz: breaks both arms).
        if fx.limb_break then
          for _, limb in ipairs(fx.limb_break) do
            tgt.updateLimb(limb, 100, true, false)
            Silverfury.log.info("Runelore empower: assumed limb break %s (from %s)",
              limb, rname)
          end
        end
        -- Rib burst (wunjo): instant damage scaled by cracked rib count.
        -- No persistent aff to model; raise event for any external consumers.
        if fx.rib_burst then
          Silverfury.log.info("Runelore empower: wunjo rib-burst fired on target")
          raiseEvent("SF_WunjoRibBurst")
        end
        -- Fracture relapse (sowulu): extra damage to already-damaged limbs.
        -- Heuristic: bump damage_pct by 15 for any limb above 30% damaged.
        if fx.fracture_relapse then
          for lname, lb in pairs(tgt.limbs) do
            if lb.damage_pct >= 30 then
              local bumped = math.min(lb.damage_pct + 15, 150)
              tgt.updateLimb(lname, bumped, bumped >= 100, bumped >= 150)
              Silverfury.log.info("Runelore empower: sowulu relapse — %s %d%% → %d%%",
                lname, lb.damage_pct, bumped)
            end
          end
        end
      end
      _state.last_empower_rune = nil
    end
  end)

  -- Forward incoming text to rune queue.
  _handlers[#_handlers+1] = registerAnonymousEventHandler("sysDataReceived", function(_, line)
    core.onLine(line)
  end)
end

function core.shutdown()
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}
  core.cancelQueue()
end

-- ── Status ───────────────────────────────────────────────────────────────────

function core.statusLines()
  local lines = {}
  lines[#lines+1] = string.format("Core: %s | Empowered: %s", _state.core_rune or "none", _state.empowered and "YES" or "no")
  local attuned = {}
  for rname in pairs(_state.attuned) do attuned[#attuned+1] = rname end
  lines[#lines+1] = "Attuned: " .. (#attuned > 0 and table.concat(attuned,", ") or "none")
  lines[#lines+1] = "Config runes: " .. table.concat(_state.config_runes, ", ")
  local nxt = core.nextEmpowerRune()
  lines[#lines+1] = "Next empower: " .. (nxt or "none")

  -- Bisect availability (only relevant with hugalaz).
  if _state.core_rune == "hugalaz" then
    local bisect_on  = Silverfury.config.get("runelore.bisect_enabled")
    local bisect_pct = (Silverfury.config.get("runelore.bisect_hp_threshold") or 0.20) * 100
    local eligible   = core.canBisect()
    lines[#lines+1] = string.format("Bisect: %s | Threshold: %.0f%% | %s",
      bisect_on and "ON" or "OFF",
      bisect_pct,
      eligible and "<ansi_green>ELIGIBLE NOW<reset>" or "not eligible"
    )
  else
    lines[#lines+1] = "Bisect: requires hugalaz core rune"
  end

  -- Pith+Kena mana heuristic.
  local drain_window = Silverfury.config.get("runelore.pithakhan_drain_window_ms") or 10000
  local drain_age    = Silverfury.time.now() - _state.last_drain
  if drain_age < drain_window then
    lines[#lines+1] = string.format("<ansi_cyan>Pithakhan<reset>: drain seen %.1fs ago — mana likely LOW",
      drain_age / 1000)
  end

  -- Kelp stack count.
  if Silverfury.offense and Silverfury.offense.venoms then
    local kc = Silverfury.offense.venoms.countKelpAffs()
    local kt = Silverfury.config.get("venoms.kelp_stack_target_count") or 3
    lines[#lines+1] = string.format("Kelp stack: %d/%d affs on target", kc, kt)
  end

  -- Runelore-kill scenario phase.
  local sc = Silverfury.scenarios and Silverfury.scenarios.base and Silverfury.scenarios.base.status()
  if sc and sc.active and sc.name == "runelore_kill" then
    local ph = Silverfury.scenarios.runelore_kill.phase and Silverfury.scenarios.runelore_kill.phase() or "?"
    lines[#lines+1] = string.format("RL-Kill phase: <ansi_cyan>%s<reset>", ph)
  end

  return lines
end
