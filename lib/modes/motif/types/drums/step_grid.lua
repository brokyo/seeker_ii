-- step_grid.lua
-- 4-lane step grid for polymetric drum sequencer.
-- Three layers: step state (data), build_motif (pure function), grid UI (I/O).

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
    step_state[lane_id][i] = { active = false, note = nil, velocity = 100 }
  end
end

function StepGrid.get_steps(lane_id)
  return step_state[lane_id]
end

function StepGrid.get_step(lane_id, step_index)
  return step_state[lane_id][step_index]
end

function StepGrid.toggle_step(lane_id, step_index)
  local s = step_state[lane_id][step_index]
  s.active = not s.active
end

function StepGrid.set_step_field(lane_id, step_index, field, value)
  step_state[lane_id][step_index][field] = value
end

StepGrid.selected_step = {}

function StepGrid.get_selected_step(lane_id)
  return StepGrid.selected_step[lane_id] or 1
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
-- Pure Motif Builder
------------------------------------------------------------------------

function StepGrid.build_motif(steps, p)
  local events = {}
  local length = p.length
  local division = p.division
  local gate = math.min(p.gate_pct * division, division * 0.95)

  for i = 1, length do
    local s = steps[i]
    if s.active then
      local note = s.note or p.default_note
      local time = (i - 1) * division
      local col = ((i - 1) % MAX_COLS) + 1
      local row = p.row_start + math.floor((i - 1) / MAX_COLS)

      events[#events + 1] = {
        time = time,
        type = "note_on",
        note = note,
        velocity = s.velocity,
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

  return events, length * division
end

------------------------------------------------------------------------
-- Apply (side-effect shell)
------------------------------------------------------------------------

function StepGrid.apply_motif(lane_id)
  local lane = _seeker.lanes[lane_id]
  if not lane then return end
  if not step_state[lane_id] then init_lane_state(lane_id) end

  local local_index = lane_id - LaneMap.OFFSETS.drums
  local row_start = (local_index - 1) * ROWS_PER_LANE + 1

  local events, duration = StepGrid.build_motif(step_state[lane_id], {
    length       = get_length(lane_id),
    division     = get_division(lane_id),
    gate_pct     = get_gate_pct(lane_id),
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
        end
      end
      break
    end

    for _, lane_id in ipairs(lane_ids) do
      local local_index = lane_id - LaneMap.OFFSETS.drums
      local row_start = (local_index - 1) * ROWS_PER_LANE + 1
      local length = get_length(lane_id)
      local steps = step_state[lane_id]
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
      _seeker.ui_state.register_activity()
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
      return
    end

    local was_long = self:is_long_press(key_id)
    self:key_release(key_id)

    if step <= length then
      if was_long then
        _seeker.ui_state.set_focused_lane(lane_id)
        StepGrid.selected_step[lane_id] = step
        _seeker.ui_state.set_current_section("DRUMS_HOME")
      else
        StepGrid.toggle_step(lane_id, step)
        StepGrid.apply_motif(lane_id)
        _seeker.ui_state.set_focused_lane(lane_id)
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
    params:add_group("lane_" .. lane_id .. "_drum_step", "LANE " .. lane_id .. " DRUM STEPS", 4)

    params:add_number("lane_" .. lane_id .. "_drum_length", "Length", 1, 16, 8)
    params:set_action("lane_" .. lane_id .. "_drum_length", function()
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
