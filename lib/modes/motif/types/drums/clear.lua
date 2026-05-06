-- clear.lua
-- Drums: clear the focused lane's step pattern and motif

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local DrumsClear = {}

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "DRUMS_CLEAR",
    name = "Clear",
    description = "Hold to clear the drum pattern on this lane.",
    params = {}
  })
  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "DRUMS_CLEAR",
    layout = { x = 3, y = 7, width = 1, height = 1 }
  })

  grid_ui.draw = function(self, layers)
    local brightness
    if _seeker.ui_state.get_current_section() == "DRUMS_CLEAR" then
      brightness = GridConstants.BRIGHTNESS.FULL
    else
      brightness = GridConstants.BRIGHTNESS.LOW
    end
    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    local key_id = string.format("%d,%d", x, y)
    if z == 1 then
      self:key_down(key_id)
      _seeker.ui_state.set_current_section("DRUMS_CLEAR")
      _seeker.screen_ui.set_needs_redraw()
    else
      if self:is_long_press(key_id) then
        local lane_id = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[lane_id]
        if lane then
          lane:stop()
          lane.motif.events = {}
          lane.motif.duration = 0
          local StepGrid = include("lib/modes/motif/types/drums/step_grid")
          local step_data = StepGrid.get_steps(lane_id)
          for i = 1, #step_data do step_data[i] = false end
          _seeker.screen_ui.set_needs_redraw()
        end
      end
      self:key_release(key_id)
    end
  end

  return grid_ui
end

function DrumsClear.init()
  return { screen = create_screen_ui(), grid = create_grid_ui() }
end

return DrumsClear
