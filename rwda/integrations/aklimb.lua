rwda = rwda or {}
rwda.integrations = rwda.integrations or {}
rwda.integrations.aklimb = rwda.integrations.aklimb or {}

local adapter = rwda.integrations.aklimb

function adapter.detect()
  local present = type(rawget(_G, "ak")) == "table" or type(rawget(_G, "aklimb")) == "table"
  rwda.state.integration.aklimb_present = present
  return present
end

function adapter.pull(targetName)
  if not adapter.detect() then
    return nil
  end

  targetName = targetName or rwda.state.target.name
  if not targetName then
    return nil
  end

  local aklimbGlobal = rawget(_G, "aklimb")
  local akGlobal = rawget(_G, "ak")

  if type(aklimbGlobal) == "table" and type(aklimbGlobal.targets) == "table" then
    return aklimbGlobal.targets[targetName]
  end

  if type(akGlobal) == "table" and type(akGlobal.targets) == "table" then
    return akGlobal.targets[targetName]
  end

  return nil
end

function adapter.mergeSnapshot(snapshot)
  if type(snapshot) ~= "table" then
    return false
  end

  local map = {
    leftleg = "left_leg",
    rightleg = "right_leg",
    leftarm = "left_arm",
    rightarm = "right_arm",
    torso = "torso",
    head = "head",
  }

  for key, limb in pairs(map) do
    local row = snapshot[key]
    if type(row) == "table" then
      rwda.state.updateTargetLimb(limb, {
        damage_pct = row.damage_pct or row.damage or rwda.state.target.limbs[limb].damage_pct,
        broken = not not (row.broken or row.crippled),
        mangled = not not (row.mangled or row.damaged),
        confidence = 0.85,
      })
    end
  end

  return true
end

function adapter.sync()
  local snap = adapter.pull(rwda.state.target.name)
  if not snap then
    return false
  end

  return adapter.mergeSnapshot(snap)
end
