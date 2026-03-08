rwda = rwda or {}
rwda.integrations = rwda.integrations or {}
rwda.integrations.helpdb = rwda.integrations.helpdb or {
  loaded = false,
  path = nil,
  data = {
    command_index = {},
    ability_index = {},
    affliction_index = {},
    defence_index = {},
    class_index = {},
    skill_index = {},
    relations = {},
    command_names = {},
    manifest = {},
  },
}

local helpdb = rwda.integrations.helpdb

local function log(level, fmt, ...)
  if rwda.util and rwda.util.log then
    rwda.util.log(level, "[HelpDB] " .. fmt, ...)
  elseif type(echo) == "function" then
    echo(string.format("[RWDA HelpDB] " .. tostring(fmt) .. "\n", ...))
  end
end

local function normalizeSlashes(path)
  if type(path) ~= "string" then return nil end
  return path:gsub("/", "\\")
end

local function fileExists(path)
  if type(path) ~= "string" or path == "" then return false end
  local f = io.open(path, "r")
  if f then f:close(); return true end
  return false
end

local function dirLooksLikeExport(path)
  return fileExists(path .. "\\command_index.lua") or fileExists(path .. "/command_index.lua")
end

local function join(a, b)
  if not a or a == "" then return b end
  local sep = a:find("/") and "/" or "\\"
  if a:match("[/\\]$") then return a .. b end
  return a .. sep .. b
end

local function trim(s)
  if type(s) ~= "string" then return "" end
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(s)
  if type(s) ~= "string" then return s end
  return trim(s:lower())
end

local function resolveExportDir(path)
  local candidates = {}

  local function add(p)
    if type(p) == "string" and p ~= "" then
      candidates[#candidates + 1] = p
    end
  end

  if type(path) == "string" and path ~= "" then
    add(path)
    add(join(path, "silverfury_data"))
    add(join(path, "processed\\lua\\silverfury_data"))
    add(join(path, "processed/lua/silverfury_data"))
  end

  local basePath = rwda.base_path or "rwda"
  add(join(basePath, "vendor\\silverfury_data"))
  add(join(basePath, "vendor/silverfury_data"))
  add(join(basePath, "..\\achaea_help_dataset\\processed\\lua\\silverfury_data"))
  add(join(basePath, "../achaea_help_dataset/processed/lua/silverfury_data"))
  if type(getMudletHomeDir) == "function" then
    local ok, home = pcall(getMudletHomeDir)
    if ok and type(home) == "string" and home ~= "" then
      add(join(home, "rwda\\vendor\\silverfury_data"))
      add(join(home, "rwda/vendor/silverfury_data"))
      add(join(home, "achaea_help_dataset\\processed\\lua\\silverfury_data"))
      add(join(home, "achaea_help_dataset/processed/lua/silverfury_data"))
    end
  end

  for _, candidate in ipairs(candidates) do
    if dirLooksLikeExport(candidate) then
      return candidate
    end
  end

  return nil
end

local function loadModule(dir, filename)
  local tried = {
    join(dir, filename),
    normalizeSlashes(join(dir, filename)),
  }
  for _, full in ipairs(tried) do
    if fileExists(full) then
      local ok, value = pcall(dofile, full)
      if ok then return true, value end
      return false, value
    end
  end
  return false, "missing file: " .. tostring(filename)
end

function helpdb.load(path)
  local dir = resolveExportDir(path)
  if not dir then
    return false, "could not resolve silverfury_data export directory"
  end

  local files = {
    command_index = "command_index.lua",
    ability_index = "ability_index.lua",
    affliction_index = "affliction_index.lua",
    defence_index = "defence_index.lua",
    class_index = "class_index.lua",
    skill_index = "skill_index.lua",
    relations = "relations.lua",
    command_names = "command_names.lua",
    manifest = "manifest.lua",
  }

  local loaded = {}
  for key, filename in pairs(files) do
    local ok, result = loadModule(dir, filename)
    if not ok then
      if key ~= "manifest" then
        return false, tostring(result)
      end
      loaded[key] = {}
    else
      loaded[key] = result
    end
  end

  helpdb.data = loaded
  helpdb.path = dir
  helpdb.loaded = true
  rwda.data = rwda.data or {}
  rwda.data.helpdb = loaded
  log("info", "Loaded export from %s", dir)
  return true, dir
end

function helpdb.unload()
  helpdb.loaded = false
  helpdb.path = nil
  helpdb.data = {
    command_index = {}, ability_index = {}, affliction_index = {}, defence_index = {},
    class_index = {}, skill_index = {}, relations = {}, command_names = {}, manifest = {},
  }
  if rwda.data then rwda.data.helpdb = nil end
end

function helpdb.status()
  return {
    loaded = helpdb.loaded == true,
    path = helpdb.path,
    commands = type(helpdb.data.command_index) == "table" and (next(helpdb.data.command_index) and true or false) or false,
    abilities = type(helpdb.data.ability_index) == "table" and (next(helpdb.data.ability_index) and true or false) or false,
    afflictions = type(helpdb.data.affliction_index) == "table" and (next(helpdb.data.affliction_index) and true or false) or false,
    defences = type(helpdb.data.defence_index) == "table" and (next(helpdb.data.defence_index) and true or false) or false,
  }
end

local function lookup(indexName, key)
  local index = helpdb.data[indexName] or {}
  if type(index) ~= "table" then return nil end
  return index[lower(key)] or index[key]
end

function helpdb.getCommand(name) return lookup("command_index", name) end
function helpdb.getAbility(name) return lookup("ability_index", name) end
function helpdb.getAffliction(name) return lookup("affliction_index", name) end
function helpdb.getDefence(name) return lookup("defence_index", name) end
function helpdb.getSkill(name) return lookup("skill_index", name) end
function helpdb.getClass(name) return lookup("class_index", name) end

function helpdb.search(term, limit)
  term = lower(term)
  limit = tonumber(limit) or 15
  local out = {}
  if term == "" then return out end
  local indexes = {
    { kind = "command", data = helpdb.data.command_index },
    { kind = "ability", data = helpdb.data.ability_index },
    { kind = "affliction", data = helpdb.data.affliction_index },
    { kind = "defence", data = helpdb.data.defence_index },
    { kind = "skill", data = helpdb.data.skill_index },
    { kind = "class", data = helpdb.data.class_index },
  }
  for _, bundle in ipairs(indexes) do
    if type(bundle.data) == "table" then
      for key, value in pairs(bundle.data) do
        local k = tostring(key):lower()
        if k:find(term, 1, true) then
          out[#out + 1] = { kind = bundle.kind, key = tostring(key), value = value }
          if #out >= limit then return out end
        end
      end
    end
  end
  return out
end

function helpdb.bootstrap()
  local cfg = rwda.config and rwda.config.helpdb or {}
  if cfg.auto_load == false then
    return false
  end
  local ok, err = helpdb.load(cfg.path)
  if not ok then
    log("warn", "Auto-load skipped: %s", tostring(err))
    return false
  end
  return true
end
