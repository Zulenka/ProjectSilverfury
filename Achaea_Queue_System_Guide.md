# Achaea Server-Side Queue System
## AI Combat Reference Guide

### Overview

Achaea's **server-side queueing system** executes commands the **instant** you recover the necessary balance/equilibrium, eliminating network latency. This is critical for Dragon combat where timing determines kill success.

**Key Insight**: Instead of sending commands from the client when you *think* you have balance, you tell the server "execute this the moment I have balance" - the server handles the timing perfectly.

---

## System Configuration

```
CONFIG USEQUEUEING ON       -- Enable the queue system
CONFIG SHOWQUEUEALERTS ON   -- Show queue execution feedback
```

---

## Core Queue Commands

| Command | Effect |
|---------|--------|
| `QUEUE ADD <type> <command>` | Add command to end of queue |
| `QUEUE PREPEND <type> <command>` | Add command to START of queue (priority) |
| `QUEUE ADDCLEAR <type> <command>` | Clear that queue type, then add command |
| `QUEUE ADDCLEARFULL <type> <command>` | Clear ALL queues, add command |
| `QUEUE LIST` | Show all queued actions |
| `CLEARQUEUE <type>` | Clear specific queue |
| `CLEARQUEUE ALL` | Clear everything |

**Maximum**: 10 commands can be queued across all types.

---

## Queue Types (Requirements to Fire)

| Type | Flag | Requirement |
|------|------|-------------|
| **Eq** | `e` | Have mental equilibrium |
| **Bal** | `b` | Have physical balance |
| **Eqbal** | `eb` | Have BOTH equilibrium AND balance |
| **Class** | `c` | Have class-specific balance |
| **Para** | `p!` | NOT paralyzed |
| **Free** | - | Eqbal + unbound + not paralyzed + not stunned |
| **Freestand** | - | All "Free" requirements + must be standing |

---

## Logic Flags for Advanced Conditions

Use `!` (exclamation) to **invert** a flag (meaning "NOT this condition"):

| Flag | Meaning |
|------|---------|
| `p!` | NOT paralyzed |
| `t!` | NOT stunned |
| `w!` | NOT webbed/bound |
| `u` | Standing upright |
| `c` | Have class balance |

### Combining Flags

You can combine multiple flags for precise conditions:

```
QUEUE ADD c! p! t! u <command>
```
This fires when: class balance + not paralyzed + not stunned + standing

```
QUEUE ADD eb! w! p! t! <command>
```
This is effectively the "FREE" queue condition.

---

## Dragon Combat Applications

### Recommended Queue Types by Action

| Dragon Action | Recommended Queue | Reason |
|---------------|-------------------|--------|
| **Rend/Bite/Gut** | `eqbal` or `bal` | Standard attacks need balance |
| **Gust** | `eq` | Uses equilibrium |
| **Tailsweep** | `bal` | Uses balance |
| **Devour** | `freestand` | MUST be standing, unhindered |
| **Dragonflex** | `bal` | Escape bindings on balance |
| **Block** | `free` | Movement control |
| **Breath weapons** | `eq` | Most breaths use equilibrium |

### Why Freestand for Devour

Devour will **fail** if you are:
- Prone (not standing)
- Paralyzed
- Stunned
- Bound/webbed

Using `freestand` ensures the command only fires when ALL conditions are met.

---

## Implementation Patterns

### Pattern 1: Simple Attack Queue
```
QUEUE ADDCLEAR bal rend Enemy torso
```
Clears any existing balance queue, queues rend for when balance returns.

### Pattern 2: Combo with Priority
```
QUEUE ADDCLEAR bal rend Enemy torso
QUEUE PREPEND eq gust Enemy
```
Gust fires first (prepended to eq queue), then rend when balance returns.

### Pattern 3: Full Offensive Sequence
```
QUEUE ADDCLEARFULL bal rend Enemy torso
QUEUE ADD bal bite Enemy head
QUEUE ADD eq gust Enemy
```
Clears everything, sets up a rotation.

### Pattern 4: Safe Devour Execution
```
QUEUE ADDCLEAR freestand devour Enemy
```
Only executes when standing, not paralyzed, not stunned, not bound.

### Pattern 5: Defensive Priority
```
QUEUE PREPEND bal dragonflex
```
Inserts dragonflex at front - will fire before any other balance action.

---

## Lua Integration for Dragon System

### Sending Queued Commands

```lua
function Dragon.Queue:send(queueType, command)
    send("queue addclear " .. queueType .. " " .. command)
end

function Dragon.Queue:prepend(queueType, command)
    send("queue prepend " .. queueType .. " " .. command)
end

function Dragon.Queue:clear(queueType)
    queueType = queueType or "all"
    send("clearqueue " .. queueType)
end
```

### Dragon-Specific Queue Functions

```lua
-- Safe attack that won't fire if paralyzed/prone
function Dragon.Queue:attack(command)
    send("queue addclear freestand " .. command)
end

-- Emergency escape - highest priority
function Dragon.Queue:escape(command)
    send("queue prepend bal " .. command)
end

-- Standard balance attack
function Dragon.Queue:queueBal(command)
    send("queue addclear bal " .. command)
end

-- Standard equilibrium action
function Dragon.Queue:queueEq(command)
    send("queue addclear eq " .. command)
end

-- Devour with all safety checks
function Dragon.Queue:devour(target)
    send("queue addclear freestand devour " .. target)
end
```

### Full Combat Example

```lua
function Dragon.Offense:executeQueued(target, attack, limb)
    -- Clear all queues for clean state
    send("clearqueue all")
    
    -- Queue the attack for when we have balance
    if attack == "gust" then
        send("queue add eq gust " .. target)
    elseif attack == "devour" then
        send("queue add freestand devour " .. target)
    else
        send("queue add bal " .. attack .. " " .. target .. " " .. limb)
    end
end
```

---

## Queue vs Client-Side Timing

| Approach | Latency Impact | Reliability |
|----------|---------------|-------------|
| **Client sends on trigger** | +50-200ms round trip | Can miss window |
| **Server queue** | 0ms (server-side) | Guaranteed instant |

**Example**:
- Your ping is 100ms
- Balance recovers at server time T
- Client trigger fires, sends command at T+100ms
- Command arrives at server at T+200ms
- **You've lost 200ms** - opponent may have acted

With queue:
- Server has command ready
- Balance recovers at server time T
- Command executes at T+0ms
- **Instant execution**

---

## Best Practices

1. **Always use `addclear` or `addclearfull`** to prevent stale commands
2. **Use `freestand` for kill moves** (Devour) to prevent wasted attempts
3. **Use `prepend` for emergency escapes** (Dragonflex)
4. **Don't over-queue** - 10 command limit, and situations change
5. **Clear queues when target dies** or combat ends
6. **Queue type must match the ability's balance requirement**

---

## Quick Reference Card

```
-- Standard attack (balance)
QUEUE ADDCLEAR bal rend TARGET torso

-- Knock prone (equilibrium)  
QUEUE ADDCLEAR eq gust TARGET

-- Safe devour (all checks)
QUEUE ADDCLEAR freestand devour TARGET

-- Emergency escape (priority)
QUEUE PREPEND bal dragonflex

-- Clear everything
CLEARQUEUE ALL

-- Check what's queued
QUEUE LIST
```

---

*This queue system is essential for competitive Dragon combat - it removes human/network latency from the equation entirely.*
