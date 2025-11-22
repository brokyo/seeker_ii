-- motif_playback.lua
-- Self-contained component for motif playback control
-- NOTE: This wraps existing lane params (playback_offset, scale_degree_offset, speed, quantize)
-- ARCHITECTURAL DEBT: Playback config arguably belongs to Motif object, not Lane
-- See roadmap.md for refactoring discussion

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local MotifPlayback = {}
MotifPlayback.__index = MotifPlayback

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "MOTIF",
    name = "Motif Playback",
    description = "Configure motifs created in generate or record. Hold grid to start and stop playback.",
    params = {}
  })

  -- Dynamic parameter rebuilding based on focused lane
  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()

    self.params = {
      { separator = true, title = "Playback Config" },
      { id = "lane_" .. lane_idx .. "_playback_offset" },
      { id = "lane_" .. lane_idx .. "_scale_degree_offset" },
      { id = "lane_" .. lane_idx .. "_speed" },
      { id = "lane_" .. lane_idx .. "_quantize" }
    }
  end

  -- Override enter to rebuild params for current lane
  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  -- Override draw to add help text
  norns_ui.draw_default = function(self)
    screen.clear()

    -- Check if showing description
    if self.state.showing_description then
      NornsUI.draw_default(self)
      return
    end

    -- Draw parameters
    self:_draw_standard_ui()

    -- Draw help text
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local help_text
    if lane and lane.playing then
      help_text = "⏹: hold grid key"
    else
      help_text = "⏵: hold grid key"
    end
    local width = screen.text_extents(help_text)

    -- Brighten text during long press
    if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "MOTIF" then
      screen.level(15)
    else
      screen.level(2)
    end

    screen.move(64 - width/2, 46)
    screen.text(help_text)

    -- Draw footer
    self:draw_footer()

    screen.update()
  end

  return norns_ui
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "MOTIF",
    layout = {
      x = 1,
      y = 7,
      width = 1,
      height = 1
    }
  })

  -- Override draw
  grid_ui.draw = function(self, layers)
    -- Draw keyboard outline during long press
    if self:is_holding_long_press() then
      self:draw_keyboard_outline_highlight(layers)
    end

    -- Draw button with brightness logic
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local brightness

    if lane and lane.playing then
      -- Pulsing bright when playing, regardless of section
      brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
    elseif _seeker.ui_state.get_current_section() == "MOTIF" then
      brightness = GridConstants.BRIGHTNESS.FULL
    elseif _seeker.ui_state.get_current_section() == "GENERATE" or
           _seeker.ui_state.get_current_section() == "RECORDING" or
           _seeker.ui_state.get_current_section() == "OVERDUB" then
      brightness = GridConstants.BRIGHTNESS.MEDIUM
    else
      brightness = GridConstants.BRIGHTNESS.LOW
    end

    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  -- Override handle_key
  grid_ui.handle_key = function(self, x, y, z)
    local key_id = string.format("%d,%d", x, y)

    if z == 1 then -- Key pressed
      self:key_down(key_id)
      _seeker.ui_state.set_current_section("MOTIF")
      _seeker.ui_state.set_long_press_state(true, "MOTIF")
      _seeker.screen_ui.set_needs_redraw()
    else -- Key released
      -- If it was a long press, toggle play state
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

      -- Always clear long press state on release
      _seeker.ui_state.set_long_press_state(false, nil)
      _seeker.screen_ui.set_needs_redraw()

      self:key_release(key_id)
    end
  end

  return grid_ui
end

function MotifPlayback.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui()
  }
  -- No params to create - we wrap existing lane params

  return component
end

return MotifPlayback
