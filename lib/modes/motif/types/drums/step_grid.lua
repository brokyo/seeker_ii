-- step_grid.lua
-- 4-lane step grid for polymetric drum sequencer.
-- Three layers: step state (data), build_motif (pure function), grid UI (I/O).
-- Mutation engine: shape-preserving transforms over a triangle-wave depth cycle.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local LaneMap = include("lib/lanes/lane_map")
local musicutil = require('musicutil')
local theory = include("lib/modes/motif/core/theory")

local StepGrid = {}

local MAX_COLS = 8
local ROWS_PER_LANE = 2
local MAX_STEPS = MAX_COLS * ROWS_PER_LANE

local DIVISION_OPTIONS = {"1/4", "1/3", "1/2", "2/3", "1", "3/2", "2", "3", "4"}
local DIVISION_VALUES = {0.25, 1/3, 0.5, 2/3, 1, 1.5, 2, 3, 4}

------------------------------------------------------------------------
-- Step State
------------------------------------------------------------------------

local step_state = {}

local function init_lane_state(lane_id)
  step_state[lane_id] = {}
  for i = 1, MAX_STEPS do
    step_state[lane_id][i] = { active = false, note = nil, velocity = 100, ratchet = 1 }
  end
end

local function ensure_state(lane_id)
  if not step_state[lane_id] then init_lane_state(lane_id) end
  return step_state[lane_id]
end

function StepGrid.get_steps(lane_id)
  return ensure_state(lane_id)
end

function StepGrid.get_step(lane_id, step_index)
  return ensure_state(lane_id)[step_index]
end

function StepGrid.toggle_step(lane_id, step_index)
  local s = ensure_state(lane_id)[step_index]
  s.active = not s.active
  StepGrid.snapshot_genesis(lane_id)
end

function StepGrid.set_step_field(lane_id, step_index, field, value)
  ensure_state(lane_id)[step_index][field] = value
  StepGrid.snapshot_genesis(lane_id)
end

StepGrid.selected_step = {}
StepGrid.held_step = nil

function StepGrid.get_selected_step(lane_id)
  return StepGrid.selected_step[lane_id] or 1
end

------------------------------------------------------------------------
-- Genesis Storage
------------------------------------------------------------------------

local genesis = {}
local mutation_loop_count = {}
local cycle_counter = {}

local function deep_copy_steps(steps)
  local copy = {}
  for i, s in ipairs(steps) do
    copy[i] = { active = s.active, note = s.note, velocity = s.velocity, ratchet = s.ratchet }
  end
  return copy
end

function StepGrid.snapshot_genesis(lane_id)
  genesis[lane_id] = deep_copy_steps(ensure_state(lane_id))
  mutation_loop_count[lane_id] = 0
  cycle_counter[lane_id] = 0
end

function StepGrid.get_genesis(lane_id)
  if not genesis[lane_id] then
    StepGrid.snapshot_genesis(lane_id)
  end
  return genesis[lane_id]
end

function StepGrid.increment_mutation_loop(lane_id)
  mutation_loop_count[lane_id] = (mutation_loop_count[lane_id] or 0) + 1
end

function StepGrid.get_mutation_loop_count(lane_id)
  return mutation_loop_count[lane_id] or 0
end

function StepGrid.get_cycle_counter(lane_id)
  return cycle_counter[lane_id] or 0
end

------------------------------------------------------------------------
-- Param Helpers
------------------------------------------------------------------------

local function get_length(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_length")
end

local function get_division(lane_id)
  return DIVISION_VALUES[params:get("lane_" .. lane_id .. "_drum_division")]
end

local function get_gate_pct(lane_id)
  return params:get("lane_" .. lane_id .. "_drum_gate_length") / 100
end

local function get_voice_note(lane_id)
  local pos = params:get("lane_" .. lane_id .. "_drum_voice_note")
  local scale = theory.get_scale()
  return scale[math.max(1, math.min(pos, #scale))]
end

StepGrid.get_length = get_length
StepGrid.get_division = get_division
StepGrid.get_gate_pct = get_gate_pct
StepGrid.get_voice_note = get_voice_note

------------------------------------------------------------------------
-- Playhead
------------------------------------------------------------------------

local function get_current_step(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane or not lane.playing then return nil end
  local stage = lane.stages[lane.current_stage_index]
  if not stage or not stage.last_start_time then return nil end
  local division = get_division(lane_id)
  local length = get_length(lane_id)
  local duration = length * division
  local elapsed = (clock.get_beats() - stage.last_start_time) % duration
  local step = math.floor(elapsed / division) + 1
  return math.min(step, length)
end

StepGrid.get_current_step = get_current_step

------------------------------------------------------------------------
-- Mutation Engine
------------------------------------------------------------------------

function StepGrid.triangle_depth(loop_count, half_cycle)
  local full_cycle = half_cycle * 2
  local position = loop_count % full_cycle
  if position <= half_cycle then
    return position
  else
    return full_cycle - position
  end
end

local function mutation_seed(lane_id, cycle_num, depth_level, mutation_type)
  return lane_id * 100000 + cycle_num * 1000 + depth_level * 10 + mutation_type
end

local function mutate_displace(steps, length, intensity, lane_id, cycle_num, depth_level)
  math.randomseed(mutation_seed(lane_id, cycle_num, depth_level, 1))
  local max_swaps = math.max(1, math.floor(length / 4))
  local count = math.max(1, math.ceil(intensity / 100 * max_swaps))

  for _ = 1, count do
    local active_indices = {}
    for i = 1, length do
      if steps[i].active then active_indices[#active_indices + 1] = i end
    end
    if #active_indices == 0 then return end

    local idx = active_indices[math.random(#active_indices)]
    local direction = math.random(2) == 1 and 1 or -1
    local target = idx + direction
    if target < 1 then target = 2 end
    if target > length then target = length - 1 end
    if target < 1 or target > length then return end

    steps[idx], steps[target] = steps[target], steps[idx]
  end
end

local function mutate_pitch(steps, length, intensity, lane_id, cycle_num, depth_level, scale)
  math.randomseed(mutation_seed(lane_id, cycle_num, depth_level, 2))
  if not scale or #scale == 0 then return end

  local note_indices = {}
  for i = 1, length do
    if steps[i].note then note_indices[#note_indices + 1] = i end
  end
  if #note_indices == 0 then return end

  local max_drifts = math.max(1, #note_indices)
  local count = math.max(1, math.ceil(intensity / 100 * max_drifts))

  for c = 1, count do
    local idx = note_indices[((c - 1) % #note_indices) + 1]
    local midi = steps[idx].note
    local scale_pos = nil
    for si, sn in ipairs(scale) do
      if sn == midi then scale_pos = si; break end
      if sn > midi then scale_pos = math.max(1, si - 1); break end
    end
    if not scale_pos then scale_pos = #scale end

    local shift
    if intensity <= 33 then
      shift = math.random(2) == 1 and 1 or -1
    elseif intensity <= 66 then
      shift = math.random(-3, 3)
      if shift == 0 then shift = 1 end
    else
      -- Octave leap: find same pitch class one octave up or down
      local direction = math.random(2) == 1 and 1 or -1
      local pc = midi % 12
      local target_octave = math.floor(midi / 12) + direction
      local target_midi = pc + target_octave * 12
      -- Find nearest scale position to target
      shift = 0
      for si, sn in ipairs(scale) do
        if sn >= target_midi then
          shift = si - scale_pos
          break
        end
      end
      if shift == 0 then shift = direction * 7 end
    end

    local new_pos = math.max(1, math.min(scale_pos + shift, #scale))
    steps[idx].note = scale[new_pos]
  end
end

local function mutate_density(steps, length, intensity, lane_id, cycle_num, depth_level)
  math.randomseed(mutation_seed(lane_id, cycle_num, depth_level, 3))
  local max_toggles = math.max(1, math.floor(length / 4))
  local count = math.max(1, math.ceil(intensity / 100 * max_toggles))

  for _ = 1, count do
    local idx = math.random(1, length)
    steps[idx].active = not steps[idx].active
  end
end

function StepGrid.mutate_steps(genesis_steps, depth, intensities, lane_id, cycle_num, scale, length)
  local steps = deep_copy_steps(genesis_steps)
  if depth == 0 then return steps end

  for d = 1, depth do
    if intensities.displace > 0 then
      mutate_displace(steps, length, intensities.displace, lane_id, cycle_num, d)
    end
    if intensities.pitch > 0 then
      mutate_pitch(steps, length, intensities.pitch, lane_id, cycle_num, d, scale)
    end
    if intensities.density > 0 then
      mutate_density(steps, length, intensities.density, lane_id, cycle_num, d)
    end
  end

  return steps
end

------------------------------------------------------------------------
-- Pure Motif Builder
------------------------------------------------------------------------

function StepGrid.build_motif(steps, p)
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

function StepGrid.apply_motif(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane then return end

  local local_index = lane_id - LaneMap.OFFSETS.drums
  local row_start = (local_index - 1) * ROWS_PER_LANE + 1

  local events, duration = StepGrid.build_motif(ensure_state(lane_id), {
    length       = get_length(lane_id),
    division     = get_division(lane_id),
    gate_pct     = get_gate_pct(lane_id),
    swing        = params:get("lane_" .. lane_id .. "_drum_swing") / 100,
    probability  = params:get("lane_" .. lane_id .. "_drum_probability"),
    default_note = get_voice_note(lane_id),
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
-- Grid Helpers
------------------------------------------------------------------------

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

local function rebuild_current_drums_screen()
  local section = _seeker.ui_state.get_current_section()
  local sections = _seeker.drums_type and _seeker.drums_type.sections
  if sections and sections[section] and sections[section].rebuild_params then
    sections[section]:rebuild_params()
    sections[section]:filter_active_params()
  end
end

------------------------------------------------------------------------
-- Grid UI
------------------------------------------------------------------------

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "DRUMS_STEP_GRID",
    layout = { x = 1, y = 1, width = MAX_COLS, height = 8 }
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
      local length = get_length(lane_id)
      local steps = ensure_state(lane_id)
      local current_step = get_current_step(lane_id)

      for i = 1, MAX_STEPS do
        local col = ((i - 1) % MAX_COLS) + 1
        local row = row_start + math.floor((i - 1) / MAX_COLS)

        if i <= length then
          local s = steps[i]
          local brightness

          if current_step == i then
            brightness = s.active and GridConstants.BRIGHTNESS.FULL or GridConstants.BRIGHTNESS.MEDIUM
          elseif s.active then
            brightness = GridConstants.BRIGHTNESS.HIGH
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
    end
  end

  grid_ui.contains = function(self, x, y)
    return x >= 1 and x <= MAX_COLS and y >= 1 and y <= 8
  end

  grid_ui.handle_key = function(self, x, y, z)
    local lane_id, step = xy_to_lane_step(x, y)
    if not lane_id then return end

    local key_id = string.format("%d,%d", x, y)
    local length = get_length(lane_id)

    if z == 1 then
      self:key_down(key_id)
      if step <= length then
        StepGrid.held_step = { lane_id = lane_id, step = step }
      end
      _seeker.ui_state.register_activity()
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
      return
    end

    local was_long = self:is_long_press(key_id)
    self:key_release(key_id)
    StepGrid.held_step = nil

    if step <= length then
      if was_long then
        _seeker.ui_state.set_focused_lane(lane_id)
        StepGrid.selected_step[lane_id] = step
        _seeker.ui_state.set_current_section("DRUMS_HOME")
        rebuild_current_drums_screen()
      else
        StepGrid.toggle_step(lane_id, step)
        StepGrid.apply_motif(lane_id)
        _seeker.ui_state.set_focused_lane(lane_id)
        rebuild_current_drums_screen()
      end
    end

    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
  end

  return grid_ui
end

------------------------------------------------------------------------
-- Params
------------------------------------------------------------------------

local function create_params()
  for _, lane_id in ipairs(LaneMap.lanes_for_mode("drums")) do
    params:add_group("lane_" .. lane_id .. "_drum_step", "LANE " .. lane_id .. " DRUM STEPS", 10)

    params:add_number("lane_" .. lane_id .. "_drum_length", "Length", 1, 16, 8)
    params:set_action("lane_" .. lane_id .. "_drum_length", function()
      StepGrid.snapshot_genesis(lane_id)
      StepGrid.apply_motif(lane_id)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_option("lane_" .. lane_id .. "_drum_division", "Division", DIVISION_OPTIONS, 5)
    params:set_action("lane_" .. lane_id .. "_drum_division", function()
      StepGrid.apply_motif(lane_id)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_number("lane_" .. lane_id .. "_drum_voice_note", "Voice Note", 1, 128, 36,
      function(param)
        local s = theory.get_scale()
        local midi = s[math.max(1, math.min(param:get(), #s))]
        return midi and musicutil.note_num_to_name(midi, true) or "?"
      end)
    params:set_action("lane_" .. lane_id .. "_drum_voice_note", function()
      StepGrid.apply_motif(lane_id)
    end)

    params:add_number("lane_" .. lane_id .. "_drum_gate_length", "Gate Length", 1, 100, 50,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. lane_id .. "_drum_gate_length", function()
      StepGrid.apply_motif(lane_id)
    end)

    params:add_number("lane_" .. lane_id .. "_drum_swing", "Swing", 0, 100, 0,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. lane_id .. "_drum_swing", function()
      StepGrid.apply_motif(lane_id)
    end)

    params:add_number("lane_" .. lane_id .. "_drum_probability", "Probability", 0, 100, 100,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. lane_id .. "_drum_probability", function()
      StepGrid.apply_motif(lane_id)
    end)

    params:add_number("lane_" .. lane_id .. "_drum_reseed", "Mutate Cycle", 0, 32, 0,
      function(param)
        local v = param:get()
        return v == 0 and "off" or (v .. " loops")
      end)

    params:add_number("lane_" .. lane_id .. "_drum_mutate_displace", "Mut: Displace", 0, 100, 0,
      function(param) return param:get() .. "%" end)

    params:add_number("lane_" .. lane_id .. "_drum_mutate_pitch", "Mut: Pitch", 0, 100, 0,
      function(param) return param:get() .. "%" end)

    params:add_number("lane_" .. lane_id .. "_drum_mutate_density", "Mut: Density", 0, 100, 0,
      function(param) return param:get() .. "%" end)
  end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

function StepGrid.init()
  for _, lane_id in ipairs(LaneMap.lanes_for_mode("drums")) do
    init_lane_state(lane_id)
  end
  create_params()
  return {
    grid = create_grid_ui()
  }
end

return StepGrid
