-- grid_controls.lua
-- Bottom row buttons and stage nav for composer keyboard_mode integration.
-- Play (x=1,y=7), Smooth (x=2,y=7), Clear (x=3,y=7), Randomize (x=4,y=7).
-- Stage nav (x=1-4, y=2) sets stage count.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local GridControls = {}

local HOLD_THRESHOLD_RANDOMIZE = 1.5

---------------------------------------------------------------
-- Play button: tap = play/stop focused lane
---------------------------------------------------------------
local function create_play_grid()
  local grid_ui = GridUI.new({
    id = "COMPOSER_PLAY",
    layout = { x = 1, y = 7, width = 1, height = 1 }
  })

  grid_ui.draw = function(self, layers)
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local brightness
    if lane and lane.playing then
      brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
    else
      brightness = GridConstants.BRIGHTNESS.LOW
    end
    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    local key_id = string.format("%d,%d", x, y)
    if z == 1 then
      self:key_down(key_id)
    else
      if self:is_long_press(key_id) then
        local lane_id = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[lane_id]
        local Composer = _seeker.composer_mode.composer
        if lane.playing then
          lane:stop()
        else
          Composer.rebuild()
          lane:play({ quantize = true })
        end
        _seeker.screen_ui.set_needs_redraw()
      end
      self:key_release(key_id)
    end
  end

  return grid_ui
end

---------------------------------------------------------------
-- Smooth button: tap = trigger smooth voice leading
---------------------------------------------------------------
local function create_smooth_grid()
  local grid_ui = GridUI.new({
    id = "COMPOSER_SMOOTH",
    layout = { x = 2, y = 7, width = 1, height = 1 }
  })

  grid_ui.flash_until = nil

  grid_ui.draw = function(self, layers)
    local brightness
    if self.flash_until and util.time() < self.flash_until then
      brightness = GridConstants.BRIGHTNESS.FULL
    else
      brightness = GridConstants.BRIGHTNESS.LOW
    end
    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local Composer = _seeker.composer_mode.composer
      Composer.smooth()
      self.flash_until = util.time() + 0.3
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return grid_ui
end

---------------------------------------------------------------
-- Clear button: tap = clear degree overrides, hold = clear all + stop
---------------------------------------------------------------
local function create_clear_grid()
  local grid_ui = GridUI.new({
    id = "COMPOSER_CLEAR",
    layout = { x = 3, y = 7, width = 1, height = 1 }
  })

  grid_ui.draw = function(self, layers)
    local brightness = GridConstants.BRIGHTNESS.LOW
    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    local key_id = string.format("%d,%d", x, y)
    if z == 1 then
      self:key_down(key_id)
    else
      local lane_id = _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[lane_id]
      local Composer = _seeker.composer_mode.composer

      if self:is_long_press(key_id) then
        lane.composer_degree_overrides = {}
        lane.composer_spread_voices_overrides = {}
        lane.composer_rotation_overrides = {}
        lane.composer_gate_overrides = {}
        lane.composer_chord_len_overrides = {}
        lane.composer_strum_overrides = {}
        lane.composer_loops_overrides = {}
        lane.composer_notes_overrides = {}
        lane.composer_vel_min_overrides = {}
        lane.composer_vel_max_overrides = {}
        lane.composer_vel_stage_overrides = {}
        lane.composer_vel_tone_overrides = {}
        if lane.playing then lane:stop() end
      else
        lane.composer_degree_overrides = {}
        lane.composer_notes_overrides = {}
      end

      Composer.rebuild()
      _seeker.screen_ui.set_needs_redraw()
      self:key_release(key_id)
    end
  end

  return grid_ui
end

---------------------------------------------------------------
-- Randomize button: hold = randomize progression
---------------------------------------------------------------
local function create_perform_grid()
  local grid_ui = GridUI.new({
    id = "COMPOSER_PERFORM",
    layout = { x = 4, y = 7, width = 1, height = 1 }
  })

  grid_ui.draw = function(self, layers)
    local brightness = GridConstants.BRIGHTNESS.LOW

    local key_id = "4,7"
    local press = self.press_state.pressed_keys[key_id]
    if press then
      local elapsed = util.time() - press.start_time
      if elapsed > 0.3 then
        local progress = math.min((elapsed - 0.3) / (HOLD_THRESHOLD_RANDOMIZE - 0.3), 1)
        brightness = math.floor(GridConstants.BRIGHTNESS.LOW + progress * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.LOW))
      end
    end

    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    local key_id = string.format("%d,%d", x, y)
    if z == 1 then
      self:key_down(key_id)
      _seeker.hold_confirm.start({
        text = "randomizing...",
        threshold = HOLD_THRESHOLD_RANDOMIZE,
        on_confirm = function()
          local Composer = _seeker.composer_mode.composer
          Composer.randomize()
          _seeker.screen_ui.set_needs_redraw()
        end
      })
    else
      _seeker.hold_confirm.cancel()
      self:key_release(key_id)
    end
  end

  return grid_ui
end

---------------------------------------------------------------
-- Stage nav: buttons at x=1-6, y=2. Tap = set stage count.
---------------------------------------------------------------
local function create_stage_nav_grid()
  local grid_ui = GridUI.new({
    id = "COMPOSER_STAGE_NAV",
    layout = { x = 1, y = 2, width = 4, height = 1 }
  })

  grid_ui.contains = function(self, x, y)
    return y == 2 and x >= 1 and x <= 4
  end

  grid_ui.draw = function(self, layers)
    local num_stages = params:get("rc_composer_stages")
    for i = 1, 4 do
      local brightness
      if i <= num_stages then
        brightness = GridConstants.BRIGHTNESS.MEDIUM
      else
        brightness = GridConstants.BRIGHTNESS.LOW
      end
      layers.ui[i][2] = brightness
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 and y == 2 and x >= 1 and x <= 4 then
      params:set("rc_composer_stages", x)
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return grid_ui
end

---------------------------------------------------------------
-- Init: create all grid controls
---------------------------------------------------------------
function GridControls.init()
  return {
    playback = { grid = create_play_grid() },
    smooth = { grid = create_smooth_grid() },
    clear = { grid = create_clear_grid() },
    perform = { grid = create_perform_grid() },
    stage_nav = { grid = create_stage_nav_grid() },
  }
end

return GridControls
