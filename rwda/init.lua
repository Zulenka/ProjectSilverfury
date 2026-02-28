rwda = rwda or {}
rwda._version = rwda._version or "0.1.0"
rwda._loaded_files = rwda._loaded_files or {}
rwda._bootstrapped = rwda._bootstrapped or false

local pathSep = package and package.config and package.config:sub(1, 1) or "\\"

local function normalize(path)
  if not path then
    return nil
  end
  local p = path:gsub("/", pathSep):gsub("\\", pathSep)
  return p
end

local function join(a, b)
  if not a or a == "" then
    return normalize(b)
  end
  return normalize(a .. pathSep .. b)
end

local function discoverBasePath()
  local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
  if src:sub(1, 1) == "@" then
    local file = src:sub(2)
    return normalize(file:match("^(.*)[/\\][^/\\]+$") or ".")
  end

  return normalize("rwda")
end

rwda.base_path = rwda.base_path or discoverBasePath()

local FILES = {
  "util.lua",
  "config.lua",
  "state/me.lua",
  "state/target.lua",
  "state/cooldowns.lua",
  "state/store.lua",
  "data/afflictions.lua",
  "data/defences.lua",
  "data/abilities.lua",
  "data/venoms.lua",
  "engine/events.lua",
  "engine/timers.lua",
  "engine/queue.lua",
  "engine/planner.lua",
  "engine/executor.lua",
  "engine/parser.lua",
  "engine/replay.lua",
  "integrations/legacy.lua",
  "integrations/svof.lua",
  "integrations/aklimb.lua",
  "integrations/groupcombat.lua",
  "ui/commands.lua",
}

function rwda.loadAll(basePath)
  basePath = normalize(basePath or rwda.base_path)

  for _, rel in ipairs(FILES) do
    if not rwda._loaded_files[rel] then
      local full = join(basePath, rel)
      local ok, err = pcall(dofile, full)
      if ok then
        rwda._loaded_files[rel] = true
      else
        -- Mudlet package users may load each script directly instead of filesystem dofile.
        if rwda.util and rwda.util.log then
          rwda.util.log("warn", "Skipped dofile(%s): %s", full, tostring(err))
        end
      end
    end
  end
end

local function applyConfigToState()
  rwda.state.flags.mode = rwda.config.combat.mode or "auto"
  rwda.state.flags.goal = rwda.config.combat.goal or "limbprep"
  rwda.state.flags.profile = rwda.config.combat.profile or "duel"
  rwda.state.me.dragon.breath_type = rwda.config.dragon.breath_type or "lightning"
end

function rwda.bootstrap(opts)
  if rwda._bootstrapped then
    return true
  end

  opts = opts or {}
  if opts.load_files ~= false then
    rwda.loadAll(opts.base_path)
  end

  if not rwda.state or not rwda.state.bootstrap then
    error("RWDA state module is not loaded.")
  end

  rwda.state.bootstrap()
  applyConfigToState()

  local legacyActive = false
  if rwda.config.integration.use_legacy and rwda.integrations and rwda.integrations.legacy then
    -- Register first so late Legacy init still reaches RWDA via LegacyLoaded.
    rwda.integrations.legacy.registerHandlers()
    legacyActive = rwda.integrations.legacy.detect()
    if legacyActive then
      rwda.integrations.legacy.syncFromGlobals()
      if rwda.config.integration.auto_enable_with_legacy and not rwda.state.flags.enabled then
        rwda.enable()
      end
    end
  end

  local allowParallel = rwda.config.integration.allow_parallel_backends
  if rwda.config.integration.use_svof and rwda.integrations and rwda.integrations.svof and (allowParallel or not legacyActive) then
    rwda.integrations.svof.detect()
    rwda.integrations.svof.syncFromGlobals()
    rwda.integrations.svof.registerHandlers()
  end

  if rwda.config.integration.use_aklimb and rwda.integrations and rwda.integrations.aklimb then
    rwda.integrations.aklimb.detect()
  end

  if rwda.config.integration.use_group_layer and rwda.integrations and rwda.integrations.groupcombat then
    rwda.integrations.groupcombat.detect()
  end

  if rwda.engine and rwda.engine.parser then
    rwda.engine.parser.registerMudletHandlers()
  end

  if rwda.engine and rwda.engine.executor then
    rwda.engine.executor.registerSafetyValve()
  end

  if rwda.ui and rwda.ui.commands then
    rwda.ui.commands.registerAlias()
  end

  rwda._bootstrapped = true
  rwda.util.log("info", "RWDA bootstrap complete (version %s).", rwda._version)
  return true
end

function rwda.enable()
  rwda.state.setEnabled(true)
  rwda.state.setStopped(false)
  rwda.util.log("info", "RWDA enabled.")
end

function rwda.disable()
  rwda.state.setEnabled(false)
  rwda.util.log("info", "RWDA disabled.")
end

function rwda.stop()
  local clearQueue = rwda.config.executor.clear_on_stop ~= false
  if rwda.engine and rwda.engine.executor then
    rwda.engine.executor.stop(clearQueue)
  else
    rwda.state.setStopped(true)
  end
  rwda.util.log("warn", "RWDA stopped.")
end

function rwda.resume()
  if rwda.engine and rwda.engine.executor then
    rwda.engine.executor.resume()
  else
    rwda.state.setStopped(false)
  end
  rwda.util.log("info", "RWDA resumed.")
end

function rwda.setTarget(name)
  rwda.state.setTarget(name)
end

function rwda.tick(source)
  if not rwda.state.flags.enabled or rwda.state.flags.stopped then
    return nil
  end

  if rwda.config.integration.use_legacy and rwda.integrations and rwda.integrations.legacy and not rwda.state.integration.legacy_present then
    if rwda.integrations.legacy.detect() then
      rwda.integrations.legacy.registerHandlers()
      rwda.integrations.legacy.syncFromGlobals()
      rwda.util.log("info", "RWDA attached to Legacy backend.")
    end
  end

  if rwda.config.integration.use_svof and rwda.integrations and rwda.integrations.svof and not rwda.state.integration.svof_present then
    if rwda.integrations.svof.detect() then
      rwda.integrations.svof.registerHandlers()
      rwda.integrations.svof.syncFromGlobals()
      rwda.util.log("info", "RWDA attached to SVO backend.")
    end
  end

  local allowParallel = rwda.config.integration.allow_parallel_backends
  local usingLegacy = rwda.state.integration.legacy_present

  if usingLegacy and rwda.integrations and rwda.integrations.legacy then
    rwda.integrations.legacy.syncFromGlobals()
  end

  if rwda.state.integration.svof_present and rwda.integrations and rwda.integrations.svof and (allowParallel or not usingLegacy) then
    rwda.integrations.svof.syncFromGlobals()
  end

  if rwda.state.integration.group_present and rwda.integrations and rwda.integrations.groupcombat then
    rwda.integrations.groupcombat.sync()
  end

  if rwda.state.integration.aklimb_present and rwda.integrations and rwda.integrations.aklimb then
    rwda.integrations.aklimb.sync()
  end

  if rwda.engine and rwda.engine.parser and rwda.engine.parser.refreshTargetAvailabilityFromGMCP then
    rwda.engine.parser.refreshTargetAvailabilityFromGMCP("tick")
  end

  local action = rwda.engine.planner.choose(rwda.state)
  if not action then
    return nil
  end

  local ok, reason = rwda.engine.executor.execute(action)
  if rwda.state.flags.debug then
    rwda.util.log("trace", "tick source=%s action=%s ok=%s reason=%s", tostring(source), tostring(action.name), tostring(ok), tostring(reason))
  end

  return action
end

function rwda.statusLine()
  if rwda.ui and rwda.ui.commands then
    return rwda.ui.commands.statusText()
  end
  return "RWDA loaded"
end

function rwda.shutdown()
  if rwda.ui and rwda.ui.commands and rwda.ui.commands.unregisterAlias then
    pcall(rwda.ui.commands.unregisterAlias)
  end

  if rwda.engine and rwda.engine.parser and rwda.engine.parser.unregisterMudletHandlers then
    pcall(rwda.engine.parser.unregisterMudletHandlers)
  end

  if rwda.engine and rwda.engine.executor and rwda.engine.executor.unregisterSafetyValve then
    pcall(rwda.engine.executor.unregisterSafetyValve)
  end

  if rwda.integrations and rwda.integrations.svof and rwda.integrations.svof.unregisterHandlers then
    pcall(rwda.integrations.svof.unregisterHandlers)
  end

  if rwda.integrations and rwda.integrations.legacy and rwda.integrations.legacy.unregisterHandlers then
    pcall(rwda.integrations.legacy.unregisterHandlers)
  end

  rwda._bootstrapped = false
end

function rwda.reload(opts)
  opts = opts or {}
  local base = opts.base_path or rwda.base_path

  rwda.shutdown()
  rwda._loaded_files = {}
  rwda.loadAll(base)
  rwda._bootstrapped = false

  return rwda.bootstrap({
    load_files = false,
    base_path = base,
  })
end

if not rwda._autoboot_disabled then
  pcall(rwda.bootstrap)
end
