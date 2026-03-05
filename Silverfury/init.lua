-- Silverfury/init.lua
-- Bootstrap entry point. Load order matters — dependencies first.
-- Version: 1.0.0

Silverfury = Silverfury or {}
Silverfury.VERSION = "1.0.0"

-- ── Load order ────────────────────────────────────────────────────────────────
-- Modules are loaded in dependency order.
-- Each module registers itself into the Silverfury namespace.

-- Detect this file's directory so all relative loads resolve correctly.
-- In Mudlet, dofile() sets debug.getinfo source to the file path with @ prefix.
local BASE_DIR do
  local src = debug and debug.getinfo(1,"S") and debug.getinfo(1,"S").source or ""
  local dir = src:match("^@(.+[/\\])[^/\\]+$")  -- strip filename, keep trailing sep
  if dir and dir ~= "" then
    BASE_DIR = dir:gsub("[/\\]+$", "")  -- strip trailing sep; we add it in path()
  else
    -- Fallback: assume installed in getMudletHomeDir()/Silverfury/
    BASE_DIR = getMudletHomeDir() .. "/Silverfury"
  end
end

-- Resolve path relative to this file's directory.
local function path(...)
  local parts = { BASE_DIR }
  for _, p in ipairs({...}) do parts[#parts+1] = p end
  -- Collapse any double-slashes.
  return table.concat(parts, "/"):gsub("//+", "/")
end

local function load(...)
  local p = path(...)
  local fn, err = loadfile(p)
  if not fn then
    error("[Silverfury] Failed to load " .. tostring(p) .. ": " .. tostring(err))
  end
  fn()
end

-- ── Module load sequence ──────────────────────────────────────────────────────

local function loadAll()
  -- Utilities (no dependencies)
  load("util/log.lua")
  load("util/time.lua")
  load("util/table.lua")
  load("util/files.lua")

  -- Configuration (depends on log)
  load("config.lua")
  Silverfury.config.init()

  -- Logging setup (depends on config, util)
  load("logging/formats.lua")
  load("logging/logger.lua")

  -- State (depends on log, time)
  load("state/me.lua")
  load("state/target.lua")
  load("state/room.lua")

  -- Engine (depends on config, state, log, time)
  load("engine/queue.lua")
  load("engine/safety.lua")
  load("engine/planner.lua")

  -- Data tables (depends on config — no other SF deps)
  load("data/afflictions.lua")

  -- Offense (depends on config, state, engine, data)
  load("offense/venoms.lua")
  load("offense/attacks.lua")

  -- Runelore (depends on config, state, engine)
  load("runelore/runes.lua")
  load("runelore/core.lua")

  -- Scenarios (depends on all above)
  load("scenarios/base.lua")
  load("scenarios/venomlock.lua")
  load("scenarios/runelore_kill.lua")

  -- Retaliation (depends on state, safety)
  load("retaliate.lua")

  -- Parsers (depends on state, engine, logging)
  load("parser/incoming.lua")
  load("parser/outgoing.lua")

  -- Bridges (depends on state, engine, safety)
  load("bridge/gmcp.lua")
  load("bridge/legacy.lua")
  load("bridge/ak.lua")

  -- UI (depends on everything)
  load("ui/components.lua")
  load("ui/window.lua")
  load("ui/bindings.lua")
end

-- ── Flags / runtime state ─────────────────────────────────────────────────────

Silverfury.state = Silverfury.state or {}
Silverfury.state.flags = {
  armed           = false,
  auto_tick       = true,
  attack_enabled  = false,
}

-- ── Core tick ─────────────────────────────────────────────────────────────────
-- Called on each LPrompt event (or manually via "sf tick").
-- This is the single "decision boundary" for the whole system.

Silverfury.core = Silverfury.core or {}

function Silverfury.core.tick(source)
  -- Heartbeat for deadman timer.
  Silverfury.safety.heartbeat()

  -- Update retaliation state.
  Silverfury.retaliate.update()

  -- Choose and execute next action.
  local action = Silverfury.engine.planner.choose()
  if action and action.type ~= "idle" then
    Silverfury.engine.planner.execute(action)
  end

  -- Log prompt snapshot.
  Silverfury.logging.logger.write("PROMPT_SNAPSHOT", { source=source })
end

-- ── Bootstrap ─────────────────────────────────────────────────────────────────

function Silverfury.bootstrap()
  -- Load all modules.
  local ok, err = pcall(loadAll)
  if not ok then
    error("[Silverfury] Boot failed: " .. tostring(err))
  end

  -- Auto-load persisted config if enabled.
  if Silverfury.config.get("persistence.auto_load") and Silverfury.config.exists() then
    Silverfury.config.load()
  end

  -- Initialise logging.
  Silverfury.logging.logger.init()

  -- Register runelore event hooks.
  Silverfury.runelore.core.init()
  Silverfury.runelore.core.registerHandlers()

  -- Register parser hooks.
  Silverfury.parser.incoming.registerHandlers()
  Silverfury.parser.outgoing.registerHandlers()

  -- Register bridge hooks.
  Silverfury.bridge.gmcp.registerHandlers()
  Silverfury.bridge.legacy.registerHandlers()
  Silverfury.bridge.ak.registerHandlers()

  -- Register safety event hooks.
  Silverfury.safety.registerHandlers()

  -- Register retaliation event hooks.
  Silverfury.retaliate.registerHandlers()

  -- Register UI command alias.
  Silverfury.ui.bindings.registerAlias()

  -- Register UI event hooks.
  Silverfury.ui.window.registerHandlers()

  -- Restore HUD state from config.
  if Silverfury.config.get("ui.open_on_start") then
    Silverfury.ui.window.open()
  end

  Silverfury.log.info("Silverfury v%s ready. Type 'sf help' to get started.", Silverfury.VERSION)
end

-- ── Shutdown ──────────────────────────────────────────────────────────────────

function Silverfury.shutdown()
  Silverfury.safety.disarm()
  Silverfury.safety.shutdown()
  Silverfury.retaliate.shutdown()
  Silverfury.parser.incoming.shutdown()
  Silverfury.parser.outgoing.shutdown()
  Silverfury.bridge.gmcp.shutdown()
  Silverfury.bridge.legacy.shutdown()
  Silverfury.bridge.ak.shutdown()
  Silverfury.runelore.core.shutdown()
  Silverfury.ui.bindings.shutdown()
  Silverfury.ui.window.shutdown()
  Silverfury.logging.logger.shutdown()
  Silverfury.log.info("Silverfury shut down.")
end

-- ── Reload ────────────────────────────────────────────────────────────────────

function Silverfury.reload()
  Silverfury.shutdown()
  Silverfury = nil
  Silverfury = {}
  -- Re-run this file.
  dofile(path("init.lua"))
  Silverfury.bootstrap()
end

-- ── Auto-boot if called directly ──────────────────────────────────────────────
-- When Mudlet runs this file via the package system, bootstrap fires automatically.

Silverfury.bootstrap()
