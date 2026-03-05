-- Silverfury/offense/attacks.lua
-- Attack template helpers and wield state management.

Silverfury = Silverfury or {}
Silverfury.offense = Silverfury.offense or {}

local attacks = {}
Silverfury.offense.attacks = attacks

-- Returns the template string for a given template key.
function attacks.getTemplate(key)
  local templates = Silverfury.config.get("attack.templates") or {}
  return templates[key]
end

-- Fill template with provided vars table.
-- vars: { target, v1, v2, limb, rune }
function attacks.fill(template, vars)
  return Silverfury.engine.planner._fill(template, vars)
end

-- Build a full attack command for a given template key.
function attacks.build(key, vars)
  local tpl = attacks.getTemplate(key)
  if not tpl then
    Silverfury.log.warn("attacks.build: unknown template '%s'", tostring(key))
    return nil
  end
  return attacks.fill(tpl, vars or {})
end

-- Ensure weapons are wielded (human form). Sends rewield if not.
-- Returns true if already wielded (no send needed).
function attacks.checkWield()
  local me = Silverfury.state.me
  if me.form ~= "human" then return true end
  if me.swords_wielded then return true end
  local cmd = Silverfury.config.get("attack.rewield_cmd") or "wield scimitar scimitar"
  Silverfury.engine.queue.send(cmd)
  me.swords_wielded = true
  return false
end
