rwda = rwda or {}
rwda.statebuilders = rwda.statebuilders or {}

local builders = rwda.statebuilders

function builders.newCooldowns()
  return {
    channels = {
      herb = 0,
      salve = 0,
      smoke = 0,
      sip = 0,
      focus = 0,
      writhe = 0,
      special = 0,
    },
    command = 0,
  }
end
