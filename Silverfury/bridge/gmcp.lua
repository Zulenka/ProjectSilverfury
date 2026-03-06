-- Silverfury/bridge/gmcp.lua
-- GMCP data bridge: Char.Vitals, Room.Players, Char.Status.

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

-- ── Registration ─────────────────────────────────────────────────────────────

function gmcp.registerHandlers()
  for _, id in ipairs(_handlers) do killHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end

  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Char.Vitals",    onVitals)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Room.Players",   onRoomPlayers)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Room.Info",       onRoomInfo)
end

function gmcp.shutdown()
  for _, id in ipairs(_handlers) do killHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end
end
