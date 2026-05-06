-- step_grid.lua
-- Toggle grid for drum step sequencer.
-- Each step maps to a beat position in the lane's motif.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local LaneMap = include("lib/lanes/lane_map")

local StepGrid = {}

local GRID_X = 1
local GRID_Y = 3
local MAX_COLS = 12

-- Per-lane step state: steps[lane_id] = {true, false, true, ...}
local steps = {}

-- Per-lane step counts (default 8)
local function get_step_count(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_steps")
end

local function get_gate_length(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_gate_length")
end

local function get_voice_note(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_voice_note")
end

function StepGrid.get_steps(lane_id)
  if not steps[lane_id] then
    steps[lane_id] = {}
    for i = 1, 16 do steps[lane_id][i] = false end
  end
  return steps[lane_id]
end

function StepGrid.rebuild_motif(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane then return end

  local step_count = get_step_count(lane_id)
  local gate = get_gate_length(lane_id)
  local note = get_voice_note(lane_id)
  local step_data = StepGrid.get_steps(lane_id)
  local step_duration = 1

  lane.motif.events = {}
  for i = 1, step_count do
    if step_data[i] then
      table.insert(lane.motif.events, {
        time = (i - 1) * step_duration,
        type = "note_on",
        note = note,
        velocity = 100,
        x = i,
        y = GRID_Y,
        step = i,
        is_playback = false,
      })
      table.insert(lane.motif.events, {
        time = (i - 1) * step_duration + gate,
        type = "note_off",
        note = note,
        step = i,
      })
    end
  end
  lane.motif.duration = step_count * step_duration

  if lane.playing then
    lane:sync_all_stages_from_params()
    _seeker.conductor.clear_events_for_lane(lane_id)
    lane:schedule_stage(lane.current_stage_index, clock.get_beats())
  end
end

-- Euclidean rhythm: distribute k hits across n steps
function StepGrid.euclidean(k, n)
  if k >= n then
    local pattern = {}
    for i = 1, n do pattern[i] = true end
    return pattern
  end
  if k <= 0 then
    local pattern = {}
    for i = 1, n do pattern[i] = false end
    return pattern
  end

  local pattern = {}
  for i = 1, n do pattern[i] = false end

  local bucket = 0
  for i = 1, n do
    bucket = bucket + k
    if bucket >= n then
      bucket = bucket - n
      pattern[i] = true
    end
  end
  return pattern
end

function StepGrid.apply_euclidean(lane_id)
  local step_count = get_step_count(lane_id)
  local fills = params:get("lane_" .. lane_id .. "_drum_euclidean_fills")
  local step_data = StepGrid.get_steps(lane_id)
  local pattern = StepGrid.euclidean(fills, step_count)
  for i = 1, step_count do
    step_data[i] = pattern[i]
  end
  StepGrid.rebuild_motif(lane_id)
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "DRUMS_STEP_GRID",
    layout = {
      x = GRID_X,
      y = GRID_Y,
      width = MAX_COLS,
      height = 2
    }
  })

  grid_ui.draw = function(self, layers)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local step_count = get_step_count(lane_id)
    local step_data = StepGrid.get_steps(lane_id)
    local lane = _seeker.lanes[lane_id]

    -- Current playhead position
    local current_step = nil
    if lane and lane.playing and lane.motif and lane.motif.duration > 0 then
      local beat_pos = lane.current_beat_position or 0
      current_step = math.floor(beat_pos) + 1
      if current_step > step_count then current_step = ((current_step - 1) % step_count) + 1 end
    end

    for i = 1, step_count do
      local col = ((i - 1) % MAX_COLS) + GRID_X
      local row = GRID_Y + math.floor((i - 1) / MAX_COLS)

      local brightness
      if step_data[i] then
        if current_step == i then
          brightness = GridConstants.BRIGHTNESS.FULL
        else
          brightness = GridConstants.BRIGHTNESS.HIGH
        end
      else
        if current_step == i then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        else
          brightness = GridConstants.BRIGHTNESS.DIM
        end
      end

      layers.ui[col][row] = brightness
    end
  end

  grid_ui.contains = function(self, x, y)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local step_count = get_step_count(lane_id)
    local num_rows = math.ceil(step_count / MAX_COLS)
    if x < GRID_X or x > GRID_X + MAX_COLS - 1 then return false end
    if y < GRID_Y or y > GRID_Y + num_rows - 1 then return false end
    local step = (y - GRID_Y) * MAX_COLS + (x - GRID_X) + 1
    return step <= step_count
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z ~= 1 then return end

    local lane_id = _seeker.ui_state.get_focused_lane()
    local step = (y - GRID_Y) * MAX_COLS + (x - GRID_X) + 1
    local step_count = get_step_count(lane_id)
    if step < 1 or step > step_count then return end

    local step_data = StepGrid.get_steps(lane_id)
    step_data[step] = not step_data[step]
    StepGrid.rebuild_motif(lane_id)

    _seeker.ui_state.register_activity()
  end

  return grid_ui
end

local function create_params()
  local LaneMap = include("lib/lanes/lane_map")
  for _, i in ipairs(LaneMap.lanes_for_mode("drums")) do
    params:add_group("lane_" .. i .. "_drum_step", "LANE " .. i .. " DRUM STEPS", 4)
    params:add_number("lane_" .. i .. "_drum_steps", "Steps", 4, 16, 8)
    params:set_action("lane_" .. i .. "_drum_steps", function()
      StepGrid.rebuild_motif(i)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_number("lane_" .. i .. "_drum_voice_note", "Voice Note", 24, 96, 60)
    params:set_action("lane_" .. i .. "_drum_voice_note", function()
      StepGrid.rebuild_motif(i)
    end)

    params:add_control("lane_" .. i .. "_drum_gate_length", "Gate Length",
      controlspec.new(0.05, 0.95, 'lin', 0.05, 0.25, "beats"))
    params:set_action("lane_" .. i .. "_drum_gate_length", function()
      StepGrid.rebuild_motif(i)
    end)

    params:add_number("lane_" .. i .. "_drum_euclidean_fills", "Euclidean Fills", 0, 16, 4)
    params:set_action("lane_" .. i .. "_drum_euclidean_fills", function()
      StepGrid.apply_euclidean(i)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
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
