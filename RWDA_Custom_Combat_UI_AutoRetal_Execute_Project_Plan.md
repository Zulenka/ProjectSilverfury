# RWDA Custom Combat UI + Auto Retaliation + Auto Execute Project Plan

Date: 2026-02-28
Project: Project Silverfury (RWDA + Legacy)
Target Runtime: Mudlet Lua, Legacy backend only

## 1. Objective
Build a configurable combat control system for RWDA that allows live, on-the-fly strategy editing from a simple popout UI, with separate Runewarden and Dragon tabs, plus:
- Auto retaliation (auto-target aggressor and respond with configured kill pipeline)
- Auto execute logic (Runewarden finisher + Dragon devour finisher)
- Automatic fallback logic when execution fails

This plan explicitly converts hardcoded rotation logic (like `Cyrene Auto Dragon Combat v2.lua`) into reusable, user-editable strategy layers.

## 2. Why This Is Needed
Current RWDA strengths:
- Strong runtime state model
- Parser/planner/executor separation
- Legacy integration and queue safety controls

Current gap:
- Strategy logic is mostly hardcoded in planner functions
- No visual config for priorities/attacks/affliction focus
- No full auto-retaliation workflow
- No robust execute-fail recovery state machine

The requested feature set requires moving from a fixed rule tree to a configurable decision graph with UI controls.

## 3. Scope
### In Scope
- Popout UI for combat strategy editing
- Live strategy reload into planner without reloading profile
- Runewarden and Dragon specific strategy tabs
- Per-mode selection of affliction focus, venoms, curses, and attack blocks
- Auto-retaliation target acquisition and lock policy
- Auto finisher detection + dispatch + fallback recovery
- Config persistence and profile export/import
- Diagnostic visibility and test harness updates

### Out of Scope (initial release)
- Full visual drag-and-drop graph editor
- Denizen automation / resource farming / PvE loops
- Multi-target battlefield AI beyond single primary target
- ML-based rotation optimization

## 4. Design Principles
1. Safety first: no uncontrolled spam, no blind target swaps, and hard kill-switch support.
2. Explainability: every chosen action must have a reason code visible in `rwda explain` and UI.
3. Runtime mutability: updates in UI should apply immediately or after explicit "Apply".
4. Legacy-compatible: reads Legacy + AK/LB state; does not replace Legacy curing logic.
5. Deterministic execution: execute paths must have preconditions, timeout, and fallback transitions.

## 5. Reference Mapping from Cyrene Script
The Cyrene script currently hardcodes:
- Curse priority chain (`impatience -> asthma -> paralysis -> stupidity`)
- Venom chain (`curare/kalmia/gecko/slike/aconite`)
- Attack mode switch (`gut` if not prone, `bite` if prone)
- Override priorities (`shield -> lyre -> flying -> attack`)

We will represent this as editable strategy entries:
- Condition blocks
- Priority order list
- Action templates
- Overrides with top-of-stack precedence

## 6. High-Level Architecture Changes
### 6.1 New Modules
- `rwda/ui/combat_builder.lua`
  - Popout UI rendering and interactions
- `rwda/ui/combat_builder_state.lua`
  - View model + temporary edits + apply/revert
- `rwda/engine/strategy.lua`
  - Runtime strategy registry, validation, merge, activation
- `rwda/engine/retaliation.lua`
  - Aggressor detection, auto-target lock, retaliate trigger
- `rwda/engine/finisher.lua`
  - Execute detection, attempt lifecycle, fallback routing
- `rwda/data/strategy_presets.lua`
  - Default Runewarden and Dragon templates (including Cyrene-style preset)

### 6.2 Existing Modules to Refactor
- `rwda/engine/planner.lua`
  - Replace direct hardcoded branches with strategy-driven action resolver
- `rwda/engine/parser.lua`
  - Add aggressor extraction + execute success/fail pattern events
- `rwda/ui/commands.lua`
  - Add builder open/apply/save/load commands
- `rwda/config.lua`
  - Persist strategy profiles + retaliation/execute settings
- `rwda/engine/doctor.lua`
  - Add status lines for strategy and retaliation/execute state

## 7. Data Model Specification
## 7.1 Strategy Root
```lua
strategy = {
  version = 1,
  active_profile = "duel",
  profiles = {
    duel = {
      runewarden = { ... },
      dragon = { ... },
      shared = { ... }
    }
  }
}
```

### 7.2 Mode Strategy
```lua
mode_strategy = {
  enabled = true,
  aff_focus = { "paralysis", "asthma", "slickness" },
  curse_priority = { "impatience", "asthma", "paralysis", "stupidity" },
  venom_priority = { "curare", "kalmia", "gecko", "slike", "aconite" },
  attack_blocks = {
    { id="strip_shield", enabled=true, priority=100, when={"target.shield"}, do_={"tailsmash {target}"} },
    { id="force_prone", enabled=true, priority=80, when={"not target.prone"}, do_={"gut {target} {venom1}", "breathgust {target}"} },
    { id="prone_dps", enabled=true, priority=70, when={"target.prone"}, do_={"bite {target}", "breathgust {target}"} }
  },
  finisher = {
    enabled = true,
    name = "devour",
    threshold = 6.0,
    verify_patterns = { "You begin to devour", "You have devoured" },
    fail_timeout_ms = 2500,
    fallback_block_id = "force_prone"
  }
}
```

### 7.3 Condition DSL (simple)
- `target.shield`
- `target.rebounding`
- `target.prone`
- `target.available`
- `me.form == dragon|human`
- `aff.<name> < percent`
- `limb.<name>.broken`
- `finisher.window_ready`

No arbitrary eval in v1; use parser for trusted condition tokens.

## 8. Popout UI Plan (Simple, Practical)
### 8.1 Window Layout
- Top bar:
  - Profile selector (`duel`, `group`, custom)
  - Apply, Save, Revert buttons
  - Toggle Auto Retaliate, Toggle Auto Execute
- Tab group:
  - `Runewarden`
  - `Dragon`
  - `Shared`
  - `Safety`

### 8.2 Runewarden Tab
- Venom priority list editor (up/down/toggle)
- Attack blocks table:
  - Raze, Razeslash, DSL, Impale, Intimidate, Disembowel
  - Enabled checkbox
  - Priority numeric input
  - Condition selector
- Finisher panel:
  - Auto disembowel enabled
  - Preconditions display
  - Fail timeout and fallback block

### 8.3 Dragon Tab
- Curse priority list editor
- Dragon venom preference list
- Attack blocks:
  - Tailsmash, Breathstrip, Blast, Gut/Rend/Swipe/Bite/Breathgust
- Finisher panel:
  - Auto devour enabled
  - Min window threshold
  - Fallback block selection

### 8.4 Shared Tab
- Targeting behavior:
  - Follow Legacy target
  - Auto target aggressor
  - Retaliation lock duration
  - Allow target swap while executing (yes/no)
- Priority overrides:
  - Shield strip first
  - Rebounding strip first
  - Flying checks

### 8.5 Safety Tab
- Emergency stop behavior
- Max actions per N seconds
- Ignore non-player aggressors
- Ignore groupmate aggressors
- Required confirmation for high-risk forced executes

## 9. Auto Retaliation Plan
### 9.1 Detection Inputs
- Parser patterns for incoming attack lines (`<Name> <verb> you`)
- GMCP/IRE target changes when available
- Existing target tracking from `groupcombat` adapter

### 9.2 Retaliation State Machine
States:
- `idle`
- `candidate_detected`
- `locked_target`
- `retaliating`
- `cooldown`

Rules:
1. On aggressor line, validate aggressor against safety filters.
2. If allowed, set target source `retaliation` and start lock timer.
3. Planner uses kill-focused profile branch while retaliation lock is active.
4. On lock expiry or target unavailable, return to previous manual/external target behavior.

### 9.3 Anti-Churn Rules
- Debounce aggressor swaps (e.g., 1500 ms)
- Minimum confidence threshold before target swap
- Prevent swap if current execute attempt is in progress

## 10. Auto Execute Plan
### 10.1 Runewarden Finisher Path
Primary finisher: `disembowel` (requires successful impale context and readiness)

Execution logic:
1. Detect execute window in planner via target state + class prerequisites.
2. Dispatch `impale` if required and not active.
3. Dispatch `disembowel` when preconditions pass.
4. Wait for success/fail confirmation lines.
5. If fail or timeout, transition to fallback prep (leg break/prone lock) and retry cycle.

### 10.2 Dragon Finisher Path
Primary finisher: `devour`

Execution logic:
1. Compute devour readiness score (existing threshold model + config).
2. Attempt `devour` in valid state.
3. Parse success/fail/interruption text.
4. On failure, route to configured fallback block (typically prone + torso/limb pressure).
5. Re-attempt when readiness recovers.

### 10.3 Failure Handling (Both Modes)
- Track `attempt_id`, `attempt_started_ms`, `attempt_action`
- Mark outcome: `success`, `failed`, `interrupted`, `timed_out`
- Insert cooldown to prevent immediate command thrash
- Update explain log with exact failure reason

## 11. Planner Refactor Strategy
Current planner function split (`humanDualcut`, `dragonSilver`) is retained as execution engines, but their action choice becomes strategy-driven.

New planner flow:
1. Collect state snapshot
2. Resolve mode and active profile
3. Evaluate override blocks (shield/rebound/flying/etc)
4. Evaluate finisher window if enabled
5. Evaluate standard attack blocks by priority and conditions
6. Return first valid action set
7. Record `reason.code`, `reason.block_id`, `reason.strategy_profile`

## 12. Command Additions
Add commands for non-UI control:
- `rwda builder open`
- `rwda builder close`
- `rwda strategy show`
- `rwda strategy apply`
- `rwda strategy save [profile]`
- `rwda strategy load [profile]`
- `rwda retaliate <on|off>`
- `rwda execute <on|off>`
- `rwda set retalcooldown <ms>`
- `rwda set executefailtimeout <ms>`

## 13. Persistence Model
Persist in RWDA config file under new keys:
- `config.strategy`
- `config.retaliation`
- `config.finisher`

Version strategy payload so future migrations are deterministic.

## 14. Testing Plan
### 14.1 Unit/Offline
- Extend `selftest.lua` for:
  - Strategy block resolution
  - Retaliation lock behavior
  - Execute success/fail fallback transitions

### 14.2 Replay Tests
- New replay suites:
  - Dragon shield->strip->pressure->devour success
  - Dragon devour fail->fallback->retry
  - Runewarden impale->disembowel success
  - Runewarden disembowel fail->leg reprime->retry
  - Auto-retaliation target switch from incoming hits

### 14.3 Live Validation
- UI changes reflected in `rwda explain` within one tick
- No queue spam when target unavailable
- No target churn in multi-attacker rooms

## 15. Delivery Phases
### Phase A: Strategy Core (No UI yet)
- Build `engine/strategy.lua`
- Move hardcoded chains to default strategy preset
- Add command-only editing for prove-out
- Acceptance: planner selects from strategy table only

### Phase B: Auto Retaliation
- Build `engine/retaliation.lua`
- Add parser aggressor events
- Add lock/swap safety controls
- Acceptance: reliable auto-target + no churn

### Phase C: Auto Execute + Fallback
- Build `engine/finisher.lua`
- Add execute attempt lifecycle + fail recovery
- Acceptance: retries correctly after forced failure scenarios

### Phase D: Popout UI
- Build simple Geyser/Adjustable UI with tabs
- Wire Apply/Save/Revert
- Acceptance: all core strategy fields editable live

### Phase E: Hardening + Documentation
- Expand doctor status output
- Add command docs and migration notes
- Add troubleshooting playbook

## 16. Risks and Mitigations
- Risk: Over-automation causes target thrash
  - Mitigation: lock windows + confidence gating + cooldown
- Risk: Execute loops spam on bad parse
  - Mitigation: explicit timeout + fail cooldown + parser confidence checks
- Risk: UI complexity slows iteration
  - Mitigation: staged simple controls first; no drag-drop in v1
- Risk: Inconsistent third-party table shapes (`ak`, `lb`, `affstrack`)
  - Mitigation: adapter normalization layer + defensive parsing + diagnostics

## 17. Implementation Checklist (Actionable)
1. Add strategy schema and defaults in `config.lua` and new `data/strategy_presets.lua`.
2. Implement strategy resolver (`engine/strategy.lua`) and refactor planner calls.
3. Add retaliation engine and parser aggressor event extraction.
4. Add finisher engine with `attempt/verify/fallback` cycle.
5. Add commands for strategy/retaliation/execute toggles.
6. Build minimal popout UI tabs and bind to config view-model.
7. Wire persistence load/save for strategy payloads.
8. Add selftests and replay suites for new state paths.
9. Update command list, README, and dev test log.
10. Package and run live smoke pass in Mudlet.

## 18. Suggested Default Presets
### Dragon Preset: "Cyrene v2 Compatible"
- Curse priority: impatience, asthma, paralysis, stupidity
- Venom priority: curare, kalmia, gecko, slike, aconite
- Attack logic:
  - If shield -> tailsmash + dragoncurse
  - If lyre -> blast
  - If flying -> becalm
  - If not prone -> gut + breathgust
  - If prone -> bite + breathgust

### Runewarden Preset: "Impale Kill"
- Priority:
  - strip rebound
  - strip shield
  - DSL leg prep
  - impale when legal
  - disembowel on execute window
  - fallback to re-prime legs and prone if fail

## 19. Compliance and Safety Guardrails
- Keep system combat-reactive only.
- Do not automate resource generation loops.
- Ensure explicit user toggles for retaliation and execute automation.
- Preserve `rwda stop` as hard immediate kill-switch.

## 20. Immediate Next Build Step
Start Phase A by implementing strategy schema + resolver and rewire `planner.lua` to use strategy entries without changing command syntax yet. This gives immediate value and keeps all later UI work plug-in compatible.
