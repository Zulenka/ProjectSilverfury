rwda = rwda or {}
rwda.ui = rwda.ui or {}
rwda.ui.hud = rwda.ui.hud or {
  _win        = nil,
  _statusCon  = nil,
  _targetCon  = nil,
  _actionCon  = nil,
  _timerId           = nil,
  _actionHandlerId   = nil,
  _resizeHandlerId   = nil,
  _actionLog  = {},
  _initialized = false,
  _visible     = true,
}

local hud = rwda.ui.hud

local function geyserOk()
  return type(Geyser) == "table" and type(Geyser.Container) == "function"
end

local function makeFlag(v, on, off)
  return v and ("<chartreuse>[" .. on .. "]<reset>") or ("<MediumSlateBlue>[" .. off .. "]<reset>")
end

local function makeVal(v)
  return "<white>" .. tostring(v) .. "<reset>"
end

local BG_R, BG_G, BG_B = 11, 16, 32  -- #0b1020 deep navy

local function applyBG(con)
  if type(setBackgroundColor) == "function" then
    setBackgroundColor(con, BG_R, BG_G, BG_B, 255)
  end
end

-- ─────────────────────────────────────────────
-- Layout
-- ─────────────────────────────────────────────

function hud.buildLayout()
  local useGUIframe = type(GUIframe) == "table" and type(GUIframe.addWindow) == "function"

  if useGUIframe then
    hud._win = Geyser.Container:new({
      name = "rwdaHUDWin",
      x = 0, y = 0, width = "100%", height = "100%",
    })
    GUIframe.addWindow("rwdaHUDWin", { side = "right" })
  else
    if type(Geyser.UserWindow) == "function" then
      hud._win = Geyser.UserWindow:new({
        name = "rwdaHUDWin",
        docked = true, dockPosition = "right",
        width = 210, height = "60%",
      })
    else
      -- Last-resort: plain container anchored by the user
      hud._win = Geyser.Container:new({
        name = "rwdaHUDWin",
        x = "80%", y = "10%", width = "19%", height = "60%",
      })
    end
  end

  hud._statusCon = Geyser.MiniConsole:new({
    name      = "rwdaHUDStatus",
    x = 0, y = 0, width = "100%", height = "18%",
    fontSize  = 8,
    wrapAt    = 38,
    scrollBar = false,
  }, hud._win)

  hud._targetCon = Geyser.MiniConsole:new({
    name      = "rwdaHUDTarget",
    x = 0, y = "18%", width = "100%", height = "47%",
    fontSize  = 8,
    wrapAt    = 38,
    scrollBar = false,
  }, hud._win)

  hud._actionCon = Geyser.MiniConsole:new({
    name      = "rwdaHUDAction",
    x = 0, y = "65%", width = "100%", height = "35%",
    fontSize  = 8,
    wrapAt    = 38,
    scrollBar = false,
  }, hud._win)

  applyBG(hud._statusCon.name)
  applyBG(hud._targetCon.name)
  applyBG(hud._actionCon.name)
end

-- ─────────────────────────────────────────────
-- Refresh helpers
-- ─────────────────────────────────────────────

function hud.refreshStatus(state)
  clearAll(hud._statusCon.name)
  local f  = state.flags or {}
  local me = state.me or {}

  -- Line 1: core flags
  decho(hud._statusCon.name, makeFlag(f.enabled, "ON", "OFF"))
  decho(hud._statusCon.name, " " .. makeVal(f.mode    or "?"))
  decho(hud._statusCon.name, " " .. makeVal(f.goal    or "?"))
  decho(hud._statusCon.name, " " .. makeVal(f.profile or "?"))

  local retal = rwda.config and rwda.config.retaliation and rwda.config.retaliation.enabled
  local exec  = not (rwda.config and rwda.config.finisher and rwda.config.finisher.enabled == false)

  decho(hud._statusCon.name, " <dim_grey>RETAL:<reset>" ..
    (retal and "<chartreuse>on<reset>" or "<MediumSlateBlue>off<reset>"))
  decho(hud._statusCon.name, " <dim_grey>EXEC:<reset>" ..
    (exec  and "<chartreuse>on<reset>" or "<MediumSlateBlue>off<reset>"))

  if f.stopped then
    decho(hud._statusCon.name, " <tomato>[STOPPED]<reset>")
  end
  decho(hud._statusCon.name, "\n")

  -- Line 2: form + dragon breath
  local form   = me.form or "?"
  local dragon = me.dragon or {}
  decho(hud._statusCon.name, "<dim_grey>Form:<reset>" .. makeVal(form))
  if form == "dragon" then
    decho(hud._statusCon.name, "  <dim_grey>Breath:<reset>" ..
      (dragon.breath_summoned and "<chartreuse>ready<reset>" or "<tomato>missing<reset>"))
  end
  decho(hud._statusCon.name, "\n")
end

function hud.refreshTarget(state)
  clearAll(hud._targetCon.name)
  local t = state.target

  if not t or not t.name then
    decho(hud._targetCon.name, "<dim_grey>No target set.\n")
    return
  end

  -- Line 1: name + availability
  local avail = t.available ~= false
  decho(hud._targetCon.name, "<white>" .. tostring(t.name) .. "<reset>  " ..
    (avail and "<chartreuse>[available]<reset>" or "<tomato>[unavailable]<reset>") .. "\n")

  -- Line 2: status badges
  local shields     = t.defs and t.defs.shield     and t.defs.shield.active
  local rebounding  = t.defs and t.defs.rebounding and t.defs.rebounding.active
  local badges = {
    { label = "Prone",  val = t.prone    },
    { label = "Shield", val = shields    },
    { label = "Reb",    val = rebounding },
    { label = "Fly",    val = t.flying   },
    { label = "Lyred",  val = t.lyred    },
  }
  for _, b in ipairs(badges) do
    local c = b.val and "chartreuse" or "dim_grey"
    decho(hud._targetCon.name,
      "<" .. c .. ">" .. b.label .. (b.val and ":Y" or ":N") .. "<reset>  ")
  end
  decho(hud._targetCon.name, "\n")

  -- Lines 3–4: limb damage bars (5-char, each █ = 20%)
  local limbs = t.limbs or {}
  local function bar(limbName)
    local l   = limbs[limbName] or {}
    local pct = tonumber(l.damage_pct) or 0
    local filled = math.min(5, math.floor(pct / 20 + 0.5))
    local color  = pct >= 80 and "tomato" or pct >= 50 and "yellow" or "green"
    return "<" .. color .. ">" .. string.rep("█", filled) ..
           "<dim_grey>" .. string.rep("░", 5 - filled) .. "<reset>"
  end

  decho(hud._targetCon.name, "<dim_grey>LA:<reset>" .. bar("left_arm")  .. "  ")
  decho(hud._targetCon.name, "<dim_grey>RA:<reset>" .. bar("right_arm") .. "  ")
  decho(hud._targetCon.name, "<dim_grey>LL:<reset>" .. bar("left_leg")  .. "  ")
  decho(hud._targetCon.name, "<dim_grey>RL:<reset>" .. bar("right_leg") .. "\n")
  decho(hud._targetCon.name, "<dim_grey>Hd:<reset>" .. bar("head")  .. "  ")
  decho(hud._targetCon.name, "<dim_grey>To:<reset>" .. bar("torso") .. "\n")

  -- Line 5: active affs
  local affList = {}
  for k, v in pairs(t.affs or {}) do
    if v then affList[#affList + 1] = k end
  end
  table.sort(affList)
  if #affList > 0 then
    decho(hud._targetCon.name,
      "<dim_grey>Affs:<reset> <white>" .. table.concat(affList, ", ") .. "<reset>\n")
  end
end

function hud.refreshAction(state)
  clearAll(hud._actionCon.name)
  decho(hud._actionCon.name, "<dim_grey>Last Actions:\n")

  for _, entry in ipairs(hud._actionLog) do
    local a = entry.action
    if a then
      local cmds = {}
      for _, c in ipairs(a.commands or {}) do
        local s = type(c) == "table" and (c.cmd or c[1] or "") or tostring(c)
        cmds[#cmds + 1] = s
      end
      decho(hud._actionCon.name, "<white>> " .. table.concat(cmds, " | ") .. "<reset>\n")
      if a.reason and a.reason.summary then
        decho(hud._actionCon.name,
          "<dim_grey>  [" .. tostring(a.reason.summary) .. "]<reset>\n")
      end
    end
  end

  local pending = state.runtime and state.runtime.pending_action
  if pending then
    decho(hud._actionCon.name,
      "<yellow>Pending: " .. tostring(pending.name or "?") .. "<reset>\n")
  end
end

-- ─────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────

function hud.refresh()
  if not hud._initialized or not rwda.state then return end
  local ok, err = pcall(function()
    hud.refreshStatus(rwda.state)
    hud.refreshTarget(rwda.state)
    hud.refreshAction(rwda.state)
  end)
  if not ok and rwda.util and rwda.util.log then
    rwda.util.log("warn", "rwda.ui.hud.refresh error: %s", tostring(err))
  end
end

function hud._poll()
  if hud._initialized then hud.refresh() end
  hud._timerId = tempTimer(0.5, "rwda.ui.hud._poll()")
end

function hud.startPolling()
  hud._timerId = tempTimer(0.5, "rwda.ui.hud._poll()")
end

function hud.onResize()
  hud.refresh()
end

function hud.registerHandlers()
  if rwda.engine and rwda.engine.events then
    hud._actionHandlerId = rwda.engine.events.on("ACTION_SENT", function(payload)
      table.insert(hud._actionLog, 1, payload)
      if #hud._actionLog > 5 then table.remove(hud._actionLog) end
      if hud._initialized then
        local ok, err = pcall(hud.refreshAction, rwda.state)
        if not ok and rwda.util then
          rwda.util.log("warn", "hud ACTION_SENT handler: %s", tostring(err))
        end
      end
    end)
  end

  if type(registerAnonymousEventHandler) == "function" then
    hud._resizeHandlerId = registerAnonymousEventHandler(
      "sysWindowResizeEvent", "rwda.ui.hud.onResize")
  end
end

function hud.init()
  if hud._initialized or not geyserOk() then return end
  hud._initialized = true
  hud.buildLayout()
  hud.startPolling()
  hud.registerHandlers()
  hud.refresh()
  if rwda.util and rwda.util.log then
    rwda.util.log("info", "RWDA HUD initialized.")
  end
end

function hud.show()
  hud._visible = true
  if hud._win then hud._win:show() end
end

function hud.hide()
  hud._visible = false
  if hud._win then hud._win:hide() end
end

function hud.shutdown()
  if hud._timerId then
    killTimer(hud._timerId)
    hud._timerId = nil
  end
  if hud._resizeHandlerId and type(killAnonymousEventHandler) == "function" then
    pcall(killAnonymousEventHandler, hud._resizeHandlerId)
    hud._resizeHandlerId = nil
  end
  if hud._actionHandlerId and rwda.engine and rwda.engine.events then
    rwda.engine.events.off("ACTION_SENT", hud._actionHandlerId)
    hud._actionHandlerId = nil
  end
  hud._initialized = false
end
