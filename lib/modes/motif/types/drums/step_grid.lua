-- step_grid.lua
-- 4-lane step grid for polymetric drum sequencer.
-- All lanes visible simultaneously: 2 rows per lane, 8 columns, 16 steps max.
-- Tap to toggle steps. Long-press beyond pattern length to extend it.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local LaneMap = include("lib/lanes/lane_map")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")

local StepGrid = {}

local MAX_COLS = 8
local ROWS_PER_LANE = 2
local MAX_STEPS = MAX_COLS * ROWS_PER_LANE

local step_state = {}

StepGrid.selected_step = 1

local DIVISION_OPTIONS = {"1/4", "1/3", "1/2", "2/3", "1", "3/2", "2", "3", "4"}
local DIVISION_VALUES = {0.25, 1/3, 0.5, 2/3, 1, 1.5, 2, 3, 4}

local function lane_start_row(local_index)
  return (local_index - 1) * ROWS_PER_LANE + 1
end

local function get_length(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_length")
end

local function get_division(lane_id)
  local idx = params:get("lane_" .. lane_id .. "_drum_division")
  return DIVISION_VALUES[idx]
end

local function get_gate_pct(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_gate_length") / 100
end

local function get_voice_note(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_voice_note")
end

local function get_swing_pct(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_swing") / 100
end

local function get_probability(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_probability")
end

function StepGrid.get_step_state(lane_id)
  if not step_state[lane_id] then
    step_state[lane_id] = {}
    for i = 1, 32 do
      step_state[lane_id][i] = { active = false, velocity = 100, ratchet = 1, note = nil, voltage = nil }
    end
  end
  return step_state[lane_id]
end

function StepGrid.get_step(lane_id, step)
  local state = StepGrid.get_step_state(lane_id)
  return state[step]
end

function StepGrid.get_length(lane_id)
  return get_length(lane_id)
end

local function get_current_step(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane or not lane.playing or not lane.motif or lane.motif.duration <= 0 then
    return nil
  end
  local division = get_division(lane_id)
  local beat_pos = lane.current_beat_position or 0
  local length = get_length(lane_id)
  local step = math.floor(beat_pos / division) + 1
  if step > length then step = ((step - 1) % length) + 1 end
  return step
end

function StepGrid.rebuild_motif(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane then return end

  local length = get_length(lane_id)
  local division = get_division(lane_id)
  local gate_pct = get_gate_pct(lane_id)
  local lane_note = get_voice_note(lane_id)
  local swing = get_swing_pct(lane_id)
  local state = StepGrid.get_step_state(lane_id)
  local local_index = lane_id - LaneMap.OFFSETS.drums
  local row_start = lane_start_row(local_index)

  lane.motif.events = {}
  for i = 1, length do
    local s = state[i]
    if s.active then
      local note = s.note or lane_note
      local base_time = (i - 1) * division

      if i % 2 == 0 and swing > 0 then
        base_time = base_time + swing * division * 0.5
      end

      local ratchet_count = s.ratchet or 1
      local ratchet_interval = division / ratchet_count

      for r = 1, ratchet_count do
        local time = base_time + (r - 1) * ratchet_interval
        local ratchet_gate = math.min(gate_pct * division, ratchet_interval * 0.9)
        local col = ((i - 1) % MAX_COLS) + 1
        local row = row_start + math.floor((i - 1) / MAX_COLS)
        table.insert(lane.motif.events, {
          time = time,
          type = "note_on",
          note = note,
          voltage = s.voltage,
          velocity = s.velocity,
          x = col,
          y = row,
          step = i,
          is_playback = false,
        })
        table.insert(lane.motif.events, {
          time = time + ratchet_gate,
          type = "note_off",
          note = note,
          step = i,
        })
      end
    end
  end
  lane.motif.duration = length * division

  if lane.playing then
    lane:sync_all_stages_from_params()
    _seeker.conductor.clear_events_for_lane(lane_id)
    lane:schedule_stage(lane.current_stage_index, clock.get_beats())
  end
end

function StepGrid.apply_pattern(lane_id)
  local length = get_length(lane_id)
  local hits = math.min(params:get("lane_" .. lane_id .. "_drum_hits"), length)
  local rotation = params:get("lane_" .. lane_id .. "_drum_rotation")
  local distribution = params:string("lane_" .. lane_id .. "_drum_distribution")

  local state = StepGrid.get_step_state(lane_id)
  local pattern

  if distribution == "Even" then
    pattern = EurorackUtils.bjorklund(length, hits, rotation)
  else
    pattern = {}
    local placed = 0
    while placed < hits and placed < length do
      local pos = math.random(1, length)
      if not pattern[pos] then
        pattern[pos] = true
        placed = placed + 1
      end
    end
    for i = 1, length do
      if not pattern[i] then pattern[i] = false end
    end
    if rotation > 0 then
      local rotated = {}
      for i = 1, length do
        rotated[i] = pattern[((i - 1 + rotation) % length) + 1]
      end
      pattern = rotated
    end
  end

  for i = 1, length do
    state[i].active = pattern[i]
  end

  StepGrid.rebuild_motif(lane_id)
end

function StepGrid.get_pattern_table(lane_id)
  local length = get_length(lane_id)
  local state = StepGrid.get_step_state(lane_id)
  local pattern = {}
  for i = 1, length do
    pattern[i] = state[i].active
  end
  return pattern
end

local function xy_to_lane_step(x, y)
  if x < 1 or x > MAX_COLS or y < 1 or y > 8 then return nil, nil end
  local local_index = math.ceil(y / ROWS_PER_LANE)
  if local_index < 1 or local_index > 4 then return nil, nil end
  local lane_id = LaneMap.to_flat("drums", local_index)
  local row_start = lane_start_row(local_index)
  local row_offset = y - row_start
  local step = row_offset * MAX_COLS + x
  if step < 1 or step > MAX_STEPS then return nil, nil end
  return lane_id, step
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "DRUMS_STEP_GRID",
    layout = {
      x = 1,
      y = 1,
      width = MAX_COLS,
      height = 8
    }
  })

  grid_ui.draw = function(self, layers)
    local lane_ids = LaneMap.lanes_for_mode("drums")
    local focused_lane = _seeker.ui_state.get_focused_lane()

    for _, lane_id in ipairs(lane_ids) do
      local local_index = lane_id - LaneMap.OFFSETS.drums
      local row_start = lane_start_row(local_index)
      local length = get_length(lane_id)
      local state = StepGrid.get_step_state(lane_id)
      local current_step = get_current_step(lane_id)
      local is_focused = (lane_id == focused_lane)

      for i = 1, MAX_STEPS do
        local col = ((i - 1) % MAX_COLS) + 1
        local row = row_start + math.floor((i - 1) / MAX_COLS)

        if i <= length then
          local s = state[i]
          local brightness
          if s.active then
            if current_step == i then
              brightness = GridConstants.BRIGHTNESS.FULL
            elseif is_focused and i == StepGrid.selected_step then
              brightness = GridConstants.BRIGHTNESS.HIGH
            else
              brightness = s.ratchet > 1 and GridConstants.BRIGHTNESS.MEDIUM or GridConstants.BRIGHTNESS.HIGH
            end
          else
            if current_step == i then
              brightness = GridConstants.BRIGHTNESS.MEDIUM
            elseif is_focused and i == StepGrid.selected_step then
              brightness = GridConstants.BRIGHTNESS.LOW
            else
              brightness = GridConstants.BRIGHTNESS.DIM
            end
          end
          layers.ui[col][row] = brightness
        else
          layers.ui[col][row] = GridConstants.BRIGHTNESS.OFF
        end
      end
    end
  end

  grid_ui.contains = function(self, x, y)
    if x < 1 or x > MAX_COLS then return false end
    if y < 1 or y > 8 then return false end
    return true
  end

  grid_ui.handle_key = function(self, x, y, z)
    local lane_id, step = xy_to_lane_step(x, y)
    if not lane_id then return end

    local key_id = string.format("%d,%d", x, y)
    local length = get_length(lane_id)

    if z == 1 then
      self:key_down(key_id)
      _seeker.ui_state.register_activity()
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    else
      local was_long = self:is_long_press(key_id)
      self:key_release(key_id)

      if step <= length then
        if was_long then
          -- Long press: select step for editing (no toggle)
          _seeker.ui_state.set_focused_lane(lane_id)
          StepGrid.selected_step = step
          _seeker.ui_state.set_current_section("DRUMS_HOME")
          if _seeker.drums_type and _seeker.drums_type.home and _seeker.drums_type.home.screen then
            _seeker.drums_type.home.screen:rebuild_params()
          end
        else
          -- Short press: toggle step on/off
          local state = StepGrid.get_step_state(lane_id)
          state[step].active = not state[step].active
          StepGrid.rebuild_motif(lane_id)
          _seeker.ui_state.set_focused_lane(lane_id)
        end
      elseif step <= MAX_STEPS and was_long then
        -- Long press beyond length: extend pattern
        params:set("lane_" .. lane_id .. "_drum_length", step)
        StepGrid.rebuild_motif(lane_id)
        _seeker.ui_state.set_focused_lane(lane_id)
      end

      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end
  end

  return grid_ui
end

local function create_params()
  for _, i in ipairs(LaneMap.lanes_for_mode("drums")) do
    params:add_group("lane_" .. i .. "_drum_step", "LANE " .. i .. " DRUM STEPS", 9)

    params:add_number("lane_" .. i .. "_drum_length", "Length", 1, 16, 8)
    params:set_action("lane_" .. i .. "_drum_length", function(val)
      local hits = params:get("lane_" .. i .. "_drum_hits")
      if hits > val then params:set("lane_" .. i .. "_drum_hits", val) end
      StepGrid.rebuild_motif(i)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_number("lane_" .. i .. "_drum_hits", "Hits", 0, 16, 4)
    params:set_action("lane_" .. i .. "_drum_hits", function(val)
      local length = params:get("lane_" .. i .. "_drum_length")
      if val > length then params:set("lane_" .. i .. "_drum_hits", length); return end
      StepGrid.apply_pattern(i)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_option("lane_" .. i .. "_drum_distribution", "Distribution", {"Even", "Random"}, 1)
    params:set_action("lane_" .. i .. "_drum_distribution", function()
      StepGrid.apply_pattern(i)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_number("lane_" .. i .. "_drum_rotation", "Rotation", 0, 15, 0)
    params:set_action("lane_" .. i .. "_drum_rotation", function()
      StepGrid.apply_pattern(i)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_option("lane_" .. i .. "_drum_division", "Division", DIVISION_OPTIONS, 5)
    params:set_action("lane_" .. i .. "_drum_division", function()
      StepGrid.rebuild_motif(i)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_number("lane_" .. i .. "_drum_voice_note", "Voice Note", 24, 96, 60)
    params:set_action("lane_" .. i .. "_drum_voice_note", function()
      StepGrid.rebuild_motif(i)
    end)

    params:add_number("lane_" .. i .. "_drum_gate_length", "Gate Length", 1, 100, 50,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. i .. "_drum_gate_length", function()
      StepGrid.rebuild_motif(i)
    end)

    params:add_number("lane_" .. i .. "_drum_swing", "Swing", 0, 100, 0,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. i .. "_drum_swing", function()
      StepGrid.rebuild_motif(i)
    end)

    params:add_number("lane_" .. i .. "_drum_probability", "Probability", 0, 100, 100,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. i .. "_drum_probability", function()
      StepGrid.rebuild_motif(i)
    end)
  end
end

function StepGrid.init()
  create_params()
  return {
    grid = create_grid_ui()
  }
end

return StepGrid
