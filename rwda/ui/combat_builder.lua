rwda = rwda or {}
rwda.ui = rwda.ui or {}
rwda.ui.combat_builder = rwda.ui.combat_builder or {}

local builder = rwda.ui.combat_builder

-- Layout constants (pixels)
local WIN_W  = 520
local WIN_H  = 440
local TITLE_H = 24
local TABS_H  = 24
local BAR_H   = 32
local CONTENT_Y = TITLE_H + TABS_H + BAR_H
local CONTENT_H = WIN_H - CONTENT_Y

local CONSOLE = "rwda_cb_content"
local TABS = { "runewarden", "dragon", "shared", "safety" }
local TAB_W = math.floor(WIN_W / #TABS)

-- Colour palette
local C_BG     = "#1a1a2e"
local C_PANEL  = "#16213e"
local C_ACCENT = "#0f3460"
local C_BTN_OK = "#2e7d32"
local C_BTN_NG = "#c62828"
local C_BTN_NE = "#1565c0"
local C_BTN_WN = "#6a1b9a"
local C_TEXT   = "#e0e0e0"
local C_MUTED  = "#888888"

local function css(bg, fg, extra)
  extra = extra or ""
  return string.format("background-color: %s; color: %s; %s", bg, fg, extra)
end

local function geyserOk()
  return type(Geyser) == "table" and type(Geyser.Window) == "table"
end

-- Mudlet console helpers (gracefully degrade when offline)
local function cprint(text)
  if type(decho) == "function" then
    decho(CONSOLE, text)
  end
end

local function clink(text, cmd, hint)
  if type(echoLink) == "function" then
    echoLink(CONSOLE, text, cmd, hint, true)
  end
end

local function cclear()
  if type(clearWindow) == "function" then
    clearWindow(CONSOLE)
  end
end

-- Create a styled Geyser.Label button
local function makeBtn(name, x, y, w, h, text, callback, parent, bg)
  local lbl = Geyser.Label:new({ name = name, x = x, y = y, width = w, height = h }, parent)
  lbl:setStyleSheet(css(bg or C_ACCENT, C_TEXT, "border-radius:3px;padding:1px;text-align:center;font-size:9pt;"))
  lbl:echo(text)
  lbl:setClickCallback(callback)
  return lbl
end

-- ────────────────────────────────────────────────────────
--  Init: build all Geyser widgets (called lazily on first open)
-- ────────────────────────────────────────────────────────
function builder.init()
  if builder._initialized then return true end
  if not geyserOk() then
    return false, string.format("Geyser unavailable (Geyser=%s, Window=%s)",
      type(Geyser), type(Geyser and Geyser.Window))
  end

  local ok, initErr = pcall(function()
    -- Outer window
    builder._window = Geyser.Window:new({
      name  = "rwda_combat_builder",
      x     = "32%", y = "12%",
      width = WIN_W, height = WIN_H,
    })

    -- Title bar
    local title = Geyser.Label:new({
      name = "rwda_cb_title", x = 0, y = 0, width = WIN_W - 30, height = TITLE_H,
    }, builder._window)
    title:setStyleSheet(css(C_ACCENT, C_TEXT, "text-align:center;font-weight:bold;font-size:10pt;"))
    title:echo("RWDA Combat Builder")

    -- Close button
    makeBtn("rwda_cb_close", WIN_W - 30, 0, 30, TITLE_H, "X",
      function() builder.close() end, builder._window, C_BTN_NG)

    -- Tab buttons
    builder._tab_labels = {}
    for i, tab in ipairs(TABS) do
      local tx = (i - 1) * TAB_W
      local lbl = Geyser.Label:new({
        name = "rwda_cb_tab_" .. tab, x = tx, y = TITLE_H, width = TAB_W, height = TABS_H,
      }, builder._window)
      lbl:setStyleSheet(css(C_PANEL, C_MUTED, "text-align:center;font-size:9pt;"))
      lbl:echo(tab:sub(1,1):upper() .. tab:sub(2))
      local t = tab
      lbl:setClickCallback(function() builder.setTab(t) end)
      builder._tab_labels[tab] = lbl
    end

    -- Action bar
    local barY = TITLE_H + TABS_H
    local bx, by, bw, bh = 4, 4, 58, BAR_H - 8

    builder._btn_apply  = makeBtn("rwda_cb_apply",  bx, barY + by, bw, bh, "Apply",
      function() builder.onApply()  end, builder._window, C_BTN_OK)
    bx = bx + bw + 4
    builder._btn_save   = makeBtn("rwda_cb_save",   bx, barY + by, bw, bh, "Save",
      function() builder.onSave()   end, builder._window, C_BTN_NE)
    bx = bx + bw + 4
    builder._btn_revert = makeBtn("rwda_cb_revert", bx, barY + by, bw, bh, "Revert",
      function() builder.onRevert() end, builder._window, C_BTN_NG)
    bx = bx + bw + 12

    -- Retaliate toggle label + button
    local rl = Geyser.Label:new({ name = "rwda_cb_rl", x = bx, y = barY + by, width = 62, height = bh }, builder._window)
    rl:setStyleSheet(css(C_BG, C_MUTED, "font-size:9pt;"))
    rl:echo("Retaliate:")
    bx = bx + 64
    builder._btn_retaliate = makeBtn("rwda_cb_reto", bx, barY + by, 40, bh, "...",
      function() builder.onToggleRetaliate() end, builder._window, C_BTN_NG)
    bx = bx + 44

    -- Execute toggle label + button
    local el = Geyser.Label:new({ name = "rwda_cb_el", x = bx, y = barY + by, width = 55, height = bh }, builder._window)
    el:setStyleSheet(css(C_BG, C_MUTED, "font-size:9pt;"))
    el:echo("Execute:")
    bx = bx + 57
    builder._btn_execute = makeBtn("rwda_cb_exec", bx, barY + by, 40, bh, "...",
      function() builder.onToggleExecute() end, builder._window, C_BTN_NG)

    -- Content MiniConsole
    builder._content = Geyser.MiniConsole:new({
      name   = CONSOLE,
      x      = 0, y = CONTENT_Y,
      width  = WIN_W, height = CONTENT_H,
    }, builder._window)
    if type(setFont) == "function" then setFont(CONSOLE, "Bitstream Vera Sans Mono") end
    if type(setFontSize) == "function" then setFontSize(CONSOLE, 9) end
    if type(setWindowWrap) == "function" then setWindowWrap(CONSOLE, WIN_W - 8) end

    builder._window:hide()
    builder._initialized = true
  end)

  if not ok then
    -- Clean up any partially-created window so next call retries fresh
    pcall(function() if builder._window then builder._window:hide() end end)
    builder._window       = nil
    builder._content      = nil
    builder._tab_labels   = nil
    builder._initialized  = false
    return false, tostring(initErr or "widget creation failed (check Mudlet error console)")
  end

  return true
end

-- ────────────────────────────────────────────────────────
--  Public API
-- ────────────────────────────────────────────────────────
function builder.open()
  if not builder._initialized then
    local ok, err = builder.init()
    if not ok then
      rwda.util.log("warn", "combat_builder.open: init failed: %s", tostring(err))
      return false, err
    end
  end
  rwda.ui.combat_builder_state.open()
  builder._window:show()
  builder.refresh()
  return true
end

function builder.close()
  if builder._initialized and builder._window then
    builder._window:hide()
  end
  rwda.ui.combat_builder_state.close()
end

function builder.isOpen()
  return builder._initialized
    and builder._window ~= nil
    and rwda.ui.combat_builder_state.isOpen()
end

function builder.setTab(tab)
  builder._active_tab = tab or "runewarden"
  builder.refresh()
end

-- ────────────────────────────────────────────────────────
--  State helpers
-- ────────────────────────────────────────────────────────
local function workingState()
  return rwda.ui.combat_builder_state.get()
end

local function activeProfile()
  local ws = workingState()
  local strat = ws and ws.strategy or {}
  local p = type(strat.active_profile) == "string" and strat.active_profile or ""
  return p ~= "" and p or "duel"
end

local function blocksForMode(modeKey)
  local ws = workingState()
  if not ws then return {} end
  local strat = ws.strategy or {}
  local prof  = (strat.profiles or {})[activeProfile()] or {}
  local mode  = prof[modeKey] or {}
  return mode.blocks or {}
end

local function workingRetal()
  local ws = workingState()
  return ws and ws.retaliation or {}
end

local function workingFinisher()
  local ws = workingState()
  return ws and ws.finisher or {}
end

-- ────────────────────────────────────────────────────────
--  Top-bar refresh
-- ────────────────────────────────────────────────────────
local function refreshTopBar()
  local retEnabled = workingRetal().enabled == true
  local exEnabled  = workingFinisher().enabled ~= false

  local function btnStyle(on)
    local bg = on and C_BTN_OK or C_BTN_NG
    return css(bg, C_TEXT, "border-radius:3px;padding:1px;text-align:center;font-size:9pt;")
  end

  if builder._btn_retaliate then
    builder._btn_retaliate:setStyleSheet(btnStyle(retEnabled))
    builder._btn_retaliate:echo(retEnabled and "ON" or "OFF")
  end
  if builder._btn_execute then
    builder._btn_execute:setStyleSheet(btnStyle(exEnabled))
    builder._btn_execute:echo(exEnabled and "ON" or "OFF")
  end
end

local function refreshTabHighlights()
  local active = builder._active_tab or "runewarden"
  for _, tab in ipairs(TABS) do
    local lbl = builder._tab_labels and builder._tab_labels[tab]
    if lbl then
      if tab == active then
        lbl:setStyleSheet(css(C_ACCENT, C_TEXT, "text-align:center;font-weight:bold;font-size:9pt;"))
      else
        lbl:setStyleSheet(css(C_PANEL, C_MUTED, "text-align:center;font-size:9pt;"))
      end
    end
  end
end

-- ────────────────────────────────────────────────────────
--  Tab renderers
-- ────────────────────────────────────────────────────────
local function sortedBlocks(blocks)
  local t = {}
  for _, b in ipairs(blocks or {}) do
    if type(b) == "table" then t[#t+1] = b end
  end
  table.sort(t, function(a, b)
    local pa = tonumber(a.priority) or 0
    local pb = tonumber(b.priority) or 0
    return pa > pb
  end)
  return t
end

local function renderBlocksTable(modeKey, heading)
  cprint(string.format("\n<yellow>%s Blocks<reset>\n", heading))

  local blocks = sortedBlocks(blocksForMode(modeKey))
  if #blocks == 0 then
    cprint("  <gray>(none)<reset>\n")
    return
  end

  for _, b in ipairs(blocks) do
    local id       = tostring(b.id or "?")
    local enabled  = b.enabled ~= false
    local priority = math.floor(tonumber(b.priority) or 0)

    local toggleCmd = string.format(
      "rwda.ui.combat_builder.toggleBlock(%q, %q)", modeKey, id)
    local upCmd = string.format(
      "rwda.ui.combat_builder.adjustPriority(%q, %q, 5)", modeKey, id)
    local downCmd = string.format(
      "rwda.ui.combat_builder.adjustPriority(%q, %q, -5)", modeKey, id)

    -- color tag must be in the same string as the text, not a standalone decho call
    cprint("  ")
    if enabled then
      clink("<0,180,0>[ON ]<reset>", toggleCmd, "Toggle " .. id)
    else
      clink("<180,40,40>[OFF]<reset>", toggleCmd, "Toggle " .. id)
    end
    local nameFmt = enabled and "<white>  %-26s<reset>" or "<gray>  %-26s<reset>"
    cprint(string.format(nameFmt, id))
    clink("  <gray>+<reset>", upCmd,   "+5 priority")
    cprint(string.format(" <white>%3d<reset> ", priority))
    clink("<gray>-<reset>", downCmd, "-5 priority")
    cprint("\n")
  end
end

local function renderFinisherPanel(modeKey)
  local finCfg   = workingFinisher()
  local cfgFin   = rwda.config and rwda.config.finisher or {}
  local fbs      = finCfg.fallback_blocks or cfgFin.fallback_blocks or {}
  local modeId   = (modeKey == "runewarden") and "human_dualcut" or "dragon_silver"
  local finName  = (modeKey == "runewarden") and "disembowel" or "devour"
  local fallback = fbs[modeId] or "none"

  local exEnabled = finCfg.enabled ~= false
  local exCmd     = "rwda.ui.combat_builder.onToggleExecute()"

  cprint(string.format("\n<yellow>Auto-Execute  <gray>(%s)<reset>\n", finName))
  cprint("  ")
  if exEnabled then
    clink("<0,180,0>[ON ]<reset>", exCmd, "Toggle auto-execute")
  else
    clink("<180,40,40>[OFF]<reset>", exCmd, "Toggle auto-execute")
  end
  cprint(string.format("  <gray>fallback: <cyan>%s<reset>\n", fallback))
end

local function renderRunewardenTab()
  renderBlocksTable("runewarden", "Runewarden")
  renderFinisherPanel("runewarden")
  local rwCfg  = rwda.config and rwda.config.runewarden or {}
  local venoms = rwCfg.venoms or {}
  local mainV  = (venoms.dsl_main or {})[1] or "curare"
  local offV   = (venoms.dsl_off  or {})[1] or "epteth"
  cprint("\n<yellow>DSL Venoms<reset>\n")
  cprint(string.format("  <gray>Main:<reset> <white>%-12s<reset>  <gray>Off:<reset> <white>%s<reset>\n", mainV, offV))
  cprint("  <gray>rwda set venoms <main> <off><reset>\n")
end

local function renderDragonTab()
  renderBlocksTable("dragon", "Dragon")
  renderFinisherPanel("dragon")
  local dragon    = rwda.config and rwda.config.dragon or {}
  local breathType = dragon.breath_type or "lightning"
  local cursePrio  = dragon.curse_priority     or { "impatience", "asthma", "paralysis", "stupidity" }
  local gutPrio    = dragon.gut_venom_priority or { "curare", "kalmia", "gecko", "slike", "aconite" }

  cprint("\n<yellow>Dragon Config<reset>\n")
  cprint(string.format("  <gray>Breath:      <reset><white>%s<reset>  <gray>(set breath <type>)<reset>\n", breathType))
  cprint(string.format("  <gray>Curse order: <reset><white>%s<reset>\n", table.concat(cursePrio, " > ")))
  cprint("  <gray>(set cursepriority impatience asthma paralysis stupidity)<reset>\n")
  cprint(string.format("  <gray>Gut venoms:  <reset><white>%s<reset>\n", table.concat(gutPrio, " > ")))
  cprint("  <gray>(set gutvenompriority curare kalmia gecko slike aconite)<reset>\n")
end

local function renderSharedTab()
  local ret      = workingRetal()
  local integCfg = rwda.config and rwda.config.integration or {}
  local combCfg  = rwda.config and rwda.config.combat or {}

  local retEnabled  = ret.enabled == true
  local lockMs      = tonumber(ret.lock_ms)          or 8000
  local debounceMs  = tonumber(ret.swap_debounce_ms) or 1500
  local minConf     = tonumber(ret.min_confidence)   or 0.65
  local restorePrev = ret.restore_previous_target ~= false
  local ignNonPlay  = ret.ignore_non_players ~= false

  local autostart  = integCfg.auto_enable_with_legacy ~= false
  local followLeg  = integCfg.follow_legacy_target ~= false
  local promptTick = combCfg.auto_tick_on_prompt == true

  local retCmd     = "rwda.ui.combat_builder.onToggleRetaliate()"
  local restoreCmd = "rwda.ui.combat_builder.onToggleRestorePrev()"
  local ignNPCmd   = "rwda.ui.combat_builder.onToggleIgnNonPlay()"
  local astartCmd  = "rwda.ui.combat_builder.onToggleAutostart()"
  local followCmd  = "rwda.ui.combat_builder.onToggleFollowLegacy()"
  local ptickCmd   = "rwda.ui.combat_builder.onTogglePromptTick()"

  local function tog(v, cmd, label)
    cprint("  ")
    if v then
      clink("<0,180,0>[ON ]<reset>", cmd, label)
    else
      clink("<180,40,40>[OFF]<reset>", cmd, label)
    end
    cprint("  <gray>" .. label .. "<reset>\n")
  end

  cprint("\n<yellow>Auto-Retaliation<reset>\n")
  cprint("  ")
  if retEnabled then
    clink("<0,180,0>[ON ]<reset>", retCmd, "Toggle retaliation")
  else
    clink("<180,40,40>[OFF]<reset>", retCmd, "Toggle retaliation")
  end
  cprint(string.format("  <gray>lock:<reset> <white>%dms<reset>  <gray>dbnc:<reset> <white>%dms<reset>  <gray>conf:<reset> <white>%.2f<reset>\n", lockMs, debounceMs, minConf))
  cprint("  <gray>(rwda set retalockms / retaldebounce / retalminconf)<reset>\n")
  tog(restorePrev, restoreCmd, "restore prev target")
  tog(ignNonPlay,  ignNPCmd,   "ignore non-players")

  cprint("\n<yellow>Integration<reset>\n")
  tog(autostart,  astartCmd, "auto-enable with Legacy")
  tog(followLeg,  followCmd,  "follow Legacy target")
  tog(promptTick, ptickCmd,   "tick on each prompt")
end

local function renderSafetyTab()
  local finCfg    = rwda.config and rwda.config.finisher or {}
  local to        = finCfg.timeouts or {}
  local fbs       = finCfg.fallback_blocks or {}
  local parserCfg = rwda.config and rwda.config.parser or {}

  local stopCmd = "rwda.ui.commands.handle('stop')"

  cprint("\n<yellow>Emergency<reset>\n")
  cprint("  ")
  clink("<180,40,40>[STOP NOW]<reset>", stopCmd, "Stop RWDA immediately")
  cprint("  <gray>disables offense + clears queues<reset>\n")

  cprint("\n<yellow>Finisher Limits<reset>\n")
  cprint(string.format("  <gray>Cooldown:        <reset><white>%dms<reset>  <gray>(set executecooldown <ms>)<reset>\n",
    tonumber(finCfg.cooldown_ms)        or 1500))
  cprint(string.format("  <gray>Fallback window: <reset><white>%dms<reset>  <gray>(set executefallbackwindow <ms>)<reset>\n",
    tonumber(finCfg.fallback_window_ms) or 6000))
  cprint(string.format("  <gray>Disembowel TO:   <reset><white>%dms<reset>  <gray>(set executetimeout disembowel <ms>)<reset>\n",
    tonumber(to.disembowel_ms)          or 2500))
  cprint(string.format("  <gray>Devour TO:       <reset><white>%dms<reset>  <gray>(set executetimeout devour <ms>)<reset>\n",
    tonumber(to.devour_ms)              or 8000))
  cprint(string.format("  <gray>Fallback human:  <reset><white>%s<reset>  <gray>(set executefallback human <block>)<reset>\n",
    fbs.human_dualcut or "none"))
  cprint(string.format("  <gray>Fallback dragon: <reset><white>%s<reset>  <gray>(set executefallback dragon <block>)<reset>\n",
    fbs.dragon_silver  or "none"))

  local captureOn  = parserCfg.capture_unmatched_lines == true
  local captPrompt = parserCfg.capture_unmatched_include_prompts == true
  local captPath   = parserCfg.capture_unmatched_path or "(default)"

  local capCmd  = "rwda.ui.combat_builder.onToggleCapture()"
  local capPCmd = "rwda.ui.combat_builder.onToggleCapturePrompts()"

  cprint("\n<yellow>Capture Log<reset>\n")
  cprint("  ")
  if captureOn then
    clink("<0,180,0>[ON ]<reset>", capCmd, "Toggle unmatched line capture")
  else
    clink("<180,40,40>[OFF]<reset>", capCmd, "Toggle unmatched line capture")
  end
  cprint("  <gray>capture unmatched lines<reset>\n")

  cprint("  ")
  if captPrompt then
    clink("<0,180,0>[ON ]<reset>", capPCmd, "Toggle prompt capture")
  else
    clink("<180,40,40>[OFF]<reset>", capPCmd, "Toggle prompt capture")
  end
  cprint("  <gray>include prompts<reset>\n")
  cprint(string.format("  <gray>Path: <reset><white>%s<reset>\n", captPath))
  cprint("  <gray>(set capturepath <path>)<reset>\n")
end

-- ────────────────────────────────────────────────────────
--  Main refresh
-- ────────────────────────────────────────────────────────
function builder.refresh()
  if not builder._initialized then return end

  refreshTopBar()
  refreshTabHighlights()
  cclear()

  local profName = activeProfile()
  cprint(string.format("<yellow>Profile: <white>%s<reset>\n", profName))

  local tab = builder._active_tab or "runewarden"
  if     tab == "runewarden" then renderRunewardenTab()
  elseif tab == "dragon"     then renderDragonTab()
  elseif tab == "shared"     then renderSharedTab()
  elseif tab == "safety"     then renderSafetyTab()
  end
end

-- ────────────────────────────────────────────────────────
--  Action handlers (called from echoLink Lua commands)
-- ────────────────────────────────────────────────────────
function builder.onApply()
  local ok, err = rwda.ui.combat_builder_state.apply()
  if ok then
    rwda.util.log("info", "combat_builder: changes applied.")
  else
    rwda.util.log("warn", "combat_builder: apply failed: %s", tostring(err))
  end
  builder.refresh()
end

function builder.onSave()
  local ok, err = rwda.ui.combat_builder_state.apply()
  if not ok then
    rwda.util.log("warn", "combat_builder: apply before save failed: %s", tostring(err))
    return
  end
  if rwda.config and rwda.config.savePersisted then
    local saveOk, result = rwda.config.savePersisted()
    if saveOk then
      rwda.util.log("info", "combat_builder: saved to %s", tostring(result))
    else
      rwda.util.log("warn", "combat_builder: save failed: %s", tostring(result))
    end
  else
    rwda.util.log("warn", "combat_builder: config persistence unavailable.")
  end
  builder.refresh()
end

function builder.onRevert()
  rwda.ui.combat_builder_state.revert()
  rwda.util.log("info", "combat_builder: reverted to live config.")
  builder.refresh()
end

function builder.onToggleRetaliate()
  local ws = workingState()
  if not ws then
    rwda.ui.combat_builder_state.open()
    ws = workingState()
    if not ws then return end
  end
  local cur = ws.retaliation and ws.retaliation.enabled == true
  rwda.ui.combat_builder_state.setRetaliationEnabled(not cur)
  builder.refresh()
end

function builder.onToggleExecute()
  local ws = workingState()
  if not ws then
    rwda.ui.combat_builder_state.open()
    ws = workingState()
    if not ws then return end
  end
  local cur = not (ws.finisher and ws.finisher.enabled == false)
  rwda.ui.combat_builder_state.setFinisherEnabled(not cur)
  builder.refresh()
end

function builder.onToggleRestorePrev()
  local ws = workingState()
  if not ws then
    rwda.ui.combat_builder_state.open()
    ws = workingState()
    if not ws then return end
  end
  ws.retaliation = ws.retaliation or {}
  ws.retaliation.restore_previous_target = not (ws.retaliation.restore_previous_target ~= false)
  builder.refresh()
end

function builder.onToggleIgnNonPlay()
  local ws = workingState()
  if not ws then
    rwda.ui.combat_builder_state.open()
    ws = workingState()
    if not ws then return end
  end
  ws.retaliation = ws.retaliation or {}
  ws.retaliation.ignore_non_players = not (ws.retaliation.ignore_non_players ~= false)
  builder.refresh()
end

function builder.onToggleAutostart()
  local cfg = rwda.config
  if not cfg then return end
  cfg.integration = cfg.integration or {}
  cfg.integration.auto_enable_with_legacy = not (cfg.integration.auto_enable_with_legacy ~= false)
  builder.refresh()
end

function builder.onToggleFollowLegacy()
  local cfg = rwda.config
  if not cfg then return end
  cfg.integration = cfg.integration or {}
  cfg.integration.follow_legacy_target = not (cfg.integration.follow_legacy_target ~= false)
  builder.refresh()
end

function builder.onTogglePromptTick()
  local cfg = rwda.config
  if not cfg then return end
  cfg.combat = cfg.combat or {}
  cfg.combat.auto_tick_on_prompt = not (cfg.combat.auto_tick_on_prompt == true)
  builder.refresh()
end

function builder.onToggleCapture()
  local cfg = rwda.config
  if not cfg then return end
  cfg.parser = cfg.parser or {}
  cfg.parser.capture_unmatched_lines = not (cfg.parser.capture_unmatched_lines == true)
  builder.refresh()
end

function builder.onToggleCapturePrompts()
  local cfg = rwda.config
  if not cfg then return end
  cfg.parser = cfg.parser or {}
  cfg.parser.capture_unmatched_include_prompts = not (cfg.parser.capture_unmatched_include_prompts == true)
  builder.refresh()
end

function builder.toggleBlock(modeKey, blockId)
  local ws = workingState()
  if not ws then return end

  local strat    = ws.strategy or {}
  local profiles = strat.profiles or {}
  local prof     = profiles[activeProfile()] or {}
  local mode     = prof[modeKey] or {}
  local blocks   = mode.blocks or {}

  local currentEnabled = true
  for _, b in ipairs(blocks) do
    if tostring(b.id or "") == blockId then
      currentEnabled = b.enabled ~= false
      break
    end
  end

  rwda.ui.combat_builder_state.setStrategyBlock(modeKey, blockId, not currentEnabled, nil)
  builder.refresh()
end

function builder.adjustPriority(modeKey, blockId, delta)
  local ws = workingState()
  if not ws then return end

  local strat    = ws.strategy or {}
  local profiles = strat.profiles or {}
  local prof     = profiles[activeProfile()] or {}
  local mode     = prof[modeKey] or {}
  local blocks   = mode.blocks or {}

  local cur = 0
  for _, b in ipairs(blocks) do
    if tostring(b.id or "") == blockId then
      cur = tonumber(b.priority) or 0
      break
    end
  end

  local newPri = math.max(0, cur + (tonumber(delta) or 0))
  rwda.ui.combat_builder_state.setStrategyBlock(modeKey, blockId, nil, newPri)
  builder.refresh()
end

-- ────────────────────────────────────────────────────────
--  Lifecycle hooks (called from init.lua)
-- ────────────────────────────────────────────────────────
function builder.bootstrap()
  -- Lazy init on first open; nothing needed here.
  return true
end

function builder.shutdown()
  if builder._initialized then
    pcall(function()
      if builder._window then builder._window:hide() end
    end)
    rwda.ui.combat_builder_state.close()
  end
  builder._initialized  = false
  builder._window       = nil
  builder._content      = nil
  builder._tab_labels   = nil
  builder._btn_retaliate = nil
  builder._btn_execute  = nil
  builder._btn_apply    = nil
  builder._btn_save     = nil
  builder._btn_revert   = nil
end
