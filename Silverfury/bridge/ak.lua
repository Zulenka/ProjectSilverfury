-- Silverfury/bridge/ak.lua
-- Bridges AK 8.3 limb tracking into Silverfury's target state.
--
-- AK tracks accumulated hit damage in ak.limbs.limbcount[name][limb]
-- (resets to 0 when a limb breaks) and break state in affstrack.score[limb]
-- (>= 100 = broken, >= 200 = double-broken). We listen to "AK scoreup"
-- which fires after every attack round, and synthesise a continuous
-- damage_pct for SF's phase gating logic.

Silverfury = Silverfury or {}
Silverfury.bridge = Silverfury.bridge or {}

Silverfury.bridge.ak = Silverfury.bridge.ak or {}
local bridge = Silverfury.bridge.ak

-- Maps AK 8.3 limb key → SF limb key.
local AK_TO_SF = {
  leftleg  = "left_leg",
  rightleg = "right_leg",
  leftarm  = "left_arm",
  rightarm = "right_arm",
  head     = "head",
  torso    = "torso",
}

local _handler   = nil
local _prev_track = nil   -- previous ak.AustCuredTrack, restored on shutdown

local function syncLimbs()
  local tgt = Silverfury.state.target
  if not tgt or not tgt.name then return end

  local lcount = ak and ak.limbs and ak.limbs.limbcount
                     and ak.limbs.limbcount[tgt.name]
  local score  = affstrack and affstrack.score
  if not lcount or not score then
    Silverfury.log.trace("AK bridge: limbcount or affstrack.score unavailable")
    return
  end

  for ak_key, sf_key in pairs(AK_TO_SF) do
    local raw_pct  = lcount[ak_key] or 0
    local sc       = score[ak_key]  or 0
    local broken   = sc >= 100
    local mangled  = sc >= 200
    -- After a break AK resets limbcount to 0 and starts a fresh accumulator.
    -- Synthesise a continuous value: 100+ when broken so SF's >= 100 break
    -- check still fires correctly.
    local damage_pct = broken and (100 + raw_pct) or raw_pct
    tgt.updateLimb(sf_key, damage_pct, broken, mangled)
  end
end

function bridge.registerHandlers()
  if _handler then return end

  _handler = registerAnonymousEventHandler("AK scoreup", function(_, whom)
    local tgt = Silverfury.state.target
    if tgt and whom == tgt.name then
      syncLimbs()
    end
  end)

  -- Chain into AK's cured callback so limb heals (score → 0) update SF state.
  _prev_track = ak and ak.AustCuredTrack
  if ak then
    ak.AustCuredTrack = function(affliction)
      if _prev_track then _prev_track(affliction) end
      if AK_TO_SF[affliction] then
        syncLimbs()
      end
    end
  end

  Silverfury.log.info("AK bridge: registered (AK scoreup + AustCuredTrack)")
end

function bridge.shutdown()
  if _handler then
    killHandler(_handler)
    _handler = nil
  end
  if ak then
    ak.AustCuredTrack = _prev_track
  end
  _prev_track = nil
  Silverfury.log.info("AK bridge: shut down")
end
