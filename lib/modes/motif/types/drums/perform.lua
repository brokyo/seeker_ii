-- perform.lua
-- Drums: performance effects via shared PerformEngine

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local PerformEngine = include("lib/modes/motif/infrastructure/perform_engine")
local LaneMap = include("lib/lanes/lane_map")

local DrumsPerform = {}

local SECTION_ID = "DRUMS_PERFORM"

local function get_param_prefix(lane_id)
  return "lane_" .. lane_id .. "_drums_performance"
end

function DrumsPerform.get_velocity_multiplier(lane_id)
  return PerformEngine.get_velocity_multiplier(lane_id, get_param_prefix(lane_id))
end

function DrumsPerform.is_muted(lane_id)
  return PerformEngine.is_muted(lane_id, get_param_prefix(lane_id))
end

function DrumsPerform.is_active(lane_id)
  return PerformEngine.is_active(lane_id)
end

local function create_params()
  for _, i in ipairs(LaneMap.lanes_for_mode("drums")) do
    local prefix = get_param_prefix(i)
    local rebuild_callback = function()
      if _seeker and _seeker.drums_type and _seeker.drums_type.perform and _seeker.drums_type.perform.screen then
        _seeker.drums_type.perform.screen:rebuild_params()
      end
    end
    PerformEngine.create_params_for_lane(i, prefix, "LANE " .. i .. " DRUMS PERFORMANCE", rebuild_callback)
  end
end

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = SECTION_ID,
    name = "Perform",
    description = "Performance effects for the focused drum lane.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local prefix = get_param_prefix(lane_id)
    self.params = PerformEngine.get_ui_params(prefix)
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = SECTION_ID,
    layout = { x = 4, y = 7, width = 1, height = 1 }
  })

  grid_ui.draw = function(self, layers)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local is_active = DrumsPerform.is_active(lane_id)
    local brightness
    if is_active then
      brightness = GridConstants.BRIGHTNESS.FULL
    elseif _seeker.ui_state.get_current_section() == SECTION_ID then
      brightness = GridConstants.BRIGHTNESS.MEDIUM
    else
      brightness = GridConstants.BRIGHTNESS.LOW
    end
    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    local key_id = string.format("%d,%d", x, y)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local prefix = get_param_prefix(lane_id)

    if z == 1 then
      self:key_down(key_id)
      _seeker.ui_state.set_current_section(SECTION_ID)
      PerformEngine.start_effect(lane_id, prefix)
      _seeker.screen_ui.set_needs_redraw()
    else
      PerformEngine.stop_effect(lane_id, prefix)
      self:key_release(key_id)
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return grid_ui
end

function DrumsPerform.init()
  create_params()
  return { screen = create_screen_ui(), grid = create_grid_ui() }
end

return DrumsPerform
