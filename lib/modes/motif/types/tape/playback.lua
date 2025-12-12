-- playback.lua
-- Tape type: motif playback control
-- Part of lib/modes/motif/types/tape/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local TapePlayback = {}

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "TAPE_PLAYBACK",
    name = "Play",
    description = Descriptions.TAPE_PLAYBACK,
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()

    self.params = {
      { separator = true, title = "Pitch Offset" },
      { id = "lane_" .. lane_idx .. "_octave_offset", name = "Octave Offset" },
      { id = "lane_" .. lane_idx .. "_scale_degree_offset", name = "Degree Offset" },
      { separator = true, title = "Rhythm" },
      { id = "lane_" .. lane_idx .. "_speed" },
      { id = "lane_" .. lane_idx .. "_quantize" },
      { id = "lane_" .. lane_idx .. "_swing", arc_multi_float = {10, 5, 1} }
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  norns_ui.draw_default = function(self)
    screen.clear()

    if self.state.showing_description then
      NornsUI.draw_default(self)
      return
    end

    self:_draw_standard_ui()

    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local help_text
    if lane and lane.playing then
      help_text = "stop: hold"
    else
      help_text = "play: hold"
    end
    local width = screen.text_extents(help_text)

    if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "TAPE_PLAYBACK" then
      screen.level(15)
    else
      screen.level(2)
    end

    screen.move(64 - width/2, 46)
    screen.text(help_text)
    self:draw_footer()
    screen.update()
  end

  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TAPE_PLAYBACK",
    layout = {
      x = 1,
      y = 7,
      width = 1,
      height = 1
    }
  })

  grid_ui.draw = function(self, layers)
    if self:is_holding_long_press() then
      self:draw_keyboard_outline_highlight(layers)
    end

    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local brightness

    if lane and lane.playing then
      brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
    elseif _seeker.ui_state.get_current_section() == "TAPE_PLAYBACK" then
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
      _seeker.ui_state.set_current_section("TAPE_PLAYBACK")
      _seeker.ui_state.set_long_press_state(true, "TAPE_PLAYBACK")
      _seeker.screen_ui.set_needs_redraw()
    else
      if self:is_long_press(key_id) then
        local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
        if lane and lane.motif then
          if lane.playing then
            lane:stop()
          else
            lane:play()
          end
          _seeker.screen_ui.set_needs_redraw()
        end
      end

      _seeker.ui_state.set_long_press_state(false, nil)
      _seeker.screen_ui.set_needs_redraw()
      self:key_release(key_id)
    end
  end

  return grid_ui
end

function TapePlayback.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui()
  }

  return component
end

return TapePlayback
