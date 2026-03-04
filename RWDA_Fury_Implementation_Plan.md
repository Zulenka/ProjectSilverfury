# RWDA Fury Implementation Plan

**Objective:** Keep FURY active for every second of every fight, automatically managing re-activation, willpower cost gating, and endurance awareness.

---

## Mechanics Summary

```
FURY ON        -- activates (+2 STR, higher endurance drain)
FURY OFF       -- deactivates (use to reset if about to cap quarter-day time)
RELAX FURY     -- same as FURY OFF
```

| Constraint | Value |
|---|---|
| Strength bonus | +2 |
| Max uptime per Achaean day | 1/4 of a day (~4.5 real minutes per Achaean day cycle) |
| First activation cost | Free |
| Re-activation cost (same day) | 500 willpower each time |
| Equilibrium cost | 2.00 seconds |
| Endurance drain | Significantly higher while active |

**Key insight:** The goal is never to turn FURY OFF during a fight. If we activate it exactly once per fight (on engage), pay zero willpower cost, and ride it until the fight ends, we get the full +2 STR for the whole fight for free.

---

## Implementation Strategy

### Activation Policy

| Scenario | Action |
|---|---|
| Fight starts (engage fired) | `FURY ON` immediately — on equilibrium, before first tick |
| FURY drops unexpectedly mid-fight | Re-activate if willpower ≥ threshold (`config.fury.min_wp_reactivate`) |
| FURY drops and willpower is too low | Log warning, do not re-activate (avoid endurance spiral) |
| Fight ends (rwda stop/disengage) | Do nothing — let it expire naturally to preserve the free slot |

### Never use FURY OFF proactively
Turning it off and back on costs 500 willpower. Only use `FURY OFF` if the time cap is about to expire mid-fight (which is rare and probably not worth managing automatically at first).

---

## Files to Create / Modify

### New File: `engine/fury.lua`

Module structure mirrors `engine/falcon.lua`.

```
rwda.engine.fury
  .onEngage()         -- fires FURY ON (after eq check)
  .onFuryLost()       -- called by parser when fury fades; re-activates if safe
  .onFuryActivated()  -- called by parser on confirmation; updates state
  .status()           -- prints current fury state to echo
  .bootstrap()        -- registers event handlers
```

**State tracked locally:**
```lua
local state = {
  active          = false,   -- is fury currently on?
  activated_this_day = false, -- have we used the free slot today?
  reactivations   = 0,       -- how many willpower-costs incurred this day
  last_activated_ms = 0,     -- timestamp of last activation
}
```

### Modified Files

| File | Change |
|---|---|
| `config.lua` | Add `config.fury` defaults block |
| `init.lua` | Add `engine/fury.lua` to FILES list, call `fury.bootstrap()` |
| `engine/parser.lua` | Route 4-5 fury confirmation/loss lines to `fury.onLine()` |
| `ui/commands.lua` | Add `rwda fury` command tree (alias `rwda fy`) |
| `state/me.lua` | Add `fury_active = false` and `willpower = 0` / `maxwillpower = 0` to `newMe()` |

---

## Phase 1 — State & Config

### `config.lua` additions

```lua
config.fury = config.fury or {}
-- Auto-activate FURY on engage.
setDefault(config.fury, "auto_activate",        true)
-- Re-activate if fury drops mid-fight (costs 500 willpower each time).
setDefault(config.fury, "auto_reactivate",      true)
-- Minimum willpower to re-activate (avoids endurance spiral at low resources).
setDefault(config.fury, "min_wp_reactivate",    1500)
-- Warn (but still activate) if endurance falls below this fraction (0.0–1.0).
setDefault(config.fury, "endurance_warn_pct",   0.25)
-- Add fury = {} to exportPersistedConfig()
```

### `state/me.lua` additions

```lua
fury_active = false,
willpower   = 0,
maxwillpower = 0,
endurance   = 0,
maxendurance = 0,
```

These are populated by the GMCP `Char.Vitals` handler in `parser.lua`.

---

## Phase 2 — Parser Patterns

Add to `engine/parser.lua` (same approach as runesmith routing block):

| Achaea message | Routes to |
|---|---|
| `"you feel a surge of fury"` or `"you activate your fury"` | `fury.onFuryActivated()` |
| `"your fury fades"` or `"your fury dissipates"` | `fury.onFuryLost()` |
| `"you do not have enough willpower"` | `fury.onWillpowerTooLow()` |
| `"you are already in a fury"` | `fury.onAlreadyActive()` |
| `"you relax out of your fury"` | `fury.onFuryLost()` |

Also update `onGMCPVitals` to capture `willpower` and `endurance` from GMCP vitals if the game sends them.

---

## Phase 3 — `engine/fury.lua`

### Engage hook

```lua
function fury.onEngage()
  if not (rwda.config.fury and rwda.config.fury.auto_activate) then return end
  if not rwda.running then return end
  -- Send with a short delay so runesmith / falcon fire first.
  tempTimer(0.1, function() sendGame("fury on") end)
  log("FURY ON sent on engage.")
end
```

### Loss handler

```lua
function fury.onFuryLost()
  state.active = false
  if not rwda.running then return end

  local cfg = rwda.config.fury or {}
  if not cfg.auto_reactivate then
    log("Fury lost. auto_reactivate is off.")
    return
  end

  local wp = rwda.state.me and rwda.state.me.willpower or 0
  local minWP = cfg.min_wp_reactivate or 1500

  if state.activated_this_day and wp < minWP then
    rwda.util.log("warn", "[Fury] Fury lost — willpower %d < threshold %d. Not re-activating.", wp, minWP)
    return
  end

  sendGame("fury on")
  log("Fury lost mid-fight — re-activating (willpower=%d).", wp)
end
```

### Activation confirmation

```lua
function fury.onFuryActivated()
  state.active = true
  if state.activated_this_day then
    state.reactivations = state.reactivations + 1
    log("Fury re-activated (cost: 500 willpower, reactivations today: %d).", state.reactivations)
  else
    state.activated_this_day = true
    log("Fury activated (free slot used).")
  end
  state.last_activated_ms = getEpochMs and getEpochMs() or 0
  raiseEvent("FURY_ACTIVATED", { reactivations = state.reactivations })
end
```

### Day reset

Achaea days cycle roughly every 20 real minutes. The module listens for any indicator that a new day has started (or resets on full session bootstrap):

```lua
function fury.onNewDay()
  state.activated_this_day = false
  state.reactivations = 0
  log("New Achaean day — fury free slot reset.")
end
```

---

## Phase 4 — Commands (`rwda fury` / `rwda fy`)

| Command | What it does |
|---|---|
| `rwda fury on` | Manually send `FURY ON` |
| `rwda fury off` | Manually send `FURY OFF` |
| `rwda fury status` | Print fury state: active, reactivations, willpower, endurance |
| `rwda fury auto on\|off` | Toggle `config.fury.auto_activate` |
| `rwda fury reactivate on\|off` | Toggle `config.fury.auto_reactivate` |
| `rwda fury minwp <value>` | Set `config.fury.min_wp_reactivate` |

---

## Phase 5 — init.lua Wiring

Add **after falcon** in FILES list and bootstrap:

```lua
-- FILES list
"engine/fury.lua",

-- bootstrap()
fury.bootstrap()

-- onEngage hook (inside rwda.engage())
fury.onEngage()
```

---

## Phase 6 — Endurance Awareness

FURY increases endurance drain. If not monitored, the character could pass out mid-fight.

**Plan:**
1. Track `endurance` / `maxendurance` from GMCP vitals
2. In `fury.onFuryActivated()`, start a repeating timer (every 5s) that checks `endurance / maxendurance`
3. If below `config.fury.endurance_warn_pct` (default 25%), log a bright warning
4. If below 10% (hard floor), automatically send `FURY OFF` to stop the drain — better to lose +2 STR than pass out

```lua
-- Optional hard-floor safety
if endPct < 0.10 then
  sendGame("fury off")
  warn("FURY OFF: endurance critical (%.0f%%).", endPct * 100)
end
```

---

## Edge Cases

| Case | Handling |
|---|---|
| FURY times out naturally (1/4 day used) | Parser detects `"your fury fades"` → `onFuryLost()` → re-activation skipped if same day AND willpower too low |
| Engage fires while fury already active (back-to-back fights) | `fury.onEngage()` checks `state.active` — skips send if already on |
| Player manually uses `FURY OFF` | Parser routes to `onFuryLost()` — auto_reactivate will fire unless disabled |
| Willpower currently 0 (dragon/other drain) | `onFuryLost()` willpower check prevents re-activation |
| New Achaean day mid-session | `onNewDay()` resets `activated_this_day` flag |

---

## File Change Summary

| File | Type | Change |
|---|---|---|
| `engine/fury.lua` | **NEW** | Full module ~150 lines |
| `state/me.lua` | modify | Add fury_active, willpower, endurance fields |
| `config.lua` | modify | `config.fury` defaults + persistence |
| `init.lua` | modify | FILES list + bootstrap call + engage hook |
| `engine/parser.lua` | modify | fury line routing block |
| `ui/commands.lua` | modify | `rwda fury` / `rwda fy` command tree |

---

## Implementation Order

1. `state/me.lua` — add fields (no dependencies)
2. `config.lua` — add defaults (no dependencies)
3. `engine/fury.lua` — create module
4. `engine/parser.lua` — add routing block
5. `init.lua` — wire it in
6. `ui/commands.lua` — add commands
7. Build, test with `rwda engage <name>`, verify `FURY ON` fires
