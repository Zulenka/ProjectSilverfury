-- Silverfury/util/table.lua
-- Table utility helpers.

Silverfury = Silverfury or {}
Silverfury.tbl = Silverfury.tbl or {}

-- Deep copy any value.
function Silverfury.tbl.deepcopy(src)
  if type(src) ~= "table" then return src end
  local seen = {}
  local function cp(v)
    if type(v) ~= "table" then return v end
    if seen[v] then return seen[v] end
    local t = {}
    seen[v] = t
    for k, val in pairs(v) do t[cp(k)] = cp(val) end
    return setmetatable(t, getmetatable(v))
  end
  return cp(src)
end

-- Deep merge src into dst (dst wins on type conflict).
function Silverfury.tbl.merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      Silverfury.tbl.merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

-- True if value exists in list.
function Silverfury.tbl.contains(list, value)
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

-- Return keys of a table as a sorted list.
function Silverfury.tbl.keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks+1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

-- Return count of entries in a table (pairs, not ipairs).
function Silverfury.tbl.count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- Filter list: return new list where fn(v) is truthy.
function Silverfury.tbl.filter(list, fn)
  local out = {}
  for _, v in ipairs(list) do
    if fn(v) then out[#out+1] = v end
  end
  return out
end

-- Map list: return new list of fn(v) results.
function Silverfury.tbl.map(list, fn)
  local out = {}
  for i, v in ipairs(list) do out[i] = fn(v) end
  return out
end
