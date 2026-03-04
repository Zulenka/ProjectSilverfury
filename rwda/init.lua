rwda = rwda or {}
rwda._version = "0.3.5"  -- always stamp; no `or` guard so dofile always wins
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
  "state/runeblade.lua",
  "data/afflictions.lua",
  "data/defences.lua",
  "data/abilities.lua",
  "data/venoms.lua",
  "data/runes.lua",
  "data/rune_configs.lua",
  "data/strategy_presets.lua",
  "engine/events.lua",
  "engine/timers.lua",
  "engine/queue.lua",
  "engine/strategy.lua",
  "engine/retaliation.lua",
  "engine/finisher.lua",
  "engine/runelore.lua",
  "engine/falcon.lua",
  "engine/fury.lua",
  "engine/runesmith.lua",
  "engine/planner.lua",
  "engine/executor.lua",
  "engine/parser.lua",
  "engine/replay.lua",
  "engine/doctor.lua",
  "engine/selftest.lua",
  "integrations/legacy.lua",
  "integrations/aklimb.lua",
  "integrations/groupcombat.lua",
  "ui/combat_builder_state.lua",
  "ui/combat_builder.lua",
  "ui/hud.lua",
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

function rwda.applyConfigToState()
  rwda.state.flags.mode = rwda.config.combat.mode or "auto"
  rwda.state.flags.goal = rwda.config.combat.goal or "limbprep"
  rwda.state.flags.profile = (rwda.config.strategy and rwda.config.strategy.active_profile) or rwda.config.combat.profile or "duel"
  rwda.state.me.dragon.breath_type = rwda.config.dragon.breath_type or "lightning"

  if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.setEnabled then
    local retalCfg = rwda.config.retaliation or {}
    rwda.engine.retaliation.setEnabled(retalCfg.enabled == true)
  end

  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.setEnabled then
    local finisherCfg = rwda.config.finisher or {}
    rwda.engine.finisher.setEnabled(finisherCfg.enabled ~= false)
  end
end

function rwda.bootstrap(opts)
  if rwda._bootstrapped then
    return true
  end

  opts = opts or {}
  if opts.load_files ~= false then
    rwda.loadAll(opts.base_path)
  end

  if rwda.config and rwda.config.persistence and rwda.config.persistence.auto_load and rwda.config.persistedExists and rwda.config.loadPersisted then
    if rwda.config.persistedExists() then
      local ok, err = rwda.config.loadPersisted()
      if not ok and rwda.util and rwda.util.log then
        rwda.util.log("warn", "Failed to load persisted RWDA config: %s", tostring(err))
      end
    end
  end

  if not rwda.state or not rwda.state.bootstrap then
    error("RWDA state module is not loaded.")
  end

  rwda.state.bootstrap()

  if rwda.state and rwda.state.runeblade and rwda.state.runeblade.bootstrap then
    rwda.state.runeblade.bootstrap()
  end

  rwda.applyConfigToState()

  if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.bootstrap then
    rwda.engine.strategy.bootstrap()
  end

  if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.bootstrap then
    rwda.engine.retaliation.bootstrap()
  end

  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.bootstrap then
    rwda.engine.finisher.bootstrap()
  end

  if rwda.engine and rwda.engine.runelore and rwda.engine.runelore.bootstrap then
    rwda.engine.runelore.bootstrap()
  end

  if rwda.engine and rwda.engine.falcon and rwda.engine.falcon.bootstrap then
    rwda.engine.falcon.bootstrap()
  end

  if rwda.engine and rwda.engine.fury and rwda.engine.fury.bootstrap then
    rwda.engine.fury.bootstrap()
  end

  if rwda.engine and rwda.engine.runesmith and rwda.engine.runesmith.bootstrap then
    rwda.engine.runesmith.bootstrap()
  end

  local legacyActive = false
  if rwda.integrations and rwda.integrations.legacy then
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

  if rwda.config.integration.use_aklimb and rwda.integrations and rwda.integrations.aklimb then
    rwda.integrations.aklimb.detect()
  end

  if rwda.config.integration.use_group_layer and rwda.integrations and rwda.integrations.groupcombat then
    rwda.integrations.groupcombat.detect()
    rwda.integrations.groupcombat.registerHandlers()
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

  if rwda.ui and rwda.ui.hud then
    pcall(rwda.ui.hud.init)
    -- Geyser may not be ready at LegacyLoaded time; retry after a short delay.
    if not rwda.ui.hud._initialized and type(tempTimer) == "function" then
      tempTimer(1.5, function()
        if rwda.ui and rwda.ui.hud and not rwda.ui.hud._initialized then
          pcall(rwda.ui.hud.init)
        end
      end)
    end
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

function rwda.setTarget(name, source)
  rwda.state.setTarget(name, source)
end

function rwda.tick(source)
  if not rwda.state.flags.enabled or rwda.state.flags.stopped then
    return nil
  end

  if rwda.integrations and rwda.integrations.legacy and not rwda.state.integration.legacy_present then
    if rwda.integrations.legacy.detect() then
      rwda.integrations.legacy.registerHandlers()
      rwda.integrations.legacy.syncFromGlobals()
      rwda.util.log("info", "RWDA attached to Legacy backend.")
    end
  end

  if rwda.config.integration.use_group_layer and rwda.integrations and rwda.integrations.groupcombat and not rwda.state.integration.group_present then
    if rwda.integrations.groupcombat.detect() then
      rwda.integrations.groupcombat.registerHandlers()
      rwda.util.log("info", "RWDA attached to group target backend.")
    end
  end

  local usingLegacy = rwda.state.integration.legacy_present

  if usingLegacy and rwda.integrations and rwda.integrations.legacy then
    rwda.integrations.legacy.syncFromGlobals()
  end

  if rwda.state.integration.group_present and rwda.integrations and rwda.integrations.groupcombat then
    rwda.integrations.groupcombat.sync()
  end

  if rwda.config.integration.use_aklimb and rwda.integrations and rwda.integrations.aklimb then
    if not rwda.state.integration.aklimb_present then
      rwda.integrations.aklimb.detect()
    end
    if rwda.state.integration.aklimb_present then
      rwda.integrations.aklimb.sync()
    end
  end

  if rwda.engine and rwda.engine.parser and rwda.engine.parser.refreshTargetAvailabilityFromGMCP then
    rwda.engine.parser.refreshTargetAvailabilityFromGMCP("tick")
  end

  if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.update then
    rwda.engine.retaliation.update()
  end

  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.update then
    rwda.engine.finisher.update()
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
  if rwda.ui and rwda.ui.hud and rwda.ui.hud.shutdown then
    pcall(rwda.ui.hud.shutdown)
  end

  if rwda.ui and rwda.ui.combat_builder and rwda.ui.combat_builder.shutdown then
    pcall(rwda.ui.combat_builder.shutdown)
  end

  if rwda.ui and rwda.ui.commands and rwda.ui.commands.unregisterAlias then
    pcall(rwda.ui.commands.unregisterAlias)
  end

  if rwda.engine and rwda.engine.parser and rwda.engine.parser.unregisterMudletHandlers then
    pcall(rwda.engine.parser.unregisterMudletHandlers)
  end

  if rwda.engine and rwda.engine.executor and rwda.engine.executor.unregisterSafetyValve then
    pcall(rwda.engine.executor.unregisterSafetyValve)
  end

  if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.shutdown then
    pcall(rwda.engine.retaliation.shutdown)
  end

  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.shutdown then
    pcall(rwda.engine.finisher.shutdown)
  end

  if rwda.integrations and rwda.integrations.legacy and rwda.integrations.legacy.unregisterHandlers then
    pcall(rwda.integrations.legacy.unregisterHandlers)
  end

  if rwda.integrations and rwda.integrations.groupcombat and rwda.integrations.groupcombat.unregisterHandlers then
    pcall(rwda.integrations.groupcombat.unregisterHandlers)
  end

  rwda._bootstrapped = false
end

function rwda.reload(opts)
  opts = opts or {}
  local base = opts.base_path or rwda.base_path

  rwda.shutdown()
  rwda._loaded_files = {}
  -- NOTE: _version is NOT cleared here.
  -- The XML loader dofiles init.lua before calling reload(), which already stamped
  -- the correct version (no `or` guard above).  Clearing it here would cause
  -- bootstrap() to log "version nil" since init.lua is not in the FILES list.
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
