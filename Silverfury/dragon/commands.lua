-- Silverfury/dragon/commands.lua
-- Canonical command string builders for all Dragoncraft PvP abilities.
-- Use these everywhere — never hardcode command strings in planner/scenario code.

Silverfury        = Silverfury or {}
Silverfury.dragon = Silverfury.dragon or {}

local commands = {}
Silverfury.dragon.commands = commands

local function tname()
  return Silverfury.state.target.name or ""
end

-- ── Breath weapons ────────────────────────────────────────────────────────────
function commands.summon(breath_type)
  return "summon " .. (breath_type or "lightning")
end

function commands.blast(target)
  return "blast " .. (target or tname())
end

function commands.breathgust(target)
  return "breathgust " .. (target or tname())
end

function commands.breathstorm()
  return "breathstorm"
end

function commands.breathstrip(target)
  return "breathstrip " .. (target or tname())
end

function commands.breathstream(target, direction)
  return "breathstream " .. (target or tname()) .. " " .. (direction or "")
end

-- ── Room control ──────────────────────────────────────────────────────────────
function commands.block(dir)
  return "block " .. (dir or "")
end

function commands.unblock()
  return "unblock"
end

function commands.tailsweep()
  return "tailsweep"
end

function commands.becalm(target)
  return "becalm " .. (target or tname())
end

function commands.enmesh(target)
  return "enmesh " .. (target or tname())
end

-- ── Physical attacks ──────────────────────────────────────────────────────────
-- rend: targeted limb is optional; without it AK records faster balance.
function commands.rend(target, limb)
  if limb then
    return "rend " .. (target or tname()) .. " " .. limb
  end
  return "rend " .. (target or tname())
end

-- swipe: hits one limb then follows up on head or torso.
function commands.swipe(target, limb, follow)
  return string.format("swipe %s %s %s",
    target or tname(),
    limb   or "left leg",
    follow or "torso")
end

function commands.gut(target, venom)
  local cmd = "gut " .. (target or tname())
  if venom and venom ~= "" then cmd = cmd .. " " .. venom end
  return cmd
end

function commands.bite(target)
  return "bite " .. (target or tname())
end

function commands.tailsmash(target)
  return "tailsmash " .. (target or tname())
end

-- ── Kill ──────────────────────────────────────────────────────────────────────
function commands.devour(target)
  return "devour " .. (target or tname())
end

-- ── Defensive / utility ───────────────────────────────────────────────────────
function commands.dragonarmour(state)
  return "dragonarmour " .. (state or "on")
end

function commands.dragonflex()
  return "dragonflex"
end

function commands.dragonheal()
  return "dragonheal"
end

function commands.clawparry(part)
  return "clawparry " .. (part or "head")
end

-- ── Tracking / location ───────────────────────────────────────────────────────
function commands.track(target)
  return "track " .. (target or tname())
end

function commands.view()
  return "view"
end

function commands.dragonsense(target)
  return "dragonsense " .. (target or tname())
end

-- ── Affliction delivery ───────────────────────────────────────────────────────
-- dragoncurse: random masked affs without args; targeted with aff + delay.
function commands.dragoncurse(target, aff, delay_s)
  if aff and delay_s then
    return string.format("dragoncurse %s %s %d",
      target or tname(), aff, delay_s)
  end
  return "dragoncurse " .. (target or tname())
end
