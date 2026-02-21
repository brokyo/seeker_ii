-- lane_selector.lua
-- Wheel lane buttons: 4 lanes at col 1, rows 4-7.
-- Tap to focus lane (saves/loads form snapshot), hold to play/stop.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local NUM_WHEEL_LANES = 4
local FIRST_ROW = 4

local LaneSelector = {}

function LaneSelector.init()
  local grid_ui = GridUI.new({
    id = "FORM_LANE_SELECT",
    layout = {
      x = 1,
      y = FIRST_ROW,
      width = 1,
      height = NUM_WHEEL_LANES
    }
  })

  grid_ui.draw = function(self, layers)
    for i = 1, NUM_WHEEL_LANES do
      local row = FIRST_ROW + i - 1
      local lane = _seeker.lanes[i]
      local is_focused = i == _seeker.ui_state.get_focused_lane()

      local brightness
      if is_focused then
        brightness = GridConstants.BRIGHTNESS.FULL
      elseif lane.playing then
        -- Pulse between FULL-3 and FULL synced to beat time
        brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
      else
        brightness = GridConstants.BRIGHTNESS.LOW
      end

      layers.ui[1][row] = brightness
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    if not self:contains(x, y) then return false end

    local lane_idx = y - FIRST_ROW + 1
    local key_id = string.format("1,%d", y)

    if z == 1 then
      self:key_down(key_id)

      local old_lane = _seeker.ui_state.get_focused_lane()
      if lane_idx ~= old_lane then
        _seeker.ui_state.set_focused_lane(lane_idx)
        _seeker.screen_ui.set_needs_redraw()
      end

    else
      if self:is_long_press(key_id) then
        local lane = _seeker.lanes[lane_idx]
        if lane.playing then
          lane:stop()
        else
          lane:play({quantize = true})
        end
      end
      self:key_release(key_id)
    end

    return true
  end

  return grid_ui
end

return LaneSelector
