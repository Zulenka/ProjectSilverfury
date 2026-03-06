-- Silverfury/ui/window.lua
-- Main Silverfury configuration window (Geyser popup, ~560x480).
-- Opens/closes with "sf ui".
-- Tabs: Status | Venoms | Runelore | Scenarios | Safety | Logging

Silverfury = Silverfury or {}
Silverfury.ui = Silverfury.ui or {}

local win = {}
Silverfury.ui.window = win

local _root       = nil   -- Geyser.Container
local _visible    = false
local _tabs       = {}    -- tab button labels
local _panels     = {}    -- panel containers per tab
local _active_tab = nil   -- current tab name
local _status_mc  = nil   -- status mini-console (updated each refresh)
local _action_mc  = nil   -- action log mini-console

-- ── Open / close ─────────────────────────────────────────────────────────────

function win.open()
  if _visible then return end
  _visible = true
  if _root then
    _root:show()
    win.refresh()
    return
  end
  win._build()
  win.refresh()
end

function win.close()
  if not _visible then return end
  _visible = false
  if _root then _root:hide() end
end

function win.toggle()
  if _visible then win.close() else win.open() end
end

function win.isOpen()
  return _visible
end

-- ── Build UI ──────────────────────────────────────────────────────────────────

function win._build()
  local comp = Silverfury.ui.components
  local theme = function(k) return Silverfury.config.get("ui.theme." .. k) or "#ffffff" end

  -- Root container — centred, 560×480.
  _root = Geyser.Container:new({
    name   = "sf_win_root",
    x      = "20%", y = "10%",
    width  = 560, height = 480,
  })

  -- Background panel.
  local bg = Geyser.Label:new({ name="sf_win_bg", x=0, y=0, width=560, height=480 }, _root)
  bg:setStyleSheet(string.format(
    "background-color: %s; border: 1px solid %s; border-radius: 4px;",
    theme("bg"), theme("accent")
  ))

  -- Title bar.
  comp.header({
    name="sf_win_title", parent=_root,
    x=0, y=0, width=560, height=24,
    text=" Silverfury Combat System", align="left", font_size=10,
  })

  -- Close button.
  comp.button({
    name="sf_win_close", parent=_root,
    x=530, y=2, width=24, height=20,
    text="X", align="center",
    onclick = function() win.close() end,
  })

  -- ── Tab bar ───────────────────────────────────────────────────────────────
  local TAB_NAMES = { "Status", "Venoms", "Runelore", "Scenarios", "Safety", "Logging" }
  local tab_w = 80
  for i, tname in ipairs(TAB_NAMES) do
    local btn = Geyser.Label:new({
      name   = "sf_tab_" .. tname,
      x      = (i-1)*tab_w, y = 26,
      width  = tab_w, height = 22,
    }, _root)
    btn:setStyleSheet(string.format(
      "background-color: %s; color: %s; font-size:9px; "
      .. "border-bottom: 2px solid %s; text-align:center; padding-top:3px;",
      theme("header_bg"), theme("text"), theme("header_bg")
    ))
    btn:echo(tname)
    local captured = tname
    btn:setClickCallback(function() win._showTab(captured) end)
    _tabs[tname] = btn
  end

  -- ── Panel area ────────────────────────────────────────────────────────────
  for _, tname in ipairs(TAB_NAMES) do
    local panel = Geyser.Container:new({
      name  = "sf_panel_" .. tname,
      x     = 0, y = 50, width = 560, height = 425,
    }, _root)
    _panels[tname] = panel
    win._buildPanel(tname, panel, comp, theme)
    panel:hide()
  end

  win._showTab("Status")
end

-- ── Show tab ──────────────────────────────────────────────────────────────────
function win._showTab(name)
  local accent = Silverfury.config.get("ui.theme.accent") or "#4a90d9"
  local header_bg = Silverfury.config.get("ui.theme.header_bg") or "#12203a"
  local text_col = Silverfury.config.get("ui.theme.text") or "#c8d6e5"

  for tname, btn in pairs(_tabs) do
    if tname == name then
      btn:setStyleSheet(string.format(
        "background-color: %s; color: %s; font-size:9px; "
        .. "border-bottom: 2px solid %s; text-align:center; padding-top:3px;",
        header_bg, accent, accent
      ))
    else
      btn:setStyleSheet(string.format(
        "background-color: %s; color: %s; font-size:9px; "
        .. "border-bottom: 2px solid %s; text-align:center; padding-top:3px;",
        header_bg, text_col, header_bg
      ))
    end
  end

  for tname, panel in pairs(_panels) do
    if tname == name then panel:show() else panel:hide() end
  end
  _active_tab = name
  win.refresh()
end

-- ── Build each panel ──────────────────────────────────────────────────────────

function win._buildPanel(name, panel, comp, theme)
  if name == "Status" then
    win._buildStatus(panel, comp, theme)
  elseif name == "Venoms" then
    win._buildVenoms(panel, comp, theme)
  elseif name == "Runelore" then
    win._buildRunelore(panel, comp, theme)
  elseif name == "Scenarios" then
    win._buildScenarios(panel, comp, theme)
  elseif name == "Safety" then
    win._buildSafety(panel, comp, theme)
  elseif name == "Logging" then
    win._buildLogging(panel, comp, theme)
  end
end

-- ── Status panel ─────────────────────────────────────────────────────────────

function win._buildStatus(panel, comp, theme)
  comp.header({ name="sf_stat_hdr", parent=panel,
    x=4, y=4, width=548, height=18, text=" System Status" })

  -- Toggle buttons row
  comp.toggle({ name="sf_tog_armed", parent=panel,
    x=4, y=28, width=90, height=22,
    label_on="ARMED", label_off="DISARMED",
    state_fn = function() return Silverfury.safety.isArmed() end,
    ontoggle  = function()
      if Silverfury.safety.isArmed() then Silverfury.safety.disarm()
      else Silverfury.safety.arm() end
    end,
  })

  comp.toggle({ name="sf_tog_attack", parent=panel,
    x=100, y=28, width=80, height=22,
    label_on="ATK ON", label_off="ATK OFF",
    state_fn = function() return Silverfury.state.flags and Silverfury.state.flags.attack_enabled end,
    ontoggle  = function()
      local f = Silverfury.state.flags
      f.attack_enabled = not f.attack_enabled
    end,
  })

  comp.toggle({ name="sf_tog_retal", parent=panel,
    x=186, y=28, width=80, height=22,
    label_on="RETAL ON", label_off="RETAL OFF",
    state_fn = function() return Silverfury.retaliate.isEnabled() end,
    ontoggle  = function()
      if Silverfury.retaliate.isEnabled() then Silverfury.retaliate.disable()
      else Silverfury.retaliate.enable() end
    end,
  })

  comp.button({ name="sf_btn_abort", parent=panel,
    x=272, y=28, width=70, height=22,
    text="ABORT", bg="#8b0000", fg="#ffffff",
    onclick = function() Silverfury.safety.abort("UI abort button") end,
  })

  -- Status mini-console.
  _status_mc = comp.console({ name="sf_status_mc", parent=panel,
    x=4, y=56, width=548, height=200, wrap=90, font_size=9 })

  -- Action log.
  comp.header({ name="sf_action_hdr", parent=panel,
    x=4, y=262, width=548, height=18, text=" Last Actions" })
  _action_mc = comp.console({ name="sf_action_mc", parent=panel,
    x=4, y=282, width=548, height=135, wrap=90, font_size=9 })
end

-- ── Venoms panel ─────────────────────────────────────────────────────────────

function win._buildVenoms(panel, comp, theme)
  comp.header({ name="sf_ven_hdr", parent=panel,
    x=4, y=4, width=548, height=18, text=" Venom Configuration" })

  local mc = comp.console({ name="sf_ven_mc", parent=panel,
    x=4, y=28, width=548, height=340, wrap=90, font_size=9 })

  local function refreshVenoms()
    mc:clear()
    local lock = Silverfury.config.get("venoms.lock_priority") or {}
    mc:cecho("<ansi_cyan>Lock priority:<reset> " .. table.concat(lock, ", ") .. "\n")
    local kelp = Silverfury.config.get("venoms.kelp_cycle") or {}
    mc:cecho("<ansi_cyan>Kelp cycle:<reset> " .. table.concat(kelp, ", ") .. "\n")
    local off = Silverfury.config.get("venoms.off_priority") or {}
    mc:cecho("<ansi_cyan>Off-hand priority:<reset> " .. table.concat(off, ", ") .. "\n")
    mc:cecho("\n")
    local v1, v2 = Silverfury.offense.venoms.pick()
    mc:cecho("<ansi_green>Next venoms:<reset> " .. (v1 or "none") .. " / " .. (v2 or "none") .. "\n")
    mc:cecho("\n<ansi_dark_gray>Use 'sf set venoms <lock list>' and 'sf set kelpcycle <cycle list>' to configure.\n")
  end

  comp.button({ name="sf_ven_refresh", parent=panel,
    x=4, y=375, width=80, height=22, text="Refresh",
    onclick = refreshVenoms,
  })

  refreshVenoms()
end

-- ── Runelore panel ────────────────────────────────────────────────────────────

function win._buildRunelore(panel, comp, theme)
  comp.header({ name="sf_rl_hdr", parent=panel,
    x=4, y=4, width=548, height=18, text=" Runelore / Runeblade" })

  local mc = comp.console({ name="sf_rl_mc", parent=panel,
    x=4, y=28, width=548, height=340, wrap=90, font_size=9 })

  local function refreshRL()
    mc:clear()
    local lines = Silverfury.runelore.core.statusLines()
    for _, l in ipairs(lines) do mc:cecho(l .. "\n") end
  end

  comp.button({ name="sf_rl_empower", parent=panel,
    x=4, y=375, width=100, height=22, text="Empower Next",
    onclick = function()
      Silverfury.runelore.core.empower()
    end,
  })

  comp.button({ name="sf_rl_refresh", parent=panel,
    x=110, y=375, width=80, height=22, text="Refresh",
    onclick = refreshRL,
  })

  refreshRL()
end

-- ── Scenarios panel ───────────────────────────────────────────────────────────

function win._buildScenarios(panel, comp, theme)
  comp.header({ name="sf_sc_hdr", parent=panel,
    x=4, y=4, width=548, height=18, text=" Execute Scenarios" })

  local mc = comp.console({ name="sf_sc_mc", parent=panel,
    x=4, y=28, width=548, height=200, wrap=90, font_size=9 })

  local function refreshScenario()
    mc:clear()
    local s = Silverfury.scenarios.base.status()
    if s.active then
      mc:cecho(string.format("<ansi_green>ACTIVE<reset> — %s [%s]\n", s.name, s.state))
      mc:cecho("Reason: " .. s.reason .. "\n")
      mc:cecho(string.format("Elapsed: %.1fs\n", s.elapsed))
    else
      mc:cecho("<ansi_dark_gray>No scenario running.\n")
    end
  end

  comp.button({ name="sf_sc_vlock", parent=panel,
    x=4, y=234, width=120, height=22, text="Start: Venom-lock",
    onclick = function()
      Silverfury.scenarios.venomlock.start()
      refreshScenario()
    end,
  })

  comp.button({ name="sf_sc_rl", parent=panel,
    x=130, y=234, width=130, height=22, text="Start: Runelore Kill",
    onclick = function()
      Silverfury.scenarios.runelore_kill.start()
      refreshScenario()
    end,
  })

  comp.button({ name="sf_sc_stop", parent=panel,
    x=266, y=234, width=80, height=22, text="Stop",
    onclick = function()
      Silverfury.scenarios.base.stop("UI stop")
      refreshScenario()
    end,
  })

  comp.button({ name="sf_sc_abort", parent=panel,
    x=352, y=234, width=80, height=22, text="Abort",
    bg="#8b0000", fg="#ffffff",
    onclick = function()
      Silverfury.scenarios.base.abort("UI abort")
      refreshScenario()
    end,
  })

  comp.button({ name="sf_sc_refresh", parent=panel,
    x=4, y=375, width=80, height=22, text="Refresh",
    onclick = refreshScenario,
  })

  refreshScenario()
end

-- ── Safety panel ─────────────────────────────────────────────────────────────

function win._buildSafety(panel, comp, theme)
  comp.header({ name="sf_safe_hdr", parent=panel,
    x=4, y=4, width=548, height=18, text=" Safety Configuration" })

  local mc = comp.console({ name="sf_safe_mc", parent=panel,
    x=4, y=28, width=548, height=340, wrap=90, font_size=9 })

  local function refreshSafety()
    mc:clear()
    local s = Silverfury.safety.status()
    mc:cecho("Armed:  " .. (s.armed  and "<ansi_green>YES<reset>" or "<ansi_red>NO<reset>")  .. "\n")
    mc:cecho("Paused: " .. (s.paused and "<ansi_yellow>YES<reset>" or "<ansi_green>NO<reset>") .. "\n")
    mc:cecho("Panic:  " .. (s.panic  and "<ansi_red>YES<reset>" or "<ansi_green>NO<reset>")  .. "\n")
    mc:cecho("\n")
    mc:cecho(string.format("HP floor:     %.0f%%\n", (Silverfury.config.get("safety.hp_floor_pct") or 0)*100))
    mc:cecho(string.format("MP floor:     %.0f%%\n", (Silverfury.config.get("safety.mp_floor_pct") or 0)*100))
    local affs = Silverfury.config.get("safety.danger_affs") or {}
    mc:cecho("Danger affs:  " .. table.concat(affs, ", ") .. "\n")
    mc:cecho("\n<ansi_dark_gray>Use 'sf set hpfloor <0-100>' and 'sf set mpfloor <0-100>' to configure.\n")
  end

  comp.button({ name="sf_safe_refresh", parent=panel,
    x=4, y=375, width=80, height=22, text="Refresh",
    onclick = refreshSafety,
  })

  refreshSafety()
end

-- ── Logging panel ─────────────────────────────────────────────────────────────

function win._buildLogging(panel, comp, theme)
  comp.header({ name="sf_log_hdr", parent=panel,
    x=4, y=4, width=548, height=18, text=" Combat Logging" })

  local mc = comp.console({ name="sf_log_mc", parent=panel,
    x=4, y=28, width=548, height=280, wrap=90, font_size=9 })

  local function refreshLog()
    mc:clear()
    local enabled = Silverfury.logging.logger.isEnabled()
    mc:cecho("Logging: " .. (enabled and "<ansi_green>ENABLED<reset>" or "<ansi_red>DISABLED<reset>") .. "\n")
    local path = Silverfury.logging.logger.currentPath()
    mc:cecho("Current file: " .. (path or "none") .. "\n")
    mc:cecho("\n<ansi_dark_gray>Logs stored in:\n" .. Silverfury.files.logDir() .. "\n")
  end

  comp.toggle({ name="sf_log_toggle", parent=panel,
    x=4, y=314, width=100, height=22,
    label_on="Log ON", label_off="Log OFF",
    state_fn = function() return Silverfury.logging.logger.isEnabled() end,
    ontoggle = function()
      if Silverfury.logging.logger.isEnabled() then Silverfury.logging.logger.disable()
      else Silverfury.logging.logger.enable() end
      refreshLog()
    end,
  })

  comp.button({ name="sf_log_folder", parent=panel,
    x=110, y=314, width=100, height=22, text="Open Folder",
    onclick = function() Silverfury.logging.logger.openFolder() end,
  })

  comp.button({ name="sf_log_refresh", parent=panel,
    x=4, y=375, width=80, height=22, text="Refresh",
    onclick = refreshLog,
  })

  refreshLog()
end

-- ── Refresh (called on prompt tick / each open) ────────────────────────────────

function win.refresh()
  if not _visible then return end
  if _active_tab == "Status" then
    win._refreshStatus()
  end
  -- Refresh toggle state on all visible toggles (best-effort).
  -- Individual panels call their own refresh on button press.
end

function win._refreshStatus()
  if not _status_mc then return end
  _status_mc:clear()
  local s = Silverfury.safety.status()
  local me = Silverfury.state.me
  local tgt = Silverfury.state.target

  _status_mc:cecho(string.format("<ansi_cyan>STATE<reset>  Armed: %s  Paused: %s  Panic: %s\n",
    s.armed  and "<ansi_green>Y<reset>" or "<ansi_red>N<reset>",
    s.paused and "<ansi_yellow>Y<reset>" or "<ansi_green>N<reset>",
    s.panic  and "<ansi_red>Y<reset>" or "<ansi_green>N<reset>"
  ))

  _status_mc:cecho(string.format("<ansi_cyan>SELF<reset>   HP: %d/%d  MP: %d/%d  Bal: %s  Eq: %s\n",
    me.hp, me.maxhp, me.mp, me.maxmp,
    me.bal and "<ansi_green>Y<reset>" or "<ansi_red>N<reset>",
    me.eq  and "<ansi_green>Y<reset>" or "<ansi_red>N<reset>"
  ))

  local tname = tgt.name or "<none>"
  _status_mc:cecho(string.format("<ansi_cyan>TARGET<reset> %s  In room: %s  Prone: %s  Dead: %s\n",
    tname,
    tgt.in_room and "<ansi_green>Y<reset>" or "<ansi_red>N<reset>",
    tgt.prone   and "<ansi_yellow>Y<reset>" or "N",
    tgt.dead    and "<ansi_red>Y<reset>"   or "N"
  ))

  if tgt.hasDef("shield") then
    _status_mc:cecho("<ansi_yellow>  Shield ACTIVE<reset>\n")
  end
  if tgt.hasDef("rebounding") then
    _status_mc:cecho("<ansi_yellow>  Rebounding ACTIVE<reset>\n")
  end

  local sc = Silverfury.scenarios.base.status()
  if sc.active then
    _status_mc:cecho(string.format("<ansi_cyan>SCENARIO<reset> %s [%s] — %s\n",
      sc.name, sc.state, sc.reason))
  end

  local v1, v2 = Silverfury.offense.venoms.pick()
  _status_mc:cecho(string.format("<ansi_cyan>VENOMS<reset> next: %s / %s\n", v1 or "none", v2 or "none"))

  local rl = Silverfury.runelore.core.statusLines()
  for _, l in ipairs(rl) do _status_mc:cecho(l .. "\n") end
end

-- Action log update (called by SF_ActionSent event).
function win.onActionSent(_, action)
  if not _visible or not _action_mc then return end
  local a = action or {}
  _action_mc:cecho(string.format("<ansi_cyan>[%s]<reset> %s — %s\n",
    Silverfury.time.hms(),
    a.cmd or "?",
    a.reason or ""
  ))
end

-- ── Event hooks ───────────────────────────────────────────────────────────────

win._handlers = win._handlers or {}
local _handlers = win._handlers

function win.registerHandlers()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end

  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_ActionSent",  win.onActionSent)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("LPrompt", function()
    if _visible then win.refresh() end
  end)
end

function win.shutdown()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end
  if _root then _root:hide() end
  _visible = false
end
