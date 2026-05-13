-- degree_grid.lua
-- 7×6 grid for punching in chord degrees per stage.
-- Columns = scale degrees (I-vii), rows = stages (1-6).
-- Tap to set degree, tap active cell to cycle chord extension.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local DegreeGrid = {}

local GRID_X = 6
local GRID_Y = 2
local GRID_W = 7
local GRID_H = 6

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "COMPOSER_DEGREE_GRID",
    layout = {
      x = GRID_X,
      y = GRID_Y,
      width = GRID_W,
      height = GRID_H,
    }
  })

  grid_ui.draw = function(self, layers)
    local Composer = _seeker.composer_mode.composer
    local lane_id = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_id]
    local num_stages = params:get("rc_composer_stages")
    local start = params:get("rc_composer_start")
    local movement = Composer.movement_value(params:get("rc_composer_movement"))
    local degree_overrides = lane.composer_degree_overrides or {}
    local current_stage = lane.current_stage_index or 1
    local is_playing = lane.playing

    local live_view = _seeker.composer_mode.live_view
    local edit_stage = live_view and live_view.edit_stage and live_view.edit_stage()

    for row = 1, GRID_H do
      local stage = row
      local is_active_stage = stage <= num_stages
      local is_current = is_playing and stage == current_stage
      local is_editing = edit_stage and stage == edit_stage

      local stage_degree = nil
      if is_active_stage then
        stage_degree = degree_overrides[stage] or ((start - 1 + movement * (stage - 1)) % 7) + 1
      end

      for col = 1, GRID_W do
        local degree = col
        local gx = GRID_X + col - 1
        local gy = GRID_Y + row - 1

        local brightness
        if not is_active_stage then
          brightness = GridConstants.BRIGHTNESS.OFF
        elseif degree == stage_degree then
          if is_current then
            brightness = GridConstants.BRIGHTNESS.FULL
          elseif is_editing then
            brightness = GridConstants.BRIGHTNESS.HIGH
          else
            brightness = GridConstants.BRIGHTNESS.MEDIUM
          end
        else
          brightness = GridConstants.BRIGHTNESS.LOW
        end

        layers.ui[gx][gy] = brightness
      end
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z ~= 1 then return end

    local col = x - GRID_X + 1
    local row = y - GRID_Y + 1
    if col < 1 or col > GRID_W or row < 1 or row > GRID_H then return end

    local Composer = _seeker.composer_mode.composer
    local lane_id = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_id]
    local num_stages = params:get("rc_composer_stages")
    local stage = row

    if stage > num_stages then
      params:set("rc_composer_stages", stage)
    end

    local degree = col

    local live_view = _seeker.composer_mode.live_view
    if live_view and live_view.set_edit_stage then
      live_view.set_edit_stage(stage)
    end

    lane.composer_degree_overrides = lane.composer_degree_overrides or {}
    lane.composer_degree_overrides[stage] = degree
    Composer.rebuild()

    _seeker.ui_state.set_current_section("COMPOSER_LIVE")
    if _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return grid_ui
end

function DegreeGrid.init()
  return {
    grid = create_grid_ui(),
  }
end

return DegreeGrid
