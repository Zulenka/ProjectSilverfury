-- Silverfury/util/files.lua
-- File system helpers for log path construction.

Silverfury = Silverfury or {}
Silverfury.files = Silverfury.files or {}

-- Base directory for all Silverfury output inside the Mudlet profile.
function Silverfury.files.baseDir()
  return getMudletHomeDir() .. "/Silverfury"
end

-- Log directory: baseDir/logs/YYYY-MM-DD/
function Silverfury.files.logDir()
  return Silverfury.files.baseDir() .. "/logs/" .. Silverfury.time.date()
end

-- Ensure a directory exists (creates parents as needed on supported platforms).
function Silverfury.files.ensureDir(path)
  -- Mudlet's lfs or os.execute mkdir -p
  if lfs then
    -- Walk and create each segment.
    local current = ""
    for segment in path:gmatch("[^/\\]+") do
      current = current .. "/" .. segment
      lfs.mkdir(current)
    end
  else
    -- Fallback: system call
    local sep = package.config:sub(1,1)
    if sep == "\\" then
      os.execute('mkdir "' .. path:gsub("/", "\\") .. '" 2>nul')
    else
      os.execute('mkdir -p "' .. path .. '"')
    end
  end
end

-- Open file for appending, creating parent dirs as needed.
-- Returns file handle or nil, err.
function Silverfury.files.openAppend(path)
  Silverfury.files.ensureDir(path:match("(.+)[/\\][^/\\]+$") or ".")
  return io.open(path, "a")
end
