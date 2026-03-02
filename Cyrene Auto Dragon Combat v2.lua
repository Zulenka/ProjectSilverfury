--Version 2 Patch Notes
--Credits to Salisa and Crixos for helping me refine.

-- Impatience placed at top of dragoncurse priority.
-- Added breathgust into all our combos.
-- We now GUT instead of REND for a double DPS increase at a slight balance malus.
-- Breathgust also added to our bite conditional.

-- To use V2, simply copy everything here and paste it over V1. 
-- The script is entirely plug-and-play! Should be hassle-free.
-- Go out and kill the Lowlanders!

-- <3 Claes Ancyrion-Firedancer <3


-- This is our local variables. Don't touch these! --
 
if gmcp.Char.Status.class:match("Dragon") then
  local aff = table.deepcopy(affstrack.score)
  attk = nil
 
-- These are our Dragon Curses, as seen under AB DRAGONCURSE --
 
  if aff.impatience < 100 then
    curse = "impatience"
  elseif aff.asthma < 34 then
    curse = "asthma"
  elseif aff.paralysis < 100 then
    curse = "paralysis"
  elseif aff.stupidity < 50 then
    curse = "stupidity"
  end
  
-- These are our Dragon Rend Venoms, you can use any as long as you have the venom vial --
  
  if aff.paralysis < 100 and curse ~= "paralysis" then
    v1 = "curare"
  elseif aff.asthma < 100 and curse ~= "asthma" then
    v1 = "kalmia"
  elseif aff.slickness < 100 then
    v1 = "gecko"    
  elseif aff.anorexia < 100 then
    v1 = "slike"
  elseif aff.stupidity < 100 then
    v1 = "aconite"
  end
 
-- This is the logic for our attacks --
 
  if aff.prone < 100 then
    attk = "gut"
  elseif aff.prone >= 100 then
    attk = "bite"
 end
  
  
-- This is the Priority System of how we attack --
 
  -- Always check first to see if they are shielding --
  if ak.defs.shield then 
    Legacy.Q.free("stand/tailsmash "..target.."/dragoncurse "..target.." "..curse.." 1")
  
  -- Then we check to see if they are using lyre --
  elseif targetlyred == 1 then
    Legacy.Q.free("stand/blast "..target)
  
  -- Then we check to see if they are flying --
  elseif tarFlying == true then
    Legacy.Q.free("stand/becalm")
  
  -- If they are not shielding, lyred, or flying, we attack them --
  elseif attk == "gut" then
    Legacy.Q.free("stand/dragoncurse "..target.." "..curse.." 1/gut "..target.." "..v1.."/breathgust "..target)
  
  -- If they are prone then we dragon bite them for 35%+ damage --
  elseif attk == "bite" then
    Legacy.Q.free("stand/bite "..target.."/breathgust "..target) 
  end
end