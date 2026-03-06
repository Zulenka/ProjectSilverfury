-- Silverfury/parser/outgoing.lua
-- Track outgoing commands and confirm actions (venoms applied, attacks sent).

Silverfury = Silverfury or {}
Silverfury.parser = Silverfury.parser or {}

local outgoing = {}
Silverfury.parser.outgoing = outgoing

-- ── Track last sent DSL/attack so we can extract venoms ──────────────────────

local _last_cmd     = nil
local _last_venoms  = {}   -- list of venom names from most recently sent attack cmd

-- Extract venoms and assume affs landed on target (unconfirmed / inferred).
local function _processVenoms(v1, v2)
  _last_venoms = {}
  local function process(vname)
    if not vname then return end
    local data = Silverfury.offense.venoms.DATA[vname]
    if data then
      Silverfury.offense.venoms.record(vname)
      _last_venoms[#_last_venoms + 1] = vname
      -- Assume the aff landed (conservative: not confirmed, confidence = 0.5).
      if data.aff then
        Silverfury.state.target.addAff(data.aff, false)
        Silverfury.log.trace("Assumed aff: %s (from %s)", data.aff, vname)
      end
    end
  end
  process(v1)
  process(v2)
end

-- Intercept via SF_CommandSent event fired by queue.
local function onCommandSent(_, cmd)
  _last_cmd = cmd

  -- dsl pattern: "dsl target limb venom1 venom2"
  local v1, v2 = cmd:match("^dsl%s+%S+%s+%S+%s+(%S+)%s+(%S+)")
  if v1 then
    _processVenoms(v1, v2)
    Silverfury.logging.logger.write("OUTGOING_COMMAND", { cmd=cmd, venom1=v1, venom2=v2 })
    return
  end

  -- undercut pattern: "undercut target limb venom1 venom2"
  v1, v2 = cmd:match("^undercut%s+%S+%s+%S+%s+(%S+)%s+(%S+)")
  if v1 then
    _processVenoms(v1, v2)
    Silverfury.logging.logger.write("OUTGOING_COMMAND", { cmd=cmd, venom1=v1, venom2=v2 })
    return
  end

  -- razeslash pattern: "razeslash target venom1 venom2"
  local rv1, rv2 = cmd:match("^razeslash%s+%S+%s+(%S+)%s+(%S+)")
  if rv1 then
    _processVenoms(rv1, rv2)
    Silverfury.logging.logger.write("OUTGOING_COMMAND", { cmd=cmd, venom1=rv1, venom2=rv2 })
    return
  end

  -- ── Dragon command recognizers ────────────────────────────────────────────

  -- summon <type>
  local btype = cmd:match("^summon%s+(%S+)")
  if btype then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="summon", breath=btype })
    raiseEvent("SF_DragonSummonSent", btype)
    return
  end

  -- devour <target>
  if cmd:match("^devour%s+%S+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="devour" })
    raiseEvent("SF_DevourSent")
    return
  end

  -- block <direction>
  local bdir = cmd:match("^block%s+(%S+)")
  if bdir then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="block", dir=bdir })
    raiseEvent("SF_DragonBlockSent", bdir)
    return
  end

  -- unblock
  if cmd:match("^unblock$") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="unblock" })
    raiseEvent("SF_DragonUnblockSent")
    return
  end

  -- breathgust <target> — optimistically mark target as prone
  if cmd:match("^breathgust%s+%S+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="breathgust" })
    raiseEvent("SF_DragonGustSent")
    return
  end

  -- tailsweep — room-wide prone
  if cmd:match("^tailsweep$") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="tailsweep" })
    raiseEvent("SF_DragonTailsweepSent")
    return
  end

  -- gut / rend / bite — log dragon physical strikes
  if cmd:match("^gut%s+") or cmd:match("^rend%s+") or cmd:match("^bite%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="strike" })
    return
  end

  -- dragonarmour on/off
  local da = cmd:match("^dragonarmour%s+(%S+)")
  if da then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="dragonarmour", state=da })
    return
  end

  -- dragonflex
  if cmd:match("^dragonflex$") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="dragonflex" })
    return
  end

  -- tailsmash <target>
  if cmd:match("^tailsmash%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="tailsmash" })
    return
  end

  -- breathstrip <target>
  if cmd:match("^breathstrip%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="breathstrip" })
    return
  end

  -- blast <target> — breath weapon fired
  if cmd:match("^blast%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="blast" })
    raiseEvent("SF_DragonBlastSent")
    return
  end

  -- breathstorm <target>
  if cmd:match("^breathstorm%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="breathstorm" })
    return
  end

  -- swipe <target> ...
  if cmd:match("^swipe%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="swipe" })
    return
  end

  -- enmesh <target>
  if cmd:match("^enmesh%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="enmesh" })
    return
  end

  -- becalm <target>
  if cmd:match("^becalm%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="becalm" })
    return
  end

  -- track <target>
  if cmd:match("^track%s+") then
    Silverfury.logging.logger.write("DRAGON_COMMAND", { cmd=cmd, action="track" })
    return
  end
end

-- ── Confirm lines ─────────────────────────────────────────────────────────────
-- These patterns confirm that a sent command was accepted by the server.

local CONFIRMS = {
  { "^You slash (.+) with",          "dsl_confirm" },
  { "^You raze (.+) with",           "raze_confirm" },
  { "^You impale (.+)%.",            "impale_confirm" },
  { "^You disembowel (.+) with",     "disembowel_confirm" },
  { "^You undercut (.+) with",       "undercut_confirm" },
}

local function onLine(_, line)
  if not line then return end
  for _, entry in ipairs(CONFIRMS) do
    if line:match(entry[1]) then
      raiseEvent("SF_OutgoingConfirm", entry[2], line)
      Silverfury.logging.logger.write("OUTGOING_CONFIRM", { type=entry[2], line=line })
    end
  end
end

-- ── Registration ─────────────────────────────────────────────────────────────

local _handlers = {}

function outgoing.registerHandlers()
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}

  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_CommandSent", onCommandSent)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("sysDataReceived", onLine)
end

function outgoing.shutdown()
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}
end

function outgoing.lastCmd()
  return _last_cmd
end

function outgoing.lastVenoms()
  return _last_venoms
end
