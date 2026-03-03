rwda = rwda or {}
rwda.state = rwda.state or {}
rwda.state.runeblade = rwda.state.runeblade or {}

local runeblade = rwda.state.runeblade

-- ─────────────────────────────────────────────
-- Default state
-- ─────────────────────────────────────────────

local function defaultState()
  return {
    -- Runeblade configuration (core + up to 3 config runes)
    configuration = {
      core_rune     = nil,     -- "pithakhan" | "nairat" | "eihwaz" | "hugalaz"
      config_runes  = {},      -- { "kena", "sleizak", ... }
      active        = false,
      activated_at  = nil,
    },

    -- Per-rune attunement
    -- [rune_name] = { attuned = bool, attuned_at = number, can_empower = bool }
    attunement = {},

    -- Ordered empower priority
    empower_priority = {},

    -- Whether the runeblade has been empowered (lagul+lagua+laguz)
    empowered = false,

    -- Adapt mechanic
    adapt = {
      last_swap_at   = nil,
      cooldown_until = nil,
    },
  }
end

runeblade._state = nil

-- ─────────────────────────────────────────────
-- Bootstrap / Reset
-- ─────────────────────────────────────────────

function runeblade.bootstrap()
  runeblade._state = defaultState()

  -- Apply defaults from config
  local cfg = rwda.config and rwda.config.runeblade or {}

  if cfg.default_core and cfg.default_config_runes then
    runeblade.setConfiguration(cfg.default_core, cfg.default_config_runes)
  end

  if cfg.empower_priority then
    runeblade.setEmpowerPriority(cfg.empower_priority)
  end

  -- Recommended defaults when nothing configured
  if not runeblade._state.configuration.core_rune then
    runeblade.setConfiguration("pithakhan", { "kena", "sleizak", "inguz" })
    runeblade.setEmpowerPriority({ "kena", "sleizak", "inguz" })
  end
end

function runeblade.reset()
  runeblade._state = defaultState()
end

local function state()
  return runeblade._state
end

-- ─────────────────────────────────────────────
-- Configuration
-- ─────────────────────────────────────────────

local VALID_CORES = { pithakhan = true, nairat = true, eihwaz = true, hugalaz = true }

function runeblade.setConfiguration(coreRune, configRunes)
  local s = state()
  if not s then return false end

  coreRune = coreRune and tostring(coreRune):lower() or nil
  if coreRune and not VALID_CORES[coreRune] then
    if rwda.util then
      rwda.util.log("warn", "runeblade.setConfiguration: invalid core rune '%s'", tostring(coreRune))
    end
    return false
  end

  s.configuration.core_rune    = coreRune
  s.configuration.config_runes = {}
  s.configuration.active       = false
  s.configuration.activated_at = nil
  s.attunement                 = {}

  local runes = rwda.data and rwda.data.runes
  for _, rune in ipairs(configRunes or {}) do
    rune = tostring(rune):lower()
    if runes and not runes.canBeInConfiguration(rune) then
      if rwda.util then
        rwda.util.log("warn", "runeblade: '%s' cannot be in configuration", rune)
      end
    else
      table.insert(s.configuration.config_runes, rune)
    end
  end

  return true
end

function runeblade.getConfiguration()
  local s = state()
  return s and s.configuration
end

function runeblade.isConfigurationActive()
  local s = state()
  return s and s.configuration.active
end

function runeblade.activateConfiguration()
  local s = state()
  if not s or not s.configuration.core_rune then return false end

  s.configuration.active       = true
  s.configuration.activated_at = rwda.util.now()

  -- Pre-seed attunement slots
  for _, rune in ipairs(s.configuration.config_runes) do
    if not s.attunement[rune] then
      s.attunement[rune] = { attuned = false, attuned_at = nil, can_empower = false }
    end
  end

  if rwda.util then
    rwda.util.log("info", "Runeblade configuration activated: %s + [%s]",
      s.configuration.core_rune,
      table.concat(s.configuration.config_runes, ", "))
  end
  return true
end

-- ─────────────────────────────────────────────
-- Attunement
-- ─────────────────────────────────────────────

function runeblade.setAttuned(runeName, attuned)
  local s = state()
  if not s then return false end

  runeName = tostring(runeName):lower()
  s.attunement[runeName] = s.attunement[runeName] or {}
  s.attunement[runeName].attuned     = attuned
  s.attunement[runeName].can_empower = attuned

  if attuned then
    s.attunement[runeName].attuned_at = rwda.util.now()
    if rwda.util then
      rwda.util.log("debug", "Rune ATTUNED: %s", runeName:upper())
    end
  end
  return true
end

function runeblade.isAttuned(runeName)
  local s = state()
  if not s then return false end
  local att = s.attunement[tostring(runeName):lower()]
  return att ~= nil and att.attuned == true
end

function runeblade.canEmpower(runeName)
  local s = state()
  if not s then return false end
  local att = s.attunement[tostring(runeName):lower()]
  return att ~= nil and att.can_empower == true
end

function runeblade.getAttunedRunes()
  local s = state()
  if not s then return {} end
  local result = {}
  for rune, att in pairs(s.attunement) do
    if att.attuned then table.insert(result, rune) end
  end
  return result
end

function runeblade.consumeEmpower(runeName)
  local s = state()
  if not s then return false end
  runeName = tostring(runeName):lower()
  local att = s.attunement[runeName]
  if att then
    att.attuned     = false
    att.can_empower = false
    return true
  end
  return false
end

-- ─────────────────────────────────────────────
-- Empower Priority
-- ─────────────────────────────────────────────

function runeblade.setEmpowerPriority(priority)
  local s = state()
  if not s then return false end
  s.empower_priority = {}
  for _, rune in ipairs(priority or {}) do
    table.insert(s.empower_priority, tostring(rune):lower())
  end
  if rwda.util then
    rwda.util.log("info", "Empower priority: %s", table.concat(s.empower_priority, " > "))
  end
  return true
end

function runeblade.getEmpowerPriority()
  local s = state()
  return s and s.empower_priority or {}
end

-- Returns the highest-priority rune that is currently empowerable
function runeblade.getNextEmpowerRune()
  local s = state()
  if not s then return nil end

  -- Check declared priority first
  for _, rune in ipairs(s.empower_priority) do
    if runeblade.canEmpower(rune) then return rune end
  end

  -- Fall back: any attuned rune
  for rune, att in pairs(s.attunement) do
    if att.can_empower then return rune end
  end

  return nil
end

-- ─────────────────────────────────────────────
-- Adapt mechanic tracking
-- ─────────────────────────────────────────────

function runeblade.recordWeaponSwap(oldType, newType)
  local s = state()
  if not s then return end

  if oldType and newType and oldType ~= newType then
    local now = rwda.util.now()
    local coolUntil = s.adapt.cooldown_until or 0
    if now >= coolUntil then
      s.adapt.last_swap_at   = now
      s.adapt.cooldown_until = now + 10000  -- 10s cooldown
      -- Skip configuration activation delay
      if s.configuration.core_rune and not s.configuration.active then
        runeblade.activateConfiguration()
        if rwda.util then
          rwda.util.log("info", "ADAPT: configuration immediately active")
        end
      end
    end
  end
end

-- ─────────────────────────────────────────────
-- Empowered blade tracking
-- ─────────────────────────────────────────────

function runeblade.setEmpowered(empowered)
  local s = state()
  if s then s.empowered = empowered end
end

function runeblade.isEmpowered()
  local s = state()
  return s and s.empowered or false
end

-- ─────────────────────────────────────────────
-- Serialization (for config persistence)
-- ─────────────────────────────────────────────

function runeblade.serialize()
  local s = state()
  if not s then return nil end
  return {
    configuration    = s.configuration,
    empower_priority = s.empower_priority,
    empowered        = s.empowered,
  }
end

function runeblade.deserialize(data)
  if not data then return false end
  local s = state()
  if not s then return false end

  if type(data.configuration) == "table" then
    s.configuration = data.configuration
  end
  if type(data.empower_priority) == "table" then
    s.empower_priority = data.empower_priority
  end
  if data.empowered ~= nil then
    s.empowered = data.empowered
  end
  return true
end

return runeblade
