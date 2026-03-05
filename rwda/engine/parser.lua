rwda = rwda or {}
rwda.engine = rwda.engine or {}
rwda.engine.parser = rwda.engine.parser or {
  _handler_ids = {},
  _line_trigger_id = nil,
}

local parser = rwda.engine.parser
parser._pending_assess_target = nil
parser._pending_assess_until = 0

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

local AFF_NAME_MAP = nil

local function buildAffNameMap()
  local data = rwda.data and rwda.data.afflictions or {}
  local count = 0
  for _ in pairs(data) do
    count = count + 1
  end

  if AFF_NAME_MAP and AFF_NAME_MAP._count == count and count > 0 then
    return AFF_NAME_MAP
  end

  local map = {}
  for key, _ in pairs(data) do
    local norm = tostring(key):lower():gsub("_", " "):gsub("%s+", " ")
    map[norm] = tostring(key)
  end

  map._count = count
  AFF_NAME_MAP = map
  return map
end

local function resolveAffName(phrase)
  if type(phrase) ~= "string" then
    return nil
  end

  local cleaned = phrase:lower():gsub("[^%a%s]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if cleaned == "" then
    return nil
  end

  local map = buildAffNameMap()
  if map[cleaned] then
    return map[cleaned]
  end

  for norm, key in pairs(map) do
    if cleaned:find(norm, 1, true) then
      return key
    end
  end

  return nil
end

local ASSESS_LIMB_MAP = {
  ["left leg"] = "left_leg",
  ["right leg"] = "right_leg",
  ["left arm"] = "left_arm",
  ["right arm"] = "right_arm",
  torso = "torso",
  head = "head",
}

local function assessSeverityToPct(desc)
  local d = desc:lower()
  if d:find("broken", 1, true) then
    return 100, true, false
  end
  if d:find("mangled", 1, true) then
    return 100, false, true
  end
  if d:find("very badly", 1, true) then
    return 90, false, false
  end
  if d:find("badly", 1, true) then
    return 75, false, false
  end
  if d:find("moderately", 1, true) then
    return 50, false, false
  end
  if d:find("slightly", 1, true) then
    return 25, false, false
  end
  if d:find("scratched", 1, true) or d:find("bruised", 1, true) then
    return 10, false, false
  end
  if d:find("healthy", 1, true) or d:find("uninjured", 1, true) then
    return 0, false, false
  end
  return nil, false, false
end

local function parseAssessLimbLine(line)
  local lower = line:lower()
  local limbText, pct = lower:match("^%s*(left leg|right leg|left arm|right arm|torso|head)%s*[:%-]?%s*(%d+)%%")
  if not limbText then
    limbText, pct = lower:match("^%s*(left leg|right leg|left arm|right arm|torso|head)%s+is%s+(%d+)%%")
  end
  if limbText and pct then
    local limb = ASSESS_LIMB_MAP[limbText]
    if limb then
      local value = tonumber(pct) or 0
      local broken = value >= 100
      return limb, math.min(100, value), broken, false
    end
  end

  local limbText2, desc = lower:match("^%s*(left leg|right leg|left arm|right arm|torso|head)%s+is%s+([%a%s]+)%.?")
  if limbText2 and desc then
    local limb = ASSESS_LIMB_MAP[limbText2]
    if limb then
      local value, broken, mangled = assessSeverityToPct(desc)
      if value ~= nil then
        return limb, value, broken, mangled
      end
    end
  end

  return nil
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

local function captureTargetAff(source, patterns)
  for _, pat in ipairs(patterns) do
    local who, aff = source:match(pat)
    if who and who ~= "" and aff and aff ~= "" then
      return trim(who), trim(aff)
    end
  end
  return nil, nil
end

local function containsAny(haystack, needles)
  if type(haystack) ~= "string" or type(needles) ~= "table" then
    return false
  end

  for _, needle in ipairs(needles) do
    if type(needle) == "string" and needle ~= "" and haystack:find(needle, 1, true) then
      return true
    end
  end

  return false
end

local function detectFormFromText(lowerLine)
  local parserCfg = rwda.config and rwda.config.parser or {}
  local formCfg = parserCfg.form_detect or {}
  if formCfg.enabled == false then
    return nil
  end

  local dragonOn = formCfg.dragon_on or {}
  if containsAny(lowerLine, dragonOn) then
    return "dragon"
  end

  local dragonOff = formCfg.dragon_off or {}
  if containsAny(lowerLine, dragonOff) then
    return "human"
  end

  return nil
end

local function matchesPromptPattern(line)
  if type(line) ~= "string" then
    return false
  end

  local pattern = rwda.config and rwda.config.replay and rwda.config.replay.prompt_pattern
  if not pattern or pattern == "" then
    return false
  end

  local ok, result = pcall(string.match, line, pattern)
  return ok and result ~= nil
end

local function resolveCapturePath()
  local parserCfg = rwda.config and rwda.config.parser or {}
  local explicit = parserCfg.capture_unmatched_path
  if type(explicit) == "string" and explicit ~= "" then
    return explicit
  end

  if type(getMudletHomeDir) == "function" then
    local ok, home = pcall(getMudletHomeDir)
    if ok and type(home) == "string" and home ~= "" then
      -- Use / separator — works on Windows, Mac, and Linux.
      return home:gsub("\\$", "") .. "/rwda_combat.log"
    end
  end

  return "rwda_combat.log"
end

-- Persistent line-capture trigger (works around broken sysDataReceived).
-- Active whenever capture_all_lines is true.
function parser.capturePath()
  return resolveCapturePath()
end

function parser.startCaptureTrigger()
  parser.stopCaptureTrigger()
  if type(tempRegexTrigger) ~= "function" then return end
  parser._capture_trigger = tempRegexTrigger(".", function()
    local parserCfg = rwda.config and rwda.config.parser or {}
    if not parserCfg.capture_all_lines then return end
    local path = resolveCapturePath()
    local f = io.open(path, "a")
    if f then
      local ts = os.date and os.date("%Y-%m-%d %H:%M:%S") or "0000-00-00 00:00:00"
      f:write(string.format("%s | %s\n", ts, tostring(line)))
      f:close()
    end
  end)
end

function parser.stopCaptureTrigger()
  if parser._capture_trigger and type(killTrigger) == "function" then
    pcall(killTrigger, parser._capture_trigger)
  end
  parser._capture_trigger = nil
end

local function captureUnmatchedLine(line)
  local parserCfg = rwda.config and rwda.config.parser or {}
  if not parserCfg.capture_unmatched_lines then
    return
  end

  if line == "" then
    return
  end

  if not parserCfg.capture_unmatched_include_prompts and matchesPromptPattern(line) then
    return
  end

  local path = resolveCapturePath()
  local f = io.open(path, "a")
  if not f then
    return
  end

  local ts = os.date and os.date("%Y-%m-%d %H:%M:%S") or "0000-00-00 00:00:00"
  f:write(string.format("%s | %s\n", ts, line))
  f:close()
end

local AGGRESSIVE_VERBS = {
  attack = true,
  attacks = true,
  blast = true,
  blasts = true,
  bite = true,
  bites = true,
  cast = true,
  casts = true,
  claw = true,
  claws = true,
  cut = true,
  cuts = true,
  disembowel = true,
  disembowels = true,
  drive = true,
  drives = true,
  gaze = true,
  gazes = true,
  gesture = true,
  gestures = true,
  gust = true,
  gusts = true,
  hit = true,
  hits = true,
  impale = true,
  impales = true,
  intimidate = true,
  intimidates = true,
  kick = true,
  kicks = true,
  lash = true,
  lashes = true,
  lunge = true,
  lunges = true,
  point = true,
  points = true,
  punch = true,
  punches = true,
  raze = true,
  razes = true,
  rend = true,
  rends = true,
  slash = true,
  slashes = true,
  smash = true,
  smashes = true,
  stab = true,
  stabs = true,
  stare = true,
  stares = true,
  strike = true,
  strikes = true,
  summon = true,
  summons = true,
  swipe = true,
  swipes = true,
  tailsmash = true,
  tailsmashes = true,
  throw = true,
  throws = true,
}

local function ownName()
  if gmcp and gmcp.Char and gmcp.Char.Status and type(gmcp.Char.Status.name) == "string" then
    return gmcp.Char.Status.name
  end
  return nil
end

local function looksLikePlayerName(name)
  if type(name) ~= "string" then
    return false
  end
  local trimmed = trim(name)
  if trimmed == "" then
    return false
  end
  local lowered = trimmed:lower()
  if lowered == "you" or lowered == "someone" then
    return false
  end
  if lowered == "a" or lowered == "an" or lowered == "the" then
    return false
  end
  if lowered:sub(1, 2) == "a " or lowered:sub(1, 3) == "an " or lowered:sub(1, 4) == "the " then
    return false
  end
  return true
end

local function detectAggressorFromLine(line)
  if type(line) ~= "string" or line == "" then
    return nil
  end

  local patterns = {
    "^([A-Z][%w'%-]+) attacks you",
    "^([A-Z][%w'%-]+) hits you",
    "^([A-Z][%w'%-]+) strikes you",
    "^([A-Z][%w'%-]+) slashes you",
    "^([A-Z][%w'%-]+) slashes viciously at you",
    "^([A-Z][%w'%-]+) kicks you",
    "^([A-Z][%w'%-]+) punches you",
    "^([A-Z][%w'%-]+) stares at you",
    "^([A-Z][%w'%-]+) points at you",
    "^([A-Z][%w'%-]+) gestures toward you",
    "^([A-Z][%w'%-]+) gestures at you",
    "^([A-Z][%w'%-]+) .- at you",
  }

  local who
  for _, pat in ipairs(patterns) do
    who = line:match(pat)
    if who and who ~= "" then
      break
    end
  end

  if not who or who == "" then
    return nil
  end

  local mine = ownName()
  if mine and normalizeName(who) == normalizeName(mine) then
    return nil
  end

  if not looksLikePlayerName(who) then
    return nil
  end

  return who
end

local function detectFinisherOutcome(lowerLine)
  if type(lowerLine) ~= "string" then
    return nil
  end

  if lowerLine:find("you disembowel", 1, true) then
    return { event = "FINISHER_SUCCESS", name = "disembowel", reason = "line_success" }
  end

  if lowerLine:find("you devour", 1, true) or lowerLine:find("you have devoured", 1, true) then
    return { event = "FINISHER_SUCCESS", name = "devour", reason = "line_success" }
  end

  if lowerLine:find("you cannot disembowel", 1, true)
    or lowerLine:find("you fail to disembowel", 1, true)
    or lowerLine:find("you are not impaling", 1, true) then
    return { event = "FINISHER_FAIL", name = "disembowel", reason = "line_fail" }
  end

  if lowerLine:find("you cannot devour", 1, true)
    or lowerLine:find("you fail to devour", 1, true)
    or lowerLine:find("you cease trying to devour", 1, true)
    or lowerLine:find("you stop trying to devour", 1, true) then
    return { event = "FINISHER_FAIL", name = "devour", reason = "line_fail" }
  end

  return nil
end

local function targetRemainderFromLine(line)
  local target = rwda.state and rwda.state.target and rwda.state.target.name
  if not target or target == "" then
    return nil
  end

  local lineNorm = normalizeName(line)
  local targetNorm = normalizeName(target)
  if lineNorm == "" or targetNorm == "" then
    return nil
  end

  local prefix = targetNorm .. " "
  if lineNorm:sub(1, #prefix) == prefix then
    return lineNorm:sub(#prefix + 1)
  end

  local possessivePrefix = targetNorm .. "'s "
  if lineNorm:sub(1, #possessivePrefix) == possessivePrefix then
    return lineNorm:sub(#possessivePrefix + 1)
  end

  return nil
end

local function isLikelyTargetAggressive(line)
  local rem = targetRemainderFromLine(line)
  if not rem or rem == "" then
    return false
  end

  local verb = rem:match("^(%a+)")
  if verb and AGGRESSIVE_VERBS[verb] then
    return true
  end

  if rem:find(" hits you", 1, true)
    or rem:find(" strikes you", 1, true)
    or rem:find(" slashes you", 1, true)
    or rem:find(" attacks you", 1, true)
    or rem:find(" stares at you", 1, true)
    or rem:find(" points at you", 1, true)
    or rem:find(" gestures toward you", 1, true)
    or rem:find(" gestures at you", 1, true) then
    return true
  end

  return false
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

local function inferTargetDefenceLoss(kind, line)
  local parserCfg = rwda.config and rwda.config.parser or {}
  if kind == "aggressive" and parserCfg.infer_defence_loss_on_aggressive == false then
    return false
  end
  if kind == "move" and parserCfg.infer_defence_loss_on_move == false then
    return false
  end

  local specs = rwda.data and rwda.data.defences or {}
  local targetName = rwda.state and rwda.state.target and rwda.state.target.name
  local confidence = tonumber(parserCfg.inferred_defence_confidence) or 0.35
  local changed = false

  for defName, spec in pairs(specs) do
    local shouldDrop = false
    if kind == "aggressive" and spec.drop_on_aggressive_act then
      shouldDrop = true
    elseif kind == "move" and spec.drop_on_move then
      shouldDrop = true
    end

    if shouldDrop then
      local d = rwda.state.target.defs and rwda.state.target.defs[defName]
      if d and d.active then
        rwda.state.setTargetDefence(defName, false, confidence, "assumed_" .. kind)
        emit("DEF_ASSUMED_LOST", {
          who = targetName,
          defence = defName,
          reason = kind,
          confidence = confidence,
          line = line,
        })
        changed = true
      end
    end
  end

  return changed
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

  if rwda.integrations and rwda.integrations.legacy and not rwda.state.integration.legacy_present then
    if rwda.integrations.legacy.detect() then
      rwda.integrations.legacy.registerHandlers()
      rwda.integrations.legacy.syncFromGlobals()
      rwda.util.log("info", "RWDA attached to Legacy backend.")
    end
  end

  local usingLegacy = rwda.state.integration.legacy_present

  if rwda.integrations and rwda.integrations.legacy and usingLegacy then
    rwda.integrations.legacy.syncFromGlobals()
  end

  parser.refreshTargetAvailabilityFromGMCP("prompt")

  if rwda.engine and rwda.engine.retaliation and rwda.engine.retaliation.update then
    rwda.engine.retaliation.update()
  end

  if rwda.engine and rwda.engine.finisher and rwda.engine.finisher.update then
    rwda.engine.finisher.update()
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

  local prevForm = rwda.state and rwda.state.me and rwda.state.me.form
  rwda.state.setForm(form)
  emit("FORM_CHANGED", { form = form, source = source or "parser" })

  -- Dragon shift auto-stores weapons; mark as unwielded so executor re-wields on return.
  if form == "dragon" then
    rwda.state.me.swords_wielded = false
  end

  if prevForm and prevForm ~= form and type(decho) == "function" then
    local fromLabel = prevForm == "dragon" and "Dragon" or "Runewarden"
    local toLabel   = form == "dragon"
      and "<orange_red>DRAGON<reset>"
      or "<chartreuse>RUNEWARDEN<reset>"
    decho("<dim_grey>[RWDA]<reset> Mode: <white>" .. fromLabel .. "<reset> → " .. toLabel .. "\n")
  end
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

  -- Capture every clean line to the log file when capture_all_lines is on.
  -- Use the same path as unmatched capture so one file covers the whole fight.
  local parserCfgAll = rwda.config and rwda.config.parser or {}
  if parserCfgAll.capture_all_lines then
    local path = resolveCapturePath()
    local f = io.open(path, "a")
    if f then
      local ts = os.date and os.date("%Y-%m-%d %H:%M:%S") or "0000-00-00 00:00:00"
      f:write(string.format("%s | %s\n", ts, line))
      f:close()
    end
  end

  local state = rwda.state
  local lower = line:lower()
  local nowMs = rwda.util.now()

  if parser._pending_assess_until and nowMs <= parser._pending_assess_until then
    local limb, pct, broken, mangled = parseAssessLimbLine(line)
    if limb then
      markTargetSeen("assess")
      state.target.last_assess = nowMs
      state.updateTargetLimb(limb, {
        damage_pct = pct,
        broken = broken or state.target.limbs[limb].broken,
        mangled = mangled or state.target.limbs[limb].mangled,
        confidence = 0.9,
      })
      emit("LIMB_DAMAGE", { who = state.target.name, limb = limb, source = "assess" })
      if broken then
        emit("LIMB_BROKEN", { who = state.target.name, limb = limb, source = "assess" })
      elseif mangled then
        emit("LIMB_MANGLED", { who = state.target.name, limb = limb, source = "assess" })
      end
      return
    end
  end

  local matched = false

  local aggressor = detectAggressorFromLine(line)
  if aggressor then
    matched = true
    emit("AGGRESSOR_HIT", {
      who = aggressor,
      line = line,
      confidence = 0.9,
    })
  end

  local finisherOutcome = detectFinisherOutcome(lower)
  if finisherOutcome then
    matched = true
    emit(finisherOutcome.event, {
      name = finisherOutcome.name,
      line = line,
      reason = finisherOutcome.reason,
    })
  end

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

  local assessTarget = captureByPatterns(line, {
    "^You assess (.+) and determine that:?$",
    "^You assess (.+)%.$",
    "^You assess (.+), determining that:?$",
  }) or captureByPatterns(lower, {
    "^you assess (.+) and determine that:?$",
    "^you assess (.+)[%.!]*$",
    "^you assess (.+), determining that:?$",
  })
  if assessTarget and isTarget(assessTarget) then
    markTargetSeen("assess")
    state.target.last_assess = nowMs
    parser._pending_assess_target = assessTarget
    parser._pending_assess_until = nowMs + 2500
    return
  end

  local selfAffGain = captureByPatterns(line, {
    "^You are afflicted with (.+)%.$",
    "^You have been afflicted with (.+)%.$",
    "^You are now afflicted with (.+)%.$",
    "^You suffer from (.+)%.$",
  }) or captureByPatterns(lower, {
    "^you are afflicted with (.+)[%.!]*$",
    "^you have been afflicted with (.+)[%.!]*$",
    "^you are now afflicted with (.+)[%.!]*$",
    "^you suffer from (.+)[%.!]*$",
  })
  if selfAffGain then
    local aff = resolveAffName(selfAffGain)
    if aff then
      state.setMeAff(aff, true, "line")
      emit("AFF_GAINED", { who = "me", affliction = aff })
      return
    end
  end

  local selfAffCure = captureByPatterns(line, {
    "^You are no longer afflicted with (.+)%.$",
    "^You have recovered from (.+)%.$",
    "^You are cured of (.+)%.$",
  }) or captureByPatterns(lower, {
    "^you are no longer afflicted with (.+)[%.!]*$",
    "^you have recovered from (.+)[%.!]*$",
    "^you are cured of (.+)[%.!]*$",
  })
  if selfAffCure then
    local aff = resolveAffName(selfAffCure)
    if aff then
      state.setMeAff(aff, false, "line")
      emit("AFF_CURED", { who = "me", affliction = aff })
      return
    end
  end

  local who, affText = captureTargetAff(line, {
    "^(.+) is afflicted with (.+)%.$",
    "^(.+) has been afflicted with (.+)%.$",
    "^(.+) suffers from (.+)%.$",
  })
  if not who then
    who, affText = captureTargetAff(lower, {
      "^(.+) is afflicted with (.+)[%.!]*$",
      "^(.+) has been afflicted with (.+)[%.!]*$",
      "^(.+) suffers from (.+)[%.!]*$",
    })
  end
  if who and affText and isTarget(who) then
    local aff = resolveAffName(affText)
    if aff then
      markTargetSeen("aff")
      state.setTargetAff(aff, true, "line")
      emit("AFF_GAINED", { who = who, affliction = aff })
      return
    end
  end

  local whoCure, affTextCure = captureTargetAff(line, {
    "^(.+) is no longer afflicted with (.+)%.$",
    "^(.+) has recovered from (.+)%.$",
    "^(.+) is cured of (.+)%.$",
  })
  if not whoCure then
    whoCure, affTextCure = captureTargetAff(lower, {
      "^(.+) is no longer afflicted with (.+)[%.!]*$",
      "^(.+) has recovered from (.+)[%.!]*$",
      "^(.+) is cured of (.+)[%.!]*$",
    })
  end
  if whoCure and affTextCure and isTarget(whoCure) then
    local aff = resolveAffName(affTextCure)
    if aff then
      markTargetSeen("aff")
      state.setTargetAff(aff, false, "line")
      emit("AFF_CURED", { who = whoCure, affliction = aff })
      return
    end
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

  if isLikelyTargetAggressive(line) then
    markTargetSeen("aggressive")
    inferTargetDefenceLoss("aggressive", line)
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

  -- TODO: fill in exact Achaea output lines for target taking flight / landing
  -- Flying up (target takes to the skies):
  -- local flyingUp = line:match("^(.+) takes to the skies%.$")
  -- if flyingUp and isTarget(flyingUp) then
  --   markTargetSeen("flying")
  --   state.target.flying = true
  --   return
  -- end
  -- Flying down (target lands):
  -- local flyingDown = line:match("^(.+) descends from the skies%.$")
  -- if flyingDown and isTarget(flyingDown) then
  --   state.target.flying = false
  --   return
  -- end

  -- TODO: fill in exact Achaea output lines for target caught in / freed from lyre trap
  -- Lyred (target caught):
  -- local lyred = line:match("^(.+) is ensnared by a .-lyre trap%.$")
  -- if lyred and isTarget(lyred) then
  --   markTargetSeen("lyred")
  --   state.target.lyred = true
  --   return
  -- end
  -- Freed from lyre:
  -- local unlyred = line:match("^(.+) breaks free from the lyre trap%.$")
  -- if unlyred and isTarget(unlyred) then
  --   state.target.lyred = false
  --   return
  -- end

  local detectedForm = detectFormFromText(lower)
  if detectedForm then
    parser.setForm(detectedForm, "line")
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

  if lower:find("you begin to wield", 1, true) then
    state.me.swords_wielded = true
    return
  end

  if lower:find("you stop wielding", 1, true) or lower:find("you are no longer wielding", 1, true) then
    state.me.swords_wielded = false
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

  -- Starburst tattoo: target survived death via tattoo resurrection.
  -- Server line: "A starburst tattoo flares and bathes <Name> in red light"
  -- The kill line fires first (clearing/marking the target dead), then this line
  -- arrives on the next server line.  Restore the target so attacks continue.
  -- Match against both the current target name and the most recent cleared target
  -- (state.target.last_target) so the restore works even after clearTarget().
  local starburstWho = line:match("^A starburst tattoo flares and bathes ([A-Z][%w'%-]+)")
  if starburstWho then
    local norm = normalizeName(starburstWho)
    local targetNorm = normalizeName(state.target.name or "")
    local lastNorm = normalizeName(state.target.last_target or "")
    if (targetNorm ~= "" and norm == targetNorm)
      or (lastNorm ~= "" and norm == lastNorm) then
      local restoreSource = state.target.target_source or "starburst"
      state.setTarget(starburstWho, restoreSource)
      emit("TARGET_ALIVE", { who = starburstWho, reason = "starburst" })
      rwda.util.log("info", "Starburst: %s survived, resuming attack.", tostring(starburstWho))
      return
    end
  end

  local escape = line:match("^(.+) leaves [a-z]+%.$")
  if escape and isTarget(escape) then
    inferTargetDefenceLoss("move", line)
    markTargetMissing("left_room")
    state.target.last_seen = rwda.util.now()
    emit("TARGET_MOVED", { who = escape })
    return
  end

  -- ── Runelore: rune attunement / empower events ────────────────────────────
  -- These messages are sent by the Achaea server when your runeblade rune
  -- mechanics activate.  All are first-person messages (only fire for your own
  -- runeblade), so no target-matching is required.

  local runeAttuned = line:match("^Your (%a+) rune becomes attuned")
    or line:match("^Your (%a+) rune has become attuned")
    or lower:match("^your (%a+) rune becomes attuned")
    or lower:match("^your (%a+) rune has become attuned")
  if runeAttuned and rwda.engine and rwda.engine.runelore then
    rwda.engine.runelore.onRuneAttuned_event(runeAttuned)
    return
  end

  local runeDetuned = line:match("^Your (%a+) rune is no longer attuned")
    or line:match("^Your (%a+) rune loses its attunement")
    or lower:match("^your (%a+) rune is no longer attuned")
    or lower:match("^your (%a+) rune loses its attunement")
  if runeDetuned and rwda.engine and rwda.engine.runelore then
    rwda.engine.runelore.onRuneAttuneLost_event(runeDetuned)
    return
  end

  local runeEmpowered = line:match("^You empower your (%a+) rune")
    or lower:match("^you empower your (%a+) rune")
  if runeEmpowered and rwda.engine and rwda.engine.runelore then
    rwda.engine.runelore.onRuneEmpowered_event(runeEmpowered)
    return
  end

  if (lower:find("your runic configuration", 1, true))
    and (lower:find("activates", 1, true) or lower:find("springs to life", 1, true))
    and rwda.engine and rwda.engine.runelore then
    rwda.engine.runelore.onConfigActivated_event()
    return
  end

  if (lower:find("your pithakhan rune", 1, true))
    and (lower:find("drain", 1, true) or lower:find("mana from", 1, true))
    and rwda.engine and rwda.engine.runelore then
    rwda.engine.runelore.onPithakhanDrain_event()
    return
  end

  -- ── Runesmith: sketch / empower confirmation lines ───────────────────────────
  -- All lines are routed through runesmith.onLine() regardless of which specific
  -- pattern matched.  The state machine inside runesmith decides relevance.
  if rwda.engine and rwda.engine.runesmith and rwda.engine.runesmith.onLine then
    local rsPatterns = {
      "you finish sketching",
      "you empower",
      "you set the empowerment priority",
      "you need more equilibrium",
      "you don't have any",
      "you aren't holding",
      "that is not a runeblade",
      "you cannot sketch",
      "you cannot empower",
      "you don't have enough mana",
      "no need to duplicate",
    }
    for _, pat in ipairs(rsPatterns) do
      if lower:find(pat, 1, true) then
        rwda.engine.runesmith.onLine(line)
        break
      end
    end
  end

  -- ── Fury: activation / loss confirmation lines ──────────────────────────────
  if rwda.engine and rwda.engine.fury and rwda.engine.fury.onLine then
    local furyPatterns = {
      "surge of fury",
      "you activate your fury",
      "you enter a fury",
      "your fury fades",
      "your fury dissipates",
      "you relax out of your fury",
      "you are already in a fury",
      "you do not have enough willpower",
    }
    for _, pat in ipairs(furyPatterns) do
      if lower:find(pat, 1, true) then
        rwda.engine.fury.onLine(line)
        break
      end
    end
  end

  if not matched then
    captureUnmatchedLine(line)
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
