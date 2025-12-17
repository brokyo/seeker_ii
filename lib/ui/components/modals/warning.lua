-- modals/warning.lua
-- Auto-dismissing warning modal

local Base = include("lib/ui/components/modals/base")

local Warning = {}

-- State keys this modal uses
Warning.state_keys = {
  "body",
  "warning_clock_id"
}

function Warning.show(state, config, dismiss_callback)
  -- Cancel any existing warning timer
  if state.warning_clock_id then
    clock.cancel(state.warning_clock_id)
    state.warning_clock_id = nil
  end

  state.body = config.body or ""

  -- Auto-dismiss after timeout
  local timeout_sec = (config.timeout_ms or 2000) / 1000
  state.warning_clock_id = clock.run(function()
    clock.sleep(timeout_sec)
    dismiss_callback()
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)
end

function Warning.draw(state)
  local modal_x = 10
  local modal_y = 18
  local modal_width = Base.SCREEN_WIDTH - 20
  local modal_height = 28

  Base.draw_frame(modal_x, modal_y, modal_width, modal_height)

  -- Warning text (centered)
  screen.level(15)
  screen.font_face(Base.FONTS.STATUS)
  screen.font_size(Base.SIZES.STATUS)
  local text_width = screen.text_extents(state.body)
  screen.move(Base.SCREEN_WIDTH / 2 - text_width / 2, modal_y + modal_height / 2 + Base.SIZES.STATUS / 3)
  screen.text(state.body)

  Base.reset_font()
end

function Warning.cleanup(state)
  if state.warning_clock_id then
    clock.cancel(state.warning_clock_id)
    state.warning_clock_id = nil
  end
  state.body = nil
end

return Warning
