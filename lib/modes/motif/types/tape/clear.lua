-- clear.lua
-- Tape type: clear motif control
-- Long press to clear the current lane's motif
-- Part of lib/modes/motif/types/tape/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local TapeClear = {}

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "TAPE_CLEAR",
    name = "Clear",
    description = Descriptions.TAPE_CLEAR,
    params = {
      { separator = true, title = "Clear Motif" }
    }
  })

  norns_ui.rebuild_params = function(self)
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[focused_lane]
    local max_gen = lane and lane.motif and lane.motif:get_max_generation() or 0

    self.params = {
      { separator = true, title = "Clear Motif" }
    }

    -- Only show generation selector if there's more than one generation
    if max_gen >= 2 then
      -- Update param max to match actual generations
      local param = params:lookup_param("lane_" .. focused_lane .. "_clear_generation")
      if param then
        param.max = max_gen
        -- Clamp current value if needed
        local current = params:get("lane_" .. focused_lane .. "_clear_generation")
        if current > max_gen then
          params:set("lane_" .. focused_lane .. "_clear_generation", 0)
        end
      end

      table.insert(self.params, {
        id = "lane_" .. focused_lane .. "_clear_generation",
        name = "Generation"
      })
    else
      -- Reset to "all" when only one generation exists
      params:set("lane_" .. focused_lane .. "_clear_generation", 0)
    end
  end

  norns_ui.draw_default = function(self)
    NornsUI.draw_default(self)

    if not self.state.showing_description then
      local tooltip
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[focused_lane]

      if lane and lane.motif and #lane.motif.events > 0 then
        local gen = params:get("lane_" .. focused_lane .. "_clear_generation")
        if gen > 0 then
          tooltip = "clear gen " .. gen .. ": hold"
        else
          tooltip = "clear all: hold"
        end
      else
        tooltip = "no motif to clear"
      end

      local width = screen.text_extents(tooltip)

      if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "TAPE_CLEAR" then
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
    id = "TAPE_CLEAR",
    layout = {
      x = 3,
      y = 7,
      width = 1,
      height = 1
    },
    long_press_threshold = 1.5
  })

  local button_pressed = false
  local button_press_time = nil

  local original_grid_draw = grid_ui.draw

  grid_ui.draw = function(self, layers)
    original_grid_draw(self, layers)

    if button_pressed and button_press_time then
      local press_duration = util.time() - button_press_time
      local threshold_reached = press_duration >= self.long_press_threshold

      local keyboard_brightness
      if threshold_reached then
        local time_since_threshold = press_duration - self.long_press_threshold
        local pulse_rate = 4
        local pulse_duration = 1 / pulse_rate
        local pulses_completed = time_since_threshold / pulse_duration

        if pulses_completed < 3 then
          local phase = (clock.get_beats() * pulse_rate) % 1
          local pulse = math.sin(phase * math.pi * 2) * 0.5 + 0.5
          keyboard_brightness = math.floor(GridConstants.BRIGHTNESS.MEDIUM + pulse * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.MEDIUM))
        else
          keyboard_brightness = GridConstants.BRIGHTNESS.FULL
        end
      else
        keyboard_brightness = GridConstants.BRIGHTNESS.MEDIUM
      end

      -- Illuminate tape keyboard area
      local keyboard = {
        x = 6,
        y = 2,
        width = 6,
        height = 6
      }

      for x = keyboard.x, keyboard.x + keyboard.width - 1 do
        for y = keyboard.y, keyboard.y + keyboard.height - 1 do
          layers.response[x][y] = keyboard_brightness
        end
      end
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    local key_id = string.format("%d,%d", x, y)

    if z == 1 then
      self:key_down(key_id)
      button_pressed = true
      button_press_time = util.time()
      _seeker.ui_state.set_current_section("TAPE_CLEAR")
      _seeker.ui_state.set_long_press_state(true, "TAPE_CLEAR")
      _seeker.screen_ui.set_needs_redraw()
    else
      button_pressed = false
      button_press_time = nil

      if self:is_long_press(key_id) then
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[focused_lane]

        if lane and lane.motif and #lane.motif.events > 0 then
          local target_gen = params:get("lane_" .. focused_lane .. "_clear_generation")

          if target_gen > 0 then
            lane.motif:clear_generation(target_gen)
            -- Reset selector after clearing
            params:set("lane_" .. focused_lane .. "_clear_generation", 0)
          else
            lane:clear()
          end

          -- Update create screen parameter visibility
          if _seeker.tape and _seeker.tape.create and _seeker.tape.create.screen then
            _seeker.tape.create.screen:rebuild_params()
          end
          -- Rebuild clear screen to update generation options
          if _seeker.tape and _seeker.tape.clear and _seeker.tape.clear.screen then
            _seeker.tape.clear.screen:rebuild_params()
          end
        end

        _seeker.screen_ui.set_needs_redraw()
      end

      _seeker.ui_state.set_long_press_state(false, nil)
      _seeker.screen_ui.set_needs_redraw()
      self:key_release(key_id)
    end
  end

  return grid_ui
end

function TapeClear.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui()
  }

  return component
end

return TapeClear
