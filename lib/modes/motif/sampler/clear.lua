-- clear.lua
-- Sampler type: clear motif functionality
-- Part of lib/modes/motif/sampler/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local SamplerClear = {}
SamplerClear.__index = SamplerClear

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "SAMPLER_CLEAR",
    name = "Clear",
    description = "Hold to clear the recorded motif and reset to a blank canvas.",
    params = {
      { separator = true, title = "Clear Motif" }
    }
  })

  norns_ui.draw_default = function(self)
    NornsUI.draw_default(self)

    if not self.state.showing_description then
      local tooltip
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[focused_lane]

      if lane and lane.motif and #lane.motif.events > 0 then
        tooltip = "x: hold [clear]"
      else
        tooltip = "No motif to clear"
      end

      local width = screen.text_extents(tooltip)

      if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "SAMPLER_CLEAR" then
        screen.level(15)
      else
        screen.level(2)
      end

      screen.move(64 - width/2, 46)
      screen.text(tooltip)
    end

    screen.update()
  end

  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "SAMPLER_CLEAR",
    layout = {
      x = 3,
      y = 7,
      width = 1,
      height = 1
    },
    long_press_threshold = 1.5
  })

  -- Track button state for animation
  local button_pressed = false
  local button_press_time = nil

  local original_draw = grid_ui.draw
  grid_ui.draw = function(self, layers)
    original_draw(self, layers)

    if button_pressed and button_press_time then
      local press_duration = util.time() - button_press_time
      local threshold_reached = press_duration >= self.long_press_threshold

      local keyboard_brightness
      if threshold_reached then
        local time_since_threshold = press_duration - self.long_press_threshold
        local pulse_rate = 4
        local pulse_duration = 1 / pulse_rate
        local pulses_completed = time_since_threshold / pulse_duration

        if pulses_completed < 3 then
          local phase = (clock.get_beats() * pulse_rate) % 1
          local pulse = math.sin(phase * math.pi * 2) * 0.5 + 0.5
          keyboard_brightness = math.floor(GridConstants.BRIGHTNESS.MEDIUM + pulse * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.MEDIUM))
        else
          keyboard_brightness = GridConstants.BRIGHTNESS.FULL
        end
      else
        keyboard_brightness = GridConstants.BRIGHTNESS.MEDIUM
      end

      -- Illuminate sampler pad area (4x4 grid)
      local keyboard = {
        upper_left_x = 7,
        upper_left_y = 3,
        width = 4,
        height = 4
      }

      for x = keyboard.upper_left_x, keyboard.upper_left_x + keyboard.width - 1 do
        for y = keyboard.upper_left_y, keyboard.upper_left_y + keyboard.height - 1 do
          layers.response[x][y] = keyboard_brightness
        end
      end
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    local key_id = string.format("%d,%d", x, y)

    if z == 1 then
      self:key_down(key_id)
      button_pressed = true
      button_press_time = util.time()
      _seeker.ui_state.set_current_section("SAMPLER_CLEAR")
      _seeker.ui_state.set_long_press_state(true, "SAMPLER_CLEAR")
      _seeker.screen_ui.set_needs_redraw()
    else
      button_pressed = false
      button_press_time = nil

      if self:is_long_press(key_id) then
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[focused_lane]

        if lane and lane.motif and #lane.motif.events > 0 then
          -- Stop any playing samples
          if _seeker.sampler then
            for pad = 1, 16 do
              _seeker.sampler.stop_pad(focused_lane, pad)
            end
            -- Reset chops to genesis on clear
            _seeker.sampler.reset_lane_to_genesis(focused_lane)
          end

          lane:clear()

          -- Rebuild sampler create params
          if _seeker.sampler_create and _seeker.sampler_create.screen then
            _seeker.sampler_create.screen:rebuild_params()
          end
        end

        _seeker.screen_ui.set_needs_redraw()
      end

      _seeker.ui_state.set_long_press_state(false, nil)
      _seeker.screen_ui.set_needs_redraw()

      self:key_release(key_id)
    end
  end

  return grid_ui
end

function SamplerClear.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui()
  }

  return component
end

return SamplerClear
