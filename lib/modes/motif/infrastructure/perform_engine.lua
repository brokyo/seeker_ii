-- perform_engine.lua
-- Shared performance effect engine for all motif types
-- Hold-to-activate controls organized by category:
--   Velocity: Mute, Gain, Gate
--   Pattern: Compress, Splice, Double, Reverse

local PerformEngine = {}

-- Mode categories and options
PerformEngine.VELOCITY_MODES = {"Mute", "Gain", "Gate"}
PerformEngine.PATTERN_MODES = {"Compress", "Splice", "Double", "Reverse"}

-- State per lane (shared across all motif types)
local lane_state = {}

local function get_lane_state(lane_id)
  if not lane_state[lane_id] then
    lane_state[lane_id] = {
      active = false,
      activation_beat = 0,
      compress_clock = nil,
      splice_clock = nil,
      gate_clock = nil,
      gate_open = true,
      double_clock = nil,
      reverse_clock = nil,
      original_speed_index = nil
    }
  end
  return lane_state[lane_id]
end

-- Returns the mode name for a lane based on its category
function PerformEngine.get_mode(lane_id, param_prefix)
  local category = params:string(param_prefix .. "_category")
  local mode_index = params:get(param_prefix .. "_mode")
  local modes = category == "Velocity" and PerformEngine.VELOCITY_MODES or PerformEngine.PATTERN_MODES
  local clamped_index = math.min(mode_index, #modes)
  return modes[clamped_index]
end

-- Returns velocity multiplier based on active performance mode and slew progress
function PerformEngine.get_velocity_multiplier(lane_id, param_prefix)
  local state = get_lane_state(lane_id)
  if not state.active then
    return 1.0
  end

  local mode = PerformEngine.get_mode(lane_id, param_prefix)
  local target = 1.0
  local slew_time = 0

  if mode == "Mute" then
    target = 0.0
    slew_time = params:get(param_prefix .. "_mute_slew")
  elseif mode == "Gain" then
    target = params:get(param_prefix .. "_gain_amount")
    slew_time = params:get(param_prefix .. "_gain_slew")
  elseif mode == "Gate" then
    local floor = params:get(param_prefix .. "_gate_floor") / 100
    return state.gate_open and 1.0 or floor
  end

  if slew_time <= 0 then
    return target
  end

  local elapsed = clock.get_beat_sec() * (clock.get_beats() - state.activation_beat)
  local progress = math.min(1.0, elapsed / slew_time)
  return 1.0 + (target - 1.0) * progress
end

function PerformEngine.is_muted(lane_id, param_prefix)
  local state = get_lane_state(lane_id)
  local mode = PerformEngine.get_mode(lane_id, param_prefix)
  return state.active and mode == "Mute"
end

function PerformEngine.is_active(lane_id)
  local state = get_lane_state(lane_id)
  return state.active
end

function PerformEngine.set_active(lane_id, active)
  local state = get_lane_state(lane_id)
  state.active = active
  if active then
    state.activation_beat = clock.get_beats()
  end
  if _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

-- Start compress: loop entire pattern compressed into window
function PerformEngine.start_compress(lane_id, param_prefix)
  local state = get_lane_state(lane_id)
  local lane = _seeker.lanes[lane_id]

  if not lane.playing or #lane.motif.events == 0 then
    return
  end

  local window_beats = params:get(param_prefix .. "_compress_window")

  _seeker.conductor.clear_events_for_lane(lane_id)

  state.compress_clock = clock.run(function()
    while state.active do
      local loop_start = clock.get_beats()
      local speed = lane.speed

      for _, event in ipairs(lane.motif.events) do
        if event.type == "note_on" then
          local event_time_in_window = (event.time % window_beats) / speed
          local absolute_time = loop_start + event_time_in_window

          _seeker.conductor.insert_event({
            time = absolute_time,
            lane_id = lane_id,
            type = "note_on",
            callback = function()
              if state.active then
                lane:on_note_on({
                  note = event.note,
                  velocity = event.velocity,
                  x = event.x,
                  y = event.y,
                  is_playback = true,
                  attack = event.attack,
                  decay = event.decay,
                  sustain = event.sustain,
                  release = event.release,
                  pan = event.pan
                })
              end
            end
          })

          local note_duration = 0.1 / speed
          _seeker.conductor.insert_event({
            time = absolute_time + note_duration,
            lane_id = lane_id,
            type = "note_off",
            callback = function()
              if state.active then
                lane:on_note_off({
                  note = event.note,
                  velocity = 0,
                  x = event.x,
                  y = event.y,
                  is_playback = true
                })
              end
            end
          })
        end
      end

      clock.sync(window_beats / speed)
    end
  end)
end

function PerformEngine.stop_compress(lane_id)
  local state = get_lane_state(lane_id)
  local lane = _seeker.lanes[lane_id]

  if state.compress_clock then
    clock.cancel(state.compress_clock)
    state.compress_clock = nil
  end

  _seeker.conductor.clear_events_for_lane(lane_id)

  if lane.playing then
    lane.stages[lane.current_stage_index].current_loop = 0
    lane:schedule_stage(lane.current_stage_index, clock.get_beats())
  end
end

-- Start splice: loop only events within window from start of pattern
function PerformEngine.start_splice(lane_id, param_prefix)
  local state = get_lane_state(lane_id)
  local lane = _seeker.lanes[lane_id]

  if not lane.playing or #lane.motif.events == 0 then
    return
  end

  local window_beats = params:get(param_prefix .. "_splice_window")

  _seeker.conductor.clear_events_for_lane(lane_id)

  state.splice_clock = clock.run(function()
    while state.active do
      local loop_start = clock.get_beats()
      local speed = lane.speed

      for _, event in ipairs(lane.motif.events) do
        if event.type == "note_on" and event.time < window_beats then
          local absolute_time = loop_start + (event.time / speed)

          _seeker.conductor.insert_event({
            time = absolute_time,
            lane_id = lane_id,
            type = "note_on",
            callback = function()
              if state.active then
                lane:on_note_on({
                  note = event.note,
                  velocity = event.velocity,
                  x = event.x,
                  y = event.y,
                  is_playback = true,
                  attack = event.attack,
                  decay = event.decay,
                  sustain = event.sustain,
                  release = event.release,
                  pan = event.pan
                })
              end
            end
          })

          local note_off_time = window_beats
          for _, off_event in ipairs(lane.motif.events) do
            if off_event.type == "note_off" and off_event.note == event.note and off_event.time > event.time then
              note_off_time = math.min(off_event.time, window_beats)
              break
            end
          end

          _seeker.conductor.insert_event({
            time = loop_start + (note_off_time / speed),
            lane_id = lane_id,
            type = "note_off",
            callback = function()
              if state.active then
                lane:on_note_off({
                  note = event.note,
                  velocity = 0,
                  x = event.x,
                  y = event.y,
                  is_playback = true
                })
              end
            end
          })
        end
      end

      clock.sync(window_beats / speed)
    end
  end)
end

function PerformEngine.stop_splice(lane_id)
  local state = get_lane_state(lane_id)
  local lane = _seeker.lanes[lane_id]

  if state.splice_clock then
    clock.cancel(state.splice_clock)
    state.splice_clock = nil
  end

  _seeker.conductor.clear_events_for_lane(lane_id)

  if lane.playing then
    lane.stages[lane.current_stage_index].current_loop = 0
    lane:schedule_stage(lane.current_stage_index, clock.get_beats())
  end
end

-- Start gate: rhythmically open/close based on rate and duty cycle
function PerformEngine.start_gate(lane_id, param_prefix)
  local state = get_lane_state(lane_id)

  local rate = params:get(param_prefix .. "_gate_rate")
  local duty = params:get(param_prefix .. "_gate_duty") / 100

  state.gate_open = true

  state.gate_clock = clock.run(function()
    while state.active do
      state.gate_open = true
      clock.sync(rate * duty)

      state.gate_open = false
      clock.sync(rate * (1 - duty))
    end
  end)
end

function PerformEngine.stop_gate(lane_id)
  local state = get_lane_state(lane_id)

  if state.gate_clock then
    clock.cancel(state.gate_clock)
    state.gate_clock = nil
  end

  state.gate_open = true
end

-- Temporarily change playback speed while held
function PerformEngine.start_double(lane_id, param_prefix)
  local state = get_lane_state(lane_id)
  local lane = _seeker.lanes[lane_id]

  state.original_speed_index = params:get("lane_" .. lane_id .. "_speed")

  local multiplier = params:get(param_prefix .. "_double_speed")
  local target_speed = lane.speed * multiplier

  local speed_values = {0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1, 1.25, 1.5, 1.75, 2, 3, 4, 5, 6, 7, 8}
  local best_index = 1
  for i, val in ipairs(speed_values) do
    if val >= target_speed then
      best_index = i
      break
    end
    best_index = i
  end

  params:set("lane_" .. lane_id .. "_speed", best_index)
end

function PerformEngine.stop_double(lane_id)
  local state = get_lane_state(lane_id)

  if state.original_speed_index then
    params:set("lane_" .. lane_id .. "_speed", state.original_speed_index)
    state.original_speed_index = nil
  end
end

-- Play pattern backwards while held by reversing event times
function PerformEngine.start_reverse(lane_id)
  local state = get_lane_state(lane_id)
  local lane = _seeker.lanes[lane_id]

  if not lane.playing or #lane.motif.events == 0 then
    return
  end

  _seeker.conductor.clear_events_for_lane(lane_id)

  local motif_duration = lane.motif.duration
  local speed = lane.speed

  state.reverse_clock = clock.run(function()
    while state.active do
      local loop_start = clock.get_beats()

      for _, event in ipairs(lane.motif.events) do
        if event.type == "note_on" then
          local reversed_time = (motif_duration - event.time) / speed
          local absolute_time = loop_start + reversed_time

          _seeker.conductor.insert_event({
            time = absolute_time,
            lane_id = lane_id,
            type = "note_on",
            callback = function()
              if state.active then
                lane:on_note_on({
                  note = event.note,
                  velocity = event.velocity,
                  x = event.x,
                  y = event.y,
                  is_playback = true,
                  attack = event.attack,
                  decay = event.decay,
                  sustain = event.sustain,
                  release = event.release,
                  pan = event.pan
                })
              end
            end
          })

          local note_duration = 0.1 / speed
          _seeker.conductor.insert_event({
            time = absolute_time + note_duration,
            lane_id = lane_id,
            type = "note_off",
            callback = function()
              if state.active then
                lane:on_note_off({
                  note = event.note,
                  velocity = 0,
                  x = event.x,
                  y = event.y,
                  is_playback = true
                })
              end
            end
          })
        end
      end

      clock.sync(motif_duration / speed)
    end
  end)
end

function PerformEngine.stop_reverse(lane_id)
  local state = get_lane_state(lane_id)
  local lane = _seeker.lanes[lane_id]

  if state.reverse_clock then
    clock.cancel(state.reverse_clock)
    state.reverse_clock = nil
  end

  _seeker.conductor.clear_events_for_lane(lane_id)

  if lane.playing then
    lane.stages[lane.current_stage_index].current_loop = 0
    lane:schedule_stage(lane.current_stage_index, clock.get_beats())
  end
end

-- Start effect based on current mode
function PerformEngine.start_effect(lane_id, param_prefix)
  local mode = PerformEngine.get_mode(lane_id, param_prefix)

  if mode == "Compress" then
    PerformEngine.start_compress(lane_id, param_prefix)
  elseif mode == "Splice" then
    PerformEngine.start_splice(lane_id, param_prefix)
  elseif mode == "Gate" then
    PerformEngine.start_gate(lane_id, param_prefix)
  elseif mode == "Double" then
    PerformEngine.start_double(lane_id, param_prefix)
  elseif mode == "Reverse" then
    PerformEngine.start_reverse(lane_id)
  end
end

-- Stop effect based on current mode
function PerformEngine.stop_effect(lane_id, param_prefix)
  local mode = PerformEngine.get_mode(lane_id, param_prefix)

  if mode == "Compress" then
    PerformEngine.stop_compress(lane_id)
  elseif mode == "Splice" then
    PerformEngine.stop_splice(lane_id)
  elseif mode == "Gate" then
    PerformEngine.stop_gate(lane_id)
  elseif mode == "Double" then
    PerformEngine.stop_double(lane_id)
  elseif mode == "Reverse" then
    PerformEngine.stop_reverse(lane_id)
  end
end

-- Create params for a lane with given prefix
-- param_prefix should be like "lane_1_tape_performance"
function PerformEngine.create_params_for_lane(i, param_prefix, group_name, rebuild_callback)
  params:add_group(param_prefix, group_name, 11)

  params:add_option(param_prefix .. "_category", "Category", {"Velocity", "Pattern"}, 1)
  params:set_action(param_prefix .. "_category", function()
    params:set(param_prefix .. "_mode", 1)
    if rebuild_callback then rebuild_callback() end
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)

  params:add_option(param_prefix .. "_mode", "Mode", {"1", "2", "3", "4"}, 1)
  params:set_action(param_prefix .. "_mode", function()
    if rebuild_callback then rebuild_callback() end
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)

  -- Velocity mode: Mute
  params:add_control(param_prefix .. "_mute_slew", "Mute Slew",
    controlspec.new(0.0, 5.0, 'lin', 0.01, 0.0, "s"))

  -- Velocity mode: Gain
  params:add_control(param_prefix .. "_gain_amount", "Gain",
    controlspec.new(0.1, 2.0, 'lin', 0.01, 1.5, "x"))
  params:add_control(param_prefix .. "_gain_slew", "Gain Slew",
    controlspec.new(0.0, 5.0, 'lin', 0.01, 0.0, "s"))

  -- Velocity mode: Gate
  params:add_control(param_prefix .. "_gate_rate", "Gate Rate",
    controlspec.new(0.0625, 2, 'lin', 0.0625, 0.25, "beats"))
  params:add_control(param_prefix .. "_gate_duty", "Gate Duty",
    controlspec.new(10, 90, 'lin', 1, 50, "%"))
  params:add_control(param_prefix .. "_gate_floor", "Gate Floor",
    controlspec.new(0, 100, 'lin', 1, 0, "%"))

  -- Pattern mode: Compress
  params:add_control(param_prefix .. "_compress_window", "Compress Window",
    controlspec.new(0.125, 12, 'lin', 0.0625, 1, "beats"))

  -- Pattern mode: Splice
  params:add_control(param_prefix .. "_splice_window", "Splice Window",
    controlspec.new(0.125, 12, 'lin', 0.0625, 1, "beats"))

  -- Pattern mode: Double
  params:add_control(param_prefix .. "_double_speed", "Speed",
    controlspec.new(0.25, 4, 'lin', 0.25, 2, "x"))
end

-- Build param table for UI based on current mode
function PerformEngine.build_param_table(lane_id, param_prefix)
  local mode = PerformEngine.get_mode(lane_id, param_prefix)

  local param_table = {
    { separator = true, title = "Performance" },
    { id = param_prefix .. "_category" },
    { id = param_prefix .. "_mode", custom_name = "Mode", custom_value = mode },
  }

  if mode == "Mute" then
    table.insert(param_table, { id = param_prefix .. "_mute_slew", arc_multi_float = {1.0, 0.1, 0.01} })
  elseif mode == "Gain" then
    table.insert(param_table, { id = param_prefix .. "_gain_amount", arc_multi_float = {0.1, 0.05, 0.01} })
    table.insert(param_table, { id = param_prefix .. "_gain_slew", arc_multi_float = {1.0, 0.1, 0.01} })
  elseif mode == "Gate" then
    table.insert(param_table, { id = param_prefix .. "_gate_rate", arc_multi_float = {0.25, 0.125, 0.0625} })
    table.insert(param_table, { id = param_prefix .. "_gate_duty", arc_multi_float = {10, 5, 1} })
    table.insert(param_table, { id = param_prefix .. "_gate_floor", arc_multi_float = {10, 5, 1} })
  elseif mode == "Compress" then
    table.insert(param_table, { id = param_prefix .. "_compress_window", arc_multi_float = {1, 0.25, 0.0625} })
  elseif mode == "Splice" then
    table.insert(param_table, { id = param_prefix .. "_splice_window", arc_multi_float = {1, 0.25, 0.0625} })
  elseif mode == "Double" then
    table.insert(param_table, { id = param_prefix .. "_double_speed", arc_multi_float = {0.5, 0.25, 0.25} })
  end

  return param_table
end

return PerformEngine
