-- grid.lua
-- Drum grid UI. Cols 1-8: step grid (follows playback). Col 9: gap.
-- Col 10: call/response toggle. Col 11: response strategy cycle.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local LaneMap = include("lib/lanes/lane_map")

local DrumsGrid = {}

local MAX_COLS = 8
local ROWS_PER_LANE = 2
local MAX_STEPS = MAX_COLS * ROWS_PER_LANE

local _step_state = nil

function DrumsGrid.set_step_state_ref(ref)
  _step_state = ref
end

local function xy_to_lane_step(x, y)
  if x < 1 or x > MAX_COLS or y < 1 or y > 8 then return nil, nil end
  local local_index = math.ceil(y / ROWS_PER_LANE)
  if local_index < 1 or local_index > 4 then return nil, nil end
  local lane_id = LaneMap.to_flat("drums", local_index)
  local row_start = (local_index - 1) * ROWS_PER_LANE + 1
  local row_offset = y - row_start
  local step = row_offset * MAX_COLS + x
  if step < 1 or step > MAX_STEPS then return nil, nil end
  return lane_id, step
end

local function y_to_lane_id(y)
  if y < 1 or y > 8 then return nil end
  local local_index = math.ceil(y / ROWS_PER_LANE)
  if local_index < 1 or local_index > 4 then return nil end
  return LaneMap.to_flat("drums", local_index)
end

local function rebuild_current_drums_screen()
  local section = _seeker.ui_state.get_current_section()
  local sections = _seeker.drums_type and _seeker.drums_type.sections
  if sections and sections[section] and sections[section].rebuild_params then
    sections[section]:rebuild_params()
    sections[section]:filter_active_params()
  end
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "DRUMS_STEP_GRID",
    layout = { x = 1, y = 1, width = 11, height = 8 }
  })

  grid_ui.draw = function(self, layers)
    local lane_ids = LaneMap.lanes_for_mode("drums")

    -- Find held key for charge-up animation
    local hold_lane, hold_step, hold_progress
    for key_id, press in pairs(self.press_state.pressed_keys) do
      local kx, ky = key_id:match("(%d+),(%d+)")
      if kx then
        local hl, hs = xy_to_lane_step(tonumber(kx), tonumber(ky))
        if hl then
          hold_lane = hl
          hold_step = hs
          hold_progress = (util.time() - press.start_time) / self.long_press_threshold
          if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
        end
      end
      break
    end

    for _, lane_id in ipairs(lane_ids) do
      local local_index = lane_id - LaneMap.OFFSETS.drums
      local row_start = (local_index - 1) * ROWS_PER_LANE + 1
      local length = _step_state.get_length(lane_id)
      local cr_on = _step_state.is_cr_enabled(lane_id)
      local is_resp = _step_state.is_viewing_response(lane_id)

      local steps
      if is_resp then
        steps = _step_state.get_response_steps(lane_id)
      else
        steps = _step_state.get_steps(lane_id)
      end
      local current_step = _step_state.get_current_step(lane_id)

      -- Cols 1-8: step grid
      for i = 1, MAX_STEPS do
        local col = ((i - 1) % MAX_COLS) + 1
        local row = row_start + math.floor((i - 1) / MAX_COLS)

        if i <= length then
          local s = steps[i]
          local brightness

          if current_step == i then
            brightness = s.active and GridConstants.BRIGHTNESS.FULL or GridConstants.BRIGHTNESS.MEDIUM
          elseif s.active then
            brightness = is_resp and GridConstants.BRIGHTNESS.MEDIUM or GridConstants.BRIGHTNESS.HIGH
          else
            brightness = GridConstants.BRIGHTNESS.LOW
          end

          if hold_lane == lane_id and hold_step == i and hold_progress then
            local charge = math.min(hold_progress, 1.0)
            local charge_brightness = GridConstants.BRIGHTNESS.LOW +
              math.floor(charge * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.LOW))
            brightness = math.max(brightness, charge_brightness)
          end

          layers.ui[col][row] = brightness
        else
          layers.ui[col][row] = GridConstants.BRIGHTNESS.OFF
        end
      end

      -- Col 9: gap
      layers.ui[9][row_start] = GridConstants.BRIGHTNESS.OFF
      layers.ui[9][row_start + 1] = GridConstants.BRIGHTNESS.OFF

      -- Col 10: call screen button
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local current_section = _seeker.ui_state.get_current_section()
      local on_call_screen = current_section == "DRUMS_CALL" and focused_lane == lane_id
      layers.ui[10][row_start] = on_call_screen and GridConstants.BRIGHTNESS.FULL or GridConstants.BRIGHTNESS.DIM
      layers.ui[10][row_start + 1] = cr_on and (is_resp and GridConstants.BRIGHTNESS.LOW or GridConstants.BRIGHTNESS.MEDIUM) or GridConstants.BRIGHTNESS.OFF

      -- Col 11: response screen button
      local on_resp_screen = current_section == "DRUMS_RESPONSE" and focused_lane == lane_id
      layers.ui[11][row_start] = on_resp_screen and GridConstants.BRIGHTNESS.FULL or GridConstants.BRIGHTNESS.DIM
      layers.ui[11][row_start + 1] = cr_on and (is_resp and GridConstants.BRIGHTNESS.MEDIUM or GridConstants.BRIGHTNESS.LOW) or GridConstants.BRIGHTNESS.OFF
    end
  end

  grid_ui.contains = function(self, x, y)
    if y < 1 or y > 8 then return false end
    if x >= 1 and x <= MAX_COLS then return true end
    if x >= 9 and x <= 11 then return true end
    return false
  end

  grid_ui.handle_key = function(self, x, y, z)
    -- Column 10-11: call/response controls (press only)
    if x == 10 or x == 11 then
      if z == 0 then return end
      local lane_id = y_to_lane_id(y)
      if not lane_id then return end
      local local_index = lane_id - LaneMap.OFFSETS.drums
      local row_start = (local_index - 1) * ROWS_PER_LANE + 1

      if x == 10 and y == row_start then
        _seeker.ui_state.set_focused_lane(lane_id)
        local on_call = _seeker.ui_state.get_current_section() == "DRUMS_CALL"
          and _seeker.ui_state.get_focused_lane() == lane_id
        if on_call then
          _step_state.set_editing_call(lane_id, false)
          _seeker.ui_state.set_current_section("DRUMS_TIMING")
        else
          _step_state.set_editing_call(lane_id, true)
          _seeker.ui_state.set_current_section("DRUMS_CALL")
        end
        rebuild_current_drums_screen()
      elseif x == 11 and y == row_start then
        _seeker.ui_state.set_focused_lane(lane_id)
        local on_resp = _seeker.ui_state.get_current_section() == "DRUMS_RESPONSE"
          and _seeker.ui_state.get_focused_lane() == lane_id
        if on_resp then
          _step_state.set_editing_response(lane_id, false)
          _seeker.ui_state.set_current_section("DRUMS_TIMING")
        else
          _step_state.set_editing_response(lane_id, true)
          _seeker.ui_state.set_current_section("DRUMS_RESPONSE")
        end
        rebuild_current_drums_screen()
      end
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
      return
    end

    if x == 9 then return end

    -- Columns 1-8: step grid
    local lane_id, step = xy_to_lane_step(x, y)
    if not lane_id then return end

    local key_id = string.format("%d,%d", x, y)
    local length = _step_state.get_length(lane_id)

    if z == 1 then
      self:key_down(key_id)
      if step <= length then
        _step_state.held_step = { lane_id = lane_id, step = step }
      end
      _seeker.ui_state.register_activity()
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
      return
    end

    local was_long = self:is_long_press(key_id)
    self:key_release(key_id)
    _step_state.held_step = nil

    if step <= length then
      if was_long then
        _seeker.ui_state.set_focused_lane(lane_id)
        _step_state.selected_step[lane_id] = step
        _seeker.ui_state.set_current_section("DRUMS_HOME")
        rebuild_current_drums_screen()
      else
        local is_resp = _step_state.is_viewing_response(lane_id)
        if is_resp then
          _step_state.get_response_steps(lane_id)[step].active = not _step_state.get_response_steps(lane_id)[step].active
          _step_state.mark_response_manual(lane_id)
          _step_state.snapshot_response_genesis(lane_id)
        else
          _step_state.toggle_step(lane_id, step)
          _step_state.snapshot_genesis(lane_id)
        end
        _step_state.apply_motif(lane_id)
        _seeker.ui_state.set_focused_lane(lane_id)
        rebuild_current_drums_screen()
      end
    end

    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
  end

  return grid_ui
end

function DrumsGrid.init()
  return {
    grid = create_grid_ui()
  }
end

return DrumsGrid
