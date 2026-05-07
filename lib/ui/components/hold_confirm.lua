-- hold_confirm.lua
-- Full-screen hold-to-confirm overlay with animated progress bar.
-- Any module can trigger: start({text, threshold, on_confirm}), cancel on release.
-- Screen draw priority (highest first): screensaver > modal > hold_confirm > section.

local Base = include("lib/ui/components/modals/base")

local HoldConfirm = {}

-- Overlay stays hidden for DISPLAY_DELAY seconds so quick taps never flash the screen.
-- Threshold is the visible progress duration after the overlay appears.
-- Total hold time = DISPLAY_DELAY + threshold.
local DISPLAY_DELAY = 0.4

local state = {
  active = false,       -- true once display delay elapses (controls drawing)
  pending = false,      -- true immediately on start (controls cancel cleanup)
  text = "",
  threshold = 1.0,
  display_time = nil,   -- when overlay became visible (progress bar starts from here)
  on_confirm = nil,
  confirm_clock = nil,
  display_clock = nil,
  confirmed_at = nil,
  flash_duration = 0.3,
}

function HoldConfirm.start(config)
  -- Cancel any existing hold first
  HoldConfirm.cancel()

  state.pending = true
  state.text = config.text or ""
  state.threshold = config.threshold or 1.0
  state.on_confirm = config.on_confirm
  state.confirmed_at = nil
  state.display_time = nil

  -- Delay the screen takeover so taps don't flash
  state.display_clock = clock.run(function()
    clock.sleep(DISPLAY_DELAY)
    if not state.pending then return end
    state.active = true
    state.display_time = util.time()
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
  end)

  -- Confirm fires after display delay + visible threshold
  state.confirm_clock = clock.run(function()
    clock.sleep(DISPLAY_DELAY + state.threshold)
    if not state.pending then return end
    state.active = true
    if state.on_confirm then state.on_confirm() end
    state.confirmed_at = util.time()
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    -- Hold flash briefly, then auto-clear
    clock.sleep(state.flash_duration)
    HoldConfirm._clear()
  end)
end

function HoldConfirm.cancel()
  if state.confirm_clock then
    clock.cancel(state.confirm_clock)
    state.confirm_clock = nil
  end
  if state.display_clock then
    clock.cancel(state.display_clock)
    state.display_clock = nil
  end
  HoldConfirm._clear()
end

function HoldConfirm._clear()
  state.active = false
  state.pending = false
  state.text = ""
  state.display_time = nil
  state.on_confirm = nil
  state.confirm_clock = nil
  state.display_clock = nil
  state.confirmed_at = nil
  if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

function HoldConfirm.is_active()
  return state.active
end

function HoldConfirm.draw()
  if not state.active then return end

  -- Modal frame: centered box
  local modal_x = 10
  local modal_y = 16
  local modal_width = Base.SCREEN_WIDTH - 20
  local modal_height = 32
  Base.draw_frame(modal_x, modal_y, modal_width, modal_height)

  -- Centered text
  local text_level = state.confirmed_at and 15 or 12
  screen.level(text_level)
  screen.font_face(1)
  screen.font_size(8)
  local text_width = screen.text_extents(state.text)
  screen.move(Base.SCREEN_WIDTH / 2 - text_width / 2, modal_y + 16)
  screen.text(state.text)

  -- Progress bar
  local bar_x = modal_x + Base.PADDING
  local bar_y = modal_y + 22
  local bar_width = modal_width - Base.PADDING * 2
  local bar_height = 4

  -- Background track
  screen.level(2)
  screen.rect(bar_x, bar_y, bar_width, bar_height)
  screen.fill()

  -- Fill proportional to time since overlay appeared
  local progress = 1
  if not state.confirmed_at and state.display_time then
    local elapsed = util.time() - state.display_time
    progress = math.min(elapsed / state.threshold, 1)
  end
  screen.level(12)
  screen.rect(bar_x, bar_y, math.floor(bar_width * progress), bar_height)
  screen.fill()

  Base.reset_font()
end

return HoldConfirm
