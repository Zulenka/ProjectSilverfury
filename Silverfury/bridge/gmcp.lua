-- Silverfury/bridge/gmcp.lua
-- GMCP data bridge: Char.Vitals, Room.Players, Char.Status,
-- IRE.Target.Set (auto-target), IRE.Target.Status (target HP%).

Silverfury = Silverfury or {}
Silverfury.bridge = Silverfury.bridge or {}

Silverfury.bridge.gmcp = Silverfury.bridge.gmcp or {}
local gmcp = Silverfury.bridge.gmcp

gmcp._handlers = gmcp._handlers or {}
local _handlers = gmcp._handlers

-- ── Vitals ──────────────────────────────────────────────────────────────────

local function onVitals()
  local v = gmcp and gmcp.Char and gmcp.Char.Vitals
  if type(v) ~= "table" then return end
  local me = Silverfury.state.me

  me.hp    = tonumber(v.hp)    or me.hp
  me.maxhp = tonumber(v.maxhp) or me.maxhp
  me.mp    = tonumber(v.mp)    or me.mp
  me.maxmp = tonumber(v.maxmp) or me.maxmp
  me.wp    = tonumber(v.wp)    or me.wp
  me.maxwp = tonumber(v.maxwp) or me.maxwp
  me.en    = tonumber(v.en)    or me.en
  me.maxen = tonumber(v.maxen) or me.maxen

  -- Balance / eq
  if v.bal ~= nil then me.bal = (v.bal == "1" or v.bal == true) end
  if v.eq  ~= nil then me.eq  = (v.eq  == "1" or v.eq  == true) end

  -- Flush executor if balance restored.
  if Silverfury.engine and Silverfury.engine.queue then
    Silverfury.engine.queue.onBalanceRestored()
  end
end

-- ── Room players ─────────────────────────────────────────────────────────────

local function onRoomPlayers()
  local players = gmcp and gmcp.Room and gmcp.Room.Players
  if type(players) ~= "table" then return end

  local room = Silverfury.state.room
  room.players = {}
  for _, p in ipairs(players) do
    if type(p) == "table" and p.name then
      room.players[p.name:lower()] = true
    end
  end

  -- Refresh target availability.
  local target = Silverfury.state.target
  if target.name then
    target.in_room = room.players[target.name:lower()] == true
  end
end

local function onRoomInfo()
  local info = gmcp and gmcp.Room and gmcp.Room.Info
  if type(info) ~= "table" then return end
  local room = Silverfury.state.room
  local old_num = room.num
  room.num  = tonumber(info.num)  or room.num
  room.name = info.name           or room.name
  room.area = info.area           or room.area

  -- Room change check.
  if old_num and room.num and old_num ~= room.num then
    Silverfury.log.trace("Room changed: %d → %d", old_num, room.num)
    raiseEvent("SF_RoomChanged", old_num, room.num)
  end
end

-- ── Char.Status (dragon form detection) ──────────────────────────────────────

local function onCharStatus()
  local st = gmcp and gmcp.Char and gmcp.Char.Status
  if type(st) ~= "table" then return end
  local race = (st.race or ""):lower()
  local me   = Silverfury.state.me
  local cur  = me.form
  if race:find("dragon") then
    if cur ~= "dragon" then
      me.form = "dragon"
      raiseEvent("SF_DragonFormGained")
      Silverfury.log.info("Dragon: dragon form detected via GMCP (race: %s)", tostring(st.race))
    end
  else
    if cur == "dragon" then
      me.form = "human"
      raiseEvent("SF_DragonFormLost")
      Silverfury.log.info("Dragon: human form detected via GMCP (race: %s)", tostring(st.race))
    end
  end
end

-- ── IRE.Target.Set (auto-target from in-game settarget) ──────────────────────
-- RWDA groupcombat integration pattern: read target name from GMCP.
-- Fires when the player uses `settarget <name>` in Achaea.
-- Mudlet stores the data at gmcp.IRE.Target with a "name" field.

local function onTargetSet()
  local t = gmcp and gmcp.IRE and gmcp.IRE.Target
  if type(t) ~= "table" then return end
  local tname = t.name or t.Name or ""
  if tname == "" then return end
  local tgt = Silverfury.state.target
  if (tgt.name or ""):lower() ~= tname:lower() then
    Silverfury.state.target.setName(tname)
    Silverfury.log.info("Target: auto-set from GMCP settarget → %s", tname)
  end
end

-- ── IRE.Target.Status (target HP% for bisect eligibility) ────────────────────
-- When available, syncs target HP/mana percentage into tgt.hp_pct / tgt.mana_pct
-- for use by the Hugalaz bisect threshold check and devour estimator.

local function onTargetStatus()
  local s = gmcp and gmcp.IRE and gmcp.IRE.Target and gmcp.IRE.Target.Status
  if type(s) ~= "table" then return end
  local tgt    = Silverfury.state.target
  local hp_pct = tonumber(s.hppercent) or tonumber(s.hp_percent)
             or tonumber(s.hpPercent)
  local mp_pct = tonumber(s.mppercent) or tonumber(s.mp_percent)
             or tonumber(s.mpPercent)
  if hp_pct then tgt.hp_pct   = hp_pct / 100 end
  if mp_pct then tgt.mana_pct = mp_pct / 100 end
end

-- ── Registration ─────────────────────────────────────────────────────────────

function gmcp.registerHandlers()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end

  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Char.Vitals",       onVitals)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Room.Players",      onRoomPlayers)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Room.Info",          onRoomInfo)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Char.Status",        onCharStatus)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.IRE.Target.Set",     onTargetSet)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.IRE.Target.Status",  onTargetStatus)
end

function gmcp.shutdown()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end
end
