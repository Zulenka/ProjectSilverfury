-- Silverfury/engine/planner.lua
-- Chooses the next action each tick based on current state, mode, and scenario.
-- Separated cleanly from execution — planner only DECIDES, never SENDs.

Silverfury = Silverfury or {}
Silverfury.engine = Silverfury.engine or {}

local planner = {}
Silverfury.engine.planner = planner

-- ── Action descriptor ─────────────────────────────────────────────────────────
-- An "action" is a table:
--   { type = "attack"|"rune"|"scenario"|"idle", cmd = "...", reason = "..." }

local function action(type, cmd, reason)
  return { type=type, cmd=cmd, reason=reason or "" }
end

-- ── Main decision entry ───────────────────────────────────────────────────────

function planner.choose()
  -- 1. Decay stale target defences.
  Silverfury.state.target.decayDefs()

  -- 2. Safety evaluation.
  Silverfury.safety.evaluate()
  if not Silverfury.safety.canAct() then
    return action("idle", nil, "safety hold")
  end

  -- 3. Must have armed target that is in room.
  if not Silverfury.state.target.isAvailable() then
    return action("idle", nil, "no valid target")
  end

  -- 4. Check active scenario first — it overrides free-form attack.
  if Silverfury.scenarios and Silverfury.scenarios.base.isActive() then
    local a = Silverfury.scenarios.base.nextAction()
    if a then return a end
  end

  -- 5. Free-form attack selection.
  if not Silverfury.state.flags.attack_enabled then
    return action("idle", nil, "attack disabled")
  end

  -- Branch: dragon form uses its own planner to avoid mixing sword/venom logic.
  if Silverfury.state.me.form == "dragon"
      and Silverfury.config.get("dragon.enabled") then
    return planner._chooseDragonAction()
  end

  return planner._chooseAttack()
end

-- ── Attack selection ─────────────────────────────────────────────────────────

function planner._chooseAttack()
  local me  = Silverfury.state.me
  local tgt = Silverfury.state.target
  local cfg = Silverfury.config

  -- Build context.
  local v1, v2 = Silverfury.offense.venoms.pick()

  local limb = planner._nextPrepLimb()

  local template_key = cfg.get("attack.default_template") or "dsl"

  -- Shield stripping takes priority.
  if tgt.hasDef("shield") then
    local tpl = cfg.get("attack.templates.razeslash") or "razeslash {target} {venom1} {venom2}"
    return action("attack", planner._fill(tpl, {v1=v1, v2=v2}), "strip shield")
  end

  -- Rebounding stripping.
  if tgt.hasDef("rebounding") then
    local tpl = cfg.get("attack.templates.raze") or "raze {target}"
    return action("attack", planner._fill(tpl, {}), "strip rebounding")
  end

  -- Bisect window (Hugalaz core): fires before impale when target is at kill threshold.
  -- Bisect does not require prone/impale — it's a direct finisher at low HP.
  if Silverfury.runelore.core.canBisect() then
    local tpl = cfg.get("attack.templates.bisect") or "bisect {target}"
    return action("attack", planner._fill(tpl, {}), "bisect window (hugalaz)")
  end

  -- Impale if already set up (prone and legs broken).
  if tgt.prone and tgt.limbs.left_leg.broken and tgt.limbs.right_leg.broken and not tgt.impaled then
    local tpl = cfg.get("attack.templates.impale") or "impale {target}"
    return action("attack", planner._fill(tpl, {}), "impale window")
  end

  -- Disembowel if impaled.
  if tgt.impaled then
    local tpl = cfg.get("attack.templates.disembowel") or "disembowel {target}"
    return action("attack", planner._fill(tpl, {}), "disembowel window")
  end

  -- Standard DSL limb prep.
  local tpl = cfg.get("attack.templates." .. template_key) or "dsl {target} {limb} {venom1} {venom2}"
  return action("attack", planner._fill(tpl, {v1=v1, v2=v2, limb=limb}), "limbprep " .. (limb or "?"))
end

-- ── Dragon attack selection ───────────────────────────────────────────────────
-- Delegates to dragon/core.lua free-form logic when in dragon form without
-- an active scenario. The dragon_devour scenario handles its own action
-- selection via scenarios/base.lua; this is only for unscripted dragon play.

function planner._chooseDragonAction()
  return Silverfury.dragon.core.chooseFreeAction()
end

-- ── Limb selection ────────────────────────────────────────────────────────────

function planner._nextPrepLimb()
  local tgt      = Silverfury.state.target
  local cfg_limbs = Silverfury.config.get("attack.prep_limbs") or { "left_leg", "right_leg", "torso" }
  local near_pct  = Silverfury.config.get("attack.near_break_pct") or 75

  -- Find first limb in prep order that isn't broken and is highest priority.
  local best, best_dmg = nil, -1
  for _, limb_name in ipairs(cfg_limbs) do
    local lb = tgt.limbs[limb_name]
    if lb and not lb.broken then
      if lb.damage_pct > best_dmg then
        best     = limb_name
        best_dmg = lb.damage_pct
      end
    end
  end
  return best or cfg_limbs[1]
end

-- ── Template filling ─────────────────────────────────────────────────────────

function planner._fill(template, vars)
  local tname = Silverfury.state.target.name or "target"
  local cmd = template
  cmd = cmd:gsub("{target}",  tname)
  cmd = cmd:gsub("{venom1}",  vars.v1 or "")
  cmd = cmd:gsub("{venom2}",  vars.v2 or "")
  cmd = cmd:gsub("{limb}",    vars.limb or "")
  cmd = cmd:gsub("{rune}",    vars.rune or "")
  -- Clean up trailing/double spaces.
  cmd = cmd:gsub("%s+", " "):gsub("%s+$", "")
  return cmd
end

-- ── Execute an action ─────────────────────────────────────────────────────────
-- Called by queue.onBalanceRestored or core.tick.

function planner.execute(a)
  if not a or a.type == "idle" or not a.cmd then return end
  local me = Silverfury.state.me

  -- Wield check for human form.
  if me.form == "human" and not me.swords_wielded then
    local rewield = Silverfury.config.get("attack.rewield_cmd") or "wield scimitar scimitar"
    Silverfury.engine.queue.send(rewield)
    me.swords_wielded = true
  end

  local sent = Silverfury.engine.queue.send(a.cmd)
  if sent then
    -- Optimistically clear balance so we don't double-fire this tick.
    me.bal = false
    Silverfury.log.info("[%s] %s  — %s", a.type, a.cmd, a.reason)
    Silverfury.logging.logger.write("OUTGOING_COMMAND", { cmd=a.cmd, reason=a.reason, type=a.type })
    raiseEvent("SF_ActionSent", a)
  else
    -- Throttled — pend for next balance.
    Silverfury.engine.queue.pend(a)
  end
end
