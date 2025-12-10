-- velocity.lua
-- Sampler type: velocity/amplitude control for pad triggers
-- Part of lib/modes/motif/types/sampler/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local SamplerVelocity = {}
SamplerVelocity.__index = SamplerVelocity

-- Velocity labels (maps to sample amplitude)
local VELOCITY_LABELS = {"soft", "med", "loud", "max"}

local function create_params()
  params:add_group("sampler_velocity", "SAMPLER VELOCITY", 5)

  params:add_number("sampler_velocity_1", "Soft Level", 0, 127, 40)
  params:add_number("sampler_velocity_2", "Medium Level", 0, 127, 70)
  params:add_number("sampler_velocity_3", "Loud Level", 0, 127, 100)
  params:add_number("sampler_velocity_4", "Max Level", 0, 127, 127)

  params:add_number("sampler_velocity_selected", "Selected", 1, 4, 3)
  params:set_action("sampler_velocity_selected", function(value)
    if _seeker and _seeker.sampler_velocity and _seeker.sampler_velocity.screen then
      _seeker.sampler_velocity.screen:rebuild_params()
    end
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)
end

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "SAMPLER_VELOCITY",
    name = "Sample Amplitude",
    description = "Control sample playback amplitude. Press grid keys to select level.",
    params = {
      { separator = true, title = "Amplitude Levels" },
      { id = "sampler_velocity_1" },
      { id = "sampler_velocity_2" },
      { id = "sampler_velocity_3" },
      { id = "sampler_velocity_4" }
    }
  })

  norns_ui.rebuild_params = function(self)
    local selected = params:get("sampler_velocity_selected")

    self.params = {
      { separator = true, title = "Amplitude Levels" },
      { id = "sampler_velocity_1" },
      { id = "sampler_velocity_2" },
      { id = "sampler_velocity_3" },
      { id = "sampler_velocity_4" }
    }

    -- Jump to selected parameter
    self.state.selected_index = selected + 1
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    original_enter(self)
    self:rebuild_params()
  end

  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "SAMPLER_VELOCITY",
    layout = {
      x = 1,
      y = 3,
      width = 4,
      height = 1
    }
  })

  grid_ui.draw = function(self, layers)
    local is_velocity_section = (_seeker.ui_state.get_current_section() == "SAMPLER_VELOCITY")
    local selected = params:get("sampler_velocity_selected")

    for i = 0, self.layout.width - 1 do
      local x = self.layout.x + i
      local is_selected = (i + 1 == selected)
      local brightness = GridConstants.BRIGHTNESS.UI.NORMAL

      if is_velocity_section then
        if is_selected then
          brightness = GridConstants.BRIGHTNESS.FULL
        else
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        end
      else
        if is_selected then
          brightness = GridConstants.BRIGHTNESS.HIGH
        else
          brightness = GridConstants.BRIGHTNESS.LOW
        end
      end

      layers.ui[x][self.layout.y] = brightness
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local selected = (x - self.layout.x) + 1
      params:set("sampler_velocity_selected", selected)

      _seeker.ui_state.set_current_section("SAMPLER_VELOCITY")

      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

-- Helper function to get current velocity value
function SamplerVelocity.get_current_velocity()
  local selected = params:get("sampler_velocity_selected")
  return params:get("sampler_velocity_" .. selected)
end

function SamplerVelocity.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui(),
    get_current_velocity = SamplerVelocity.get_current_velocity
  }
  create_params()

  return component
end

return SamplerVelocity
