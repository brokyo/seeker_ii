-- tuning.lua
-- Self-contained component for lane tuning control (octave and grid offset)
-- NOTE: Wraps existing lane params (keyboard_octave, grid_offset)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local Tuning = {}
Tuning.__index = Tuning

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "TUNING",
    name = "Tuning",
    description = "Octave and grid offset for this Lane",
    params = {}
  })

  -- Dynamic parameter rebuilding based on focused lane
  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()

    self.params = {
      { separator = true, title = "Lane " .. lane_idx .. " Tuning" },
      { id = "lane_" .. lane_idx .. "_keyboard_octave" },
      { id = "lane_" .. lane_idx .. "_grid_offset" }
    }

    -- Jump to last selected param (set by grid buttons)
    if self.jump_to_param then
      self.state.selected_index = self.jump_to_param
    end
  end

  -- Override enter to rebuild params for current lane
  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TUNING",
    layout = {
      x = 1,
      y = 2,
      width = 4,
      height = 1
    }
  })

  -- Layout for buttons
  local button_layout = {
    octave = {
      decrease = {x = 1, y = 2},
      increase = {x = 2, y = 2}
    },
    offset = {
      decrease = {x = 3, y = 2},
      increase = {x = 4, y = 2}
    }
  }

  -- Override draw
  grid_ui.draw = function(self, layers)
    local is_tuning_section = (_seeker.ui_state.get_current_section() == "TUNING")
    local brightness = is_tuning_section and GridConstants.BRIGHTNESS.HIGH or GridConstants.BRIGHTNESS.LOW

    -- Draw octave buttons (- dimmer, + brighter)
    layers.ui[button_layout.octave.decrease.x][button_layout.octave.decrease.y] = brightness - 2
    layers.ui[button_layout.octave.increase.x][button_layout.octave.increase.y] = brightness + 2

    -- Draw offset buttons (- dimmer, + brighter)
    layers.ui[button_layout.offset.decrease.x][button_layout.offset.decrease.y] = brightness - 2
    layers.ui[button_layout.offset.increase.x][button_layout.offset.increase.y] = brightness + 2
  end

  -- Override handle_key
  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local focused_lane = _seeker.ui_state.get_focused_lane()

      -- Handle octave controls
      if x == button_layout.octave.decrease.x and y == button_layout.octave.decrease.y then
        local current = params:get("lane_" .. focused_lane .. "_keyboard_octave")
        params:set("lane_" .. focused_lane .. "_keyboard_octave", math.max(1, current - 1))
        _seeker.tuning.screen.jump_to_param = 2 -- Octave param
      elseif x == button_layout.octave.increase.x and y == button_layout.octave.increase.y then
        local current = params:get("lane_" .. focused_lane .. "_keyboard_octave")
        params:set("lane_" .. focused_lane .. "_keyboard_octave", math.min(7, current + 1))
        _seeker.tuning.screen.jump_to_param = 2 -- Octave param

      -- Handle offset controls
      elseif x == button_layout.offset.decrease.x and y == button_layout.offset.decrease.y then
        local current = params:get("lane_" .. focused_lane .. "_grid_offset")
        params:set("lane_" .. focused_lane .. "_grid_offset", math.max(-8, current - 1))
        _seeker.tuning.screen.jump_to_param = 3 -- Offset param
      elseif x == button_layout.offset.increase.x and y == button_layout.offset.increase.y then
        local current = params:get("lane_" .. focused_lane .. "_grid_offset")
        params:set("lane_" .. focused_lane .. "_grid_offset", math.min(8, current + 1))
        _seeker.tuning.screen.jump_to_param = 3 -- Offset param
      end

      -- Switch to tuning section
      _seeker.ui_state.set_current_section("TUNING")

      -- Trigger UI updates
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

function Tuning.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui()
  }
  -- No params to create - we wrap existing lane params

  return component
end

return Tuning
