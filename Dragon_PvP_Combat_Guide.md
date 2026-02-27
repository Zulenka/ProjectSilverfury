# Dragon PvP Combat Automation Guide
## Technical Architecture of Draconic Combat in Achaea

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [GMCP Infrastructure](#gmcp-infrastructure)
3. [Combat Philosophy](#combat-philosophy)
4. [Dragoncraft Abilities](#dragoncraft-abilities)
5. [Breath Weapons](#breath-weapons)
6. [Defensive Items](#defensive-items)
7. [Class Matchups](#class-matchups)
8. [References](#references)

---

## Prerequisites

Before engaging in Dragon PvP combat automation, ensure:

- **Character Level**: Level 99 (required for Dragon transformation)
- **Skillset**: Complete mastery of the **Dragoncraft** skillset
- **Client**: Mudlet with Lua scripting capabilities
- **Protocol**: GMCP (Generic Mud Communication Protocol) enabled

---

## GMCP Infrastructure

### Char.Vitals Module
The automation system relies heavily on the `Char.Vitals` GMCP module for real-time state tracking:

```lua
-- GMCP event handler for Char.Vitals
function onGMCPVitals()
    local vitals = gmcp.Char.Vitals
    
    -- Track balance and equilibrium
    local hasBalance = vitals.bal == "1"
    local hasEquilibrium = vitals.eq == "1"
    
    -- Only act when we have both balance and equilibrium
    if hasBalance and hasEquilibrium then
        executeCombatLogic()
    end
end

-- Register the event
registerAnonymousEventHandler("gmcp.Char.Vitals", "onGMCPVitals")
```

### Key GMCP Fields
| Field | Description | Values |
|-------|-------------|--------|
| `bal` | Balance status | "1" = have, "0" = lost |
| `eq` | Equilibrium status | "1" = have, "0" = lost |
| `hp` | Current health | Integer |
| `maxhp` | Maximum health | Integer |
| `mp` | Current mana | Integer |
| `maxmp` | Maximum mana | Integer |

---

## Combat Philosophy

### The "Locate, Pin, Damage" Strategy

Dragon combat follows a simple but effective three-phase approach:

1. **LOCATE** - Find and identify your target
   - Use `VIEW <target>` to locate players
   - Use `TRACK <target>` to follow fleeing opponents
   - Monitor room entries/exits via triggers

2. **PIN** - Prevent target escape
   - **BLOCK** - Prevents movement out of the room
   - **TAILSWEEP** - Knocks target prone (can't flee while prone)
   
3. **DAMAGE** - Apply consistent pressure
   - Select appropriate breath weapon for the situation
   - Use **BREATHSTORM** for area damage and clearing minions
   - Maintain offensive pressure while curing afflictions

---

## Dragoncraft Abilities

### Core Combat Abilities

| Ability | Type | Effect | Strategic Use |
|---------|------|--------|---------------|
| **Block** | Utility | Prevents all movement from room | Pin fleeing targets |
| **Tailsweep** | Physical | Knocks target prone | Prevent actions, combo starter |
| **Breathstorm** | AoE | Damages all enemies in room | Clear minions, reveal hidden |
| **Restoration** | Healing | Heals limb damage | Counter limb-attack classes |
| **Mending** | Healing | Alternative limb healing | When Restoration on cooldown |

### Breath Attacks
All breath attacks consume balance and deal their damage type plus potential afflictions.

```lua
-- Example breath attack targeting
function breathAttack(target, breathType)
    if hasBalance and hasEquilibrium then
        send("BREATHE " .. breathType .. " " .. target)
    end
end
```

---

## Breath Weapons

| Breath Type | Dragon Color | Damage Type | Key Effect | Strategic Use |
|-------------|--------------|-------------|------------|---------------|
| **Acid** | Black | Acid | Unblockable | Bypasses shields and barriers |
| **Ice** | Blue | Cold | Freezing | Prevents movement and actions |
| **Psi** | Gold | Psychic | Equilibrium Loss | Disrupts offensive tempo |
| **Venom** | Green | Poison | Random Venom | Complicates enemy curing priority |
| **Dragonfire** | Red | Fire | Ablaze | Periodic fire damage over time |
| **Lightning** | Silver | Electric | Balance Loss | Counter casters and momentum builds |

### Breath Selection Logic

```lua
-- Recommended breath selection based on enemy class
local breathTable = {
    -- Mana-dependent classes
    ["Apostate"] = "psi",
    ["Shaman"] = "psi",
    ["Sylvan"] = "psi",
    
    -- Mobile classes
    ["Serpent"] = "ice",
    ["Sentinel"] = "ice",
    
    -- Shield users
    ["Blademaster"] = "acid",
    ["Depthswalker"] = "acid",
    
    -- General damage
    ["default"] = "dragonfire"
}

function selectBreath(enemyClass)
    return breathTable[enemyClass] or breathTable["default"]
end
```

---

## Defensive Items

Maintain these defenses at all times during combat:

| Item | Also Known As | Effect | Counter To |
|------|---------------|--------|-----------|
| **Sileris** | Quicksilver | Blocks venom delivery | Serpent fangs, venomed weapons |
| **Caloric Salve** | Caloric | Counters Shivering affliction | Sylvan storms, ice attacks |
| **Skullcap** | Rebounding | Reflects damage back | Physical attackers |
| **Restoration Salve** | Resto | Heals broken/damaged limbs | Blademaster, physical damage |
| **Mending Salve** | Mending | Alternative limb healing | Backup for Restoration |

### Defense Upkeep Script

```lua
-- Automatic defense checking
defenses = {
    sileris = false,
    caloric = false,
    rebounding = false
}

function checkDefenses()
    if not defenses.sileris then
        send("EAT SILERIS")
    end
    if not defenses.caloric then
        send("APPLY CALORIC")
    end
    if not defenses.rebounding then
        send("EAT SKULLCAP")
    end
end
```

---

## Class Matchups

### Apostate (Necromancy, Apostasy)

**Threat Level**: High  
**Skills**: Necromancy, Apostasy

**Key Threats**:
- **Vivisect** - Instakill ability requiring specific affliction stack
- **Daemon** summons that assist in combat
- Affliction-heavy offense

**Counter Strategy**:
1. Prioritize curing their affliction stack to prevent Vivisect setup
2. Use **Breathstorm** to damage/distract their Daemon
3. **Psi breath** recommended to drain mana and disrupt casting
4. Maintain pressure - Apostates are weaker when on defensive

---

### Bard (Bladedance, Composition, Sagas, Woe)

**Threat Level**: Medium-High  
**Skills**: Bladedance, Composition, Sagas, Woe

**Key Threats**:
- Music-based afflictions from Composition
- Bladedance provides melee pressure
- Sagas provide passive bonuses
- Woe enhances damage output

**Counter Strategy**:
1. High mobility - they will try to kite; use **Block** and **Ice breath**
2. Their music effects can stack; cure promptly
3. **Dragonfire** breath works well for sustained damage
4. Watch for Bladedance combos - Tailsweep to interrupt

---

### Blademaster (TwoArts, Striking, Shindo)

**Threat Level**: High  
**Skills**: TwoArts, Striking, Shindo

**Key Threats**:
- **Limb lock** instakill - damages specific limbs to enable killing blow
- Fast balance recovery
- Can parry many attacks

**Counter Strategy**:
1. **Acid breath** bypasses their parrying/shielding
2. Keep **Restoration/Mending** salves ready for limb damage
3. They will target your limbs methodically - track which limbs are damaged
4. Do NOT let them complete their limb lock sequence
5. Tailsweep disrupts their attack rhythm

---

### Depthswalker (Aeonics, Shadowmancy, Terminus)

**Threat Level**: Very High  
**Skills**: Aeonics, Shadowmancy, Terminus

**Key Threats**:
- **Time manipulation** via Aeonics - can slow you or speed themselves
- **Shadowmancy** allows stealth and shadow attacks
- **Terminus** provides powerful finishers
- Can manipulate your balance/equilibrium recovery

**Counter Strategy**:
1. Most dangerous class due to time manipulation
2. **Acid breath** to pierce their shadow defenses
3. **Breathstorm** to reveal if they hide in shadows
4. Prioritize curing anything that affects your action timing
5. Aggressive offense - don't let them set up their combos

---

### Sentinel (Skirmishing, Woodlore, Metamorphosis)

**Threat Level**: Medium  
**Skills**: Skirmishing, Woodlore, Metamorphosis

**Key Threats**:
- High mobility via Skirmishing (can jump in/out of rooms)
- Summons woodland creatures via Woodlore
- Animal form transformations via Metamorphosis

**Counter Strategy**:
1. They WILL try to kite you - maintain **Block** at all times
2. **Ice breath** to hamper their mobility
3. **Breathstorm** to clear summoned creatures
4. Use **VIEW** and **TRACK** to follow when they flee
5. **Tailsweep** when they re-enter to prevent immediate escape

---

### Serpent (Subterfuge, Venom, Hypnosis)

**Threat Level**: Very High  
**Skills**: Subterfuge, Venom, Hypnosis

**Key Threats**:
- **Hypnosis** - Implants "suggestions" triggered by "prompt words"
- Masters of venoms - fast affliction stacking
- **Subterfuge** allows vanishing/stealth
- This is the "trickiest class to fight"

**Counter Strategy**:
1. **CRITICAL**: Monitor ALL text for common prompt words
2. Have your Dragon immediately SAY any potential trigger words to clear hypnosis
3. **Sileris (Quicksilver)** berries are MANDATORY - blocks venom delivery
4. **Breathstorm** constantly to reveal them if they vanish
5. **Ice breath** to prevent their escape

**Common Hypnosis Triggers** (say these immediately if heard):
- "yes", "no", "ok", "hi", "hello"
- Numbers, colors, simple words
- Your character's name

```lua
-- Example hypnosis clearing
local triggerWords = {"yes", "no", "ok", "hello", "hi"}
for _, word in ipairs(triggerWords) do
    send("SAY " .. word)
end
```

---

### Shaman (Spiritlore, Curses, Vodun)

**Threat Level**: High  
**Skills**: Spiritlore, Curses, Vodun

**Key Threats**:
- **Vodun dolls** - Can target you from distance via doll link
- **Curses** provide powerful debuffs
- With Dragon's "link" can deliver damage/afflictions remotely
- **Spiritlore** binds spirits for various effects

**Counter Strategy**:
1. **PRIORITY**: Find and attack the Shaman directly to disrupt concentration
2. They can fight from distance - you cannot; close the gap fast
3. **Psi breath** to drain mental energy (disrupts spirit bindings)
4. Breaking their link to the doll stops remote damage
5. High damage output to force them defensive

---

### Sylvan (Propagation, Groves, Weatherweaving)

**Threat Level**: High (in Grove: Extreme)  
**Skills**: Propagation, Groves, Weatherweaving

**Key Threats**:
- **Weatherweaving** - Calls down storms (constant damage + Shivering affliction)
- **Groves** - Massively empowered in their personal Grove
- **Propagation** - Nature-based attacks and healing

**CRITICAL IMPERATIVE**: **NEVER fight a Sylvan in their Grove**

**Counter Strategy**:
1. If in their Grove, LEAVE IMMEDIATELY
2. **Caloric salve** is mandatory - cures Shivering and prevents equilibrium loss
3. **Psi breath** to drain their mana (caster class)
4. Their storm damage is constant - end fights quickly
5. Curing system must prioritize Caloric application

---

### Unnamable (Weaponmastery, Anathema, Dominion)

**Threat Level**: High  
**Skills**: Weaponmastery, Anathema, Dominion

**Key Threats**:
- Corrupted warriors with powerful physical attacks
- **Anathema** provides dark magic enhancements
- **Dominion** abilities control the battlefield

**Counter Strategy**:
1. Mixed physical/magical threat - prepare for both
2. Standard pinning strategy (Block + Tailsweep)
3. **Dragonfire** breath for sustained damage
4. Watch for Dominion area control abilities

---

## General Combat Loop

```lua
-- Main combat automation structure
function combatLoop(target)
    -- Phase 1: LOCATE
    if not inSameRoom(target) then
        send("TRACK " .. target)
        return
    end
    
    -- Phase 2: PIN  
    if not targetBlocked then
        send("BLOCK")
        return
    end
    
    if targetStanding then
        send("TAILSWEEP " .. target)
        return
    end
    
    -- Phase 3: DAMAGE
    local breath = selectBreath(getClass(target))
    send("BREATHE " .. breath .. " " .. target)
end

-- Run on balance/equilibrium recovery
function onBalanceRecovery()
    checkDefenses()
    if inCombat and currentTarget then
        combatLoop(currentTarget)
    end
end
```

---

## Quick Reference Card

### Priority Actions (in order)
1. Cure critical afflictions
2. Maintain defenses (Sileris, Caloric, Rebounding)
3. Block (if enemy can flee)
4. Tailsweep (if enemy is standing)
5. Breath attack (class-appropriate selection)

### Emergency Responses
| Situation | Immediate Action |
|-----------|------------------|
| Serpent vanishes | `BREATHSTORM` |
| Limb damaged | `APPLY RESTORATION TO <limb>` |
| Shivering | `APPLY CALORIC` |
| Hypnosis suspected | `SAY` random words |
| Low health | Consider tactical retreat |

### Breath Quick-Select
| Enemy Type | Recommended Breath |
|------------|-------------------|
| Mana users | Psi (Gold) |
| Shield users | Acid (Black) |
| Mobile classes | Ice (Blue) |
| Everyone else | Dragonfire (Red) |

---

## References

1. AchaeaWiki - Dragoncraft: https://wiki.achaea.com/Dragoncraft
2. Achaea (Video Game) - TV Tropes: https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Achaea
3. keneanung/GMCPAdditions - GMCP Documentation: https://github.com/keneanung/GMCPAdditions
4. GMCP - Iron Realms Nexus Client: https://nexus.ironrealms.com/GMCP
5. Game Help | Achaea - Basic Principles of Combat: https://www.achaea.com/game-help/
6. All The Tropes - Achaea: https://allthetropes.org/wiki/Achaea

---

*Document Purpose: Combat automation reference guide for Dragon class PvP in Achaea MUD*  
*Client: Mudlet with Lua scripting*  
*Last Updated: February 2026*
