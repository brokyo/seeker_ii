-- stage_nav.lua
-- Stage navigation for Tape type
-- Four buttons to select stage for editing
-- Part of lib/modes/motif/tape/

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local TapeStageNav = {}

local layout = {
  x = 1,
  y = 2,
  width = 4,
  height = 1
}

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TAPE_STAGE_NAV",
    layout = layout
  })

  grid_ui.draw = function(self, layers)
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local focused_lane = _seeker.lanes[focused_lane_id]
    if not focused_lane then return end

    local current_playing_stage = focused_lane.current_stage_index or 1
    local is_stage_config_section = (_seeker.ui_state.get_current_section() == "TAPE_STAGE_CONFIG")
    local selected_config_stage = params:get("lane_" .. focused_lane_id .. "_tape_config_stage")

    for i = 0, self.layout.width - 1 do
      local x = self.layout.x + i
      local stage_num = i + 1
      local is_playing_stage = (stage_num == current_playing_stage)
      local is_selected_stage = (stage_num == selected_config_stage)
      local brightness = GridConstants.BRIGHTNESS.LOW

      if is_stage_config_section then
        -- Show playing stage at full brightness, selected editing stage at medium
        if is_playing_stage then
          brightness = GridConstants.BRIGHTNESS.HIGH
        elseif is_selected_stage then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        else
          brightness = GridConstants.BRIGHTNESS.LOW
        end
      else
        -- Outside stage config, just show current playing stage
        if is_playing_stage then
          brightness = GridConstants.BRIGHTNESS.HIGH
        else
          brightness = GridConstants.BRIGHTNESS.LOW
        end
      end

      layers.ui[x][self.layout.y] = brightness
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local focused_lane_id = _seeker.ui_state.get_focused_lane()
      local stage_num = (x - self.layout.x) + 1

      -- Set the config stage and navigate to stage config section
      params:set("lane_" .. focused_lane_id .. "_tape_config_stage", stage_num)
      _seeker.ui_state.set_current_section("TAPE_STAGE_CONFIG")
    end
  end

  return grid_ui
end

function TapeStageNav.init()
  local component = {
    grid = create_grid_ui()
  }

  return component
end

return TapeStageNav
