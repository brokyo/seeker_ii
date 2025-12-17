-- modals/waveform.lua
-- Waveform editor modal for sample chopping

local Base = include("lib/ui/components/modals/base")

local Waveform = {}

-- State keys this modal uses
Waveform.state_keys = {
  "hint",
  "waveform_peaks",
  "waveform_duration",
  "waveform_start",
  "waveform_stop",
  "waveform_view_start",
  "waveform_view_end",
  "waveform_pad",
  "waveform_lane",
  "waveform_filepath",
  "waveform_on_change",
  "waveform_on_reload",
  "waveform_selected",
  "waveform_reload_clock"
}

-- Time step sizes in seconds for each Arc ring (2=coarse, 3=medium, 4=fine)
local RING_STEP_SECONDS = {
  [2] = 1.0,    -- coarse: 1 second
  [3] = 0.1,    -- medium: 100ms
  [4] = 0.01    -- fine: 10ms
}

-- Debounce delay before reloading peaks after position change
local RELOAD_DEBOUNCE = 0.5

function Waveform.show(state, config)
  state.waveform_peaks = config.peaks or {}
  state.waveform_duration = config.duration or 1
  state.waveform_start = config.start_pos or 0
  state.waveform_stop = config.stop_pos or state.waveform_duration
  state.waveform_view_start = config.view_start or 0
  state.waveform_view_end = config.view_end or state.waveform_duration
  state.waveform_pad = config.pad or 1
  state.waveform_lane = config.lane or 1
  state.waveform_filepath = config.filepath
  state.waveform_on_change = config.on_change
  state.waveform_on_reload = config.on_reload
  state.waveform_selected = 1
  state.hint = config.hint or "e2 select  e3 adjust"
end

function Waveform.draw(state)
  local modal_x = Base.MODAL_MARGIN
  local modal_y = Base.MODAL_MARGIN
  local modal_width = Base.SCREEN_WIDTH - (Base.MODAL_MARGIN * 2)
  local modal_height = Base.SCREEN_HEIGHT - (Base.MODAL_MARGIN * 2)

  local peaks = state.waveform_peaks or {}
  local start_pos = state.waveform_start
  local stop_pos = state.waveform_stop
  local view_start = state.waveform_view_start
  local view_end = state.waveform_view_end
  local view_duration = view_end - view_start
  local pad = state.waveform_pad
  local selected = state.waveform_selected

  Base.draw_frame(modal_x, modal_y, modal_width, modal_height)

  -- Waveform area
  local wave_x = modal_x + Base.PADDING
  local wave_y = modal_y + 14
  local wave_width = modal_width - (Base.PADDING * 2)
  local wave_height = 24

  -- Waveform background
  screen.level(2)
  screen.rect(wave_x, wave_y, wave_width, wave_height)
  screen.fill()

  -- Center line
  local center_y = wave_y + wave_height / 2
  screen.level(3)
  screen.move(wave_x, center_y)
  screen.line(wave_x + wave_width, center_y)
  screen.stroke()

  -- Draw waveform peaks
  if #peaks > 0 then
    local half_height = wave_height / 2
    screen.level(8)
    for i, peak in ipairs(peaks) do
      local x = wave_x + ((i - 1) / #peaks) * wave_width
      local peak_height = peak * half_height
      if peak_height > 0 then
        screen.move(x, center_y - peak_height)
        screen.line(x, center_y + peak_height)
      end
    end
    screen.stroke()
  end

  -- Calculate marker positions
  local start_x = wave_x + ((start_pos - view_start) / view_duration) * wave_width
  local stop_x = wave_x + ((stop_pos - view_start) / view_duration) * wave_width

  -- Selected region highlight
  screen.level(4)
  screen.rect(start_x, wave_y, stop_x - start_x, wave_height)
  screen.fill()

  -- Re-draw waveform in selected region brighter
  if #peaks > 0 then
    local half_height = wave_height / 2
    screen.level(12)
    for i, peak in ipairs(peaks) do
      local x = wave_x + ((i - 1) / #peaks) * wave_width
      if x >= start_x and x <= stop_x then
        local peak_height = peak * half_height
        if peak_height > 0 then
          screen.move(x, center_y - peak_height)
          screen.line(x, center_y + peak_height)
        end
      end
    end
    screen.stroke()
  end

  -- Start marker
  screen.level(selected == 1 and 15 or 6)
  screen.move(start_x, wave_y)
  screen.line(start_x, wave_y + wave_height)
  screen.stroke()

  -- Stop marker
  screen.level(selected == 2 and 15 or 6)
  screen.move(stop_x, wave_y)
  screen.line(stop_x, wave_y + wave_height)
  screen.stroke()

  -- Marker labels
  screen.font_face(1)
  screen.font_size(8)

  -- Start label
  local start_label = string.format("%.2fs", start_pos)
  if selected == 1 then
    screen.level(15)
    local label_width = screen.text_extents(start_label)
    screen.rect(wave_x - 2, wave_y + wave_height + 1, label_width + 4, 10)
    screen.fill()
    screen.level(0)
  else
    screen.level(8)
  end
  screen.move(wave_x, wave_y + wave_height + 8)
  screen.text(start_label)

  -- Stop label
  local stop_label = string.format("%.2fs", stop_pos)
  local stop_label_width = screen.text_extents(stop_label)
  if selected == 2 then
    screen.level(15)
    screen.rect(wave_x + wave_width - stop_label_width - 2, wave_y + wave_height + 1, stop_label_width + 4, 10)
    screen.fill()
    screen.level(0)
  else
    screen.level(8)
  end
  screen.move(wave_x + wave_width - stop_label_width, wave_y + wave_height + 8)
  screen.text(stop_label)

  -- Title
  screen.level(10)
  local title = "PAD " .. pad
  screen.move(modal_x + modal_width / 2 - screen.text_extents(title) / 2, modal_y + 10)
  screen.text(title)

  Base.draw_hint(state.hint, modal_x, modal_y, modal_width, modal_height)
end

-- Adjust selected marker position (start/stop) and trigger debounced peak reload
function Waveform.adjust_selected(state, ring_number, delta)
  local step = RING_STEP_SECONDS[ring_number] or 0.1

  if state.waveform_selected == 1 then
    state.waveform_start = util.clamp(
      state.waveform_start + (delta * step),
      0,
      state.waveform_stop - 0.01
    )
  else
    state.waveform_stop = util.clamp(
      state.waveform_stop + (delta * step),
      state.waveform_start + 0.01,
      state.waveform_duration
    )
  end

  if state.waveform_on_change then
    state.waveform_on_change(state.waveform_start, state.waveform_stop)
  end

  -- Debounce reload
  if state.waveform_reload_clock then
    clock.cancel(state.waveform_reload_clock)
  end

  if state.waveform_on_reload then
    state.waveform_reload_clock = clock.run(function()
      clock.sleep(RELOAD_DEBOUNCE)
      state.waveform_on_reload(state.waveform_start, state.waveform_stop)
      state.waveform_reload_clock = nil
    end)
  end
end

function Waveform.handle_enc(state, n, d, source)
  if source == "arc" then
    if n == 1 then
      local new_sel = util.clamp(state.waveform_selected + util.round(d), 1, 2)
      state.waveform_selected = new_sel
      if _seeker.arc then _seeker.arc.update_waveform_display() end
      _seeker.screen_ui.set_needs_redraw()
      return true
    elseif n >= 2 and n <= 4 then
      Waveform.adjust_selected(state, n, d)
      if _seeker.arc then _seeker.arc.update_waveform_display() end
      _seeker.screen_ui.set_needs_redraw()
      return true
    end
  else
    if n == 2 then
      local new_sel = util.clamp(state.waveform_selected + util.round(d), 1, 2)
      state.waveform_selected = new_sel
      _seeker.screen_ui.set_needs_redraw()
      return true
    elseif n == 3 then
      Waveform.adjust_selected(state, 3, d)
      _seeker.screen_ui.set_needs_redraw()
      return true
    end
  end
  return true  -- Block all encoder input during waveform modal
end

-- Update chop data (when switching pads)
function Waveform.update_chop(state, config)
  state.waveform_start = config.start_pos or state.waveform_start
  state.waveform_stop = config.stop_pos or state.waveform_stop
  state.waveform_pad = config.pad or state.waveform_pad

  if config.peaks then
    state.waveform_peaks = config.peaks
  end
  if config.view_start then
    state.waveform_view_start = config.view_start
  end
  if config.view_end then
    state.waveform_view_end = config.view_end
  end
  if config.duration then
    state.waveform_duration = config.duration
  end
  if config.on_change then
    state.waveform_on_change = config.on_change
  end
end

-- Getters for external access (Arc display)
function Waveform.get_selected(state)
  return state.waveform_selected
end

function Waveform.set_selected(state, idx)
  state.waveform_selected = util.clamp(idx, 1, 2)
end

function Waveform.get_positions(state)
  return {
    start_pos = state.waveform_start,
    stop_pos = state.waveform_stop,
    duration = state.waveform_duration,
    pad = state.waveform_pad,
    lane = state.waveform_lane
  }
end

function Waveform.cleanup(state)
  if state.waveform_reload_clock then
    clock.cancel(state.waveform_reload_clock)
    state.waveform_reload_clock = nil
  end
  state.waveform_peaks = nil
  state.waveform_duration = 0
  state.waveform_start = 0
  state.waveform_stop = 0
  state.waveform_view_start = 0
  state.waveform_view_end = 0
  state.waveform_pad = 1
  state.waveform_lane = 1
  state.waveform_filepath = nil
  state.waveform_on_change = nil
  state.waveform_on_reload = nil
  state.waveform_selected = 1
  state.hint = nil
end

return Waveform
