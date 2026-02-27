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

local function trim(text)
  if type(text) ~= "string" then
    return ""
  end
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeName(name)
  if type(name) ~= "string" then
    return ""
  end

  return name:lower():gsub("[^%w%s%-']", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function captureByPatterns(source, patterns)
  for _, pat in ipairs(patterns) do
    local value = source:match(pat)
    if value and value ~= "" then
      return trim(value)
    end
  end
  return nil
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

local function markTargetSeen(source)
  if rwda.state and rwda.state.target and rwda.state.target.name then
    rwda.state.setTargetAvailable(true, source or "line", "seen")
  end
end

local function roomPlayersTable()
  if not gmcp or not gmcp.Room then
    return nil
  end
  return gmcp.Room.Players or gmcp.Room.players
end

local function roomHasTargetByGMCP()
  local target = rwda.state and rwda.state.target and rwda.state.target.name
  if not target or target == "" then
    return nil
  end

  local players = roomPlayersTable()
  if type(players) ~= "table" then
    return nil
  end

  local targetNorm = normalizeName(target)

  for k, v in pairs(players) do
    local candidate = nil
    if type(v) == "string" then
      candidate = v
    elseif type(v) == "table" then
      candidate = v.name or v.fullname or v.id
    elseif type(k) == "string" and type(v) == "boolean" and v then
      candidate = k
    end

    if candidate and normalizeName(tostring(candidate)) == targetNorm then
      return true
    end
  end

  return false
end

local function setLimbBrokenFromWords(who, side, part)
  if not isTarget(who) then
    return false
  end

  markTargetSeen("limb")

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

  markTargetSeen("limb")

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

local function markTargetMissing(reason)
  if not (rwda.state and rwda.state.target and rwda.state.target.name) then
    return
  end

  rwda.state.setTargetAvailable(false, "line", reason or "missing")
  emit("TARGET_UNAVAILABLE", { reason = reason or "missing" })

  if rwda.config and rwda.config.combat and rwda.config.combat.clear_queue_when_target_missing
    and rwda.engine and rwda.engine.queue then
    rwda.engine.queue.clear("all")
  end
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

function parser.refreshTargetAvailabilityFromGMCP(source)
  if not (rwda.config and rwda.config.combat and rwda.config.combat.require_room_presence_when_gmcp) then
    return
  end

  local present = roomHasTargetByGMCP()
  if present == nil then
    return
  end

  if present then
    rwda.state.setTargetAvailable(true, source or "gmcp_room", "seen")
  else
    rwda.state.setTargetAvailable(false, source or "gmcp_room", "gmcp_not_in_room")
  end
end

function parser.onGMCPRoomPlayers()
  parser.refreshTargetAvailabilityFromGMCP("gmcp_room")
end

function parser.onPrompt()
  local state = rwda.state
  state.me.last_prompt_ms = rwda.util.now()

  if rwda.integrations and rwda.integrations.svof and rwda.state.integration.svof_present then
    rwda.integrations.svof.syncFromGlobals()
  end

  parser.refreshTargetAvailabilityFromGMCP("prompt")

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
  line = trim(line)
  if line == "" then
    return
  end

  local state = rwda.state
  local lower = line:lower()

  local missingTargetMessages = {
    "you detect nothing here by that name.",
    "you cannot see that being here.",
    "i do not recognise anything called that here.",
    "i do not recognize anything called that here.",
    "there is no one here by that name.",
    "you see no one by that name here.",
    "they aren't here.",
    "they are not here.",
    "no such person here.",
  }
  for _, msg in ipairs(missingTargetMessages) do
    if lower == msg then
      markTargetMissing("not_here")
      return
    end
  end

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

  local shieldUp = captureByPatterns(line, {
    "^A shimmering shield surrounds (.+)%.$",
    "^A shimmering shield surrounds (.+)!$",
    "^A shimmering shield surrounds (.+)$",
  }) or captureByPatterns(lower, {
    "^a shimmering shield surrounds (.+)[%.!]*$",
  })
  if shieldUp and isTarget(shieldUp) then
    markTargetSeen("shield")
    state.setTargetDefence("shield", true, 1.0, "line")
    emit("DEF_GAINED", { who = shieldUp, defence = "shield" })
    return
  end

  local shieldDown = captureByPatterns(line, {
    "^The shimmering shield around (.+) shatters%.$",
    "^The shimmering shield around (.+) is destroyed%.$",
  }) or captureByPatterns(lower, {
    "^the shimmering shield around (.+) shatters[%.!]*$",
    "^the shimmering shield around (.+) is destroyed[%.!]*$",
  })
  if shieldDown and isTarget(shieldDown) then
    markTargetSeen("shield")
    state.setTargetDefence("shield", false, 0.0, "line")
    emit("DEF_LOST", { who = shieldDown, defence = "shield" })
    return
  end

  local reboundUp = captureByPatterns(line, {
    "^A nearly invisible magical shield forms around (.+)%.$",
    "^A nearly invisible magical shield forms around (.+)!$",
    "^An aura of weapons rebounding begins to surround (.+)%.$",
  }) or captureByPatterns(lower, {
    "^a nearly invisible magical shield forms around (.+)[%.!]*$",
    "^an aura of weapons rebounding begins to surround (.+)[%.!]*$",
  })
  if reboundUp and isTarget(reboundUp) then
    markTargetSeen("rebounding")
    state.setTargetDefence("rebounding", true, 1.0, "line")
    emit("DEF_GAINED", { who = reboundUp, defence = "rebounding" })
    return
  end

  local reboundDown = captureByPatterns(line, {
    "^The rebounding aura around (.+) dissipates%.$",
    "^The aura of weapons rebounding around (.+) dissipates%.$",
  }) or captureByPatterns(lower, {
    "^the rebounding aura around (.+) dissipates[%.!]*$",
    "^the aura of weapons rebounding around (.+) dissipates[%.!]*$",
  })
  if reboundDown and isTarget(reboundDown) then
    markTargetSeen("rebounding")
    state.setTargetDefence("rebounding", false, 0.0, "line")
    emit("DEF_LOST", { who = reboundDown, defence = "rebounding" })
    return
  end

  local proneHit = line:match("^(.+) is knocked off balance and falls to the ground%.$")
    or line:match("^(.+) is hurled to the ground%.$")
    or line:match("^(.+) falls to the ground%.$")

  if proneHit and isTarget(proneHit) then
    markTargetSeen("prone")
    state.setTargetProne(true, "line")
    emit("TARGET_PRONE", { who = proneHit })
    return
  end

  local stood = line:match("^(.+) stands up and stretches%.$")
    or line:match("^(.+) gets to (?:his|her|their) feet%.$")
    or line:match("^(.+) climbs back to (?:his|her|their) feet%.$")

  if stood and isTarget(stood) then
    markTargetSeen("stood")
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
    markTargetSeen("impale")
    state.setTargetImpaled(true, "line")
    emit("TARGET_IMPALED", { who = impaledTarget })
    return
  end

  local unimpaledTarget = line:match("^(.+) pulls free from the impalement%.$")
    or line:match("^(.+) wriggles free from the impalement%.$")

  if unimpaledTarget and isTarget(unimpaledTarget) then
    markTargetSeen("impale")
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
    markTargetSeen("torso")
    state.updateTargetLimb("torso", { broken = true, damage_pct = 100, confidence = 1.0 })
    emit("LIMB_BROKEN", { who = torsoBreak, limb = "torso" })
    return
  end

  local torsoMangled = line:match("^(.+)'s torso is mangled")
  if torsoMangled and isTarget(torsoMangled) then
    markTargetSeen("torso")
    state.updateTargetLimb("torso", { mangled = true, damage_pct = math.max(75, state.target.limbs.torso.damage_pct), confidence = 0.92 })
    emit("LIMB_MANGLED", { who = torsoMangled, limb = "torso" })
    return
  end

  local rendHitWho, rendLimb = line:match("^You rend (.+)'s ([%a_ ]+)%.$")
  if rendHitWho and isTarget(rendHitWho) then
    markTargetSeen("rend")
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
    markTargetMissing("left_room")
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
  parser._handler_ids.gmcp_room_players = registerAnonymousEventHandler("gmcp.Room.Players", "rwda.engine.parser.onGMCPRoomPlayers")
  parser._handler_ids.gmcp_room_add = registerAnonymousEventHandler("gmcp.Room.AddPlayer", "rwda.engine.parser.onGMCPRoomPlayers")
  parser._handler_ids.gmcp_room_remove = registerAnonymousEventHandler("gmcp.Room.RemovePlayer", "rwda.engine.parser.onGMCPRoomPlayers")
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
