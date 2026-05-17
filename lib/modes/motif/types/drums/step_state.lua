-- step_state.lua
-- Data layer for drum step sequencer.
-- Call + response state, genesis snapshots, response strategies, and the pure motif builder.

local LaneMap = include("lib/lanes/lane_map")
local theory = include("lib/modes/motif/core/theory")

local StepState = {}

local MAX_COLS = 8
local ROWS_PER_LANE = 2
local MAX_STEPS = MAX_COLS * ROWS_PER_LANE

StepState.MAX_COLS = MAX_COLS
StepState.ROWS_PER_LANE = ROWS_PER_LANE
StepState.MAX_STEPS = MAX_STEPS

local DIVISION_OPTIONS = {"1/4", "1/3", "1/2", "2/3", "1", "3/2", "2", "3", "4"}
local DIVISION_VALUES = {0.25, 1/3, 0.5, 2/3, 1, 1.5, 2, 3, 4}

StepState.DIVISION_OPTIONS = DIVISION_OPTIONS
StepState.DIVISION_VALUES = DIVISION_VALUES

------------------------------------------------------------------------
-- Call State (the programmed pattern)
------------------------------------------------------------------------

local step_state = {}

local function init_lane_steps(lane_id)
  step_state[lane_id] = {}
  for i = 1, MAX_STEPS do
    step_state[lane_id][i] = { active = false, note = nil, velocity = 100, ratchet = 1 }
  end
end

local function ensure_state(lane_id)
  if not step_state[lane_id] then init_lane_steps(lane_id) end
  return step_state[lane_id]
end

function StepState.get_steps(lane_id)
  return ensure_state(lane_id)
end

function StepState.get_step(lane_id, step_index)
  return ensure_state(lane_id)[step_index]
end

function StepState.toggle_step(lane_id, step_index)
  ensure_state(lane_id)[step_index].active = not ensure_state(lane_id)[step_index].active
end

function StepState.set_step_field(lane_id, step_index, field, value)
  ensure_state(lane_id)[step_index][field] = value
end

------------------------------------------------------------------------
-- Response State
------------------------------------------------------------------------

local response_state = {}
local cr_enabled = {}
local cr_strategy = {}
local cr_playing_response = {}
local cr_editing_response = {}
local cr_editing_call = {}
local cr_response_manual = {}

local RESPONSE_STRATEGIES = {"Complement", "Sequence", "Invert", "Resolve", "Rotate"}
StepState.RESPONSE_STRATEGIES = RESPONSE_STRATEGIES

local function init_response_steps(lane_id)
  response_state[lane_id] = {}
  for i = 1, MAX_STEPS do
    response_state[lane_id][i] = { active = false, note = nil, velocity = 100, ratchet = 1 }
  end
end

local function ensure_response(lane_id)
  if not response_state[lane_id] then init_response_steps(lane_id) end
  return response_state[lane_id]
end

function StepState.get_response_steps(lane_id)
  return ensure_response(lane_id)
end

function StepState.get_response_step(lane_id, step_index)
  return ensure_response(lane_id)[step_index]
end

function StepState.is_cr_enabled(lane_id)
  return cr_enabled[lane_id] or false
end

function StepState.toggle_cr(lane_id)
  cr_enabled[lane_id] = not cr_enabled[lane_id]
  if cr_enabled[lane_id] then
    StepState.generate_response(lane_id)
  end
end

function StepState.get_cr_strategy(lane_id)
  return cr_strategy[lane_id] or 1
end

function StepState.get_cr_strategy_name(lane_id)
  return RESPONSE_STRATEGIES[StepState.get_cr_strategy(lane_id)]
end

function StepState.set_cr_strategy(lane_id, val)
  cr_strategy[lane_id] = val
end

function StepState.is_playing_response(lane_id)
  return cr_playing_response[lane_id] or false
end

function StepState.set_playing_response(lane_id, value)
  cr_playing_response[lane_id] = value
end

function StepState.is_viewing_response(lane_id)
  if cr_editing_call[lane_id] then return false end
  if cr_editing_response[lane_id] then return true end
  return cr_playing_response[lane_id] or false
end

function StepState.set_editing_response(lane_id, value)
  cr_editing_response[lane_id] = value
  if value then cr_editing_call[lane_id] = false end
end

function StepState.set_editing_call(lane_id, value)
  cr_editing_call[lane_id] = value
  if value then cr_editing_response[lane_id] = false end
end


------------------------------------------------------------------------
-- Response Strategies
------------------------------------------------------------------------

local function strategy_complement(call, response, length)
  for i = 1, length do
    response[i].active = not call[i].active
    response[i].note = call[i].note
    response[i].velocity = call[i].velocity
    response[i].ratchet = call[i].ratchet
  end
end

local function strategy_sequence(call, response, length)
  for i = 1, length do
    local src = ((i - 2) % length) + 1
    response[i].active = call[src].active
    response[i].note = call[src].note
    response[i].velocity = call[src].velocity
    response[i].ratchet = call[src].ratchet
  end
end

local function strategy_invert(call, response, length, lane_id)
  local scale = theory.get_scale()
  local center = StepState.get_default_note(lane_id)
  for i = 1, length do
    response[i].active = call[i].active
    response[i].velocity = call[i].velocity
    response[i].ratchet = call[i].ratchet
    local src_note = call[i].note or center
    local interval = src_note - center
    local mirrored = center - interval
    local best = scale[1]
    for _, sn in ipairs(scale) do
      if math.abs(sn - mirrored) < math.abs(best - mirrored) then
        best = sn
      end
    end
    response[i].note = best
  end
end

local function strategy_resolve(call, response, length, lane_id)
  local scale = theory.get_scale()
  local default_note = StepState.get_default_note(lane_id)

  -- Find the default note's position in the scale
  local tonic_pos = 1
  for si, sn in ipairs(scale) do
    if sn == default_note then tonic_pos = si; break end
    if sn > default_note then tonic_pos = math.max(1, si - 1); break end
  end

  -- How many steps form the scalar run (2-4 depending on length)
  local run_length = math.max(2, math.min(4, math.floor(length / 3)))

  for i = 1, length do
    response[i].active = call[i].active
    response[i].velocity = call[i].velocity
    response[i].ratchet = call[i].ratchet

    local steps_from_end = length - i
    if steps_from_end < run_length then
      local scale_offset = steps_from_end
      local pos = math.max(1, math.min(tonic_pos + scale_offset, #scale))
      response[i].note = scale[pos]
    else
      response[i].note = call[i].note
    end
  end
end

local function strategy_rotate(call, response, length)
  for i = 1, length do
    response[i].active = call[i].active
    response[i].velocity = call[i].velocity
    response[i].ratchet = call[i].ratchet
    local note_src = (i % length) + 1
    response[i].note = call[note_src].note
  end
end

function StepState.generate_response(lane_id)
  cr_response_manual[lane_id] = false
  local call = ensure_state(lane_id)
  local response = ensure_response(lane_id)
  local length = StepState.get_length(lane_id)
  local strategy = StepState.get_cr_strategy(lane_id)

  if strategy == 1 then
    strategy_complement(call, response, length)
  elseif strategy == 2 then
    strategy_sequence(call, response, length)
  elseif strategy == 3 then
    strategy_invert(call, response, length, lane_id)
  elseif strategy == 4 then
    strategy_resolve(call, response, length, lane_id)
  elseif strategy == 5 then
    strategy_rotate(call, response, length)
  end

  StepState.snapshot_response_genesis(lane_id)
end

------------------------------------------------------------------------
-- Active Layer (what the grid shows — follows playback)
------------------------------------------------------------------------

function StepState.get_active_steps(lane_id)
  if cr_playing_response[lane_id] then
    return ensure_response(lane_id)
  end
  return ensure_state(lane_id)
end

function StepState.get_active_step(lane_id, step_index)
  return StepState.get_active_steps(lane_id)[step_index]
end


------------------------------------------------------------------------
-- Selected Step
------------------------------------------------------------------------

StepState.selected_step = {}
StepState.held_step = nil

function StepState.get_selected_step(lane_id)
  return StepState.selected_step[lane_id] or 1
end

------------------------------------------------------------------------
-- Genesis Storage
------------------------------------------------------------------------

local genesis = {}
local response_genesis = {}
local mutation_loop_count = {}
local cycle_counter = {}

function StepState.deep_copy_steps(steps)
  local copy = {}
  for i, s in ipairs(steps) do
    copy[i] = { active = s.active, note = s.note, velocity = s.velocity, ratchet = s.ratchet }
  end
  return copy
end

function StepState.snapshot_genesis(lane_id)
  genesis[lane_id] = StepState.deep_copy_steps(ensure_state(lane_id))
  mutation_loop_count[lane_id] = 0
  cycle_counter[lane_id] = 0
  if cr_enabled[lane_id] and not cr_response_manual[lane_id] then
    StepState.generate_response(lane_id)
  end
end

function StepState.mark_response_manual(lane_id)
  cr_response_manual[lane_id] = true
end

function StepState.snapshot_response_genesis(lane_id)
  response_genesis[lane_id] = StepState.deep_copy_steps(ensure_response(lane_id))
end

function StepState.get_genesis(lane_id)
  if not genesis[lane_id] then
    StepState.snapshot_genesis(lane_id)
  end
  return genesis[lane_id]
end

function StepState.get_response_genesis(lane_id)
  if not response_genesis[lane_id] then
    StepState.snapshot_response_genesis(lane_id)
  end
  return response_genesis[lane_id]
end

function StepState.increment_mutation_loop(lane_id)
  mutation_loop_count[lane_id] = (mutation_loop_count[lane_id] or 0) + 1
end

function StepState.get_mutation_loop_count(lane_id)
  return mutation_loop_count[lane_id] or 0
end

function StepState.get_cycle_counter(lane_id)
  return cycle_counter[lane_id] or 0
end

------------------------------------------------------------------------
-- Param Helpers
------------------------------------------------------------------------

function StepState.get_length(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_length")
end

function StepState.get_division(lane_id)
  return DIVISION_VALUES[params:get("lane_" .. lane_id .. "_drum_division")]
end

function StepState.get_gate_pct(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_gate_length") / 100
end

function StepState.get_default_note(lane_id)
  local scale = theory.get_scale()
  local root_pc = scale[1] % 12
  local octave = lane_id and params:get("lane_" .. lane_id .. "_drum_base_octave") or 4
  local target = root_pc + octave * 12
  for _, sn in ipairs(scale) do
    if sn == target then return sn end
    if sn > target then return sn end
  end
  return target
end

------------------------------------------------------------------------
-- Playhead
------------------------------------------------------------------------

function StepState.get_current_step(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane or not lane.playing then return nil end
  local stage = lane.stages[lane.current_stage_index]
  if not stage or not stage.last_start_time then return nil end
  local division = StepState.get_division(lane_id)
  local length = StepState.get_length(lane_id)
  local duration = length * division
  local elapsed = (clock.get_beats() - stage.last_start_time) % duration
  local step = math.floor(elapsed / division) + 1
  return math.min(step, length)
end

------------------------------------------------------------------------
-- Pure Motif Builder
------------------------------------------------------------------------

function StepState.build_motif(steps, p)
  local events = {}
  local length = p.length
  local division = p.division
  local gate_pct = p.gate_pct
  local swing = p.swing or 0
  local probability = p.probability

  for i = 1, length do
    local s = steps[i]
    if s.active then
      local note = s.note or p.default_note
      local base_time = (i - 1) * division
      local col = ((i - 1) % MAX_COLS) + 1
      local row = p.row_start + math.floor((i - 1) / MAX_COLS)

      if i % 2 == 0 and swing > 0 then
        base_time = base_time + swing * division * 0.5
      end

      local ratchet_count = s.ratchet or 1
      local ratchet_interval = division / ratchet_count
      local gate = math.min(gate_pct * division, ratchet_interval * 0.9)

      for r = 1, ratchet_count do
        local time = base_time + (r - 1) * ratchet_interval

        events[#events + 1] = {
          time = time,
          type = "note_on",
          note = note,
          velocity = s.velocity,
          probability = probability < 100 and probability or nil,
          x = col,
          y = row,
          step = i,
        }
        events[#events + 1] = {
          time = time + gate,
          type = "note_off",
          note = note,
          step = i,
        }
      end
    end
  end

  return events, length * division
end

------------------------------------------------------------------------
-- Apply (side-effect shell)
------------------------------------------------------------------------

function StepState.apply_motif(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane then return end

  local local_index = lane_id - LaneMap.OFFSETS.drums
  local row_start = (local_index - 1) * ROWS_PER_LANE + 1

  local events, duration = StepState.build_motif(ensure_state(lane_id), {
    length       = StepState.get_length(lane_id),
    division     = StepState.get_division(lane_id),
    gate_pct     = StepState.get_gate_pct(lane_id),
    swing        = params:get("lane_" .. lane_id .. "_drum_swing") / 100,
    probability  = params:get("lane_" .. lane_id .. "_drum_probability"),
    default_note = StepState.get_default_note(lane_id),
    row_start    = row_start,
  })

  lane.motif.events = events
  lane.motif.duration = duration

  if lane.playing then
    local stage = lane.stages[lane.current_stage_index]
    local now = clock.get_beats()
    local loop_start = stage.last_start_time or now
    lane:sync_all_stages_from_params()
    _seeker.conductor.clear_events_for_lane(lane_id)
    lane:schedule_stage(lane.current_stage_index, loop_start, now)
  end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

function StepState.init()
  for _, lane_id in ipairs(LaneMap.lanes_for_mode("drums")) do
    init_lane_steps(lane_id)
    init_response_steps(lane_id)
  end
end

return StepState
