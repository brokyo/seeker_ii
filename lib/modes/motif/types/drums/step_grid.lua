-- step_grid.lua
-- Toggle grid for drum step sequencer.
-- Each step maps to a beat position in the lane's motif.
-- Tapping a step toggles it and selects it for per-step config on screen.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local LaneMap = include("lib/lanes/lane_map")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")

local StepGrid = {}

local GRID_X = 1
local GRID_Y = 3
local MAX_COLS = 8

-- Per-lane step state: step_state[lane_id][step] = {active, velocity, ratchet}
local step_state = {}

StepGrid.selected_step = 1

local DIVISION_OPTIONS = {"1/4", "1/3", "1/2", "2/3", "1", "3/2", "2", "3", "4"}
local DIVISION_VALUES = {0.25, 1/3, 0.5, 2/3, 1, 1.5, 2, 3, 4}

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
      step_state[lane_id][i] = { active = false, velocity = 100, ratchet = 1 }
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

function StepGrid.rebuild_motif(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane then return end

  local length = get_length(lane_id)
  local division = get_division(lane_id)
  local gate_pct = get_gate_pct(lane_id)
  local note = get_voice_note(lane_id)
  local swing = get_swing_pct(lane_id)
  local probability = get_probability(lane_id)
  local state = StepGrid.get_step_state(lane_id)

  lane.motif.events = {}
  for i = 1, length do
    local s = state[i]
    if s.active and math.random(100) <= probability then
      local base_time = (i - 1) * division

      -- Swing: offset even-numbered steps
      if i % 2 == 0 and swing > 0 then
        base_time = base_time + swing * division * 0.5
      end

      local ratchet_count = s.ratchet or 1
      local ratchet_interval = division / ratchet_count

      for r = 1, ratchet_count do
        local time = base_time + (r - 1) * ratchet_interval
        local ratchet_gate = math.min(gate_pct * division, ratchet_interval * 0.9)
        table.insert(lane.motif.events, {
          time = time,
          type = "note_on",
          note = note,
          velocity = s.velocity,
          x = ((i - 1) % MAX_COLS) + GRID_X,
          y = GRID_Y + math.floor((i - 1) / MAX_COLS),
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
    local length = get_length(lane_id)
    local state = StepGrid.get_step_state(lane_id)
    local lane = _seeker.lanes[lane_id]

    local current_step = nil
    if lane and lane.playing and lane.motif and lane.motif.duration > 0 then
      local division = get_division(lane_id)
      local beat_pos = lane.current_beat_position or 0
      current_step = math.floor(beat_pos / division) + 1
      if current_step > length then current_step = ((current_step - 1) % length) + 1 end
    end

    for i = 1, length do
      local col = ((i - 1) % MAX_COLS) + GRID_X
      local row = GRID_Y + math.floor((i - 1) / MAX_COLS)
      local s = state[i]

      local brightness
      if s.active then
        if current_step == i then
          brightness = GridConstants.BRIGHTNESS.FULL
        elseif i == StepGrid.selected_step then
          brightness = GridConstants.BRIGHTNESS.HIGH
        else
          brightness = s.ratchet > 1 and GridConstants.BRIGHTNESS.MEDIUM or GridConstants.BRIGHTNESS.HIGH
        end
      else
        if current_step == i then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        elseif i == StepGrid.selected_step then
          brightness = GridConstants.BRIGHTNESS.LOW
        else
          brightness = GridConstants.BRIGHTNESS.DIM
        end
      end

      layers.ui[col][row] = brightness
    end
  end

  grid_ui.contains = function(self, x, y)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local length = get_length(lane_id)
    local num_rows = math.ceil(length / MAX_COLS)
    if x < GRID_X or x > GRID_X + MAX_COLS - 1 then return false end
    if y < GRID_Y or y > GRID_Y + num_rows - 1 then return false end
    local step = (y - GRID_Y) * MAX_COLS + (x - GRID_X) + 1
    return step <= length
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z ~= 1 then return end

    local lane_id = _seeker.ui_state.get_focused_lane()
    local step = (y - GRID_Y) * MAX_COLS + (x - GRID_X) + 1
    local length = get_length(lane_id)
    if step < 1 or step > length then return end

    local state = StepGrid.get_step_state(lane_id)

    state[step].active = not state[step].active
    StepGrid.rebuild_motif(lane_id)

    StepGrid.selected_step = step
    if _seeker.drums_type and _seeker.drums_type.home and _seeker.drums_type.home.screen then
      _seeker.ui_state.set_current_section("DRUMS_HOME")
      _seeker.drums_type.home.screen:rebuild_params()
    end

    _seeker.ui_state.register_activity()
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
  end

  return grid_ui
end

local function create_params()
  for _, i in ipairs(LaneMap.lanes_for_mode("drums")) do
    params:add_group("lane_" .. i .. "_drum_step", "LANE " .. i .. " DRUM STEPS", 9)

    params:add_number("lane_" .. i .. "_drum_length", "Length", 1, 32, 8)
    params:set_action("lane_" .. i .. "_drum_length", function(val)
      local hits = params:get("lane_" .. i .. "_drum_hits")
      if hits > val then params:set("lane_" .. i .. "_drum_hits", val) end
      StepGrid.apply_pattern(i)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_number("lane_" .. i .. "_drum_hits", "Hits", 0, 32, 4)
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

    params:add_number("lane_" .. i .. "_drum_rotation", "Rotation", 0, 31, 0)
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
