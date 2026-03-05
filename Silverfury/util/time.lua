-- Silverfury/util/time.lua
-- Time helpers.

Silverfury = Silverfury or {}
Silverfury.time = Silverfury.time or {}

-- Current time in milliseconds.
function Silverfury.time.now()
  if getEpoch then
    return math.floor(getEpoch() * 1000)
  end
  return math.floor(os.time() * 1000)
end

-- ISO-8601 timestamp string.
function Silverfury.time.iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Local date string YYYY-MM-DD.
function Silverfury.time.date()
  return os.date("%Y-%m-%d")
end

-- Local time string HHMMSS.
function Silverfury.time.hms()
  return os.date("%H%M%S")
end

-- Elapsed seconds since epoch_ms.
function Silverfury.time.elapsed_s(epoch_ms)
  return (Silverfury.time.now() - epoch_ms) / 1000
end
