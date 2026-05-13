-- degree_grid.lua
-- 8×6 grid: 7 degree columns (I-vii) + 1 stage count column.
-- Columns 1-7 = scale degrees, column 8 = stage enable bar.
-- Tap degree to set, tap column 8 to set stage count.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local DegreeGrid = {}

local GRID_X = 1
local GRID_Y = 2
local GRID_W = 8
local GRID_H = 6
local DEGREE_COLS = 7
local STAGE_COL = 8

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

      -- Degree columns (1-7)
      for col = 1, DEGREE_COLS do
        local degree = col
        local gx = GRID_X + col - 1
        local gy = GRID_Y + row - 1

        local brightness
        if degree == stage_degree then
          if is_current then
            brightness = GridConstants.BRIGHTNESS.FULL
          elseif is_editing then
            brightness = GridConstants.BRIGHTNESS.HIGH
          else
            brightness = GridConstants.BRIGHTNESS.MEDIUM
          end
        elseif is_active_stage then
          brightness = GridConstants.BRIGHTNESS.LOW
        else
          brightness = GridConstants.BRIGHTNESS.DIM
        end

        layers.ui[gx][gy] = brightness
      end

      -- Stage count column (8)
      local stage_gx = GRID_X + STAGE_COL - 1
      local stage_gy = GRID_Y + row - 1
      local stage_brightness
      if is_current then
        stage_brightness = GridConstants.BRIGHTNESS.FULL
      elseif is_active_stage then
        stage_brightness = GridConstants.BRIGHTNESS.MEDIUM
      else
        stage_brightness = GridConstants.BRIGHTNESS.DIM
      end
      layers.ui[stage_gx][stage_gy] = stage_brightness
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
    local stage = row

    -- Column 8: set stage count
    if col == STAGE_COL then
      params:set("rc_composer_stages", stage)
      Composer.rebuild()
      _seeker.screen_ui.set_needs_redraw()
      return
    end

    -- Columns 1-7: set degree
    local num_stages = params:get("rc_composer_stages")
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
