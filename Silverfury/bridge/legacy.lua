-- Silverfury/bridge/legacy.lua
-- Read-only integration with the Legacy curing system.
-- Never modifies Legacy — only listens and reads.

Silverfury = Silverfury or {}
Silverfury.bridge = Silverfury.bridge or {}

Silverfury.bridge.legacy = Silverfury.bridge.legacy or {}
local legacy = Silverfury.bridge.legacy

legacy._handlers = legacy._handlers or {}
local _handlers = legacy._handlers

-- ── Detection ────────────────────────────────────────────────────────────────

function legacy.isPresent()
  return type(Legacy) == "table"
end

-- ── Reading Legacy state ──────────────────────────────────────────────────────

-- Returns set of current afflictions from Legacy (keys = aff names, val = true).
function legacy.getAffs()
  if not legacy.isPresent() then return {} end
  local affs = {}
  if type(Legacy.Curing) == "table" and type(Legacy.Curing.Affs) == "table" then
    for k, v in pairs(Legacy.Curing.Affs) do
      if v then affs[k] = true end
    end
  end
  return affs
end

-- Returns set of current defences from Legacy.
function legacy.getDefs()
  if not legacy.isPresent() then return {} end
  local defs = {}
  if type(Legacy.Curing) == "table" and type(Legacy.Curing.Defs) == "table" then
    for k, v in pairs(Legacy.Curing.Defs) do
      if v then defs[k] = true end
    end
  end
  return defs
end

-- Returns bal/eq booleans from Legacy.
function legacy.getBals()
  local bal, eq = true, true
  if legacy.isPresent() and type(Legacy.Curing) == "table" then
    local b = Legacy.Curing.bal
    if b ~= nil then bal = b end
    local e = Legacy.Curing.eq
    if e ~= nil then eq = e end
  end
  return bal, eq
end

-- ── Sync into Silverfury state ────────────────────────────────────────────────

function legacy.sync()
  if not legacy.isPresent() then return end
  local me = Silverfury.state.me

  -- Affs
  local affs = legacy.getAffs()
  me.affs = affs

  -- Defs
  local defs = legacy.getDefs()
  me.defs = defs

  -- Balance / equilibrium
  local bal, eq = legacy.getBals()
  me.bal = bal
  me.eq  = eq
end

-- ── Event wiring ─────────────────────────────────────────────────────────────

local function onLegacyLoaded()
  Silverfury.log.info("Legacy detected and loaded.")
  legacy.sync()
  if Silverfury.config.get("integration.auto_enable_with_legacy") then
    if not Silverfury.state.flags.armed then
      Silverfury.safety.arm()
    end
  end
end

local function onPrompt()
  legacy.sync()
  if Silverfury.state.flags.auto_tick then
    Silverfury.core.tick("LPrompt")
  end
end

local function onAffAdd(_, affName)
  if affName then Silverfury.state.me.affs[affName] = true end
end

local function onAffRemove(_, affName)
  if affName then Silverfury.state.me.affs[affName] = nil end
end

local function onDefAdd(_, defName)
  if defName then Silverfury.state.me.defs[defName] = true end
end

local function onDefRemove(_, defName)
  if defName then Silverfury.state.me.defs[defName] = nil end
end

function legacy.registerHandlers()
  -- Clear old handlers.
  for _, id in ipairs(_handlers) do
    killAnonymousEventHandler(id)
  end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end

  _handlers[#_handlers+1] = registerAnonymousEventHandler("LegacyLoaded",         onLegacyLoaded)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("LPrompt",               onPrompt)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Char.Afflictions.Add",    onAffAdd)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Char.Afflictions.Remove", onAffRemove)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Char.Defences.Add",       onDefAdd)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("gmcp.Char.Defences.Remove",    onDefRemove)

  -- If Legacy is already loaded at register time, fire immediately.
  if legacy.isPresent() then
    onLegacyLoaded()
  else
    -- Fallback timer: poll until detected.
    local wait = Silverfury.config.get("integration.wait_for_legacy_ms") or 5000
    tempTimer(wait / 1000, function()
      if not legacy.isPresent() then
        Silverfury.log.warn("Legacy not detected after " .. wait .. "ms — running without it.")
      end
    end)
  end
end

function legacy.shutdown()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end
end
