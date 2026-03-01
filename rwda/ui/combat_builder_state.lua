rwda = rwda or {}
rwda.ui = rwda.ui or {}
rwda.ui.combat_builder_state = rwda.ui.combat_builder_state or {
  _working = nil,
}

local builder_state = rwda.ui.combat_builder_state

local function modeKey(modeWord)
  modeWord = tostring(modeWord or ""):lower()
  if modeWord == "human" or modeWord == "runewarden" or modeWord == "human_dualcut" then
    return "runewarden"
  end
  if modeWord == "dragon" or modeWord == "dragon_silver" then
    return "dragon"
  end
  return nil
end

local function profileNameFrom(source)
  local strategy = source and source.strategy or {}
  local active = strategy.active_profile
  if type(active) == "string" and active ~= "" then
    return active
  end
  if rwda.state and rwda.state.flags and type(rwda.state.flags.profile) == "string" and rwda.state.flags.profile ~= "" then
    return rwda.state.flags.profile
  end
  return "duel"
end

local function ensureStrategyDefaults(source)
  source.strategy = source.strategy or {}
  source.strategy.profiles = source.strategy.profiles or {}
  source.strategy.active_profile = source.strategy.active_profile or rwda.state.flags.profile or "duel"

  local profileName = profileNameFrom(source)
  local profiles = source.strategy.profiles
  profiles[profileName] = profiles[profileName] or {}
  profiles[profileName].runewarden = profiles[profileName].runewarden or {}
  profiles[profileName].dragon = profiles[profileName].dragon or {}
  profiles[profileName].runewarden.blocks = profiles[profileName].runewarden.blocks or {}
  profiles[profileName].dragon.blocks = profiles[profileName].dragon.blocks or {}
end

local function ensureWorking()
  if not builder_state._working then
    builder_state.open()
  end
  return builder_state._working
end

local function sortedBlocks(blocks)
  local rows = {}
  for _, block in ipairs(blocks or {}) do
    if type(block) == "table" then
      rows[#rows + 1] = block
    end
  end

  table.sort(rows, function(a, b)
    local pa = tonumber(a.priority) or 0
    local pb = tonumber(b.priority) or 0
    if pa == pb then
      return tostring(a.id or "") < tostring(b.id or "")
    end
    return pa > pb
  end)
  return rows
end

local function formatBlockSummary(blocks)
  local out = {}
  for _, block in ipairs(sortedBlocks(blocks)) do
    out[#out + 1] = string.format(
      "%s=%s@%s",
      tostring(block.id or "?"),
      (block.enabled == false) and "off" or "on",
      tostring(math.floor(tonumber(block.priority) or 0))
    )
  end
  if #out == 0 then
    return "(none)"
  end
  return table.concat(out, ", ")
end

local function sourceTable(useWorking)
  if useWorking and builder_state._working then
    return builder_state._working
  end

  return {
    strategy = rwda.config and rwda.config.strategy or {},
    retaliation = rwda.config and rwda.config.retaliation or {},
    finisher = rwda.config and rwda.config.finisher or {},
  }
end

function builder_state.open()
  if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.bootstrap then
    rwda.engine.strategy.bootstrap()
  end

  builder_state._working = {
    strategy = rwda.util.deepcopy(rwda.config and rwda.config.strategy or {}),
    retaliation = rwda.util.deepcopy(rwda.config and rwda.config.retaliation or {}),
    finisher = rwda.util.deepcopy(rwda.config and rwda.config.finisher or {}),
  }

  ensureStrategyDefaults(builder_state._working)
  return builder_state._working
end

function builder_state.close()
  builder_state._working = nil
  return true
end

function builder_state.isOpen()
  return builder_state._working ~= nil
end

function builder_state.get()
  return builder_state._working
end

function builder_state.revert()
  return builder_state.open()
end

function builder_state.apply()
  local working = builder_state._working
  if type(working) ~= "table" then
    return nil, "builder_not_open"
  end

  rwda.config.strategy = rwda.util.deepcopy(working.strategy or {})
  rwda.config.retaliation = rwda.util.deepcopy(working.retaliation or {})
  rwda.config.finisher = rwda.util.deepcopy(working.finisher or {})

  if rwda.engine and rwda.engine.strategy and rwda.engine.strategy.bootstrap then
    rwda.engine.strategy.bootstrap()
  end

  if rwda.applyConfigToState then
    rwda.applyConfigToState()
  end

  if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.setEnabled then
    rwda.engine.retaliation.setEnabled(rwda.config.retaliation and rwda.config.retaliation.enabled == true)
  end

  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.setEnabled then
    rwda.engine.finisher.setEnabled(not (rwda.config.finisher and rwda.config.finisher.enabled == false))
  end

  return true
end

function builder_state.setStrategyBlock(modeWord, blockId, enabled, priority)
  if type(blockId) ~= "string" or blockId == "" then
    return nil, "invalid_block_id"
  end

  local key = modeKey(modeWord)
  if not key then
    return nil, "invalid_mode"
  end

  local working = ensureWorking()
  ensureStrategyDefaults(working)

  local profileName = profileNameFrom(working)
  local profile = working.strategy.profiles[profileName]
  local modeTable = profile[key]
  local blocks = modeTable.blocks

  local found = nil
  for _, block in ipairs(blocks) do
    if type(block) == "table" and tostring(block.id or "") == blockId then
      found = block
      break
    end
  end

  if not found then
    found = {
      id = blockId,
      enabled = true,
      priority = 0,
      when = { "always" },
    }
    blocks[#blocks + 1] = found
  end

  if enabled ~= nil then
    found.enabled = not not enabled
  end

  if priority ~= nil then
    found.priority = math.floor(tonumber(priority) or 0)
  end

  return found, profileName
end

function builder_state.setRetaliationEnabled(enabled)
  local working = ensureWorking()
  working.retaliation = working.retaliation or {}
  working.retaliation.enabled = not not enabled
  return working.retaliation.enabled
end

function builder_state.setFinisherEnabled(enabled)
  local working = ensureWorking()
  working.finisher = working.finisher or {}
  working.finisher.enabled = not not enabled
  return working.finisher.enabled
end

function builder_state.summaryLines(useWorking)
  local source = sourceTable(useWorking)
  source.strategy = source.strategy or {}
  source.strategy.profiles = source.strategy.profiles or {}
  local profileName = profileNameFrom(source)
  local profile = source.strategy.profiles[profileName] or {}
  local runewarden = profile.runewarden or {}
  local dragon = profile.dragon or {}
  local retaliation = source.retaliation or {}
  local finisher = source.finisher or {}

  return {
    string.format("source=%s profile=%s", useWorking and "builder" or "live", tostring(profileName)),
    string.format(
      "retaliate=%s execute=%s",
      tostring(retaliation.enabled == true),
      tostring(finisher.enabled ~= false)
    ),
    "runewarden blocks: " .. formatBlockSummary(runewarden.blocks),
    "dragon blocks: " .. formatBlockSummary(dragon.blocks),
  }
end
