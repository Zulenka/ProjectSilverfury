-- Silverfury/offense/venoms.lua
-- Venom metadata and selection rules.
-- pick(mode) returns the best (v1, v2) pair for the current target state.
-- mode: nil/"lock" = standard lock path | "kelp_stack" = build kelp affs

Silverfury = Silverfury or {}
Silverfury.offense = Silverfury.offense or {}

local venoms = {}
Silverfury.offense.venoms = venoms

-- ── Venom data ────────────────────────────────────────────────────────────────
-- Maps venom name → { aff, cure_item, cure_channel, tags }
-- cure_item:    the specific herbal/salve name the target uses to cure.
-- cure_channel: "herb" | "salve" | "smoke" | "sip" | "focus"
-- tags:         category strings for strategy selection.

venoms.DATA = {
  -- ── Lock path ────────────────────────────────────────────────────────────
  curare    = { aff="paralysis",   cure_item="bloodroot", cure_channel="herb",  tags={"lock"} },
  kalmia    = { aff="asthma",      cure_item="kelp",      cure_channel="herb",  tags={"lock","kelp_stack","kelp_bypass"} },
  gecko     = { aff="slickness",   cure_item="valerian",  cure_channel="smoke", tags={"lock"} },
  slike     = { aff="anorexia",    cure_item="epidermal", cure_channel="salve", tags={"lock"} },

  -- ── Kelp-stack pressure venoms ───────────────────────────────────────────
  -- These give kelp-cured affs, clogging the herb channel before execution.
  vernalius = { aff="weariness",   cure_item="kelp",      cure_channel="herb",  tags={"pressure","kelp_stack"} },
  xentio    = { aff="clumsiness",  cure_item="kelp",      cure_channel="herb",  tags={"pressure","kelp_stack","kelp_cycle"} },
  prefarar  = { aff="sensitivity", cure_item="kelp",      cure_channel="herb",  tags={"pressure","kelp_stack","kelp_cycle"} },

  -- ── Other pressure venoms ────────────────────────────────────────────────
  euphorbia  = { aff="nausea",      cure_item="ginseng",   cure_channel="herb",  tags={"pressure"} },
  aconite    = { aff="stupidity",   cure_item="goldenseal",cure_channel="herb",  tags={"pressure"} },
  larkspur   = { aff="dizziness",   cure_item="goldenseal",cure_channel="herb",  tags={"pressure"} },
  eurypteria = { aff="recklessness",cure_item="lobelia",   cure_channel="herb",  tags={"pressure"} },
  vardrax    = { aff="addiction",   cure_item="ginseng",   cure_channel="herb",  tags={"pressure"} },
  epteth     = { aff="crippled",    cure_item="mending",   cure_channel="salve", tags={"pressure"} },

  -- ── Special ──────────────────────────────────────────────────────────────
  voyria   = { aff="voyria",     cure_item="immunity", cure_channel="sip",  tags={"kill"} },
  loki     = { aff="loki",       cure_item=nil,        cure_channel=nil,    tags={"special"} },
  sleipnir = { aff="sleepiness", cure_item=nil,        cure_channel="herb", tags={"lock"} },
}

-- ── Selection helpers ─────────────────────────────────────────────────────────

-- Seconds since last time we applied venom to target (anti-repeat).
local _last_applied = {}   -- key = venom, val = epoch_ms
local REPEAT_AVOID_MS = 0  -- loaded from config each pick

-- True if applying this venom would add a new aff (target doesn't already have it).
local function useful(venom_name)
  local data = venoms.DATA[venom_name]
  if not data then return false end
  if data.aff and Silverfury.state.target.hasAff(data.aff) then return false end
  local last = _last_applied[venom_name] or 0
  if (Silverfury.time.now() - last) < REPEAT_AVOID_MS then return false end
  return true
end

-- Pick best pair from a priority list, avoiding overlap.
local function pickFromList(list)
  local v1, v2 = nil, nil
  for _, vname in ipairs(list) do
    if useful(vname) then
      if not v1 then
        v1 = vname
      elseif not v2 and vname ~= v1 then
        v2 = vname
        break
      end
    end
  end
  return v1, v2
end

-- Count how many kelp-stack affs the target currently has.
function venoms.countKelpAffs()
  local tgt = Silverfury.state.target
  local n = 0
  for vname, data in pairs(venoms.DATA) do
    if data.cure_item == "kelp" and data.aff and tgt.hasAff(data.aff) then
      n = n + 1
    end
  end
  return n
end

-- ── Main selection ────────────────────────────────────────────────────────────
-- mode: nil | "lock" | "kelp_stack" | "pressure"
-- Returns v1, v2 (either may be nil if nothing useful remains).

function venoms.pick(mode)
  REPEAT_AVOID_MS = (Silverfury.config.get("venoms.repeat_avoid_s") or 20) * 1000
  local tgt = Silverfury.state.target

  -- ── Kelp-stack mode: build kelp-cured aff count before execution ──────────
  if mode == "kelp_stack" then
    local priority = Silverfury.config.get("venoms.kelp_stack_priority") or
                     { "kalmia", "vernalius", "xentio", "prefarar" }
    local v1, v2 = pickFromList(priority)
    -- Fall through to lock for second slot if kelp list exhausted.
    if not v2 then
      local lock = Silverfury.config.get("venoms.lock_priority") or {}
      local _, lv = pickFromList(lock)
      v2 = lv
    end
    return v1, v2
  end

  -- ── Slickness bypass: one kelp-cycle venom + one lock venom ──────────────
  if tgt.hasAff("slickness") then
    local kelp = Silverfury.config.get("venoms.kelp_cycle") or {}
    local lock  = Silverfury.config.get("venoms.lock_priority") or {}
    local kv, _ = pickFromList(kelp)
    local _, lv = pickFromList(lock)
    if kv and lv then return kv, lv end
  end

  -- ── Standard lock path ────────────────────────────────────────────────────
  local lock = Silverfury.config.get("venoms.lock_priority") or {}
  local v1, v2 = pickFromList(lock)

  -- Fill gap with off_priority.
  if not v2 then
    local off  = Silverfury.config.get("venoms.off_priority") or {}
    local _, ov = pickFromList(off)
    v2 = ov
  end

  return v1, v2
end

-- ── Record / reset ────────────────────────────────────────────────────────────

-- Record that we just sent a venom (called by outgoing parser or executor).
function venoms.record(venom_name)
  if venom_name then
    _last_applied[venom_name] = Silverfury.time.now()
  end
end

-- Manual clear (e.g., after target change).
function venoms.reset()
  _last_applied = {}
end

-- Human-readable status of venom pick state.
function venoms.status()
  local v1, v2 = venoms.pick()
  return string.format("Next venoms: %s / %s", v1 or "none", v2 or "none")
end
