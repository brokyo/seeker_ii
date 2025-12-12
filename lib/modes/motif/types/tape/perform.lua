-- perform.lua
-- Hold-to-activate performance controls: Mute, Accent, Soft
-- Tap to navigate to screen, hold to activate selected mode
-- Part of lib/modes/motif/types/tape/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local TapePerform = {}

-- Performance modes
local MODE_MUTE = 1
local MODE_ACCENT = 2
local MODE_SOFT = 3

local mode_names = {"Mute", "Accent", "Soft"}

-- State per lane (shared with global performance system)
local lane_state = {}

local function get_lane_state(lane_id)
  if not lane_state[lane_id] then
    lane_state[lane_id] = {
      active = false,
      activation_beat = 0
    }
  end
  return lane_state[lane_id]
end

-- Returns velocity multiplier based on active performance mode and slew progress
function TapePerform.get_velocity_multiplier(lane_id)
  local state = get_lane_state(lane_id)
  if not state.active then
    return 1.0
  end

  local mode = params:get("lane_" .. lane_id .. "_tape_performance_mode")
  local target = 1.0
  local slew_time = 0

  if mode == MODE_MUTE then
    target = 0.0
    slew_time = params:get("lane_" .. lane_id .. "_tape_performance_mute_slew")
  elseif mode == MODE_ACCENT then
    target = params:get("lane_" .. lane_id .. "_tape_performance_accent_amount")
    slew_time = params:get("lane_" .. lane_id .. "_tape_performance_slew")
  elseif mode == MODE_SOFT then
    target = params:get("lane_" .. lane_id .. "_tape_performance_soft_amount")
    slew_time = params:get("lane_" .. lane_id .. "_tape_performance_slew")
  end

  if slew_time <= 0 then
    return target
  end

  local elapsed = clock.get_beat_sec() * (clock.get_beats() - state.activation_beat)
  local progress = math.min(1.0, elapsed / slew_time)
  return 1.0 + (target - 1.0) * progress
end

function TapePerform.is_muted(lane_id)
  local state = get_lane_state(lane_id)
  local mode = params:get("lane_" .. lane_id .. "_tape_performance_mode")
  return state.active and mode == MODE_MUTE
end

local function set_active(lane_id, active)
  local state = get_lane_state(lane_id)
  state.active = active
  if active then
    state.activation_beat = clock.get_beats()
  end
  if _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

function TapePerform.is_active(lane_id)
  local state = get_lane_state(lane_id)
  return state.active
end

local function create_params()
  for i = 1, 8 do
    params:add_group("lane_" .. i .. "_tape_performance", "LANE " .. i .. " TAPE PERFORMANCE", 5)

    params:add_option("lane_" .. i .. "_tape_performance_mode", "Mode", mode_names, MODE_MUTE)
    params:set_action("lane_" .. i .. "_tape_performance_mode", function(value)
      if _seeker and _seeker.tape and _seeker.tape.perform and _seeker.tape.perform.screen then
        _seeker.tape.perform.screen:rebuild_params()
      end
      if _seeker and _seeker.screen_ui then
        _seeker.screen_ui.set_needs_redraw()
      end
    end)

    params:add_control("lane_" .. i .. "_tape_performance_accent_amount", "Accent Amount",
      controlspec.new(1.0, 2.0, 'lin', 0.1, 1.5, "x"))

    params:add_control("lane_" .. i .. "_tape_performance_soft_amount", "Soft Amount",
      controlspec.new(0.1, 1.0, 'lin', 0.1, 0.5, "x"))

    params:add_control("lane_" .. i .. "_tape_performance_slew", "Slew Time",
      controlspec.new(0.0, 5.0, 'lin', 0.01, 0.0, "s"))

    params:add_control("lane_" .. i .. "_tape_performance_mute_slew", "Mute Slew",
      controlspec.new(0.0, 5.0, 'lin', 0.01, 0.0, "s"))
  end
end

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "TAPE_PERFORM",
    name = "Perform",
    description = Descriptions.TAPE_PERFORM,
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local mode = params:get("lane_" .. lane_id .. "_tape_performance_mode")

    local param_table = {
      { separator = true, title = "Performance" },
      { id = "lane_" .. lane_id .. "_tape_performance_mode" },
    }

    if mode == MODE_MUTE then
      table.insert(param_table, { id = "lane_" .. lane_id .. "_tape_performance_mute_slew", arc_multi_float = {1.0, 0.1, 0.01} })
    elseif mode == MODE_ACCENT then
      table.insert(param_table, { id = "lane_" .. lane_id .. "_tape_performance_accent_amount", arc_multi_float = {0.1, 0.05, 0.01} })
      table.insert(param_table, { id = "lane_" .. lane_id .. "_tape_performance_slew", arc_multi_float = {1.0, 0.1, 0.01} })
    elseif mode == MODE_SOFT then
      table.insert(param_table, { id = "lane_" .. lane_id .. "_tape_performance_soft_amount", arc_multi_float = {0.1, 0.05, 0.01} })
      table.insert(param_table, { id = "lane_" .. lane_id .. "_tape_performance_slew", arc_multi_float = {1.0, 0.1, 0.01} })
    end

    self.params = param_table
  end

  norns_ui.draw_default = function(self)
    NornsUI.draw_default(self)

    if not self.state.showing_description then
      local lane_id = _seeker.ui_state.get_focused_lane()
      local mode = params:get("lane_" .. lane_id .. "_tape_performance_mode")
      local mode_name = ({"mute", "accent", "soft"})[mode]
      local tooltip = mode_name .. ": hold"
      local width = screen.text_extents(tooltip)

      if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "TAPE_PERFORM" then
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
    id = "TAPE_PERFORM",
    layout = {
      x = 4,
      y = 7,
      width = 1,
      height = 1
    }
  })

  grid_ui.draw = function(self, layers)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local state = get_lane_state(lane_id)
    local brightness = GridConstants.BRIGHTNESS.LOW

    if state.active then
      brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.HIGH - 3)
    elseif _seeker.ui_state.get_current_section() == "TAPE_PERFORM" then
      brightness = GridConstants.BRIGHTNESS.FULL
    end

    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local key_id = string.format("%d,%d", x, y)

    if z == 1 then
      self:key_down(key_id)
      _seeker.ui_state.set_current_section("TAPE_PERFORM")
      _seeker.ui_state.set_long_press_state(true, "TAPE_PERFORM")
      set_active(lane_id, true)
    else
      set_active(lane_id, false)

      _seeker.ui_state.set_long_press_state(false, nil)
      self:key_release(key_id)
    end

    _seeker.screen_ui.set_needs_redraw()
  end

  return grid_ui
end

function TapePerform.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui(),
    is_muted = TapePerform.is_muted,
    is_active = TapePerform.is_active,
    get_velocity_multiplier = TapePerform.get_velocity_multiplier
  }
  create_params()

  return component
end

return TapePerform
