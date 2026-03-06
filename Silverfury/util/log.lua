-- Silverfury/util/log.lua
-- Colour-tagged console logger. Respects config.logging.level.

Silverfury = Silverfury or {}
Silverfury.log = Silverfury.log or {}

local LEVELS = { trace=1, info=2, warn=3, error=4 }

local COLOURS = {
  trace = "<ansi_dark_gray>",
  info  = "<lightcyan>",
  warn  = "<ansi_yellow>",
  error = "<ansi_red>",
}

local PREFIX_COLOURS = {
  trace = "<ansi_dark_gray>",
  info  = "<126,200,227>",
  warn  = "<ansi_yellow>",
  error = "<ansi_red>",
}

local function level()
  local cfg = Silverfury.config and Silverfury.config.get
  local l = cfg and cfg("logging.level") or "info"
  return LEVELS[l] or 2
end

local function emit(lvl, fmt, ...)
  if (LEVELS[lvl] or 0) < level() then return end
  local msg    = string.format(fmt, ...)
  local colour = COLOURS[lvl] or ""
  local pcol   = PREFIX_COLOURS[lvl] or colour
  local prefix = string.format("[SF/%s] ", lvl:upper())
  cecho(pcol .. prefix .. colour .. msg .. "<reset>\n")

  -- Optional file output handled by logging module when fully initialised.
  if Silverfury.logging and Silverfury.logging.logger and Silverfury.logging.logger.raw then
    Silverfury.logging.logger.raw(lvl, msg)
  end
end

function Silverfury.log.trace(fmt, ...) emit("trace", fmt, ...) end
function Silverfury.log.info(fmt, ...)  emit("info",  fmt, ...) end
function Silverfury.log.warn(fmt, ...)  emit("warn",  fmt, ...) end
function Silverfury.log.error(fmt, ...) emit("error", fmt, ...) end
