-- tuning.lua
-- Tape keyboard tuning: octave up/down buttons with grid offset control
-- Part of lib/modes/motif/types/tape/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local TapeTuning = {}

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "TAPE_TUNING",
    name = "Keyboard Tuning",
    description = Descriptions.TAPE_TUNING,
    params = {}
  })

  -- Rebuild params to show current lane's tuning
  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()

    self.params = {
      { separator = true, title = "Tuning" },
      { id = "lane_" .. lane_idx .. "_keyboard_octave" },
      { id = "lane_" .. lane_idx .. "_grid_offset" }
    }
  end

  -- Override enter to build params for current lane
  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    original_enter(self)
    self:rebuild_params()
  end

  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TAPE_TUNING",
    layout = {
      x = 3,
      y = 3,
      width = 2,
      height = 1
    }
  })

  grid_ui.draw = function(self, layers)
    local is_tuning_section = (_seeker.ui_state.get_current_section() == "TAPE_TUNING")
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local octave = params:get("lane_" .. lane_idx .. "_keyboard_octave")

    -- Left button (octave down)
    local left_brightness
    if is_tuning_section then
      left_brightness = (octave > 1) and GridConstants.BRIGHTNESS.FULL or GridConstants.BRIGHTNESS.MEDIUM
    else
      left_brightness = GridConstants.BRIGHTNESS.LOW
    end
    layers.ui[self.layout.x][self.layout.y] = left_brightness

    -- Right button (octave up)
    local right_brightness
    if is_tuning_section then
      right_brightness = (octave < 7) and GridConstants.BRIGHTNESS.FULL or GridConstants.BRIGHTNESS.MEDIUM
    else
      right_brightness = GridConstants.BRIGHTNESS.LOW
    end
    layers.ui[self.layout.x + 1][self.layout.y] = right_brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local lane_idx = _seeker.ui_state.get_focused_lane()
      local current_octave = params:get("lane_" .. lane_idx .. "_keyboard_octave")

      if x == self.layout.x then
        -- Left button: octave down
        if current_octave > 1 then
          params:set("lane_" .. lane_idx .. "_keyboard_octave", current_octave - 1)
        end
      elseif x == self.layout.x + 1 then
        -- Right button: octave up
        if current_octave < 7 then
          params:set("lane_" .. lane_idx .. "_keyboard_octave", current_octave + 1)
        end
      end

      _seeker.ui_state.set_current_section("TAPE_TUNING")
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

function TapeTuning.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui()
  }

  return component
end

return TapeTuning
