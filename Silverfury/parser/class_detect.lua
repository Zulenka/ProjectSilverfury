-- Silverfury/parser/class_detect.lua
-- Detects opponent class from combat message patterns.
-- Derived from the "Class Tracking Legacy" Mudlet package.
--
-- Sets Silverfury.state.target.class and raises SF_TargetClassDetected when a
-- new class is identified.  Used by the matchup engine to select fight strategy.
--
-- DwC/DwB (dual-cutting/dual-blunt) detection requires two hits in the same
-- balance window; counters reset on each prompt.

Silverfury = Silverfury or {}
Silverfury.parser = Silverfury.parser or {}

Silverfury.parser.class_detect = Silverfury.parser.class_detect or {}
local cd = Silverfury.parser.class_detect

-- ── Dual-weapon counters ──────────────────────────────────────────────────────
local _dwc = 0   -- dual-cutting hit count (reset per prompt)
local _dwb = 0   -- dual-blunt   hit count (reset per prompt)

-- ── Class patterns ────────────────────────────────────────────────────────────
-- { lua_pattern, "ClassName", name_capture_group_index }
-- name_capture_group_index: which %w+ capture holds the attacker name (1-based).

local CLASS_PATTERNS = {

  -- ── Alchemist ──────────────────────────────────────────────────────────────
  { "^A diminutive homunculus resembling (%w+) stares menacingly at you", "Alchemist", 1 },
  { "^(%w+) glowers at you with a look of repressed disgust before making a slight gesture toward you%.", "Alchemist", 1 },
  { "^A short convulsion sweeps through your body as (%w+) wracks your %w+ humour%.", "Alchemist", 1 },
  { "^A low growl echoes from a diminutive homunculus resembling (%w+)'s throat", "Alchemist", 1 },
  { "^(%w+) waves a hand in your direction and you feel energy wreathing about you%. A strong burning sensation", "Alchemist", 1 },

  -- ── Apostate ───────────────────────────────────────────────────────────────
  { "^(%w+) stares at you, giving you the evil eye%.", "Apostate", 1 },
  { "^Your .+ defence has been stripped by (%w+)'s Baalzadeen%.", "Apostate", 1 },
  { "^(%w+)'s Baalzadeen casts a piercing glance at you%.", "Apostate", 1 },
  { "^With a snarl, (%w+)'s Baalzadeen opens its mouth and spews a foul black liquid all over you%.", "Apostate", 1 },
  { "^Before you can avoid it, (%w+)'s hand brushes against your arm and it withers away%.", "Apostate", 1 },
  { "^You watch in horror as (%w+) touches your %w+ arm, and it shrivels away to uselessness%.", "Apostate", 1 },
  { "^(%w+) reaches out and grabs your leg, which almost gives way underneath you as it shrivels feebly away%.", "Apostate", 1 },
  { "^You stumble slightly as (%w+) touches your %w+ leg, and it shrivels away%.", "Apostate", 1 },

  -- ── Bard ───────────────────────────────────────────────────────────────────
  { "^(%w+)'s paean slams into you with all the weight of history's greatest triumphs", "Bard", 1 },
  { "^With a flourish of .+ (%w+) steps in close, %w+ blade slicing at your", "Bard", 1 },
  { "^(%w+)'s refrain leaves you gasping for breath%.", "Bard", 1 },

  -- ── Blademaster ────────────────────────────────────────────────────────────
  { "^As (%w+) draws %w+ %w+ from its scabbard, %w+ drives the pommel into your chin%.", "Blademaster", 1 },
  { "^(%w+) unleashes a vicious slash towards you before resheathing %w+ blade", "Blademaster", 1 },
  { "^In a single motion, (%w+) draws %w+ %w+ from its scabbard and looses a vicious %w+ slash at your %w+%.", "Blademaster", 1 },
  { "^Spinning to the %w+ as (%w+) draws %w+ %w+ from %w+ sheath, %w+ delivers a precise slash across your arms%.", "Blademaster", 1 },
  { "^With a smooth lunge to the %w+, (%w+) draws %w+ %w+ from its scabbard and delivers a powerful slash across your legs%.", "Blademaster", 1 },

  -- ── Depthswalker ───────────────────────────────────────────────────────────
  { "^(%w+) delivers a lightning%-fast strike to you with (.+)%.", "Depthswalker", 1 },
  { "^(%w+) lays into you with a savage blow from (.+)%.", "Depthswalker", 1 },
  { "^(%w+) raises (.+) and points it at you with a sinister smile%.", "Depthswalker", 1 },

  -- ── Dragon ─────────────────────────────────────────────────────────────────
  { "^A heavy burden descends upon your soul as (%w+) lays the ancient Dragoncurse upon you%.", "Dragon", 1 },
  { "^(%w+) lunges forward with long, flashing claws extended, tearing down to the bones of your", "Dragon", 1 },
  { "^(%w+) snaps %w+ massive jaws close around you, flinging you effortlessly into the air before catching you", "Dragon", 1 },
  { "^You are knocked forcefully off your feet by the impact of (%w+)'s huge tail%.", "Dragon", 1 },
  { "^(%w+) turns to fix %w+ gaze upon you, and you feel your heart increase its palpitations as a low keening", "Dragon", 1 },

  -- ── Druid ──────────────────────────────────────────────────────────────────
  { "^The fire on the hands of (%w+) jumps to you, setting you ablaze%.", "Druid", 1 },
  { "^With a synchronous, guttural rasp, (%w+)'s many serpentine heads breathe forth wisps", "Druid", 1 },
  { "^(%w+) sinks %w+ vicious fangs deep into your body, ravaging your flesh%.", "Druid", 1 },
  { "^Quicker than you can follow, one of (%w+)'s serpentine heads darts forward to snap at your flesh%.", "Druid", 1 },
  { "^With %w+ deadly tail, (%w+) strikes out at you and stings you%.", "Druid", 1 },

  -- ── Infernal ───────────────────────────────────────────────────────────────
  { "^You feel sickened and weak by the aura of death emanating from (%w+)%.", "Infernal", 1 },
  { "^Your very blood rebels against the profane touch of (.+)%.", "Infernal", 1 },
  { "^Pain becomes a familiar foe as (%w+) reaches out and grasps you by your left arm and right arm", "Infernal", 1 },

  -- ── Jester ─────────────────────────────────────────────────────────────────
  { "^With an appraising glance at you, (%w+) shapes the arms and legs of a rough puppet%.", "Jester", 1 },
  { "^(%w+) glances at you while adding some facial detail to a puppet%.", "Jester", 1 },
  { "^(%w+) looks closely at your hands and alters a puppet%.", "Jester", 1 },
  { "^With one hand ominously pointed towards you, (%w+) rubs a finger over the heart of a puppet%.", "Jester", 1 },

  -- ── Magi ───────────────────────────────────────────────────────────────────
  { "^(%w+) weaves earth and water and a torrent of thick sticky mud thunders forth to roll over you", "Magi", 1 },
  { "^(%w+) clicks %w+ fingers and a bolt of lightning strikes from the air in a fulminous flash", "Magi", 1 },
  { "^(%w+) makes no motion or word, but a roiling nausea rolls through you, a terrible dizziness", "Magi", 1 },
  { "^(%w+) makes the slightest flick with an elemental staff, and a deluge of freezing water", "Magi", 1 },

  -- ── Monk Shikudo ───────────────────────────────────────────────────────────
  { "^(%w+) whips (.+) in a long sweep at your legs%.", "Shikudo", 1 },
  { "^(%w+) lashes out with a high kick at your %w+%.", "Shikudo", 1 },
  { "^(%w+) lashes out with a straight kick at you%.", "Shikudo", 1 },
  { "^Spinning on one foot (%w+) drives a knotted willow staff into your (.+) with a lightning%-fast thrust%.", "Shikudo", 1 },
  { "^Continuing %w+ kata, (%w+) spins a knotted willow staff in %w+ hands before driving it", "Shikudo", 1 },
  { "^(%w+) flows around you like water, a knotted willow staff lashing out in a swift thrust at your vulnerable kidneys%.", "Shikudo", 1 },

  -- ── Monk Tekura ────────────────────────────────────────────────────────────
  { "^(%w+) pumps out at you with a powerful side kick%.", "Tekura", 1 },
  { "^(%w+) unleashes a powerful hook towards you%.", "Tekura", 1 },
  { "^(%w+) launches a powerful uppercut at you%.", "Tekura", 1 },
  { "^(%w+) forms a spear hand and stabs out at you%.", "Tekura", 1 },
  { "^(%w+) balls up one fist and hammerfists you%.", "Tekura", 1 },

  -- ── Occultist ──────────────────────────────────────────────────────────────
  { "^(%w+) draws back with a knowing smirk and utters some alien word that vibrates deep within your bones%.", "Occultist", 1 },
  { "^(%w+) passes %w+ hand in front of you%. You feel an invisible claw brush the back of your skull%.", "Occultist", 1 },
  { "^(%w+) utters a terrible curse and points a finger at you%.", "Occultist", 1 },
  { "^(%w+) gestures sharply in your direction, and a mass of green slime flows up and over you", "Occultist", 1 },
  { "^Seven rays of different coloured light spring out from (%w+)'s outstretched hands", "Occultist", 1 },
  { "^(%w+) makes a sudden, quick gesture in front of you, almost hitting your nose%.", "Occultist", 1 },

  -- ── Paladin ────────────────────────────────────────────────────────────────
  { "^As fire surges about the righteous (%w+), a terrible heat fills your chest", "Paladin", 1 },
  { "^(%w+) is outlined in a nimbus of fire for an instant as %w+ glares at you", "Paladin", 1 },
  { "^A nimbus of flame blazes about (%w+) as %w+ turns %w+ righteousness upon you", "Paladin", 1 },
  { "^(%w+) whispers a prayer to the Righteous Fire", "Paladin", 1 },
  { "^At the command of (%w+) a beam of radiance strikes down from on high", "Paladin", 1 },

  -- ── Pariah ─────────────────────────────────────────────────────────────────
  { "^(%w+) raises %w+ left hand in front of you, clenching it into a fist, your body spasming under some arcane assault%.", "Pariah", 1 },
  { "^(%w+)'s hand lashes out, %w+ glittering ritual blade flashing as drops of crimson blood land upon its ensorceled blade%.", "Pariah", 1 },
  { "^(%w+) traces a logograph (.+) in the air before you, the blood upon his knife bursting into arcane flame", "Pariah", 1 },

  -- ── Priest ─────────────────────────────────────────────────────────────────
  { "^(%w+) utters a prayer and smites your (.+) with (.+)%.", "Priest", 1 },
  { '"Repent for your crimes!" (%w+) denounces you', "Priest", 1 },
  { "^Your .+ defence has been stripped by (%w+)'s guardian angel%.", "Priest", 1 },
  { "^(%w+)'s guardian angel's eyes glow like embers as searing heat pours over you", "Priest", 1 },

  -- ── Psion ──────────────────────────────────────────────────────────────────
  { "^A sharp pain across your throat and a sudden lack of breath comes moments before you register the retreat of (%w+)", "Psion", 1 },
  { "^Your %w+ arm flops uselessly as (%w+) severs the muscles in it with a precise blow of %w+ translucent sword%.", "Psion", 1 },
  { "^(%w+) delivers a series of lashes against you with a translucent lash", "Psion", 1 },
  { "^With a brutal thrust of a translucent sword, (%w+) sinks %w+ weapon into your guts", "Psion", 1 },
  { "^Stars explode in front of your eyes as (%w+) smashes a translucent mace into the side of your head%.", "Psion", 1 },

  -- ── Runewarden ─────────────────────────────────────────────────────────────
  { "^Cold blue flames wreathe (%w+)'s runeblade, emanating an icy chill that penetrates you to the bone%.", "Runewarden", 1 },

  -- ── Sentinel ───────────────────────────────────────────────────────────────
  { "^(%w+) viciously gouges your (.+) with (.+)%.", "Sentinel", 1 },
  { "^(%w+) whips (.+) in a swift motion toward you, scything through your (.+) defence%.", "Sentinel", 1 },
  { "^(%w+) swiftly sweeps your feet out from beneath you with (.+) before driving the point of the weapon into your", "Sentinel", 1 },
  { "^(%w+) deftly hooks (.+) behind your foot and sends you tumbling off (.+) before driving the point", "Sentinel", 1 },
  { "^(%w+) draws (.+) in an expert lateral slice across your (.+)%.", "Sentinel", 1 },
  { "^(%w+) viciously lacerates your (.+) with (.+)%.", "Sentinel", 1 },

  -- ── Serpent ────────────────────────────────────────────────────────────────
  { "^(%w+) flays away your aura of rebounding defence%.", "Serpent", 1 },
  { "^(%w+) sinks %w+ fangs into your body and you wince in pain%.", "Serpent", 1 },
  { "^(%w+) quickly pricks you with %w+ dirk%.", "Serpent", 1 },
  { "^(%w+) leaps from the shadows and plunges a dagger into your unsuspecting back!", "Serpent", 1 },

  -- ── Shaman ─────────────────────────────────────────────────────────────────
  { "^(%w+) points an imperious finger at you%.", "Shaman", 1 },
  { "^With an appraising glance at you, (%w+) shapes the arms and legs of a rough doll%.", "Shaman", 1 },
  { "^(%w+) glances at you while adding some facial detail to a doll%.", "Shaman", 1 },
  { "^(%w+) looks at your eyes and makes some alterations to %w+ doll%.", "Shaman", 1 },
  { "^With one hand ominously pointed towards you, (%w+) rubs a finger over the heart of a Vodun doll%.", "Shaman", 1 },

  -- ── Sylvan ─────────────────────────────────────────────────────────────────
  { "^(%w+) gestures sharply in your direction with one hand, and invisible whips viciously lash at you%.", "Sylvan", 1 },
  { "^(%w+) summons a blade of condensed air and shears cleanly through the magical shield surrounding you%.", "Sylvan", 1 },
  { "^Your body locks in paralysis as a burst of arcane power floods your system, directed by (%w+)%.", "Sylvan", 1 },
  { "^Your ears are abruptly filled with the shockingly loud clap of nearby thunder, summoned forth by (%w+)%.", "Sylvan", 1 },
  { "^Sweat breaking out on the forehead of (%w+) is your only warning before a bolt of lightning leaps down from on high", "Sylvan", 1 },

  -- ── Unnamable ──────────────────────────────────────────────────────────────
  { "^A wall of sound slams into you, a terrible symphony of something undescribably wrong as each of the mouths that have torn open upon the body of (%w+) howl in silent wrath%.", "Unnamable", 1 },
  { "^The myriad mouths that have torn open upon the body of (%w+) croon in profane symphony", "Unnamable", 1 },
  { "^(%w+) whispers words so anathema to you that you feel your mind fracturing at the very knowing", "Unnamable", 1 },

  -- ── Two-Handed (generic) ───────────────────────────────────────────────────
  { "^(%w+) brings (.+) down upon you with a brutal overhand blow%.", "2H", 1 },
  { "^(%w+) explodes upward from a low crouch, driving (.+) toward your (.+)%.", "2H", 1 },
  { "^(%w+) drops into a low crouch, sweeping (.+) beneath your guard and tangling it with your legs%.", "2H", 1 },

  -- ── Sword-and-Board ────────────────────────────────────────────────────────
  { "^(%w+) quickly lunges to the side, bringing %w+ shield around to smash into your spine%.", "SnB", 1 },
  { "^(%w+) drives the edge of %w+ shield into your throat, cutting off your air supply%.", "SnB", 1 },

  -- ── Elemental Lords ────────────────────────────────────────────────────────
  { "^(%w+) casts a hand out in your direction, an icy zephyr descending upon you to tear your fortitude away%.", "Airlord", 1 },
  { "^(%w+) studies you intently, the howling winds that surround %w+ stilling for a moment%.", "Airlord", 1 },

  { "^(%w+) rains a flurry of blows down upon you with %w+ great stone fists%.", "Earthlord", 1 },
  { "^(%w+) slams a foot to the ground, great tremors radiating out from the impact%.", "Earthlord", 1 },
  { "^With a terrible roar (%w+) whips a colossal fist at your (.+)%.", "Earthlord", 1 },
  { "^Cloaked in a shifting mantle of molten stone, (%w+) charges in from the %w+ with a deafening roar%.", "Earthlord", 1 },

  { "^A whip of flame coalesces in the hand of (%w+), with which %w+ viciously lashes you%.", "Firelord", 1 },
  { "^The flames that are the eyes of (%w+) flare as %w+ rakes them across you", "Firelord", 1 },

  { "^The amorphous form of (%w+) trembles, some of the liquid composing it falling away from the greater whole%.", "Waterlord", 1 },
  { "^A sudden deluge of shockingly cold water drenches you, robbing you of strength by the will of (%w+)%.", "Waterlord", 1 },
  { "^You double over and hack up water beneath the pitiless gaze of (%w+)%.", "Waterlord", 1 },
  { "^You feel suddenly light%-headed as ripples race across the amorphous form of (%w+)%.", "Waterlord", 1 },
  { "^A wave of nausea rolls over you as (%w+) casually waves a hand in your direction%.", "Waterlord", 1 },
}

-- ── Dual-cutting patterns (class fires only on 2nd hit per balance) ──────────
local DWC_PATTERNS = {
  "^(%w+) slashes into your .+ with (.+)%.$",
  "^(%w+) swings (.+) at your .+ with all %w+ might%.$",
}

-- ── Dual-blunt patterns ───────────────────────────────────────────────────────
local DWB_PATTERNS = {
  "^(%w+) whips (.+) toward your (.+)%.$",
}

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function isTarget(name)
  if not name then return false end
  local tname = Silverfury.state.target.name
  if not tname then return false end
  return tname:lower() == name:lower()
end

local function setClass(name, cls)
  if not isTarget(name) then return end
  local tgt = Silverfury.state.target
  if tgt.class ~= cls then
    tgt.class = cls
    raiseEvent("SF_TargetClassDetected", name, cls)
    Silverfury.log.info("Class detect: %s → %s", name, cls)
    -- If matchups data exists for this class, fire matchup-select event.
    if Silverfury.dragon and Silverfury.dragon.matchups then
      local m = Silverfury.dragon.matchups[cls]
      if m then raiseEvent("SF_MatchupSelected", cls, m) end
    end
  end
end

-- ── Process a single line ─────────────────────────────────────────────────────

function cd.process(clean)
  if not Silverfury.state.target.name then return end

  -- DwC: dual-cutting weapon detection (needs 2 hits same balance window).
  for _, pat in ipairs(DWC_PATTERNS) do
    local name = clean:match(pat)
    if name and isTarget(name) then
      _dwc = _dwc + 1
      if _dwc >= 2 then
        setClass(name, "DwC")
        _dwc = 0
      end
      return
    end
  end

  -- DwB: dual-blunt weapon detection.
  for _, pat in ipairs(DWB_PATTERNS) do
    local name = clean:match(pat)
    if name and isTarget(name) then
      _dwb = _dwb + 1
      if _dwb >= 2 then
        setClass(name, "DwB")
        _dwb = 0
      end
      return
    end
  end

  -- Main class pattern list.
  for _, entry in ipairs(CLASS_PATTERNS) do
    local pat     = entry[1]
    local cls     = entry[2]
    local cap_idx = entry[3]
    local m = { clean:match(pat) }
    if m[1] ~= nil then
      local name = m[cap_idx]
      setClass(name, cls)
      return   -- stop on first match per line
    end
  end
end

-- ── Event registration ────────────────────────────────────────────────────────

cd._handlers = cd._handlers or {}
local _handlers = cd._handlers

function cd.registerHandlers()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end

  -- Reset dual-weapon counters each balance prompt.
  _handlers[#_handlers+1] = registerAnonymousEventHandler("sysPrompt", function()
    _dwc = 0
    _dwb = 0
  end)

  -- Process every incoming line.
  _handlers[#_handlers+1] = registerAnonymousEventHandler("sysDataReceived", function(_, line)
    if not line or line == "" then return end
    local clean = decolor and decolor(line) or line
    cd.process(clean)
  end)
end

function cd.shutdown()
  for _, id in ipairs(_handlers) do killAnonymousEventHandler(id) end
  for i = #_handlers, 1, -1 do _handlers[i] = nil end
end
