-- perform.lua
-- Sampler motif performance controls
-- Thin wrapper around shared perform_engine

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")
local PerformEngine = include("lib/modes/motif/infrastructure/perform_engine")

local SamplerPerform = {}

local SECTION_ID = "SAMPLER_PERFORM"

local function get_param_prefix(lane_id)
  return "lane_" .. lane_id .. "_sampler_performance"
end

function SamplerPerform.get_velocity_multiplier(lane_id)
  return PerformEngine.get_velocity_multiplier(lane_id, get_param_prefix(lane_id))
end

function SamplerPerform.is_muted(lane_id)
  return PerformEngine.is_muted(lane_id, get_param_prefix(lane_id))
end

function SamplerPerform.is_active(lane_id)
  return PerformEngine.is_active(lane_id)
end

local function create_params()
  for i = 1, 8 do
    local prefix = get_param_prefix(i)
    local rebuild_callback = function()
      if _seeker and _seeker.sampler_type and _seeker.sampler_type.perform and _seeker.sampler_type.perform.screen then
        _seeker.sampler_type.perform.screen:rebuild_params()
      end
    end
    PerformEngine.create_params_for_lane(i, prefix, "LANE " .. i .. " SAMPLER PERFORMANCE", rebuild_callback)
  end
end

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = SECTION_ID,
    name = "Perform",
    description = Descriptions.SAMPLER_PERFORM,
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local prefix = get_param_prefix(lane_id)
    self.params = PerformEngine.build_param_table(lane_id, prefix)
  end

  norns_ui.draw_default = function(self)
    NornsUI.draw_default(self)

    if not self.state.showing_description then
      local lane_id = _seeker.ui_state.get_focused_lane()
      local prefix = get_param_prefix(lane_id)
      local mode = PerformEngine.get_mode(lane_id, prefix)
      local tooltip = string.lower(mode) .. ": hold"
      local width = screen.text_extents(tooltip)

      if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == SECTION_ID then
        screen.level(15)
      else
        screen.level(2)
      end

      screen.move(64 - width/2, 46)
      screen.text(tooltip)
    end

    screen.update()
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
    layout = {
      x = 4,
      y = 7,
      width = 1,
      height = 1
    }
  })

  grid_ui.draw = function(self, layers)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local brightness = GridConstants.BRIGHTNESS.LOW

    if PerformEngine.is_active(lane_id) then
      brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.HIGH - 3)
    elseif _seeker.ui_state.get_current_section() == SECTION_ID then
      brightness = GridConstants.BRIGHTNESS.FULL
    end

    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local key_id = string.format("%d,%d", x, y)
    local prefix = get_param_prefix(lane_id)

    if z == 1 then
      self:key_down(key_id)
      _seeker.ui_state.set_current_section(SECTION_ID)
      _seeker.ui_state.set_long_press_state(true, SECTION_ID)
      PerformEngine.set_active(lane_id, true)
      PerformEngine.start_effect(lane_id, prefix)
    else
      PerformEngine.stop_effect(lane_id, prefix)
      PerformEngine.set_active(lane_id, false)
      _seeker.ui_state.set_long_press_state(false, nil)
      self:key_release(key_id)
    end

    _seeker.screen_ui.set_needs_redraw()
  end

  return grid_ui
end

function SamplerPerform.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui(),
    is_muted = SamplerPerform.is_muted,
    is_active = SamplerPerform.is_active,
    get_velocity_multiplier = SamplerPerform.get_velocity_multiplier
  }
  create_params()

  return component
end

return SamplerPerform
