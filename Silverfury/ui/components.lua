-- Silverfury/ui/components.lua
-- Reusable Geyser UI component builders.

Silverfury = Silverfury or {}
Silverfury.ui = Silverfury.ui or {}

local comp = {}
Silverfury.ui.components = comp

-- ── Theme shortcut ────────────────────────────────────────────────────────────

local function theme(key)
  return Silverfury.config.get("ui.theme." .. key) or "#ffffff"
end

-- ── Label factory ─────────────────────────────────────────────────────────────
-- Creates a styled Geyser.Label.
-- opts: { name, x, y, width, height, text, bg, fg, align, font_size, parent }
function comp.label(opts)
  local parent = opts.parent
  local lbl = Geyser.Label:new({
    name   = opts.name or ("sf_lbl_" .. tostring(math.random(100000))),
    x      = opts.x      or 0,
    y      = opts.y      or 0,
    width  = opts.width  or 100,
    height = opts.height or 20,
  }, parent)

  local bg   = opts.bg   or theme("bg")
  local fg   = opts.fg   or theme("text")
  local fs   = opts.font_size or 9
  local align = opts.align or "left"

  lbl:setStyleSheet(string.format(
    "background-color: %s; color: %s; font-size: %dpx; padding: 2px 4px; text-align: %s;",
    bg, fg, fs, align
  ))

  if opts.text then
    lbl:echo(opts.text)
  end

  return lbl
end

-- ── Button factory ────────────────────────────────────────────────────────────
-- Creates a clickable label button.
-- opts: same as label + { onclick }
function comp.button(opts)
  local lbl = comp.label(opts)
  lbl:setStyleSheet(string.format(
    "background-color: %s; color: %s; font-size: %dpx; padding: 2px 6px; "
    .. "border: 1px solid %s; border-radius: 3px; text-align: center;",
    opts.bg   or theme("header_bg"),
    opts.fg   or theme("accent"),
    opts.font_size or 9,
    theme("accent")
  ))
  if opts.onclick then
    lbl:setClickCallback(opts.onclick)
  end
  return lbl
end

-- ── Toggle button ─────────────────────────────────────────────────────────────
-- A button that changes appearance based on state (on/off).
-- opts: same as button + { state_fn, label_on, label_off, ontoggle }
function comp.toggle(opts)
  local lbl = Geyser.Label:new({
    name   = opts.name or ("sf_tog_" .. tostring(math.random(100000))),
    x      = opts.x      or 0,
    y      = opts.y      or 0,
    width  = opts.width  or 80,
    height = opts.height or 20,
  }, opts.parent)

  local function refresh()
    local on = opts.state_fn and opts.state_fn() or false
    local text  = on and (opts.label_on  or "ON")  or (opts.label_off or "OFF")
    local bg    = on and theme("ok") or theme("danger")
    lbl:setStyleSheet(string.format(
      "background-color: %s; color: #ffffff; font-size: 9px; "
      .. "border-radius: 3px; padding: 2px 6px; text-align: center;",
      bg
    ))
    lbl:echo(text)
  end

  lbl:setClickCallback(function()
    if opts.ontoggle then opts.ontoggle() end
    refresh()
  end)

  refresh()

  -- Expose refresh so external code can call it.
  lbl.refresh = refresh
  return lbl
end

-- ── MiniConsole factory ───────────────────────────────────────────────────────
-- opts: { name, x, y, width, height, parent, font_size }
function comp.console(opts)
  local mc = Geyser.MiniConsole:new({
    name      = opts.name or ("sf_mc_" .. tostring(math.random(100000))),
    x         = opts.x      or 0,
    y         = opts.y      or 0,
    width     = opts.width  or 200,
    height    = opts.height or 100,
    wrapWidth = opts.wrap   or 60,
    fontSize  = opts.font_size or 9,
    color     = theme("bg"),
  }, opts.parent)
  return mc
end

-- ── Section header label ──────────────────────────────────────────────────────
function comp.header(opts)
  opts.bg = opts.bg or theme("header_bg")
  opts.fg = opts.fg or theme("accent")
  opts.font_size = opts.font_size or 9
  return comp.label(opts)
end

-- ── Separator line ────────────────────────────────────────────────────────────
function comp.separator(opts)
  opts.height = opts.height or 1
  opts.bg = theme("accent")
  return comp.label(opts)
end
