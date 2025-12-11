-- velocity.lua
-- Tape type velocity selector
-- Reuses global velocity params but with tape-specific section ID
-- Part of lib/modes/motif/types/tape/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local TapeVelocity = {}

-- Tape-specific velocity params
local function create_params()
  params:add_group("tape_velocity", "TAPE VELOCITY", 5)

  params:add_number("tape_velocity_1", "pp Velocity", 0, 127, 40)
  params:add_number("tape_velocity_2", "mp Velocity", 0, 127, 70)
  params:add_number("tape_velocity_3", "f Velocity", 0, 127, 100)
  params:add_number("tape_velocity_4", "ff Velocity", 0, 127, 127)

  params:add_number("tape_velocity_selected", "Selected", 1, 4, 3)
  params:set_action("tape_velocity_selected", function(value)
    if _seeker and _seeker.tape and _seeker.tape.velocity and _seeker.tape.velocity.screen then
      _seeker.tape.velocity.screen:rebuild_params()
    end
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)
end

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "TAPE_VELOCITY",
    name = "Note Velocity",
    description = "Control note loudness. Press grid keys to select level.",
    params = {
      { separator = true, title = "Velocity Levels" },
      { id = "tape_velocity_1" },
      { id = "tape_velocity_2" },
      { id = "tape_velocity_3" },
      { id = "tape_velocity_4" }
    }
  })

  -- Rebuild params to jump to selected velocity
  norns_ui.rebuild_params = function(self)
    local selected = params:get("tape_velocity_selected")

    self.params = {
      { separator = true, title = "Velocity Levels" },
      { id = "tape_velocity_1" },
      { id = "tape_velocity_2" },
      { id = "tape_velocity_3" },
      { id = "tape_velocity_4" }
    }

    -- Jump to selected velocity parameter
    self.state.selected_index = selected + 1 -- +1 for separator
  end

  -- Override enter to jump to selected
  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    original_enter(self)
    self:rebuild_params()
  end

  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TAPE_VELOCITY",
    layout = {
      x = 1,
      y = 3,
      width = 4,
      height = 1
    }
  })

  grid_ui.draw = function(self, layers)
    local is_velocity_section = (_seeker.ui_state.get_current_section() == "TAPE_VELOCITY")
    local selected = params:get("tape_velocity_selected")

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
      params:set("tape_velocity_selected", selected)

      _seeker.ui_state.set_current_section("TAPE_VELOCITY")
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

-- Helper function to get current velocity value
function TapeVelocity.get_current_velocity()
  local selected = params:get("tape_velocity_selected")
  return params:get("tape_velocity_" .. selected)
end

function TapeVelocity.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui(),
    get_current_velocity = TapeVelocity.get_current_velocity
  }
  create_params()

  return component
end

return TapeVelocity
