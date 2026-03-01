rwda = rwda or {}
rwda.util = rwda.util or {}

local util = rwda.util

function util.now()
  if type(getEpoch) == "function" then
    local ok, value = pcall(getEpoch)
    if ok and type(value) == "number" then
      return math.floor(value * 1000)
    end
  end

  if os and os.time then
    return os.time() * 1000
  end

  return 0
end

function util.deepcopy(value, seen)
  if type(value) ~= "table" then
    return value
  end

  seen = seen or {}
  if seen[value] then
    return seen[value]
  end

  local copy = {}
  seen[value] = copy
  for k, v in pairs(value) do
    copy[util.deepcopy(k, seen)] = util.deepcopy(v, seen)
  end

  return copy
end

function util.merge(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then
    return dst
  end

  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      util.merge(dst[k], v)
    else
      dst[k] = v
    end
  end

  return dst
end

function util.round(value, precision)
  if type(value) ~= "number" then
    return value
  end

  precision = precision or 0
  local factor = 10 ^ precision
  return math.floor(value * factor + 0.5) / factor
end

function util.bool(value)
  if value == true or value == 1 or value == "1" or value == "true" then
    return true
  end
  return false
end

local LOG_LEVELS = {
  trace = 1,
  info = 2,
  warn = 3,
  error = 4,
}

function util.log(level, fmt, ...)
  level = level or "info"
  local cfg = rwda.config or {}
  local logging = cfg.logging or {}
  if logging.enabled == false then
    return
  end

  local min_level = logging.level or "info"
  if (LOG_LEVELS[level] or 2) < (LOG_LEVELS[min_level] or 2) then
    return
  end

  local ok, message = pcall(string.format, fmt or "%s", ...)
  if not ok then
    message = tostring(fmt)
  end

  local tag    = string.upper(level)
  local line   = string.format("[RWDA][%s] %s", tag, message)

  if type(decho) == "function" then
    decho(string.format("<239,243,238>[RWDA][%s] %s<r>\n", tag, message))
  elseif type(echo) == "function" then
    echo(line .. "\n")
  elseif type(print) == "function" then
    print(line)
  end
end
