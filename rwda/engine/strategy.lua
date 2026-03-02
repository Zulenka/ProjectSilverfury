rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.strategy = rwda.engine.strategy or {}

local strategy = rwda.engine.strategy

local function trim(input)
  if type(input) ~= "string" then
    return ""
  end
  return input:gsub("^%s+", ""):gsub("%s+$", "")
end

local function defActive(target, name)
  local d = target and target.defs and target.defs[name]
  return d and d.active and (d.confidence or 0) > 0
end

local function limbBroken(target, limb)
  local l = target and target.limbs and target.limbs[limb]
  return l and l.broken
end

local function defaultProfiles()
  local presets = rwda.data and rwda.data.strategy_presets or {}
  return rwda.util.deepcopy(presets.profiles or {})
end

local function ensureProfileShape(profile, defaultProfile)
  profile = profile or {}

  if type(profile.runewarden) ~= "table" then
    profile.runewarden = rwda.util.deepcopy(defaultProfile and defaultProfile.runewarden or { blocks = {} })
  end
  if type(profile.dragon) ~= "table" then
    profile.dragon = rwda.util.deepcopy(defaultProfile and defaultProfile.dragon or { blocks = {} })
  end

  profile.runewarden.blocks = profile.runewarden.blocks or rwda.util.deepcopy(defaultProfile and defaultProfile.runewarden and defaultProfile.runewarden.blocks or {})
  profile.dragon.blocks = profile.dragon.blocks or rwda.util.deepcopy(defaultProfile and defaultProfile.dragon and defaultProfile.dragon.blocks or {})
  return profile
end

function strategy.bootstrap()
  local cfg = rwda.config
  cfg.strategy = cfg.strategy or {}

  local presets = rwda.data and rwda.data.strategy_presets or {}
  cfg.strategy.version = tonumber(cfg.strategy.version) or tonumber(presets.version) or 1
  cfg.strategy.enabled = cfg.strategy.enabled ~= false
  cfg.strategy.active_profile = trim(cfg.strategy.active_profile or cfg.combat.profile or "duel")
  if cfg.strategy.active_profile == "" then
    cfg.strategy.active_profile = "duel"
  end

  cfg.strategy.profiles = cfg.strategy.profiles or {}
  local defaults = defaultProfiles()
  for profileName, profileDefault in pairs(defaults) do
    if type(cfg.strategy.profiles[profileName]) ~= "table" then
      cfg.strategy.profiles[profileName] = rwda.util.deepcopy(profileDefault)
    else
      cfg.strategy.profiles[profileName] = ensureProfileShape(cfg.strategy.profiles[profileName], profileDefault)
    end
  end

  if not cfg.strategy.profiles[cfg.strategy.active_profile] then
    if cfg.strategy.profiles.duel then
      cfg.strategy.active_profile = "duel"
    else
      for profileName, _ in pairs(cfg.strategy.profiles) do
        cfg.strategy.active_profile = profileName
        break
      end
    end
  end
end

function strategy.resolveProfileName(state)
  local cfg = rwda.config and rwda.config.strategy or {}
  local requested = trim((state and state.flags and state.flags.profile) or cfg.active_profile or "duel")
  if requested ~= "" and cfg.profiles and cfg.profiles[requested] then
    return requested
  end

  if cfg.profiles and cfg.profiles.duel then
    return "duel"
  end

  if cfg.profiles then
    for name, _ in pairs(cfg.profiles) do
      return name
    end
  end

  return "duel"
end

local function modeKey(mode)
  if mode == "human_dualcut" then
    return "runewarden"
  end
  return "dragon"
end

function strategy.blocksForMode(mode, state)
  if not (rwda.config and rwda.config.strategy and rwda.config.strategy.profiles) then
    strategy.bootstrap()
  end

  local profileName = strategy.resolveProfileName(state)
  local profiles = rwda.config and rwda.config.strategy and rwda.config.strategy.profiles or {}
  local profile = profiles[profileName] or {}
  local key = modeKey(mode)
  local modeTable = profile[key] or {}
  local blocks = modeTable.blocks or {}
  return blocks, profileName
end

function strategy.evaluateToken(token, state, context)
  token = trim(token)
  if token == "" then
    return true
  end

  if token == "always" or token == "true" then
    return true
  end

  if token:sub(1, 4) == "not " then
    return not strategy.evaluateToken(token:sub(5), state, context)
  end

  if token == "target.def.shield" then
    return defActive(state.target, "shield")
  end
  if token == "target.def.rebounding" then
    return defActive(state.target, "rebounding")
  end
  if token == "target.prone" then
    return state.target and state.target.prone
  end
  if token == "target.flying" then
    return state.target and state.target.flying
  end
  if token == "target.lyred" then
    return state.target and state.target.lyred
  end
  if token == "target.available" then
    return state.target and state.target.available
  end
  if token == "target.impaled" then
    return context and context.target_impaled or (state.target and (state.target.impaled or state.target.affs.impaled))
  end
  if token == "target.legs_broken" then
    return context and context.both_legs_broken or (limbBroken(state.target, "left_leg") and limbBroken(state.target, "right_leg"))
  end

  local limbName, limbField = token:match("^target%.limb%.([%w_]+)%.([%w_]+)$")
  if limbName and limbField then
    local limb = state.target and state.target.limbs and state.target.limbs[limbName]
    if limb then
      if limbField == "broken" then
        return limb.broken
      elseif limbField == "mangled" then
        return limb.mangled
      end
    end
    return false
  end

  local goalName = token:match("^goal%.([%w_]+)$")
  if goalName then
    return (state.flags.goal or ""):lower() == goalName:lower()
  end

  if token == "me.form.dragon" then
    return state.me and state.me.form == "dragon"
  end
  if token == "me.form.human" then
    return state.me and state.me.form == "human"
  end
  if token == "me.dragon.breath_summoned" then
    return state.me and state.me.dragon and state.me.dragon.breath_summoned
  end

  if token == "state.can_devour" then
    return context and context.can_devour
  end

  return false
end

function strategy.conditionsMet(conditions, state, context)
  if type(conditions) ~= "table" or #conditions == 0 then
    return true
  end

  for _, token in ipairs(conditions) do
    if not strategy.evaluateToken(token, state, context) then
      return false
    end
  end

  return true
end

local function sortedEnabledBlocks(blocks)
  local rows = {}
  for idx, block in ipairs(blocks or {}) do
    if type(block) == "table" and block.enabled ~= false then
      rows[#rows + 1] = {
        idx = idx,
        priority = tonumber(block.priority) or 0,
        block = block,
      }
    end
  end

  table.sort(rows, function(a, b)
    if a.priority == b.priority then
      return a.idx < b.idx
    end
    return a.priority > b.priority
  end)

  return rows
end

function strategy.selectBlock(mode, state, context)
  local cfg = rwda.config and rwda.config.strategy
  if not cfg or cfg.enabled == false then
    return nil, strategy.resolveProfileName(state)
  end

  local blocks, profileName = strategy.blocksForMode(mode, state)
  for _, row in ipairs(sortedEnabledBlocks(blocks)) do
    local when = row.block.when or row.block.conditions
    if strategy.conditionsMet(when, state, context) then
      return row.block, profileName
    end
  end

  return nil, profileName
end
