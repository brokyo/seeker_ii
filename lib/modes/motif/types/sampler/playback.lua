-- playback.lua
-- Sampler type: motif playback control
-- Part of lib/modes/motif/types/sampler/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local SamplerPlayback = {}
SamplerPlayback.__index = SamplerPlayback

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "SAMPLER_PLAYBACK",
    name = "Sampler Playback",
    description = "Control playback timing for sampler motifs.",
    params = {}
  })

  -- Dynamic parameter rebuilding based on focused lane
  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()

    -- Sampler doesn't use pitch offset (no MIDI notes)
    -- Focus on rhythm/timing controls
    self.params = {
      { separator = true, title = "Rhythm" },
      { id = "lane_" .. lane_idx .. "_speed" },
      { id = "lane_" .. lane_idx .. "_quantize" },
      { id = "lane_" .. lane_idx .. "_swing", arc_multi_float = {10, 5, 1} }
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
      help_text = "stop: hold grid key"
    else
      help_text = "play: hold grid key"
    end
    local width = screen.text_extents(help_text)

    -- Brighten text during long press
    if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "SAMPLER_PLAYBACK" then
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
    id = "SAMPLER_PLAYBACK",
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
      -- Pulsing bright when playing
      brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
    elseif _seeker.ui_state.get_current_section() == "SAMPLER_PLAYBACK" then
      brightness = GridConstants.BRIGHTNESS.FULL
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
      _seeker.ui_state.set_current_section("SAMPLER_PLAYBACK")
      _seeker.ui_state.set_long_press_state(true, "SAMPLER_PLAYBACK")
      _seeker.screen_ui.set_needs_redraw()
    else -- Key released
      -- If it was a long press, toggle play state
      if self:is_long_press(key_id) then
        local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
        if lane and lane.motif then
          if lane.playing then
            -- Stop playback and stop any playing samples
            lane:stop()
            if _seeker.sampler then
              for pad = 1, 16 do
                _seeker.sampler.stop_pad(lane.id, pad)
              end
            end
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

function SamplerPlayback.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui()
  }

  return component
end

return SamplerPlayback
