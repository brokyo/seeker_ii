-- modals/recording.lua
-- Live waveform recording visualization modal

local Base = include("lib/ui/components/modals/base")

local Recording = {}

-- State keys this modal uses
Recording.state_keys = {
  "hint",
  "recording_data",
  "recording_output"
}

function Recording.show(state, config)
  state.recording_data = config.get_data
  state.recording_output = config.output_num
  state.hint = config.hint or "k2/k3 stop"
end

function Recording.draw(state)
  local modal_x = Base.MODAL_MARGIN
  local modal_y = Base.MODAL_MARGIN
  local modal_width = Base.SCREEN_WIDTH - (Base.MODAL_MARGIN * 2)
  local modal_height = Base.SCREEN_HEIGHT - (Base.MODAL_MARGIN * 2)

  -- Get live data from callback
  local info = state.recording_data and state.recording_data() or {data = {}, voltage = 0, min = -10, max = 10}
  local data = info.data or {}
  local current_voltage = info.voltage or 0
  local v_min = info.min or -10
  local v_max = info.max or 10

  Base.draw_frame(modal_x, modal_y, modal_width, modal_height)

  -- Waveform area
  local wave_x = modal_x + Base.PADDING
  local wave_y = modal_y + 12
  local wave_width = modal_width - (Base.PADDING * 2) - 24
  local wave_height = modal_height - 24

  -- Draw zero line
  local zero_y = wave_y + wave_height * (v_max / (v_max - v_min))
  screen.level(2)
  screen.move(wave_x, zero_y)
  screen.line(wave_x + wave_width, zero_y)
  screen.stroke()

  -- Draw waveform from recorded data
  if #data > 1 then
    local max_points = wave_width
    local start_idx = math.max(1, #data - max_points + 1)
    local points_to_draw = math.min(#data, max_points)

    screen.level(8)
    for i = 1, points_to_draw do
      local data_idx = start_idx + i - 1
      local v = data[data_idx]
      local x = wave_x + (i - 1)
      local y = wave_y + wave_height * ((v_max - v) / (v_max - v_min))
      y = util.clamp(y, wave_y, wave_y + wave_height)

      if i == 1 then
        screen.move(x, y)
      else
        screen.line(x, y)
      end
    end
    screen.stroke()
  end

  -- Draw current voltage indicator
  local current_y = wave_y + wave_height * ((v_max - current_voltage) / (v_max - v_min))
  current_y = util.clamp(current_y, wave_y, wave_y + wave_height)
  screen.level(15)
  screen.circle(wave_x + wave_width + 4, current_y, 2)
  screen.fill()

  -- Voltage text
  screen.level(12)
  screen.font_face(1)
  screen.font_size(8)
  local voltage_text = string.format("%.1fv", current_voltage)
  screen.move(wave_x + wave_width + 8, current_y + 3)
  screen.text(voltage_text)

  -- Title
  screen.level(10)
  local title = "RECORDING"
  screen.move(modal_x + modal_width / 2 - screen.text_extents(title) / 2, modal_y + 8)
  screen.text(title)

  Base.draw_hint(state.hint, modal_x, modal_y, modal_width, modal_height)
end

function Recording.cleanup(state)
  state.recording_data = nil
  state.recording_output = nil
  state.hint = nil
end

return Recording
