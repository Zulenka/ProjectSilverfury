-- Auto-generated helper lookup functions for Silverfury/Mudlet
local data = require("silverfury_data.init")

local M = {}

local function normalize(value)
  if type(value) ~= "string" then return value end
  return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

function M.get_command(name)
  if not name then return nil end
  local key = normalize(name)
  return data.command_index[key] or data.command_index[name]
end

function M.get_ability(name)
  if not name then return nil end
  local key = normalize(name)
  return data.ability_index[key] or data.ability_index[name]
end

function M.has_affliction(name)
  if not name then return false end
  local key = normalize(name)
  return data.affliction_index[key] ~= nil or data.affliction_index[name] ~= nil
end

function M.has_defence(name)
  if not name then return false end
  local key = normalize(name)
  return data.defence_index[key] ~= nil or data.defence_index[name] ~= nil
end

function M.get_skill(name)
  if not name then return nil end
  local key = normalize(name)
  return data.skill_index[key] or data.skill_index[name]
end

return M
