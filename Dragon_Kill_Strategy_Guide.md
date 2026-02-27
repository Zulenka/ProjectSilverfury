# Dragon Kill Strategy Guide
## AI Reference for Player Kill Execution

### Overview
This guide documents the **Dragon kill path** focusing on how to execute players through the **Devour** instakill mechanic. The Dragon's primary win condition is a limb-damage-based kill path that culminates in an uninterruptible execution.

---

## Core Offensive Kill Path: The Devour Window

The **Devour ability** is the Dragon's instant kill mechanic requiring channeled setup. Kill efficiency depends on tracking and maximizing limb damage throughout the fight.

### Kill Path Execution Sequence

#### Step 1: Pin and Ground
**Objective**: Prevent target escape and establish positional control

| Ability | Resource Cost | Effect |
|---------|--------------|--------|
| `Block <direction>` | None | Obstruct exits to prevent fleeing |
| `Gust` | Equilibrium | Knock target prone |
| `Tailsweep` | Balance | Alternative prone method |

**Priority**: Block key escape routes first, then force prone status.

---

#### Step 2: Limb Pressure
**Objective**: Build systematic damage on specific body parts

**Physical Strike Rotation**:
| Ability | Target | Purpose |
|---------|--------|---------|
| `Rend` | Limbs | Build limb damage |
| `Bite` | Limbs | Build limb damage |
| `Gut` | Torso | Prioritize torso damage |

**Cycle these strikes to accumulate damage across body parts.**

---

#### Step 3: Torso Focus
**Critical Insight**: A damaged/broken **torso** provides a **significantly higher boost** to Devour completion speed than any other limb.

**Strategy**:
- While all broken limbs speed up execution, prioritize torso damage
- Track torso break state carefully
- Shift focus to torso once other limbs are pressured

---

#### Step 4: The Execution
**Trigger Condition**: Torso broken

**Command**: `Devour <target>`

**Key Mechanic**: If your system calculates the total completion time to be **under six seconds**, the action becomes **uninterruptible** by standard methods like paralysis or being knocked to the ground.

**6-Second Rule**:
- <6 seconds = Uninterruptible kill
- ≥6 seconds = Vulnerable to disruption

---

## Draconic Defensive Suite

Maintain these defenses to survive long enough to execute your kill path:

### Dragonarmour
- **Type**: Mandatory toggle
- **Cost**: Mana consumption
- **Effect**: Magical armor mitigating incoming damage
- **Priority**: Always active

### Dragonflex
- **Type**: Balance-based instant escape
- **Use Case**: Snap through bindings (webs, transfixing effects)
- **Advantage**: Faster than standard `Writhe` command
- **Critical vs**: Jester puppetry, any binding effects

### Clawparry
- **Type**: Automatic physical defense
- **Effect**: Uses talons to fend off physical attacks
- **Note**: Passive protection layer

### Racial Resistances
- **Level**: Inherent Level 2 resistance
- **Coverage**: Specific damage types (varies by Dragon form)

---

## Class-Specific Counter Strategies

When fighting specific classes, apply these strategic overrides to your standard kill path:

| Target Class | Ability to Use | Counter Strategy |
|--------------|----------------|------------------|
| **Alchemist** | Ginger/Antimony | Regulate fluid levels to prevent spontaneous organ failure |
| **Apostate** | Psi/Lightning Breath | Disrupt equilibrium to prevent the setup for the Vivisect instakill |
| **Bard** | Rebounding | Counter the high-frequency physical strikes of Bladedance |
| **Blademaster** | Restoration Salve | Prioritize limb healing to prevent the "broken limb lock" required for Brokenstar |
| **Depthswalker** | Elm/Cinnabar | High-priority pipe smoking to clear Aeon action-delay |
| **Druid/Sylvan** | Leap/Hoist | Immediately exit their Grove environment where their power is highest |
| **Infernal** | Acid Breath | Use unblockable damage to bypass their heavy physical armor and magical shields |
| **Jester** | Dragonflex | Snap puppet strings used to force self-harming actions |
| **Magi** | Breathstorm | Shatter crystalline vibrations and room-based utility |
| **Monk** | Psi Breath | Target their mental resources and Kai energy reserves directly |
| **Runewarden** | Movement | Avoid ground-sketched runes |
| **Serpent** | Say prompt words | Detect prompt words in text buffer and say them to clear Hypnosis suggestions |
| **Shaman** | Physical Strike | Find and attack directly to disrupt the distance link from their Vodun doll |
| **Unnamable** | Acid Breath | Deal consistent damage ignoring their mutant-based physical defenses |

---

## Kill Scenario Template

### Standard Kill Flow
```
1. SETUP PHASE
   - Activate Dragonarmour
   - Block primary escape route
   - Establish room control

2. PRESSURE PHASE
   - Gust/Tailsweep to prone
   - Cycle: Rend → Bite → Gut
   - Track limb damage states
   - Prioritize torso damage

3. EXECUTION PHASE
   - Verify torso broken
   - Calculate completion time
   - If <6 seconds: Execute Devour
   - If ≥6 seconds: Continue pressure

4. DEFENSIVE MAINTENANCE
   - Monitor mana for Dragonarmour
   - Dragonflex out of bindings immediately
   - Maintain Clawparry active
```

### Kill Decision Logic
```lua
-- Pseudocode for kill decision
if target.torso == "broken" then
    local devour_time = calculateDevourTime(target)
    if devour_time < 6 then
        -- Safe to execute - uninterruptible
        execute("devour " .. target.name)
    else
        -- Continue pressure to reduce time
        continueAttackRotation()
    end
end
```

---

## Movement Control Reference

| Command | Effect | Resource |
|---------|--------|----------|
| `Block <dir>` | Obstruct exit | None |
| `Gust` | Knock prone | Equilibrium |
| `Tailsweep` | Knock prone | Balance |

**Tip**: Use Block on the direction the target is most likely to flee (toward city/allies), then apply prone.

---

## Quick Reference Card

### Kill Requirements
- ☐ Dragonarmour active
- ☐ Target prone
- ☐ Exits blocked
- ☐ Torso broken
- ☐ Devour time <6 seconds

### Emergency Responses
- **Webbed/Transfixed**: Dragonflex immediately
- **Taking heavy damage**: Verify Dragonarmour active
- **Target fleeing**: Block + Gust/Tailsweep

### Devour Timing
- **Uninterruptible**: <6 seconds
- **Interruptible**: ≥6 seconds (paralysis, knockdown can stop it)

---

*This guide is for AI reference to assist with Dragon PvP combat automation and decision-making in Achaea.*
