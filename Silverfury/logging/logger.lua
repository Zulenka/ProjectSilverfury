-- Silverfury/logging/logger.lua
-- JSON Lines combat logger.
-- Writes timestamped records to:
--   getMudletHomeDir()/Silverfury/logs/YYYY-MM-DD/HHMMSS_target.jsonl

Silverfury = Silverfury or {}
Silverfury.logging = Silverfury.logging or {}

local logger = {}
Silverfury.logging.logger = logger

-- ── State ─────────────────────────────────────────────────────────────────────

local _file    = nil    -- current log file handle
local _path    = nil    -- current log file path
local _buffer  = {}     -- in-memory buffer
local _enabled = true
local _handlers = {}

-- ── File management ───────────────────────────────────────────────────────────

local function logPath()
  local tname = (Silverfury.state.target and Silverfury.state.target.name) or "unknown"
  tname = tname:lower():gsub("%s+", "_")
  return Silverfury.files.logDir() .. "/" .. Silverfury.time.hms() .. "_" .. tname .. ".jsonl"
end

function logger.openFile()
  if _file then logger.closeFile() end
  if not Silverfury.config.get("logging.to_file") then return end
  local path = logPath()
  local f, err = Silverfury.files.openAppend(path)
  if not f then
    Silverfury.log.warn("logger: cannot open log file: %s", tostring(err))
    return
  end
  _file = f
  _path = path
  Silverfury.log.info("Combat log: %s", path)
end

function logger.closeFile()
  if _file then
    logger.flush()
    _file:close()
    _file = nil
    _path = nil
  end
end

-- ── Buffered write ────────────────────────────────────────────────────────────

-- Write a log record. type = string record type (see plan section 5.5).
-- data = table of additional fields.
function logger.write(record_type, data)
  if not _enabled then return end

  local record = {
    ts     = Silverfury.time.iso(),
    type   = record_type,
    me     = Silverfury.logging.formats.meSnapshot(),
    target = Silverfury.logging.formats.targetSnapshot(),
  }
  if type(data) == "table" then
    for k, v in pairs(data) do
      if record[k] == nil then record[k] = v end
    end
  end

  _buffer[#_buffer+1] = Silverfury.logging.formats.encode(record)

  -- Flush if buffer hits threshold.
  if #_buffer >= 20 then logger.flush() end
end

-- Raw console-level log line (from util/log.lua).
function logger.raw(level, msg)
  if not _enabled then return end
  logger.write("LOG_" .. level:upper(), { msg=msg })
end

-- Flush buffer to file.
function logger.flush()
  if not _file or #_buffer == 0 then _buffer = {}; return end
  for _, line in ipairs(_buffer) do
    _file:write(line .. "\n")
  end
  _file:flush()
  _buffer = {}
end

-- ── Periodic flush timer ─────────────────────────────────────────────────────

local _flush_timer = nil

local function startFlushTimer()
  if _flush_timer then killTimer(_flush_timer) end
  _flush_timer = tempTimer(5, function()
    logger.flush()
    startFlushTimer()
  end)
end

-- ── Enable / disable ──────────────────────────────────────────────────────────

function logger.enable()
  _enabled = true
  Silverfury.config.set("logging.enabled", true)
  Silverfury.log.info("Combat logging enabled.")
end

function logger.disable()
  logger.flush()
  _enabled = false
  Silverfury.config.set("logging.enabled", false)
  Silverfury.log.info("Combat logging disabled.")
end

function logger.isEnabled()
  return _enabled
end

-- ── Prompt snapshot tick ──────────────────────────────────────────────────────

local function onPrompt()
  logger.write("PROMPT_SNAPSHOT", {})
  logger.flush()
end

-- ── Target change → open new file ─────────────────────────────────────────────

local function onTargetChanged(_, name)
  if name then
    logger.closeFile()
    logger.openFile()
  else
    logger.closeFile()
  end
end

-- ── Initialise ────────────────────────────────────────────────────────────────

function logger.init()
  _enabled = Silverfury.config.get("logging.enabled") ~= false

  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}

  _handlers[#_handlers+1] = registerAnonymousEventHandler("LPrompt",           onPrompt)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_TargetChanged",  onTargetChanged)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_Armed",          function()
    logger.write("MODE_CHANGE", { mode="ARMED" })
  end)
  _handlers[#_handlers+1] = registerAnonymousEventHandler("SF_Abort",          function(_, reason)
    logger.write("ABORT", { reason=reason })
    logger.flush()
  end)

  startFlushTimer()
end

function logger.shutdown()
  logger.closeFile()
  if _flush_timer then killTimer(_flush_timer); _flush_timer = nil end
  for _, id in ipairs(_handlers) do killHandler(id) end
  _handlers = {}
end

-- ── Path helper ───────────────────────────────────────────────────────────────
function logger.currentPath()
  return _path
end

function logger.openFolder()
  local dir = Silverfury.files.logDir()
  Silverfury.log.info("Log folder: %s", dir)
  -- Attempt to open in system file explorer (best-effort).
  if package.config:sub(1,1) == "\\" then
    os.execute('explorer "' .. dir:gsub("/","\\") .. '"')
  elseif io.open("/usr/bin/open","r") then
    os.execute('open "' .. dir .. '"')
  else
    os.execute('xdg-open "' .. dir .. '"')
  end
end
