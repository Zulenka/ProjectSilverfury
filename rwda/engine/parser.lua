rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.parser = rwda.engine.parser or {
  _handler_ids = {},
  _line_trigger_id = nil,
}

local parser = rwda.engine.parser

local function emit(name, payload)
  if rwda.engine and rwda.engine.events then
    rwda.engine.events.emit(name, payload)
  end
end

local function stripAnsi(text)
  if type(text) ~= "string" then
    return ""
  end

  return text:gsub("\27%[[0-9;]*m", "")
end

local function normalizeName(name)
  if type(name) ~= "string" then
    return ""
  end

  return name:lower():gsub("[^%w%s%-']", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function isTarget(who)
  local target = rwda.state and rwda.state.target and rwda.state.target.name
  if not target or target == "" or type(who) ~= "string" then
    return false
  end

  local a = normalizeName(who)
  local b = normalizeName(target)
  if a == "" or b == "" then
    return false
  end

  return a == b or a:find(b, 1, true) ~= nil
end

local function splitChunk(chunk)
  local lines = {}
  if type(chunk) ~= "string" then
    return lines
  end

  for line in chunk:gmatch("([^\r\n]+)") do
    lines[#lines + 1] = line
  end

  return lines
end

local function setBalance(balance, value, source)
  local state = rwda.state
  state.me.balances[balance] = value

  if balance == "balance" then
    if not value then
      state.me.last_balance_loss = rwda.util.now()
      state.me.bal = false
      emit("BAL_LOST", { source = source or "parser" })
    else
      state.me.bal = true
      emit("BAL_GAINED", { source = source or "parser" })
    end
  elseif balance == "equilibrium" then
    if not value then
      state.me.last_eq_loss = rwda.util.now()
      state.me.eq = false
      emit("EQ_LOST", { source = source or "parser" })
    else
      state.me.eq = true
      emit("EQ_GAINED", { source = source or "parser" })
    end
  end
end

local function setLimbBrokenFromWords(who, side, part)
  if not isTarget(who) then
    return false
  end

  local limb
  if part == "leg" then
    limb = (side == "left") and "left_leg" or "right_leg"
  elseif part == "arm" then
    limb = (side == "left") and "left_arm" or "right_arm"
  end

  if not limb then
    return false
  end

  rwda.state.updateTargetLimb(limb, {
    broken = true,
    damage_pct = math.max(100, rwda.state.target.limbs[limb].damage_pct or 100),
    confidence = 1.0,
  })
  emit("LIMB_BROKEN", { who = who, limb = limb })
  return true
end

local function setLimbMangledFromWords(who, side, part)
  if not isTarget(who) then
    return false
  end

  local limb
  if part == "leg" then
    limb = (side == "left") and "left_leg" or "right_leg"
  elseif part == "arm" then
    limb = (side == "left") and "left_arm" or "right_arm"
  end

  if not limb then
    return false
  end

  rwda.state.updateTargetLimb(limb, {
    mangled = true,
    damage_pct = math.max(75, rwda.state.target.limbs[limb].damage_pct or 75),
    confidence = 0.92,
  })
  emit("LIMB_MANGLED", { who = who, limb = limb })
  return true
end

local function markTargetDead(name, source)
  if not isTarget(name) then
    return false
  end

  rwda.state.setTargetDead(true, source or "line")
  emit("TARGET_DEAD", { who = name, source = source or "line" })

  if rwda.engine and rwda.engine.queue then
    rwda.engine.queue.clear("all")
  end

  return true
end

function parser.onGMCPVitals()
  if not gmcp or not gmcp.Char or not gmcp.Char.Vitals then
    return
  end

  local v = gmcp.Char.Vitals
  local state = rwda.state

  state.integration.gmcp_present = true

  state.me.hp = tonumber(v.hp) or state.me.hp
  state.me.maxhp = tonumber(v.maxhp) or state.me.maxhp
  state.me.mp = tonumber(v.mp) or state.me.mp
  state.me.maxmp = tonumber(v.maxmp) or state.me.maxmp

  local oldBal = state.me.bal
  local oldEq = state.me.eq

  state.me.bal = rwda.util.bool(v.bal)
  state.me.eq = rwda.util.bool(v.eq)
  state.me.balances.balance = state.me.bal
  state.me.balances.equilibrium = state.me.eq

  if oldBal ~= state.me.bal then
    emit(state.me.bal and "BAL_GAINED" or "BAL_LOST", { source = "gmcp" })
  end
  if oldEq ~= state.me.eq then
    emit(state.me.eq and "EQ_GAINED" or "EQ_LOST", { source = "gmcp" })
  end

  if rwda.state.flags.enabled and rwda.config.combat.auto_tick_on_prompt then
    rwda.tick("gmcp")
  end
end

function parser.onPrompt()
  local state = rwda.state
  state.me.last_prompt_ms = rwda.util.now()

  if rwda.integrations and rwda.integrations.svof and rwda.state.integration.svof_present then
    rwda.integrations.svof.syncFromGlobals()
  end

  if rwda.state.flags.enabled and rwda.config.combat.auto_tick_on_prompt then
    rwda.tick("prompt")
  end

  if rwda.engine and rwda.engine.executor then
    rwda.engine.executor.flushPending()
  end
end

function parser.setForm(form, source)
  if form ~= "human" and form ~= "dragon" then
    return
  end

  rwda.state.setForm(form)
  emit("FORM_CHANGED", { form = form, source = source or "parser" })
end

function parser.onDataReceived(_, chunk)
  if type(chunk) ~= "string" then
    return
  end

  for _, line in ipairs(splitChunk(chunk)) do
    parser.handleLine(line)
  end
end

function parser.handleLine(line)
  if type(line) ~= "string" or line == "" then
    return
  end

  line = stripAnsi(line)
  if line == "" then
    return
  end

  local state = rwda.state
  local lower = line:lower()

  if line:find("You have recovered equilibrium and balance", 1, true) then
    setBalance("equilibrium", true, "line")
    setBalance("balance", true, "line")
  elseif line:find("You have recovered balance", 1, true) then
    setBalance("balance", true, "line")
  elseif line:find("You have recovered equilibrium", 1, true) then
    setBalance("equilibrium", true, "line")
  elseif line:find("You cease to wield balance", 1, true) or line:find("You lose your balance", 1, true) then
    setBalance("balance", false, "line")
  elseif line:find("You lose your equilibrium", 1, true) then
    setBalance("equilibrium", false, "line")
  end

  local shieldUp = line:match("^A shimmering shield surrounds (.+)%.$")
  if shieldUp and isTarget(shieldUp) then
    state.setTargetDefence("shield", true, 1.0, "line")
    emit("DEF_GAINED", { who = shieldUp, defence = "shield" })
    return
  end

  local shieldDown = line:match("^The shimmering shield around (.+) shatters%.$")
  if shieldDown and isTarget(shieldDown) then
    state.setTargetDefence("shield", false, 0.0, "line")
    emit("DEF_LOST", { who = shieldDown, defence = "shield" })
    return
  end

  local reboundUp = line:match("^A nearly invisible magical shield forms around (.+)%.$")
  if reboundUp and isTarget(reboundUp) then
    state.setTargetDefence("rebounding", true, 1.0, "line")
    emit("DEF_GAINED", { who = reboundUp, defence = "rebounding" })
    return
  end

  local reboundDown = line:match("^The rebounding aura around (.+) dissipates%.$")
  if reboundDown and isTarget(reboundDown) then
    state.setTargetDefence("rebounding", false, 0.0, "line")
    emit("DEF_LOST", { who = reboundDown, defence = "rebounding" })
    return
  end

  local proneHit = line:match("^(.+) is knocked off balance and falls to the ground%.$")
    or line:match("^(.+) is hurled to the ground%.$")
    or line:match("^(.+) falls to the ground%.$")

  if proneHit and isTarget(proneHit) then
    state.setTargetProne(true, "line")
    emit("TARGET_PRONE", { who = proneHit })
    return
  end

  local stood = line:match("^(.+) stands up and stretches%.$")
    or line:match("^(.+) gets to (?:his|her|their) feet%.$")
    or line:match("^(.+) climbs back to (?:his|her|their) feet%.$")

  if stood and isTarget(stood) then
    state.setTargetProne(false, "line")
    emit("TARGET_STOOD", { who = stood })
    return
  end

  if lower:find("you assume the form of a dragon", 1, true)
    or lower:find("you are now in dragonform", 1, true) then
    parser.setForm("dragon", "line")
    return
  end

  if lower:find("you return to your lesser form", 1, true)
    or lower:find("you are no longer in dragonform", 1, true) then
    parser.setForm("human", "line")
    return
  end

  if lower:find("you summon", 1, true) and lower:find("breath", 1, true) then
    state.me.dragon.breath_summoned = true
    emit("DRAGON_BREATH_SUMMONED", { source = "line" })
    return
  end

  if lower:find("your breath dissipates", 1, true) then
    state.me.dragon.breath_summoned = false
    emit("DRAGON_BREATH_LOST", { source = "line" })
    return
  end

  local impaledTarget = line:match("^You impale (.+)%.$")
  if impaledTarget and isTarget(impaledTarget) then
    state.setTargetImpaled(true, "line")
    emit("TARGET_IMPALED", { who = impaledTarget })
    return
  end

  local unimpaledTarget = line:match("^(.+) pulls free from the impalement%.$")
    or line:match("^(.+) wriggles free from the impalement%.$")

  if unimpaledTarget and isTarget(unimpaledTarget) then
    state.setTargetImpaled(false, "line")
    emit("TARGET_UNIMPALED", { who = unimpaledTarget })
    return
  end

  local who, side, part = line:match("^(.+)'s (left|right) (leg|arm).-[Bb]reak")
  if who and setLimbBrokenFromWords(who, side, part) then
    return
  end

  who, side, part = line:match("^(.+)'s (left|right) (leg|arm) is mangled")
  if who and setLimbMangledFromWords(who, side, part) then
    return
  end

  local torsoBreak = line:match("^(.+)'s torso .-[Bb]reak")
  if torsoBreak and isTarget(torsoBreak) then
    state.updateTargetLimb("torso", { broken = true, damage_pct = 100, confidence = 1.0 })
    emit("LIMB_BROKEN", { who = torsoBreak, limb = "torso" })
    return
  end

  local torsoMangled = line:match("^(.+)'s torso is mangled")
  if torsoMangled and isTarget(torsoMangled) then
    state.updateTargetLimb("torso", { mangled = true, damage_pct = math.max(75, state.target.limbs.torso.damage_pct), confidence = 0.92 })
    emit("LIMB_MANGLED", { who = torsoMangled, limb = "torso" })
    return
  end

  local rendHitWho, rendLimb = line:match("^You rend (.+)'s ([%a_ ]+)%.$")
  if rendHitWho and isTarget(rendHitWho) then
    local map = {
      ["left leg"] = "left_leg",
      ["right leg"] = "right_leg",
      ["left arm"] = "left_arm",
      ["right arm"] = "right_arm",
      torso = "torso",
      head = "head",
    }
    local key = map[normalizeName(rendLimb)]
    if key and state.target.limbs[key] then
      local cur = state.target.limbs[key].damage_pct or 0
      state.updateTargetLimb(key, { damage_pct = math.min(100, cur + 18), confidence = 0.7 })
      emit("LIMB_DAMAGE", { who = rendHitWho, limb = key, source = "rend" })
      return
    end
  end

  local killed = line:match("^You have slain (.+)%.$")
    or line:match("^(.+) has been slain by you%.$")
  if killed and markTargetDead(killed, "line") then
    return
  end

  local escape = line:match("^(.+) leaves [a-z]+%.$")
  if escape and isTarget(escape) then
    state.target.last_seen = rwda.util.now()
    emit("TARGET_MOVED", { who = escape })
    return
  end
end

function parser.registerMudletHandlers()
  if type(registerAnonymousEventHandler) ~= "function" then
    return false
  end

  if parser._handler_ids.gmcp_vitals then
    return true
  end

  parser._handler_ids.gmcp_vitals = registerAnonymousEventHandler("gmcp.Char.Vitals", "rwda.engine.parser.onGMCPVitals")
  parser._handler_ids.prompt = registerAnonymousEventHandler("sysPrompt", "rwda.engine.parser.onPrompt")

  if rwda.config.parser.use_data_events then
    parser._handler_ids.data_received = registerAnonymousEventHandler("sysDataReceived", "rwda.engine.parser.onDataReceived")
    parser._handler_ids.data_receive = registerAnonymousEventHandler("sysDataReceive", "rwda.engine.parser.onDataReceived")
  end

  if rwda.config.parser.use_temp_line_trigger and type(tempRegexTrigger) == "function" and not parser._line_trigger_id then
    parser._line_trigger_id = tempRegexTrigger("^.*$", [[rwda.engine.parser.handleLine(line)]])
  end

  return true
end

function parser.unregisterMudletHandlers()
  if type(killAnonymousEventHandler) == "function" then
    for _, id in pairs(parser._handler_ids) do
      pcall(killAnonymousEventHandler, id)
    end
  end

  parser._handler_ids = {}

  if parser._line_trigger_id and type(killTrigger) == "function" then
    pcall(killTrigger, parser._line_trigger_id)
    parser._line_trigger_id = nil
  end

  return true
end
