-- Silverfury/logging/formats.lua
-- Serialisation helpers for log records.

Silverfury = Silverfury or {}
Silverfury.logging = Silverfury.logging or {}

local formats = {}
Silverfury.logging.formats = formats

-- Current self snapshot (compact).
function formats.meSnapshot()
  local me = Silverfury.state.me
  return {
    hp  = me.hp,  maxhp = me.maxhp,
    mp  = me.mp,  maxmp = me.maxmp,
    bal = me.bal, eq    = me.eq,
    form = me.form,
  }
end

-- Current target snapshot (compact).
function formats.targetSnapshot()
  local tgt = Silverfury.state.target
  -- Aff confidence summary.
  local affs = {}
  for name, data in pairs(tgt.affs or {}) do
    affs[name] = math.floor((data.confidence or 0) * 100) .. "%"
  end
  -- Limb damage summary.
  local limbs = {}
  for name, lb in pairs(tgt.limbs or {}) do
    if lb.damage_pct > 0 or lb.broken then
      limbs[name] = {
        pct     = lb.damage_pct,
        broken  = lb.broken,
        mangled = lb.mangled,
      }
    end
  end
  return {
    name    = tgt.name,
    in_room = tgt.in_room,
    dead    = tgt.dead,
    prone   = tgt.prone,
    affs    = affs,
    limbs   = limbs,
    shield  = tgt.hasDef("shield"),
    rebounding = tgt.hasDef("rebounding"),
  }
end

-- Encode a value to a JSON-ish string (simple, no external dep).
-- Uses yajl if available, falls back to a compact manual encoder.
function formats.encode(value)
  if yajl then
    local ok, result = pcall(yajl.to_string, value)
    if ok then return result end
  end
  return formats._compact(value)
end

function formats._compact(v, depth)
  depth = depth or 0
  if depth > 8 then return '"..."' end
  local t = type(v)
  if t == "nil"     then return "null" end
  if t == "boolean" then return tostring(v) end
  if t == "number"  then return tostring(v) end
  if t == "string"  then
    return '"' .. v:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
  end
  if t == "table" then
    -- Array check: consecutive integer keys from 1.
    local is_array = true
    local maxn = 0
    for k in pairs(v) do
      if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
        is_array = false; break
      end
      if k > maxn then maxn = k end
    end
    if is_array and maxn == #v then
      local items = {}
      for i = 1, #v do items[i] = formats._compact(v[i], depth+1) end
      return "[" .. table.concat(items, ",") .. "]"
    else
      local items = {}
      for k, val in pairs(v) do
        items[#items+1] = formats._compact(tostring(k), depth+1) .. ":" .. formats._compact(val, depth+1)
      end
      return "{" .. table.concat(items, ",") .. "}"
    end
  end
  return '"[' .. t .. ']"'
end
