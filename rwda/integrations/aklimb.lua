rwda = rwda or {}
rwda.integrations = rwda.integrations or {}
rwda.integrations.aklimb = rwda.integrations.aklimb or {}

local adapter = rwda.integrations.aklimb

local function trim(input)
  if type(input) ~= "string" then
    return ""
  end
  return input:gsub("^%s+", ""):gsub("%s+$", "")
end

local function toNumber(value)
  if type(value) == "number" then
    return value
  end
  if type(value) == "string" then
    local n = tonumber((value:gsub("%%", "")))
    return n
  end
  return nil
end

local function boolish(value)
  if type(value) == "boolean" then
    return value
  end
  if type(value) == "number" then
    return value ~= 0
  end
  if type(value) == "string" then
    local v = trim(value):lower()
    if v == "1" or v == "true" or v == "yes" or v == "on" then
      return true
    end
    if v == "0" or v == "false" or v == "no" or v == "off" then
      return false
    end
  end
  return nil
end

local function normalizeKey(key)
  return tostring(key or ""):lower():gsub("[^%a%d]", "")
end

local function mapLimbKey(key)
  local k = normalizeKey(key)
  if k == "" then
    return nil
  end

  if k == "head" or k == "h" then
    return "head"
  end
  if k == "torso" or k == "body" or k == "chest" or k == "t" then
    return "torso"
  end
  if k == "leftarm" or k == "larm" or k == "la" then
    return "left_arm"
  end
  if k == "rightarm" or k == "rarm" or k == "ra" then
    return "right_arm"
  end
  if k == "leftleg" or k == "lleg" or k == "ll" then
    return "left_leg"
  end
  if k == "rightleg" or k == "rleg" or k == "rl" then
    return "right_leg"
  end

  return nil
end

local function parseLimbRow(row)
  if type(row) == "nil" then
    return nil
  end

  local out = {}
  if type(row) == "number" then
    out.damage_pct = row
  elseif type(row) == "string" then
    local lower = row:lower()
    out.damage_pct = toNumber(row)
    if lower:find("broken", 1, true) or lower:find("crippled", 1, true) then
      out.broken = true
    end
    if lower:find("mangled", 1, true) or lower:find("damaged", 1, true) then
      out.mangled = true
    end
  elseif type(row) == "table" then
    out.damage_pct = toNumber(row.damage_pct) or toNumber(row.damage) or toNumber(row.pct) or toNumber(row.percent) or toNumber(row.value)
    out.broken = boolish(row.broken)
    if out.broken == nil then
      out.broken = boolish(row.crippled) or boolish(row.fractured)
    end
    out.mangled = boolish(row.mangled)
    if out.mangled == nil then
      out.mangled = boolish(row.damaged)
    end
  end

  if out.damage_pct then
    out.damage_pct = math.max(0, math.min(150, out.damage_pct))
  end

  if out.broken and (not out.damage_pct or out.damage_pct < 100) then
    out.damage_pct = 100
  end

  if out.mangled and (not out.damage_pct or out.damage_pct < 75) then
    out.damage_pct = 75
  end

  if out.damage_pct == nil and out.broken == nil and out.mangled == nil then
    return nil
  end

  return out
end

local function mergeLimbTable(snapshot, rows)
  if type(rows) ~= "table" then
    return
  end

  for key, row in pairs(rows) do
    local limb = mapLimbKey(key)
    if limb then
      local patch = parseLimbRow(row)
      if patch then
        snapshot[limb] = snapshot[limb] or {}
        rwda.util.merge(snapshot[limb], patch)
      end
    end
  end
end

local function extractFromLBPrompt(lbObj, snapshot)
  if type(lbObj) ~= "table" or type(lbObj.prompt) ~= "function" then
    return
  end

  local ok, text = pcall(lbObj.prompt)
  if not ok or type(text) ~= "string" or text == "" then
    return
  end

  local cleaned = text:gsub("\27%[[0-9;]*m", ""):gsub("<[^>]+>", " "):lower()
  for label, value in cleaned:gmatch("([%a_ ]+)%s*[:=]%s*(%d+)") do
    local limb = mapLimbKey(label)
    local dmg = tonumber(value)
    if limb and dmg then
      snapshot[limb] = snapshot[limb] or {}
      snapshot[limb].damage_pct = math.max(0, math.min(150, dmg))
    end
  end
end

function adapter.detect()
  local present = type(rawget(_G, "ak")) == "table"
    or type(rawget(_G, "aklimb")) == "table"
    or type(rawget(_G, "lb")) == "table"

  rwda.state.integration.aklimb_present = present
  return present
end

function adapter.pull(targetName)
  if not adapter.detect() then
    return nil
  end

  targetName = targetName or rwda.state.target.name

  local aklimbGlobal = rawget(_G, "aklimb")
  local akGlobal = rawget(_G, "ak")
  local lbGlobal = rawget(_G, "lb")

  if type(aklimbGlobal) == "table" and type(aklimbGlobal.targets) == "table" and targetName then
    local row = aklimbGlobal.targets[targetName]
    if type(row) == "table" then
      return row
    end
  end

  if type(akGlobal) == "table" and type(akGlobal.targets) == "table" and targetName then
    local row = akGlobal.targets[targetName]
    if type(row) == "table" then
      return row
    end
  end

  local snapshot = {
    limbs = {},
    defs = {},
  }

  if type(lbGlobal) == "table" then
    if type(lbGlobal.targets) == "table" and targetName and type(lbGlobal.targets[targetName]) == "table" then
      mergeLimbTable(snapshot.limbs, lbGlobal.targets[targetName])
    end
    mergeLimbTable(snapshot.limbs, lbGlobal.limbs)
    mergeLimbTable(snapshot.limbs, lbGlobal.damage)
    extractFromLBPrompt(lbGlobal, snapshot.limbs)
    -- limb 1.2 shape: lb[targetName].hits[limbName] = cumulative damage %
    -- Values >= 100 indicate a broken limb.
    if targetName and type(lbGlobal[targetName]) == "table"
        and type(lbGlobal[targetName].hits) == "table" then
      for lname, val in pairs(lbGlobal[targetName].hits) do
        local limb = mapLimbKey(lname)
        local dmg = type(val) == "number" and val or nil
        if limb and dmg then
          snapshot.limbs[limb] = snapshot.limbs[limb] or {}
          snapshot.limbs[limb].damage_pct = math.max(0, math.min(150, dmg))
          if dmg >= 100 then
            snapshot.limbs[limb].broken = true
          end
        end
      end
    end
  end

  if type(akGlobal) == "table" and type(akGlobal.defs) == "table" then
    snapshot.defs.shield = boolish(akGlobal.defs.shield)
    snapshot.defs.rebounding = boolish(akGlobal.defs.rebounding)
  end

  if next(snapshot.limbs) or next(snapshot.defs) then
    return snapshot
  end

  return nil
end

function adapter.mergeSnapshot(snapshot)
  if type(snapshot) ~= "table" then
    return false
  end

  local changed = false
  local map = {
    leftleg = "left_leg",
    rightleg = "right_leg",
    leftarm = "left_arm",
    rightarm = "right_arm",
    torso = "torso",
    head = "head",
  }

  local limbRows = snapshot.limbs or snapshot
  for key, row in pairs(limbRows) do
    local limb = map[tostring(key)] or mapLimbKey(key)
    if limb and rwda.state.target.limbs[limb] then
      local patch = parseLimbRow(row) or {}
      patch.damage_pct = patch.damage_pct or rwda.state.target.limbs[limb].damage_pct
      patch.confidence = tonumber(patch.confidence) or 0.85
      rwda.state.updateTargetLimb(limb, patch)
      changed = true
    end
  end

  local defs = snapshot.defs
  if type(defs) == "table" then
    local shield = boolish(defs.shield)
    if shield ~= nil then
      rwda.state.setTargetDefence("shield", shield, shield and 0.95 or 0.75, "ak")
      changed = true
    end

    local rebound = boolish(defs.rebounding)
    if rebound ~= nil then
      rwda.state.setTargetDefence("rebounding", rebound, rebound and 0.95 or 0.75, "ak")
      changed = true
    end
  end

  return changed
end

function adapter.sync()
  local snap = adapter.pull(rwda.state.target.name)
  if not snap then
    return false
  end

  return adapter.mergeSnapshot(snap)
end
