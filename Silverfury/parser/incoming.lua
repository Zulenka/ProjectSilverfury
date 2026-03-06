-- Silverfury/parser/incoming.lua
-- Regex-driven combat line parser.
-- Translates game text into state mutations and SF events.

Silverfury = Silverfury or {}
Silverfury.parser = Silverfury.parser or {}

local incoming = {}
Silverfury.parser.incoming = incoming

-- ── Pattern definitions ───────────────────────────────────────────────────────
-- Each entry: { pattern, handler(captures...) }
-- Patterns applied to every line received from the MUD.

local PATTERNS = {

  -- ── Balance/equilibrium ──────────────────────────────────────────────────
  { "^You have recovered balance%.",
    function()
      Silverfury.state.me.bal = true
      Silverfury.engine.queue.onBalanceRestored()
    end },

  { "^You have recovered equilibrium%.",
    function()
      Silverfury.state.me.eq = true
      Silverfury.engine.queue.onBalanceRestored()
    end },

  -- ── Weapon state ─────────────────────────────────────────────────────────
  { "You have no weapon",
    function()
      Silverfury.state.me.swords_wielded = false
    end },

  { "You are already wielding",
    function()
      Silverfury.state.me.swords_wielded = true
    end },

  -- ── Target defences ──────────────────────────────────────────────────────
  { "(.+) surrounds %w+ with a swirling shield%.?",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.setDef("shield", true)
      end
    end },

  { "(.+)['s]+ shield shatters",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.setDef("shield", false)
      end
    end },

  { "^A bolt of lightning strikes (.+), shattering",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.setDef("rebounding", false)
      end
    end },

  { "(.+) is surrounded by a rebounding aura",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.setDef("rebounding", true)
      end
    end },

  -- ── Target insomnia ───────────────────────────────────────────────────────
  -- Insomnia is a defence (hasDef). Tracked so fehu's target_prone_no_insomnia
  -- condition works correctly. NOTE: exact Achaea message text should be
  -- confirmed with live testing — these cover the most common phrasings.
  { "(.+) appears? wide awake, completely immune to sleep",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.setDef("insomnia", true)
      end
    end },

  { "(.+) resists? the attempt to sleep",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.setDef("insomnia", true)
      end
    end },

  { "(.+) falls? into a deep slumber",
    function(_, name)
      if incoming._isTarget(name) then
        -- Sleep landed: target clearly lacks insomnia.
        Silverfury.state.target.setDef("insomnia", false)
        Silverfury.state.target.addAff("sleep", false)
        Silverfury.log.trace("Target fell asleep — insomnia def cleared.")
      end
    end },

  -- ── Target prone / standing ───────────────────────────────────────────────
  { "(.+) is knocked to the ground",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.prone = true
      end
    end },

  { "(.+) scrambles to %w+ feet",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.prone = false
      end
    end },

  -- ── Target flying ─────────────────────────────────────────────────────────
  { "(.+) soars up into the air",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.flying = true
      end
    end },

  { "(.+) lands gracefully",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.flying = false
      end
    end },

  -- ── Target impaled ────────────────────────────────────────────────────────
  { "You impale (.+) through",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.impaled = true
        Silverfury.log.trace("Target impaled.")
      end
    end },

  { "(.+) rips free from your impalement",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.impaled = false
      end
    end },

  -- ── Target death ─────────────────────────────────────────────────────────
  { "(.+) has been slain",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.dead = true
        Silverfury.state.target.in_room = false
        raiseEvent("SF_TargetDead", name)
        Silverfury.logging.logger.write("TARGET_DEAD", { name=name })
      end
    end },

  -- ── Disembowel / finisher outcomes ────────────────────────────────────────
  { "You disembowel (.+) with a",
    function(_, name)
      if incoming._isTarget(name) then
        raiseEvent("SF_DisembowelSuccess", name)
        Silverfury.logging.logger.write("OUTGOING_CONFIRM", { action="disembowel", result="success" })
      end
    end },

  { "You need (.+) to be",   -- disembowel failure: not prone / not impaled
    function()
      raiseEvent("SF_DisembowelFail", "precondition not met")
    end },

  -- ── Aggressor detection (incoming attacks) ────────────────────────────────
  { "(.+) slashes you with",
    function(_, name) raiseEvent("SF_AggressorHit", name) end },

  { "(.+) hacks into you",
    function(_, name) raiseEvent("SF_AggressorHit", name) end },

  { "(.+) thrusts at you",
    function(_, name) raiseEvent("SF_AggressorHit", name) end },

  { "(.+) rends your",
    function(_, name) raiseEvent("SF_AggressorHit", name) end },

  { "(.+) swipes at you",
    function(_, name) raiseEvent("SF_AggressorHit", name) end },

  -- ── Pithakhan mana drain ──────────────────────────────────────────────────
  { "drains (.+)['s]* mana",
    function(_, name)
      if incoming._isTarget(name) then
        raiseEvent("SF_PithakhanDrain")
        Silverfury.logging.logger.write("RUNE_ACTION", { rune="pithakhan", effect="drain" })
      end
    end },

  -- ── Target cure actions: herb eating ─────────────────────────────────────
  -- Remove one aff per cure bucket using LIFO heuristic (best-guess, not certain).
  -- The herb name matched here maps to a cure_item in data/afflictions.
  { "^(.+) eats? some kelp",
    function(_, name)
      if incoming._isTarget(name) then
        local tgt = Silverfury.state.target
        local aff = Silverfury.data.afflictions.chooseAffToClear(tgt, "kelp")
        if aff then tgt.removeAff(aff) end
        raiseEvent("SF_TargetCured", "kelp", aff)
      end
    end },

  { "^(.+) eats? some bloodroot",
    function(_, name)
      if incoming._isTarget(name) then
        local tgt = Silverfury.state.target
        local aff = Silverfury.data.afflictions.chooseAffToClear(tgt, "bloodroot")
        if aff then tgt.removeAff(aff) end
        raiseEvent("SF_TargetCured", "bloodroot", aff)
      end
    end },

  { "^(.+) eats? some goldenseal",
    function(_, name)
      if incoming._isTarget(name) then
        local tgt = Silverfury.state.target
        local aff = Silverfury.data.afflictions.chooseAffToClear(tgt, "goldenseal")
        if aff then tgt.removeAff(aff) end
        raiseEvent("SF_TargetCured", "goldenseal", aff)
      end
    end },

  { "^(.+) eats? some ginseng",
    function(_, name)
      if incoming._isTarget(name) then
        local tgt = Silverfury.state.target
        local aff = Silverfury.data.afflictions.chooseAffToClear(tgt, "ginseng")
        if aff then tgt.removeAff(aff) end
        raiseEvent("SF_TargetCured", "ginseng", aff)
      end
    end },

  -- ── Target cure actions: smoke ───────────────────────────────────────────
  -- Valerian smoke cures slickness (primary) and several other affs.
  { "^(.+) exhales? a puff of valerian",
    function(_, name)
      if incoming._isTarget(name) then
        local tgt = Silverfury.state.target
        local aff = Silverfury.data.afflictions.chooseAffToClear(tgt, "valerian")
        if aff then tgt.removeAff(aff) end
        raiseEvent("SF_TargetCured", "valerian", aff)
      end
    end },

  { "^(.+) smokes? some valerian",
    function(_, name)
      if incoming._isTarget(name) then
        local tgt = Silverfury.state.target
        local aff = Silverfury.data.afflictions.chooseAffToClear(tgt, "valerian")
        if aff then tgt.removeAff(aff) end
        raiseEvent("SF_TargetCured", "valerian", aff)
      end
    end },

  -- ── Target cure actions: salve application ───────────────────────────────
  { "^(.+) applies? an epidermal salve",
    function(_, name)
      if incoming._isTarget(name) then
        local tgt = Silverfury.state.target
        local aff = Silverfury.data.afflictions.chooseAffToClear(tgt, "epidermal")
        if aff then tgt.removeAff(aff) end
        raiseEvent("SF_TargetCured", "epidermal", aff)
      end
    end },

  { "^(.+) applies? a mending salve",
    function(_, name)
      if incoming._isTarget(name) then
        local tgt = Silverfury.state.target
        local aff = Silverfury.data.afflictions.chooseAffToClear(tgt, "mending")
        if aff then tgt.removeAff(aff) end
        raiseEvent("SF_TargetCured", "mending", aff)
      end
    end },

  -- ── Target focus ──────────────────────────────────────────────────────────
  -- Focus is used to cure mental affs; track it so condition evaluators can work.
  { "^(.+) focuses?%.",
    function(_, name)
      if incoming._isTarget(name) then
        raiseEvent("SF_TargetFocused")
        Silverfury.log.trace("Target used focus.")
      end
    end },

  { "^(.+) uses? focus%.",
    function(_, name)
      if incoming._isTarget(name) then
        raiseEvent("SF_TargetFocused")
      end
    end },

  -- ── Rune attunement lines ─────────────────────────────────────────────────
  { "You attune yourself to the rune of (.+)%.",
    function(_, rune)
      raiseEvent("SF_RuneAttuned", rune:lower())
    end },

  { "You are no longer attuned to the rune of (.+)%.",
    function(_, rune)
      raiseEvent("SF_RuneAttuneLost", rune:lower())
    end },

  { "Your weapon pulses with power%.",
    function()
      raiseEvent("SF_Empowered")
    end },

  { "The empower fades from your weapon%.",
    function()
      raiseEvent("SF_EmpowerConsumed")
    end },

  -- ── Lyred ─────────────────────────────────────────────────────────────────
  { "(.+) is bound by notes",
    function(_, name)
      if incoming._isTarget(name) then Silverfury.state.target.lyred = true end
    end },

  { "(.+) breaks free from the lyre",
    function(_, name)
      if incoming._isTarget(name) then Silverfury.state.target.lyred = false end
    end },

  -- ── Dragon form ───────────────────────────────────────────────────────────
  -- NOTE: exact Achaea message text needs live-test confirmation.
  { "You transform into your draconic form",
    function(_)
      Silverfury.state.me.form = "dragon"
      raiseEvent("SF_DragonFormGained")
      Silverfury.log.info("Dragon: transformed to dragon form")
    end },

  { "You return to your previous form",
    function(_)
      Silverfury.state.me.form = "human"
      raiseEvent("SF_DragonFormLost")
      Silverfury.log.info("Dragon: reverted to human form")
    end },

  -- ── Dragon armour ─────────────────────────────────────────────────────────
  { "You surround yourself with magical armour",
    function(_)
      Silverfury.dragon.core.setDragonarmour(true)
      raiseEvent("SF_DragonarmourOn")
    end },

  { "Your dragonarmour fades",
    function(_)
      Silverfury.dragon.core.setDragonarmour(false)
      raiseEvent("SF_DragonarmourOff")
    end },

  -- ── Breath summon ─────────────────────────────────────────────────────────
  { "You summon your (.+) breath",
    function(_, btype)
      Silverfury.dragon.core.setBreathSummoned(true)
      raiseEvent("SF_DragonBreathSummoned", btype)
      Silverfury.log.info("Dragon: %s breath summoned", btype)
    end },

  -- Breath is consumed on Blast/Storm/Strip — track so we know to re-summon.
  { "Your breath weapon dissipates",
    function(_)
      Silverfury.dragon.core.setBreathSummoned(false)
      raiseEvent("SF_DragonBreathLost")
    end },

  -- ── Enmesh ────────────────────────────────────────────────────────────────
  { "You will the fabric of the [Vv]eil to bind (.+) with",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.enmeshed = true
        raiseEvent("SF_TargetEnmeshed")
      end
    end },

  { "(.+) escapes? from the ethereal tendrils",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.enmeshed = false
        raiseEvent("SF_TargetEnmeshBroken")
      end
    end },

  -- ── Breathstrip / tailsmash defence removal ───────────────────────────────
  { "You strip the defences of (.+) with your breath",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.setDef("shield", false)
        Silverfury.state.target.setDef("rebounding", false)
        raiseEvent("SF_TargetStripped", name)
      end
    end },

  { "You shatter (.+)['s]* magical shield with your tail",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.setDef("shield", false)
        raiseEvent("SF_TargetShieldShattered", name)
      end
    end },

  -- ── Dragonflex ────────────────────────────────────────────────────────────
  { "You snap through your bindings with a powerful flex",
    function(_)
      Silverfury.state.me.affs["webbed"]      = nil
      Silverfury.state.me.affs["transfixed"]  = nil
      raiseEvent("SF_Dragonflex")
    end },

  -- ── Devour ────────────────────────────────────────────────────────────────
  { "You begin to devour (.+)",
    function(_, name)
      raiseEvent("SF_DevourStarted", name)
      Silverfury.logging.logger.write("DRAGON_ACTION", { action="devour_begin", target=name })
    end },

  { "You tear the head from (.+)['s]* shoulders",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.dead = true
        -- Log outcome for estimator calibration.
        local sc = Silverfury.scenarios and Silverfury.scenarios.dragon_devour
        local elapsed = nil
        if sc and sc.devourStartT() then
          elapsed = (Silverfury.time.now() - sc.devourStartT()) / 1000
          sc.clearDevourStartT()
        end
        Silverfury.dragon.devour.logOutcome(true, elapsed)
        raiseEvent("SF_DevourSucceeded", name)
      end
    end },

  { "[Yy]our [Dd]evour is interrupted",
    function(_)
      local sc = Silverfury.scenarios and Silverfury.scenarios.dragon_devour
      local elapsed = nil
      if sc and sc.devourStartT() then
        elapsed = (Silverfury.time.now() - sc.devourStartT()) / 1000
        sc.clearDevourStartT()
      end
      Silverfury.dragon.devour.logOutcome(false, elapsed)
      raiseEvent("SF_DevourInterrupted")
    end },

  { "You cannot devour",
    function(_)
      raiseEvent("SF_DevourFailed", "precondition")
    end },

  -- ── Target flying ─────────────────────────────────────────────────────────
  -- Note: base flying patterns track tgt.flying; also flag can_fly.
  { "(.+) takes to the air",
    function(_, name)
      if incoming._isTarget(name) then
        Silverfury.state.target.flying  = true
        Silverfury.state.target.can_fly = true
      end
    end },

  -- ── Target escapes ────────────────────────────────────────────────────────
  -- Record the last direction the target fled so PIN phase can block it.
  { "(.+) leaves? to the (north|south|east|west|northeast|northwest|southeast|southwest|up|down)",
    function(_, name, dir)
      if incoming._isTarget(name) then
        Silverfury.state.target.in_room        = false
        Silverfury.state.target.last_escape_dir = dir
        Silverfury.log.info("Dragon: target fled %s — stored as last_escape_dir", dir)
      end
    end },
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

function incoming._isTarget(name)
  if not name then return false end
  local tname = Silverfury.state.target.name
  if not tname then return false end
  return tname:lower() == name:lower()
end

-- ── Line processor ────────────────────────────────────────────────────────────

function incoming.process(line)
  if not line or line == "" then return end
  Silverfury.logging.logger.write("INCOMING_LINE", { line=line })

  for _, entry in ipairs(PATTERNS) do
    local pat = entry[1]
    local handler = entry[2]
    local m = { line:match(pat) }
    if m[1] ~= nil then
      local ok, err = pcall(handler, table.unpack(m))
      if not ok then
        Silverfury.log.warn("parser.incoming handler error: %s", tostring(err))
      end
      -- Don't break — multiple patterns may match one line.
    end
  end
end

-- ── Event registration ────────────────────────────────────────────────────────

local _handlers = {}

function incoming.registerHandlers()
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}

  _handlers[#_handlers+1] = registerAnonymousEventHandler("sysDataReceived", function(_, line)
    incoming.process(line)
  end)
end

function incoming.shutdown()
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}
end

-- ── Manual injection for testing ─────────────────────────────────────────────
function incoming.inject(line)
  incoming.process(line)
end
