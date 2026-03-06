-- Silverfury/config.lua
-- All user-tunable defaults. Persisted values from disk win over these defaults.
-- Save/load via sf save and sf load commands.

Silverfury = Silverfury or {}

local defaults = {
  -- ── Logging ────────────────────────────────────────────────────────────────
  logging = {
    enabled   = true,
    level     = "info",   -- trace | info | warn | error
    to_file   = true,
    console   = true,
  },

  -- ── Integration ────────────────────────────────────────────────────────────
  integration = {
    use_legacy              = true,
    auto_enable_with_legacy = true,   -- arm SF automatically when Legacy fires ready
    wait_for_legacy_ms      = 5000,   -- max wait before giving up on Legacy signal
  },

  -- ── Combat core ────────────────────────────────────────────────────────────
  combat = {
    auto_tick_on_prompt  = true,    -- fire tick on every LPrompt event
    anti_spam_ms         = 275,     -- minimum ms between sent commands
    require_bal_eq       = true,    -- skip action if missing required balance
    use_server_queue     = false,   -- true → use Achaea sq; false → Mudlet send()
  },

  -- ── Safety thresholds ──────────────────────────────────────────────────────
  safety = {
    hp_floor_pct         = 0.30,    -- pause offense when HP < 30%
    mp_floor_pct         = 0.15,    -- pause offense when MP < 15%
    danger_affs          = {        -- any of these affs = pause offense
      "paralysis", "sleep", "confusion",
    },
    abort_on_room_change = true,    -- abort execute scenario on room change
    abort_on_target_loss = true,    -- abort execute scenario on target leaving room
    deadman_ms           = 0,       -- 0 = disabled; >0 = auto-stop if no tick in N ms
  },

  -- ── Attack configuration ───────────────────────────────────────────────────
  attack = {
    -- Template placeholders: {target}, {venom1}, {venom2}
    -- {limb} only used in undercut (requires battleaxe equipped)
    templates = {
      dsl        = "dsl {target} {venom1} {venom2}",      -- inline venom; no limb arg
      undercut   = "undercut {target} {limb}",             -- battleaxe only; no venom arg
      raze       = "raze {target} rebounding",             -- must specify type (rebounding strip)
      razeslash  = "razeslash {target}",                   -- strips shield + jabs; no venom arg
      impale     = "impale {target}",
      disembowel = "disembowel {target}",
      bisect     = "bisect {target}",
    },
    default_template = "dsl",
    prep_limbs = { "left_leg", "right_leg", "torso" },   -- break order
    near_break_pct = 75,
    rewield_cmd = "wield scimitar scimitar",
  },

  -- ── Venom configuration ───────────────────────────────────────────────────
  venoms = {
    -- Primary lock path venoms (slot 1 and slot 2)
    lock_priority = {
      "kalmia",   -- asthma
      "gecko",    -- slickness
      "slike",    -- anorexia
      "curare",   -- paralysis
    },
    -- Kelp cycle to bypass slickness
    kelp_cycle = { "xentio", "prefarar" },
    -- Off-hand alternates
    off_priority = { "epteth", "kalmia" },
    -- Kelp-stack build: venoms to apply pre-execution to clog the herb channel.
    kelp_stack_priority     = { "kalmia", "vernalius", "xentio", "prefarar" },
    kelp_stack_target_count = 3,    -- how many kelp-cured affs before transitioning to execute
    -- Avoid repeating a confirmed aff for this many seconds
    repeat_avoid_s = 20,
  },

  -- ── Retaliation ───────────────────────────────────────────────────────────
  retaliation = {
    enabled            = false,
    lock_ms            = 8000,
    swap_debounce_ms   = 1500,
    ignore_non_players = true,
    restore_prev       = true,
  },

  -- ── Execute / finish ──────────────────────────────────────────────────────
  execute = {
    enabled              = true,
    cooldown_ms          = 1500,
    fallback_window_ms   = 6000,
    disembowel_timeout_ms = 2500,
  },

  -- ── Runelore / runeblade ──────────────────────────────────────────────────
  runelore = {
    auto_empower        = true,
    core_rune           = "pithakhan",
    config_runes        = { "kena", "sleizak", "inguz" },
    empower_priority    = { "kena", "inguz", "sleizak" },
    kena_mana_threshold = 0.40,
    -- Bisect: only available when core rune is hugalaz.
    -- When enabled, bisect replaces impale→disembowel once target HP drops below threshold.
    bisect_enabled      = false,
    bisect_hp_threshold = 0.20,   -- 20% target HP
    -- Runesmith steps
    step_delay_ms       = 800,
    -- Pith+Kena scenario phase settings
    kelp_phase_timeout_ms    = 30000,  -- give up on kelp phase after 30s
    pithakhan_drain_window_ms = 10000, -- window to assume mana is low after drain
    focus_cooldown_ms        = 3200,   -- how long after focus before balance returns
  },

  -- ── UI ────────────────────────────────────────────────────────────────────
  ui = {
    open_on_start = false,
    hud_enabled   = true,
    hud_refresh_s = 0.5,
    theme = {
      bg        = "#0b1020",
      header_bg = "#12203a",
      accent    = "#4a90d9",
      text      = "#c8d6e5",
      ok        = "#56c785",
      warn      = "#e8b84b",
      danger    = "#e05252",
    },
  },

  -- ── Persistence ───────────────────────────────────────────────────────────
  persistence = {
    enabled    = true,
    auto_load  = true,
  },

  -- ── Dragon combat ─────────────────────────────────────────────────────────
  dragon = {
    enabled               = true,
    breath_type           = "lightning",   -- Silver Dragon default
    mode                  = "devour",      -- "devour" | "breath_pressure"
    -- Setup upkeep
    auto_dragonarmour     = true,
    auto_summon_breath    = true,
    auto_becalm           = true,
    -- Devour estimator
    use_estimator         = true,
    devour_safe_threshold = 5.7,           -- seconds; start conservative
    -- Phase thresholds
    leg_prep_pct          = 70,            -- min leg damage_pct before TORSO_FOCUS
    torso_focus_pct       = 60,            -- min torso pct before devour window
    -- Room control
    control_block_dirs    = true,
    use_enmesh            = true,
    prefer_breathgust     = true,          -- EQ-based; use over tailsweep when possible
    prefer_tailsweep      = true,          -- BAL-based; fallback prone method
    -- Matchup overrides (class-specific config can override these at runtime)
    matchup_overrides     = {
      serpent = { use_breathstorm = true },
      sylvan  = { abort_in_grove  = true },
      druid   = { abort_in_grove  = true },
    },
    -- Attack command templates (used by _chooseDragonAction free-form path)
    templates = {
      blast       = "blast {target}",
      breathgust  = "breathgust {target}",
      breathstrip = "breathstrip {target}",
      block       = "block {direction}",
      rend        = "rend {target}",
      gut         = "gut {target}",
      bite        = "bite {target}",
      devour      = "devour {target}",
      becalm      = "becalm {target}",
      enmesh      = "enmesh {target}",
      tailsmash   = "tailsmash {target}",
    },
  },
}

-- ── Config module ─────────────────────────────────────────────────────────────

local cfg = {}
Silverfury.config = cfg

cfg._data = {}

-- Deep-copy defaults into _data, then overlay persisted values.
local function deepcopy(src)
  if type(src) ~= "table" then return src end
  local t = {}
  for k, v in pairs(src) do t[k] = deepcopy(v) end
  return t
end

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
end

-- Initialise config from defaults.
function cfg.init()
  cfg._data = deepcopy(defaults)
end

-- Return value at a dot-path, e.g. cfg.get("combat.anti_spam_ms")
function cfg.get(path)
  local node = cfg._data
  for part in path:gmatch("[^%.]+") do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return node
end

-- Set value at dot-path.
function cfg.set(path, value)
  local parts = {}
  for p in path:gmatch("[^%.]+") do parts[#parts+1] = p end
  local node = cfg._data
  for i = 1, #parts - 1 do
    if type(node[parts[i]]) ~= "table" then
      node[parts[i]] = {}
    end
    node = node[parts[i]]
  end
  node[parts[#parts]] = value
end

-- ── Persistence ──────────────────────────────────────────────────────────────

local function savePath()
  return getMudletHomeDir() .. "/silverfury_config.lua"
end

function cfg.save()
  local ok, json = pcall(function() return yajl.to_string(cfg._data) end)
  if not ok then
    Silverfury.log.warn("config.save: JSON encode failed: " .. tostring(json))
    return false
  end
  local f, err = io.open(savePath(), "w")
  if not f then
    Silverfury.log.warn("config.save: cannot open file: " .. tostring(err))
    return false
  end
  f:write("return " .. json)
  f:close()
  Silverfury.log.info("Config saved to " .. savePath())
  return true
end

function cfg.load()
  local path = savePath()
  local f = io.open(path, "r")
  if not f then return false end
  local raw = f:read("*a")
  f:close()
  local fn, err = loadstring(raw)
  if not fn then
    Silverfury.log.warn("config.load: parse error: " .. tostring(err))
    return false
  end
  local ok, data = pcall(fn)
  if not ok or type(data) ~= "table" then
    Silverfury.log.warn("config.load: bad data")
    return false
  end
  merge(cfg._data, data)
  Silverfury.log.info("Config loaded from " .. path)
  return true
end

function cfg.exists()
  local f = io.open(savePath(), "r")
  if f then f:close() return true end
  return false
end
