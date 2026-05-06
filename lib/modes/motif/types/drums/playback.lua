-- playback.lua
-- Drums: play/stop toggle for the focused lane

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local DrumsPlayback = {}

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "DRUMS_PLAYBACK",
    name = "Play",
    description = "Hold to play or stop the focused drum lane.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    self.params = {
      { separator = true, title = "Rhythm" },
      { id = "lane_" .. lane_idx .. "_speed" },
      { id = "lane_" .. lane_idx .. "_swing", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_idx .. "_offset", arc_multi_float = {1, 0.25, 0.125} }
    }
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
    id = "DRUMS_PLAYBACK",
    layout = { x = 1, y = 7, width = 1, height = 1 }
  })

  grid_ui.draw = function(self, layers)
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local brightness
    if lane and lane.playing then
      brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
    elseif _seeker.ui_state.get_current_section() == "DRUMS_PLAYBACK" then
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
      _seeker.ui_state.set_current_section("DRUMS_PLAYBACK")
      _seeker.ui_state.set_long_press_state(true, "DRUMS_PLAYBACK")
      _seeker.screen_ui.set_needs_redraw()
    else
      if self:is_long_press(key_id) then
        local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
        if lane and lane.motif then
          if lane.playing then lane:stop() else lane:play() end
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

function DrumsPlayback.init()
  return { screen = create_screen_ui(), grid = create_grid_ui() }
end

return DrumsPlayback
