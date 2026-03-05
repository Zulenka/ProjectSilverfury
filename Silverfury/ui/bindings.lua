-- Silverfury/ui/bindings.lua
-- All "sf ..." alias command handlers.
-- One Mudlet alias: ^sf(.*)$

Silverfury = Silverfury or {}
Silverfury.ui = Silverfury.ui or {}

local bindings = {}
Silverfury.ui.bindings = bindings

-- ── Alias registration ────────────────────────────────────────────────────────

local _alias_id = nil

function bindings.registerAlias()
  if _alias_id then killAlias(_alias_id) end
  _alias_id = tempAlias("^sf(.*)", function()
    local raw = matches[2] or ""
    bindings.handle(raw)
  end)
  Silverfury.log.trace("SF alias registered.")
end

function bindings.shutdown()
  if _alias_id then killAlias(_alias_id); _alias_id = nil end
end

-- ── Dispatcher ────────────────────────────────────────────────────────────────

function bindings.handle(raw)
  local args = {}
  for w in raw:gmatch("%S+") do args[#args+1] = w end
  local cmd = (args[1] or ""):lower()
  table.remove(args, 1)

  -- ── System control ──────────────────────────────────────────────────────
  if cmd == "on" then
    Silverfury.safety.arm()

  elseif cmd == "off" then
    Silverfury.safety.disarm()

  elseif cmd == "abort" then
    Silverfury.safety.abort("manual sf abort")

  elseif cmd == "resume" then
    Silverfury.safety.resume()

  -- ── Target ──────────────────────────────────────────────────────────────
  elseif cmd == "target" or cmd == "t" then
    local name = args[1]
    if not name then
      Silverfury.log.warn("Usage: sf target <name>")
      return
    end
    Silverfury.offense.venoms.reset()
    Silverfury.state.target.setName(name)
    Silverfury.log.info("Target: %s", name)

  elseif cmd == "cleartarget" or cmd == "ct" then
    Silverfury.state.target.clear()
    Silverfury.engine.queue.clear()

  -- ── Attack toggle ────────────────────────────────────────────────────────
  elseif cmd == "attack" then
    local sub = (args[1] or ""):lower()
    local flags = Silverfury.state.flags
    if sub == "on" then
      flags.attack_enabled = true
      Silverfury.log.info("Attack: ON")
    elseif sub == "off" then
      flags.attack_enabled = false
      Silverfury.log.info("Attack: OFF")
    else
      -- Legacy shortcut: "sf attack" just fires a tick.
      Silverfury.core.tick("manual")
    end

  -- ── Retaliate ───────────────────────────────────────────────────────────
  elseif cmd == "retal" then
    local sub = (args[1] or ""):lower()
    if sub == "on" then
      Silverfury.retaliate.enable()
    elseif sub == "off" then
      Silverfury.retaliate.disable()
    else
      local s = Silverfury.retaliate.status()
      Silverfury.log.info("Retaliate: %s | Aggressors: %s",
        s.enabled and "ON" or "OFF",
        #s.aggressors > 0 and table.concat(s.aggressors,",") or "none")
    end

  -- ── Execute scenarios ────────────────────────────────────────────────────
  elseif cmd == "exec" then
    local sub = (args[1] or ""):lower()
    if sub == "venomlock" then
      Silverfury.scenarios.venomlock.start()
    elseif sub == "runelore" then
      Silverfury.scenarios.runelore_kill.start()
    elseif sub == "stop" then
      Silverfury.scenarios.base.stop("sf exec stop")
    else
      Silverfury.log.warn("Usage: sf exec <venomlock|runelore|stop>")
    end

  -- ── Runelore ─────────────────────────────────────────────────────────────
  elseif cmd == "runelore" or cmd == "rl" then
    local sub = (args[1] or ""):lower()
    if sub == "status" then
      local lines = Silverfury.runelore.core.statusLines()
      for _, l in ipairs(lines) do cecho(l .. "\n") end
    elseif sub == "empower" then
      local rune = args[2]
      Silverfury.runelore.core.empower(rune)
    elseif sub == "core" then
      local rune = args[2]
      if rune then
        Silverfury.config.set("runelore.core_rune", rune)
        Silverfury.log.info("Core rune set to: %s", rune)
      end
    elseif sub == "config" then
      local list = {}
      for i=2, #args do list[#list+1] = args[i] end
      Silverfury.config.set("runelore.config_runes", list)
      Silverfury.log.info("Config runes set to: %s", table.concat(list,", "))
    elseif sub == "autoempower" then
      local v = (args[2] or ""):lower()
      Silverfury.config.set("runelore.auto_empower", v == "on")
      Silverfury.log.info("Auto-empower: %s", v == "on" and "ON" or "OFF")
    elseif sub == "priority" then
      local list = {}
      for i=2, #args do list[#list+1] = args[i] end
      Silverfury.config.set("runelore.empower_priority", list)
      Silverfury.log.info("Empower priority: %s", table.concat(list,", "))
    elseif sub == "bisect" then
      local v = (args[2] or ""):lower()
      if v == "on" then
        -- Bisect requires hugalaz as the core rune.
        if Silverfury.config.get("runelore.core_rune") ~= "hugalaz" then
          Silverfury.log.warn("Bisect requires hugalaz core rune. Set with: sf runelore core hugalaz")
        end
        Silverfury.config.set("runelore.bisect_enabled", true)
        Silverfury.log.info("Bisect: ON (will fire when target HP <= %.0f%%)",
          (Silverfury.config.get("runelore.bisect_hp_threshold") or 0.20) * 100)
      elseif v == "off" then
        Silverfury.config.set("runelore.bisect_enabled", false)
        Silverfury.log.info("Bisect: OFF")
      else
        local enabled   = Silverfury.config.get("runelore.bisect_enabled")
        local threshold = Silverfury.config.get("runelore.bisect_hp_threshold") or 0.20
        local core      = Silverfury.config.get("runelore.core_rune")
        Silverfury.log.info("Bisect: %s | Threshold: %.0f%% | Core: %s",
          enabled and "ON" or "OFF", threshold * 100, core or "none")
      end
    elseif sub == "bisectthreshold" then
      local pct = tonumber(args[2])
      if pct and pct > 0 and pct <= 100 then
        Silverfury.config.set("runelore.bisect_hp_threshold", pct / 100)
        Silverfury.log.info("Bisect HP threshold: %.0f%%", pct)
      else
        Silverfury.log.warn("Usage: sf runelore bisectthreshold <1-100>")
      end
    else
      Silverfury.log.warn("sf runelore <status|empower [rune]|core <rune>|config <r1 r2...>|autoempower on|off|priority <...>|bisect on|off|bisectthreshold <pct>>")
    end

  -- ── Set config values ────────────────────────────────────────────────────
  elseif cmd == "set" then
    local key = (args[1] or ""):lower()
    local val = args[2]
    if key == "venoms" then
      -- sf set venoms <v1> <v2> ...
      local list = {}
      for i=2, #args do list[#list+1] = args[i] end
      Silverfury.config.set("venoms.lock_priority", list)
      Silverfury.log.info("Lock venom priority: %s", table.concat(list,", "))

    elseif key == "kelpcycle" then
      local list = {}
      for i=2, #args do list[#list+1] = args[i] end
      Silverfury.config.set("venoms.kelp_cycle", list)
      Silverfury.log.info("Kelp cycle: %s", table.concat(list,", "))

    elseif key == "limbs" then
      -- sf set limbs left_leg right_leg torso
      local list = {}
      for i=2, #args do list[#list+1] = args[i] end
      Silverfury.config.set("attack.prep_limbs", list)
      Silverfury.log.info("Prep limbs: %s", table.concat(list,", "))

    elseif key == "rewield" then
      local cmd_str = table.concat(args, " ", 2)
      Silverfury.config.set("attack.rewield_cmd", cmd_str)
      Silverfury.log.info("Rewield cmd: %s", cmd_str)

    elseif key == "antispam" then
      local ms = tonumber(val)
      if ms then
        Silverfury.config.set("combat.anti_spam_ms", ms)
        Silverfury.log.info("Anti-spam: %dms", ms)
      end

    elseif key == "hpfloor" then
      local pct = tonumber(val)
      if pct then
        Silverfury.config.set("safety.hp_floor_pct", pct/100)
        Silverfury.log.info("HP floor: %d%%", pct)
      end

    elseif key == "mpfloor" then
      local pct = tonumber(val)
      if pct then
        Silverfury.config.set("safety.mp_floor_pct", pct/100)
        Silverfury.log.info("MP floor: %d%%", pct)
      end

    elseif key == "serverqueue" then
      local v = (val or ""):lower() == "on"
      Silverfury.config.set("combat.use_server_queue", v)
      Silverfury.log.info("Server queue: %s", v and "ON" or "OFF")

    elseif key == "template" then
      local tname  = args[2]
      local tvalue = table.concat(args, " ", 3)
      if tname and tvalue ~= "" then
        Silverfury.config.set("attack.templates." .. tname, tvalue)
        Silverfury.log.info("Template [%s]: %s", tname, tvalue)
      end
    else
      Silverfury.log.warn("sf set: unknown key '%s'", key)
    end

  -- ── Status ───────────────────────────────────────────────────────────────
  elseif cmd == "status" or cmd == "" then
    bindings.printStatus()

  -- ── UI ───────────────────────────────────────────────────────────────────
  elseif cmd == "ui" then
    Silverfury.ui.window.toggle()

  -- ── Save / load ──────────────────────────────────────────────────────────
  elseif cmd == "save" then
    Silverfury.config.save()

  elseif cmd == "load" then
    Silverfury.config.load()

  -- ── Logging ──────────────────────────────────────────────────────────────
  elseif cmd == "log" then
    local sub = (args[1] or ""):lower()
    if sub == "on" then
      Silverfury.logging.logger.enable()
    elseif sub == "off" then
      Silverfury.logging.logger.disable()
    elseif sub == "folder" then
      Silverfury.logging.logger.openFolder()
    else
      Silverfury.log.info("Log: %s  File: %s",
        Silverfury.logging.logger.isEnabled() and "ON" or "OFF",
        Silverfury.logging.logger.currentPath() or "none")
    end

  -- ── Help ─────────────────────────────────────────────────────────────────
  elseif cmd == "help" then
    bindings.printHelp()

  -- ── Debug ────────────────────────────────────────────────────────────────
  elseif cmd == "debug" then
    local sub = (args[1] or "on"):lower()
    Silverfury.config.set("logging.level", sub == "off" and "info" or "trace")
    Silverfury.log.info("Debug logging: %s", sub == "off" and "OFF" or "ON")

  -- ── Tick (manual) ────────────────────────────────────────────────────────
  elseif cmd == "tick" then
    Silverfury.core.tick("manual")

  else
    Silverfury.log.warn("Unknown sf command: '%s'. Try 'sf help'.", cmd)
  end
end

-- ── Status output ─────────────────────────────────────────────────────────────

function bindings.printStatus()
  local s  = Silverfury.safety.status()
  local me = Silverfury.state.me
  local tgt = Silverfury.state.target
  local sc  = Silverfury.scenarios.base.status()

  cecho("\n<ansi_cyan>══ Silverfury Status ══════════════════════<reset>\n")
  cecho(string.format(" Armed: %s  Paused: %s  Panic: %s  Attack: %s\n",
    s.armed  and "<ansi_green>ON<reset>" or "<ansi_red>OFF<reset>",
    s.paused and "<ansi_yellow>YES<reset>" or "no",
    s.panic  and "<ansi_red>YES<reset>"   or "no",
    (Silverfury.state.flags and Silverfury.state.flags.attack_enabled)
      and "<ansi_green>ON<reset>" or "<ansi_red>OFF<reset>"
  ))
  cecho(string.format(" HP: %d/%d  MP: %d/%d  Bal: %s  Eq: %s\n",
    me.hp, me.maxhp, me.mp, me.maxmp,
    me.bal and "<ansi_green>Y<reset>" or "<ansi_red>N<reset>",
    me.eq  and "<ansi_green>Y<reset>" or "<ansi_red>N<reset>"
  ))

  local tname = tgt.name or "none"
  cecho(string.format(" Target: <ansi_cyan>%s<reset>  In room: %s  Prone: %s\n",
    tname,
    tgt.in_room and "<ansi_green>Y<reset>" or "<ansi_red>N<reset>",
    tgt.prone   and "<ansi_yellow>Y<reset>" or "N"
  ))

  if sc.active then
    cecho(string.format(" Scenario: <ansi_green>%s<reset> [%s] — %s\n",
      sc.name, sc.state, sc.reason))
  end

  local v1, v2 = Silverfury.offense.venoms.pick()
  cecho(string.format(" Next venoms: <ansi_cyan>%s<reset> / <ansi_cyan>%s<reset>\n",
    v1 or "none", v2 or "none"))

  local rl_lines = Silverfury.runelore.core.statusLines()
  for _, l in ipairs(rl_lines) do cecho(" " .. l .. "\n") end
  cecho("<ansi_cyan>══════════════════════════════════════════<reset>\n")
end

-- ── Help output ───────────────────────────────────────────────────────────────

function bindings.printHelp()
  cecho("\n<ansi_cyan>══ Silverfury Help ════════════════════════<reset>\n")
  local lines = {
    "  sf on/off              — arm/disarm the system",
    "  sf abort               — emergency stop all actions",
    "  sf resume              — clear panic and resume",
    "  sf target <name>       — set attack target",
    "  sf cleartarget         — clear current target",
    "  sf attack on/off       — toggle automatic attacking",
    "  sf retal on/off        — toggle auto-retaliate",
    "  sf exec <scenario>     — start execute scenario",
    "    scenarios: venomlock | runelore | stop",
    "  sf runelore status     — show runeblade state",
    "  sf runelore empower [rune]",
    "  sf runelore core <rune>",
    "  sf runelore config <r1> [r2] ...",
    "  sf runelore autoempower on/off",
    "  sf runelore bisect on/off  — toggle hugalaz bisect kill",
    "  sf runelore bisectthreshold <pct>  — HP% to fire bisect (default 20)",
    "  sf set venoms <v1> <v2> ...  — lock priority list",
    "  sf set kelpcycle <v1> [v2]   — kelp bypass venoms",
    "  sf set limbs <l1> [l2] ...   — prep limb order",
    "  sf set rewield <cmd>         — rewield command",
    "  sf set antispam <ms>",
    "  sf set hpfloor <pct>",
    "  sf set mpfloor <pct>",
    "  sf set serverqueue on/off",
    "  sf set template <key> <value>",
    "  sf log on/off/folder",
    "  sf save / sf load      — config persistence",
    "  sf ui                  — open/close config window",
    "  sf status              — print current status",
    "  sf debug on/off        — verbose trace logging",
    "  sf tick                — manually fire one tick",
  }
  for _, l in ipairs(lines) do cecho(l .. "\n") end
  cecho("<ansi_cyan>══════════════════════════════════════════<reset>\n")
end
