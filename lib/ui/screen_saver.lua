-- screen_saver.lua
local ScreenSaver = {}

ScreenSaver.state = {
  is_active = false,
  manual = false,  -- true when in cycling live view (COMPOSER_CYCLING section)
  mode = "cycling",  -- "background", "cv_monitor", "cycling"
  timeout_seconds = 90,
  lines = {},
  cv_selected = { source = "crow", num = 1 },
  cycling_edit_stage = nil,  -- nil = follow playback, 1-8 = explicit stage selection
  cycling_control_mode = "chord",  -- "chord" = per-stage, "progression" = global
  -- Scan line configuration
  config = {
    num_lines = 4,
    min_speed = 0.3,
    max_speed = 0.8,
    line_width = 1,
    max_brightness = 12,
    fade_length = 4,
    wave_amplitude = 4,
    wave_frequency = 0.5,
    line_resolution = 8,
    fps = 30
  }
}

-- Initialize a scan line
local function init_line(force_direction)
  local config = ScreenSaver.state.config
  local going_up = force_direction or (math.random() > 0.5)
  
  return {
    y = going_up and 64 or 0,  -- Start at top or bottom
    going_up = going_up,
    speed = config.min_speed + (math.random() * (config.max_speed - config.min_speed)),
    phase = math.random() * 2 * math.pi,  -- Random starting phase for wave
    wave_freq = config.wave_frequency * (0.8 + math.random() * 0.4)  -- Slightly varied frequencies
  }
end

-- Screensaver display modes, cycled with K2
local MODES = {"background", "cv_monitor", "cycling"}

function ScreenSaver.next_mode()
  local current = ScreenSaver.state.mode
  for i, m in ipairs(MODES) do
    if m == current then
      ScreenSaver.state.mode = MODES[(i % #MODES) + 1]
      ScreenSaver._sync_arc_override()
      return
    end
  end
  ScreenSaver.state.mode = MODES[1]
  ScreenSaver._sync_arc_override()
end


function ScreenSaver.init()
  ScreenSaver.state.lines = {}
  
  -- Initialize lines, alternating directions
  for i = 1, ScreenSaver.state.config.num_lines do
    table.insert(ScreenSaver.state.lines, init_line(i % 2 == 0))
  end
  
  return ScreenSaver
end

-- Convert screensaver_timeout option index to seconds (0 = disabled)
local function get_timeout_seconds()
  local timeout_values = {0, 5, 15, 30, 45, 60, 75, 90, 105, 120}
  local option = params:get("screensaver_timeout")
  return timeout_values[option] or 0
end

-- Pick initial cv_selected based on eurorack selection params, falling
-- back to the first active output if the current selection is inactive.
function ScreenSaver._auto_select_cv_output()
  local crow_states = {}
  local txo_states = {}
  if _seeker.eurorack and _seeker.eurorack.crow_output then
    crow_states = _seeker.eurorack.crow_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.txo_cv_output then
    txo_states = _seeker.eurorack.txo_cv_output.get_cv_states()
  end

  -- Try current eurorack selection (Crow=1, TXO TR=2, TXO CV=3)
  if params.lookup["eurorack_selected_type"] then
    local type_idx = params:get("eurorack_selected_type") or 1
    local num = params:get("eurorack_selected_number") or 1
    local source = (type_idx == 1) and "crow" or (type_idx == 3) and "txo_cv" or nil
    if source then
      local states = (source == "crow") and crow_states or txo_states
      if states[num] and states[num].active then
        ScreenSaver.state.cv_selected = { source = source, num = num }
        return
      end
    end
  end

  -- Fall back to first active output (crow then txo)
  for i = 1, 4 do
    if crow_states[i] and crow_states[i].active then
      ScreenSaver.state.cv_selected = { source = "crow", num = i }
      return
    end
  end
  for i = 1, 4 do
    if txo_states[i] and txo_states[i].active then
      ScreenSaver.state.cv_selected = { source = "txo_cv", num = i }
      return
    end
  end
end

function ScreenSaver.check_timeout()
  -- Manual live view (cycling section) — bypass all timeout logic
  if ScreenSaver.state.manual then
    return ScreenSaver.state.is_active
  end

  -- Check if screensaver is enabled
  local timeout_seconds = get_timeout_seconds()
  if timeout_seconds == 0 then
    ScreenSaver.state.is_active = false
    return false
  end

  -- Don't activate while modal is open
  if _seeker.modal and _seeker.modal.is_active() then
    ScreenSaver.state.is_active = false
    return false
  end

  local time_since_last_action = util.time() - _seeker.ui_state.state.last_action_time
  local should_be_active = time_since_last_action > timeout_seconds

  -- Update active state if it changed
  if should_be_active ~= ScreenSaver.state.is_active then
    ScreenSaver.state.is_active = should_be_active

    -- Reset arc override when screensaver deactivates
    if not should_be_active then
      ScreenSaver._clear_arc_override()
    end

    -- Set mode and arc override when screensaver activates
    if should_be_active then
      if _seeker.current_mode == "EURORACK_OUTPUT" then
        ScreenSaver.state.mode = "cv_monitor"
        ScreenSaver._auto_select_cv_output()
      elseif _seeker.current_mode == "motif" then
        ScreenSaver.state.mode = "cycling"
      else
        ScreenSaver.state.mode = "background"
      end
      ScreenSaver._sync_arc_override()
    end

    -- Dismiss any active modal when screensaver activates
    if should_be_active and _seeker.modal and _seeker.modal.is_active() then
      _seeker.modal.dismiss()
    end
  end

  return ScreenSaver.state.is_active
end

-- Draw the screensaver background (scan lines and timelines) without screen.update()
function ScreenSaver._draw_background()
  -- Draw scan lines background
  for _, line in ipairs(ScreenSaver.state.lines) do
    -- Update position
    local delta = line.going_up and -line.speed or line.speed
    line.y = line.y + delta
    line.phase = (line.phase + line.wave_freq) % (2 * math.pi)

    -- Reset if off screen
    if (line.going_up and line.y < -ScreenSaver.state.config.fade_length) or
       (not line.going_up and line.y > 64 + ScreenSaver.state.config.fade_length) then
      local new_line = init_line(line.going_up)
      for k,v in pairs(new_line) do line[k] = v end
    end

    -- Draw main line and fade trail
    for i = 0, ScreenSaver.state.config.fade_length do
      local fade_y = line.going_up and line.y + i or line.y - i

      if fade_y >= 0 and fade_y <= 64 then
        local wave_offset = math.sin(line.phase + (i * 0.2)) * ScreenSaver.state.config.wave_amplitude
        local brightness = math.floor(ScreenSaver.state.config.max_brightness *
          (1 - (i / ScreenSaver.state.config.fade_length)))

        screen.level(brightness)
        screen.move(0, fade_y)

        for x = 0, 128, ScreenSaver.state.config.line_resolution do
          local y_offset = wave_offset * math.sin(x * 0.05 + line.phase)
          screen.line(x, fade_y + y_offset)
        end
        screen.stroke()
      end
    end
  end

  -- Collect active lanes
  local active_lanes = {}
  for lane_idx = 1, _seeker.num_lanes do
    local lane = _seeker.lanes[lane_idx]
    if lane.motif and #lane.motif.events > 0 then
      table.insert(active_lanes, {idx = lane_idx, lane = lane})
    end
  end

  -- Only draw timelines if we have active lanes
  if #active_lanes > 0 then
    -- Layout constants
    local MARGIN_TOP = 8
    local MARGIN_BOTTOM = 8
    local MARGIN_LEFT = 12
    local MARGIN_RIGHT = 12
    local GAP = 4

    local available_height = 64 - MARGIN_TOP - MARGIN_BOTTOM
    local lane_height = math.floor((available_height - (GAP * (#active_lanes - 1))) / #active_lanes)
    local timeline_width = 128 - MARGIN_LEFT - MARGIN_RIGHT
    local use_piano_roll = #active_lanes < 5

    -- Draw each lane's timeline
    for i, active_lane in ipairs(active_lanes) do
      local lane = active_lane.lane
      local motif = lane.motif
      local y_pos = MARGIN_TOP + ((i - 1) * (lane_height + GAP))

      -- Get loop duration
      local loop_duration = motif:get_duration()

      -- Draw grey background for timeline
      screen.level(2)
      screen.rect(MARGIN_LEFT, y_pos, timeline_width, lane_height)
      screen.fill()

      -- Draw timeline border
      screen.level(3)
      screen.rect(MARGIN_LEFT, y_pos, timeline_width, lane_height)
      screen.stroke()

      -- Draw stage indicator dots (count active stages)
      local num_stages = #lane.stages
      local dot_x = MARGIN_LEFT + 3
      local dot_spacing = (lane_height - 4) / (num_stages - 1)
      local current_stage = lane.current_stage_index or 1

      for stage = 1, num_stages do
        local dot_y = y_pos + 2 + ((stage - 1) * dot_spacing)
        local is_active = (stage == current_stage)
        screen.level(is_active and 15 or 3)
        screen.circle(dot_x, dot_y, 1)
        screen.fill()
      end

      -- Find max generation and note range for brightness scaling and piano roll
      local max_gen = 1
      local min_note = 127
      local max_note = 0
      for _, event in ipairs(motif.events) do
        if event.generation and event.generation > max_gen then
          max_gen = event.generation
        end
        if event.type == "note_on" then
          if event.note < min_note then min_note = event.note end
          if event.note > max_note then max_note = event.note end
        end
      end

      -- Match note_on with note_off events to show duration
      local note_pairs = {}
      for _, event in ipairs(motif.events) do
        if event.type == "note_on" then
          -- Find matching note_off
          local note_off_time = nil
          for _, off_event in ipairs(motif.events) do
            if off_event.type == "note_off" and
               off_event.note == event.note and
               off_event.time > event.time then
              note_off_time = off_event.time
              break
            end
          end

          table.insert(note_pairs, {
            note = event.note,
            start_time = event.time,
            end_time = note_off_time or event.time,
            generation = event.generation or 1
          })
        end
      end

      -- Draw note events as horizontal bars
      for _, note_pair in ipairs(note_pairs) do
        local gen = note_pair.generation
        local brightness = 2 + math.floor((gen / max_gen) * 10)
        screen.level(brightness)

        local x_start = MARGIN_LEFT + (note_pair.start_time / loop_duration * timeline_width)
        local x_end = MARGIN_LEFT + (note_pair.end_time / loop_duration * timeline_width)

        if use_piano_roll and max_note > min_note then
          -- Map note pitch to Y position within lane
          local note_range = max_note - min_note
          local note_y_offset = ((note_pair.note - min_note) / note_range) * (lane_height - 2)
          local note_y = y_pos + lane_height - 1 - note_y_offset
          screen.move(x_start, note_y)
          screen.line(x_end, note_y)
          screen.stroke()
        else
          -- Simple vertical line at note start
          screen.move(x_start, y_pos)
          screen.line(x_start, y_pos + lane_height)
          screen.stroke()
        end
      end

      -- Draw playhead
      if lane.playing then
        local current_beat = clock.get_beats()
        local position = current_beat % loop_duration

        -- Use stage timing if available
        local current_stage = lane.stages[lane.current_stage_index]
        if current_stage and current_stage.last_start_time then
          local elapsed_time = current_beat - current_stage.last_start_time
          position = (elapsed_time * lane.speed) % loop_duration
        end

        local x_playhead = MARGIN_LEFT + (position / loop_duration * timeline_width)
        screen.level(15)
        screen.move(x_playhead, y_pos)
        screen.line(x_playhead, y_pos + lane_height)
        screen.stroke()
      end
    end
  end
end

-- Draw CV monitor: full-width adaptive display showing only active outputs.
-- Each output's bar maps its own min/max to the full 128px width, with a
-- bright marker at the current voltage position. Selected output is highlighted.
function ScreenSaver._draw_cv_monitor()
  local crow_states = {}
  local txo_states = {}

  if _seeker.eurorack and _seeker.eurorack.crow_output then
    crow_states = _seeker.eurorack.crow_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.txo_cv_output then
    txo_states = _seeker.eurorack.txo_cv_output.get_cv_states()
  end

  -- Collect active outputs: Crow 1-4 then TXO CV 1-4 (matches grid order)
  local active_outputs = {}
  for i = 1, 4 do
    local state = crow_states[i]
    if state and state.active then
      table.insert(active_outputs, { label = "C" .. i, state = state, source = "crow", num = i })
    end
  end
  for i = 1, 4 do
    local state = txo_states[i]
    if state and state.active then
      table.insert(active_outputs, { label = "T" .. i, state = state, source = "txo_cv", num = i })
    end
  end

  -- Fall through to background if nothing is active
  if #active_outputs == 0 then
    ScreenSaver._draw_background()
    return
  end

  local selected = ScreenSaver.state.cv_selected
  local row_height = math.floor(64 / #active_outputs)
  local show_value = row_height >= 14

  for idx, entry in ipairs(active_outputs) do
    local state = entry.state
    local y_top = (idx - 1) * row_height
    local bar_h = row_height - 1  -- 1px gap between rows
    local is_selected = (entry.source == selected.source and entry.num == selected.num)

    -- Background rect: brighter for selected output
    screen.level(is_selected and 6 or 4)
    screen.rect(0, y_top, 128, bar_h)
    screen.fill()

    -- Current position marker
    local range = state.max - state.min
    if range <= 0 then range = 1 end
    if state.current then
      local normalized = (state.current - state.min) / range
      normalized = util.clamp(normalized, 0, 1)
      local marker_x = math.floor(normalized * 126)
      screen.level(15)
      screen.rect(marker_x, y_top, 2, bar_h)
      screen.fill()
    end

    -- Label: "C1 CLK" at left edge
    local label_text = entry.label .. " " .. state.type
    screen.level(is_selected and 12 or 7)
    screen.move(2, y_top + bar_h - 1)
    screen.text(label_text)

    -- Value text right-aligned (only when rows are tall enough)
    if show_value and state.current then
      screen.level(is_selected and 10 or 5)
      screen.move(126, y_top + bar_h - 1)
      screen.text_right(string.format("%.1fv", state.current))
    end
  end

  -- Overlay: flash param name + value for 1.2s after encoder change
  local overlay = ScreenSaver.state.arc_overlay
  if overlay and (util.time() - overlay.time) < 1.2 then
    local fade = math.max(0, 1 - (util.time() - overlay.time) / 1.2)
    screen.level(0)
    screen.rect(20, 52, 88, 12)
    screen.fill()
    screen.level(math.floor(15 * fade))
    screen.move(64, 62)
    screen.text_center(overlay.name .. ": " .. overlay.value)
  end
end

-- Draw voice leading graph: columns per stage showing chord voicings with
-- connecting lines that reveal voice movement across the progression.
function ScreenSaver._draw_cycling()
  -- Fall back to background if cycling params aren't active
  if not params.lookup["rc_cycling_start"] then
    ScreenSaver._draw_background()
    return
  end

  local start_degree = params:get("rc_cycling_start")       -- option index = degree value
  local movement = params:get("rc_cycling_movement") - 7    -- option index to interval value
  local num_stages = params:get("rc_cycling_stages")
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local current_stage = math.min(lane.current_stage_index or 1, num_stages)

  local DEGREE_LABELS = {"I", "ii", "iii", "IV", "V", "vi", "vii"}
  local degree_overrides = lane.cycling_degree_overrides or {}
  local degrees = {}
  for i = 1, num_stages do
    degrees[i] = degree_overrides[i] or ((start_degree - 1 + movement * (i - 1)) % 7) + 1
  end

  -- Extract unique MIDI notes per stage from rc_stage_motifs
  local stage_notes = {}
  local has_notes = false
  local global_min = 127
  local global_max = 0

  for i = 1, num_stages do
    local stage_motif = lane.rc_stage_motifs[i]
    if stage_motif and stage_motif.events then
      local seen = {}
      local notes = {}
      for _, event in ipairs(stage_motif.events) do
        if event.type == "note_on" and not seen[event.note] then
          seen[event.note] = true
          table.insert(notes, event.note)
        end
      end
      table.sort(notes)
      stage_notes[i] = notes
      if #notes > 0 then
        has_notes = true
        if notes[1] < global_min then global_min = notes[1] end
        if notes[#notes] > global_max then global_max = notes[#notes] end
      end
    else
      stage_notes[i] = {}
    end
  end

  -- Fall back to background if no stage motifs yet
  if not has_notes then
    ScreenSaver._draw_background()
    return
  end

  -- Vertical pitch area with margins for labels
  local Y_TOP = 14
  local Y_BOTTOM = 54
  -- Minimum 2-octave range so small pitch movements aren't exaggerated
  local MIN_RANGE = 24
  local raw_range = global_max - global_min + 4
  local padding = math.max(2, math.floor((MIN_RANGE - raw_range) / 2))
  local pitch_min = global_min - padding
  local pitch_max = global_max + padding
  local pitch_range = pitch_max - pitch_min

  -- Column x positions evenly spaced with margins
  local col_x = {}
  local col_spacing = 128 / (num_stages + 1)
  for i = 1, num_stages do
    col_x[i] = math.floor(col_spacing * i)
  end

  -- Higher pitch = higher on screen = lower y value
  local function note_to_y(note)
    return Y_BOTTOM - ((note - pitch_min) / pitch_range) * (Y_BOTTOM - Y_TOP)
  end

  -- Notes currently sounding on this lane
  local active_notes = lane.active_notes or {}

  -- Voice leading lines between adjacent stages
  for i = 1, num_stages - 1 do
    local from_notes = stage_notes[i]
    local to_notes = stage_notes[i + 1]
    local voice_count = math.min(#from_notes, #to_notes)
    local is_active_edge = (i + 1 == current_stage)
    screen.level(is_active_edge and 10 or 3)
    for v = 1, voice_count do
      screen.move(col_x[i], note_to_y(from_notes[v]))
      screen.line(col_x[i + 1], note_to_y(to_notes[v]))
    end
    screen.stroke()
  end

  -- Chord tone dots: bright when note is actively sounding
  for i = 1, num_stages do
    local is_current = (i == current_stage)
    for _, note in ipairs(stage_notes[i]) do
      local is_playing = is_current and active_notes[note] ~= nil
      local dot_level = is_playing and 15 or (is_current and 8 or 4)
      local dot_radius = is_playing and 3 or (is_current and 1.5 or 1)
      screen.level(dot_level)
      screen.circle(col_x[i], note_to_y(note), dot_radius)
      screen.fill()
    end
  end

  -- Degree labels above each column, with edit indicator
  local edit_stage = ScreenSaver.state.cycling_edit_stage
  for i = 1, num_stages do
    local is_playing = (i == current_stage)
    local is_editing = (edit_stage and i == edit_stage)
    screen.level(is_playing and 12 or (is_editing and 10 or 4))
    screen.move(col_x[i], 7)
    screen.text_center(DEGREE_LABELS[degrees[i]])
    -- Underline the edit stage
    if is_editing then
      screen.level(8)
      screen.move(col_x[i] - 4, 9)
      screen.line(col_x[i] + 4, 9)
      screen.stroke()
    end
  end

  -- Lane indicator (top-left)
  screen.level(6)
  screen.move(2, 7)
  screen.text("L" .. lane_id)

  -- Bottom: show arc param overlay if recent, otherwise flavor + ring labels
  local overlay = ScreenSaver.state.arc_overlay
  local overlay_dur = overlay and overlay.duration or 1.2
  if overlay and (util.time() - overlay.time) < overlay_dur then
    local fade = math.max(0, 1 - (util.time() - overlay.time) / overlay_dur)
    screen.level(math.floor(15 * fade))
    screen.move(64, 62)
    screen.text_center(overlay.name .. ": " .. overlay.value)
  else
    screen.level(6)
    screen.move(2, 62)
    screen.text(params:string("rc_cycling_flavor"))
    screen.level(4)
    screen.move(126, 62)
    local control_mode = ScreenSaver.state.cycling_control_mode or "chord"
    if control_mode == "chord" then
      screen.text_right("Deg  Voice  Len")
    else
      screen.text_right("Beat  Sprd  Strum")
    end
  end
end

-- Resolve the selected CV output's state, prefix, and type.
-- Returns state, prefix or nil if output inactive.
local function resolve_cv_output(selected)
  local states, prefix
  if selected.source == "crow" then
    prefix = "crow_" .. selected.num .. "_"
    states = _seeker.eurorack and _seeker.eurorack.crow_output and
             _seeker.eurorack.crow_output.get_cv_states() or {}
  else
    prefix = "txo_cv_" .. selected.num .. "_"
    states = _seeker.eurorack and _seeker.eurorack.txo_cv_output and
             _seeker.eurorack.txo_cv_output.get_cv_states() or {}
  end
  local state = states[selected.num]
  if not state or not state.active then return nil, nil end
  return state, prefix
end

-- Arc ring param mapping for cv_monitor: interval, range low, range high.
-- Returns { r1, r2, r3 } where each is a param ID string or nil.
local function resolve_cv_arc_params(selected)
  local state, prefix = resolve_cv_output(selected)
  if not state then return nil end

  local r1, r2, r3

  -- Ring 1: clock interval (Clocked Random uses trigger input instead)
  if state.type ~= "CR" then
    r1 = prefix .. "clock_interval"
  end

  -- Ring 2/3: range low/high depend on mode and source
  if selected.source == "crow" then
    if state.type == "CLK" then      r3 = prefix .. "clock_voltage"
    elseif state.type == "PAT" then  r3 = prefix .. "pattern_voltage"
    elseif state.type == "EUC" then  r3 = prefix .. "euclidean_voltage"
    elseif state.type == "BST" then  r3 = prefix .. "burst_voltage"
    elseif state.type == "LFO" then  r2 = prefix .. "lfo_min"; r3 = prefix .. "lfo_max"
    elseif state.type == "ENV" then  r3 = prefix .. "envelope_voltage"
    elseif state.type == "RW" then   r2 = prefix .. "random_walk_min"; r3 = prefix .. "random_walk_max"
    elseif state.type == "CR" then   r2 = prefix .. "clocked_random_min"; r3 = prefix .. "clocked_random_max"
    elseif state.type == "LR" then   r2 = prefix .. "looped_random_min"; r3 = prefix .. "looped_random_max"
    end
  else
    if state.type == "LFO" then      r2 = prefix .. "depth"; r3 = prefix .. "offset"
    elseif state.type == "RW" then   r2 = prefix .. "random_walk_min"; r3 = prefix .. "random_walk_max"
    elseif state.type == "ENV" then  r3 = prefix .. "envelope_voltage"
    end
  end

  return { r1 = r1, r2 = r2, r3 = r3 }
end

-- Per-type encoder param suffixes for cv_monitor screensaver.
-- Each entry is an array of up to 3 suffixes for E1, E2, E3.
local CROW_ENC_SUFFIXES = {
  CLK = {"_clock_length"},
  PAT = {"_pattern_length", "_pattern_hits", "_gate_length"},
  EUC = {"_euclidean_length", "_euclidean_hits", "_euclidean_rotation"},
  BST = {"_burst_count"},
  LFO = {"_lfo_shape"},
  ENV = {"_envelope_mode", "_envelope_shape"},
  RW  = {"_random_walk_mode", "_random_walk_shape"},
  CR  = {"_clocked_random_quantize", "_clocked_random_shape"},
  LR  = {"_looped_random_quantize", "_looped_random_shape", "_looped_random_steps"},
}

local TXO_ENC_SUFFIXES = {
  LFO = {"_shape", "_rect"},
  RW  = {"_random_walk_mode"},
  ENV = {"_envelope_mode"},
}

-- Handle norns encoder during cv_monitor screensaver.
-- Encoders control mode-specific params (shape, quantize, length, etc.).
function ScreenSaver.handle_cv_enc(n, d)
  local selected = ScreenSaver.state.cv_selected
  local state, prefix = resolve_cv_output(selected)
  if not state then return false end

  local suffixes = (selected.source == "crow")
    and CROW_ENC_SUFFIXES[state.type]
    or TXO_ENC_SUFFIXES[state.type]
  if not suffixes or not suffixes[n] then return false end

  local param_id = prefix .. suffixes[n]
  if not params.lookup[param_id] then return false end

  local param_obj = params:lookup_param(param_id)
  local current = params:get(param_id)
  local direction = d > 0 and 1 or -1

  if param_obj.behavior == "toggle" then
    params:set(param_id, current == 0 and 1 or 0)
  elseif param_obj.t == params.tOPTION then
    params:set(param_id, util.clamp(current + direction, 1, #param_obj.options))
  elseif param_obj.controlspec then
    local step = math.max(param_obj.controlspec.step, 0.1)
    params:set(param_id, util.clamp(current + direction * step,
      param_obj.controlspec.minval, param_obj.controlspec.maxval))
  elseif param_obj.min and param_obj.max then
    params:set(param_id, util.clamp(current + direction, param_obj.min, param_obj.max))
  end

  ScreenSaver.state.arc_overlay = {
    name = param_obj.name or param_id,
    value = params:string(param_id),
    time = util.time()
  }

  return true
end

-- Set cv_selected directly (grid press)
function ScreenSaver.select_cv_output(source, num)
  ScreenSaver.state.cv_selected = { source = source, num = num }
end

-- Cycling arc ring 2-4 mappings: two modes toggled by grid (1,1).
-- Chord mode: per-stage overrides via cycle functions with direction/clamp.
local CYCLING_ARC_CHORD = {
  {param = "Degree", cycle_fn = "cycling_cycle_stage_degree",    threshold = 56},
  {param = "Voice",  cycle_fn = "cycling_cycle_stage_voicing",   threshold = 56},
  {param = "Len",    cycle_fn = "cycling_cycle_stage_chord_len", threshold = 56},
}

-- Progression mode: global params set directly.
local CYCLING_ARC_PROGRESSION = {
  {param = "Beat",   param_id = "rc_cycling_beats",       threshold = 56},
  {param = "Spread", param_id = "rc_cycling_spread",      threshold = 40, delta = 2},
  {param = "Strum",  param_id = "rc_cycling_strum_order", threshold = 56},
}

-- Handle arc button during screensaver. Returns true if consumed.
-- Cycling: steps through stages for editing. CV monitor: cycles output type.
function ScreenSaver.handle_arc_key(n, z)
  if not ScreenSaver.state.is_active then return false end
  if z ~= 1 then return true end

  if ScreenSaver.state.mode == "cycling" then
    -- Arc button steps through stages for editing
    local num_stages = params:get("rc_cycling_stages")
    local current_edit = ScreenSaver.state.cycling_edit_stage
      or (_seeker.lanes[_seeker.ui_state.get_focused_lane()].current_stage_index or 1)
    local next_edit = (current_edit % num_stages) + 1
    ScreenSaver.state.cycling_edit_stage = next_edit
    ScreenSaver.state.arc_overlay = {
      name = "Edit",
      value = "Stage " .. next_edit,
      time = util.time()
    }
    ScreenSaver._update_cycling_arc()
    _seeker.screen_ui.set_needs_redraw()

  elseif ScreenSaver.state.mode == "cv_monitor" then
    -- CV monitor: arc button cycles output type within current category
    local selected = ScreenSaver.state.cv_selected
    local type_param, max_val

    if selected.source == "crow" then
      type_param = "crow_" .. selected.num .. "_mode"
      local category = params:string("crow_" .. selected.num .. "_category")
      max_val = (category == "Gate") and 4 or 6
    else
      type_param = "txo_cv_" .. selected.num .. "_type"
      max_val = 3
    end

    if params.lookup[type_param] then
      local current = params:get(type_param)
      params:set(type_param, (current % max_val) + 1)

      local param_obj = params:lookup_param(type_param)
      ScreenSaver.state.arc_overlay = {
        name = param_obj.name or "Type",
        value = params:string(type_param),
        time = util.time()
      }
    end
  end

  return true
end

-- CV monitor arc thresholds: ring 1=interval, ring 2=range low, ring 3=range high
local CV_ARC_MAP = {
  {threshold = 12},             -- ring 1: discrete (clock interval)
  {threshold = 6, delta = 0.1}, -- ring 2: continuous (range low)
  {threshold = 6, delta = 0.1}, -- ring 3: continuous (range high)
}

-- Handle arc delta during screensaver. Returns true if consumed.
-- Always returns true when screensaver is active to prevent waking.
function ScreenSaver.handle_arc_delta(n, delta)
  if not ScreenSaver.state.is_active then return false end

  local state = ScreenSaver.state
  state.arc_accum = state.arc_accum or {0, 0, 0, 0}

  if state.mode == "cycling" then
    if not params.lookup["rc_cycling_flavor"] then return true end

    -- Ring 1: flavor (framework recipe)
    if n == 1 then
      state.arc_accum[1] = state.arc_accum[1] + 1
      if state.arc_accum[1] >= 64 then
        state.arc_accum[1] = 0
        local direction = delta > 0 and 1 or -1
        local current = params:get("rc_cycling_flavor")
        local param_obj = params:lookup_param("rc_cycling_flavor")
        local new_val = util.clamp(current + direction, 1, #param_obj.options)
        params:set("rc_cycling_flavor", new_val)
        state.arc_overlay = {
          name = "Flavor",
          value = params:string("rc_cycling_flavor"),
          time = util.time()
        }
        ScreenSaver._update_cycling_arc()
      end
      return true
    end

    -- Rings 2-4: mode-dependent control
    local control_mode = state.cycling_control_mode or "chord"

    if control_mode == "chord" then
      local mapping = CYCLING_ARC_CHORD[n - 1]
      if not mapping then return true end

      state.arc_accum[n] = state.arc_accum[n] + 1
      if state.arc_accum[n] >= mapping.threshold then
        state.arc_accum[n] = 0
        if _seeker.composer and _seeker.composer[mapping.cycle_fn] then
          local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
          local stage_idx = ScreenSaver.state.cycling_edit_stage
            or lane.current_stage_index or 1
          local direction = delta > 0 and 1 or -1
          local new_val = _seeker.composer[mapping.cycle_fn](stage_idx, direction)
          state.arc_overlay = {
            name = "S" .. stage_idx .. " " .. mapping.param,
            value = new_val,
            time = util.time()
          }
          ScreenSaver._update_cycling_arc()
        end
      end
    else
      -- Progression mode: set global params directly
      local mapping = CYCLING_ARC_PROGRESSION[n - 1]
      if not mapping then return true end

      state.arc_accum[n] = state.arc_accum[n] + 1
      if state.arc_accum[n] >= mapping.threshold then
        state.arc_accum[n] = 0
        local param_id = mapping.param_id
        if not params.lookup[param_id] then return true end

        local direction = delta > 0 and 1 or -1
        local param_obj = params:lookup_param(param_id)
        local current = params:get(param_id)

        if mapping.delta then
          -- Continuous param (spread)
          local new_val = current + direction * mapping.delta
          if param_obj.controlspec then
            new_val = util.clamp(new_val, param_obj.controlspec.minval, param_obj.controlspec.maxval)
          end
          params:set(param_id, new_val)
        elseif param_obj.t == params.tOPTION then
          params:set(param_id, util.clamp(current + direction, 1, #param_obj.options))
        elseif param_obj.min and param_obj.max then
          params:set(param_id, util.clamp(current + direction, param_obj.min, param_obj.max))
        end

        state.arc_overlay = {
          name = mapping.param,
          value = params:string(param_id),
          time = util.time()
        }
        ScreenSaver._update_cycling_arc()
      end
    end

  elseif state.mode == "cv_monitor" then
    if n == 4 then return true end  -- ring 4 is voltage meter (display only)
    local arc_map = CV_ARC_MAP[n]
    if not arc_map then return true end

    local mapping = resolve_cv_arc_params(state.cv_selected)
    if not mapping then return true end

    local param_id
    if n == 1 then param_id = mapping.r1
    elseif n == 2 then param_id = mapping.r2
    elseif n == 3 then param_id = mapping.r3
    end
    if not param_id or not params.lookup[param_id] then return true end

    state.arc_accum[n] = state.arc_accum[n] + 1
    if state.arc_accum[n] >= arc_map.threshold then
      state.arc_accum[n] = 0
      local direction = delta > 0 and 1 or -1
      local param_obj = params:lookup_param(param_id)
      local current = params:get(param_id)

      if arc_map.delta then
        -- Continuous: voltage range params
        local new_val = current + direction * arc_map.delta
        if param_obj.controlspec then
          new_val = util.clamp(new_val, param_obj.controlspec.minval, param_obj.controlspec.maxval)
        end
        params:set(param_id, new_val)
      else
        -- Discrete: clock interval option list
        if param_obj.t == params.tOPTION then
          params:set(param_id, util.clamp(current + direction, 1, #param_obj.options))
        elseif param_obj.min and param_obj.max then
          params:set(param_id, util.clamp(current + direction, param_obj.min, param_obj.max))
        end
      end

      state.arc_overlay = {
        name = param_obj.name or param_id,
        value = params:string(param_id),
        time = util.time()
      }
      ScreenSaver._update_cv_arc()
    end
  end

  return true
end

-- Update arc LEDs for cycling mode.
-- Ring 1: flavor recipe (both modes). Rings 2-4: chord or progression params.
function ScreenSaver._update_cycling_arc()
  local dev = _seeker.arc
  if not dev then return end
  if not params.lookup["rc_cycling_flavor"] then return end

  -- Ring 1: flavor segment indicator (same in both modes)
  for i = 1, 64 do dev:led(1, i, 2) end
  local flavor = params:get("rc_cycling_flavor")
  local flavor_obj = params:lookup_param("rc_cycling_flavor")
  local total = #flavor_obj.options
  local segment = math.floor(64 / total)
  local seg_start = (flavor - 1) * segment + 1
  for i = seg_start, math.min(64, seg_start + segment - 1) do
    dev:led(1, i, 10)
  end

  local control_mode = ScreenSaver.state.cycling_control_mode or "chord"

  if control_mode == "chord" then
    -- Rings 2-4: per-chord overrides for edit stage (degree, voicing, chord_len)
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local stage_idx = ScreenSaver.state.cycling_edit_stage
      or lane.current_stage_index or 1
    local degree_overrides = lane.cycling_degree_overrides or {}
    local voicing_overrides = lane.cycling_voicing_overrides or {}
    local chord_len_overrides = lane.cycling_chord_len_overrides or {}

    local DEGREE_NAMES = {"I", "ii", "iii", "IV", "V", "vi", "vii"}
    local VOICING_NAMES = {"Close", "Open", "Drop 2", "Drop 3", "Spread"}
    local CHORD_LEN_NAMES = {"Dyad", "Triad", "Tetrad", "Pentad", "Hexad",
      "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"}

    -- Ring 2: degree (number index, not name string)
    for i = 1, 64 do dev:led(2, i, 2) end
    local start = params:get("rc_cycling_start")
    local movement = params:get("rc_cycling_movement") - 7
    local default_degree = ((start - 1 + movement * (stage_idx - 1)) % 7) + 1
    local current_degree = degree_overrides[stage_idx] or default_degree
    local deg_segment = math.floor(64 / #DEGREE_NAMES)
    local deg_start = (current_degree - 1) * deg_segment + 1
    local deg_brightness = degree_overrides[stage_idx] and 14 or 8
    for i = deg_start, math.min(64, deg_start + deg_segment - 1) do
      dev:led(2, i, deg_brightness)
    end

    -- Ring 3: voicing (name string override)
    for i = 1, 64 do dev:led(3, i, 2) end
    local voicing_idx = params:get("rc_cycling_voicing")
    if voicing_overrides[stage_idx] then
      for ci, name in ipairs(VOICING_NAMES) do
        if name == voicing_overrides[stage_idx] then voicing_idx = ci; break end
      end
    end
    local voi_segment = math.floor(64 / #VOICING_NAMES)
    local voi_start = (voicing_idx - 1) * voi_segment + 1
    local voi_brightness = voicing_overrides[stage_idx] and 14 or 8
    for i = voi_start, math.min(64, voi_start + voi_segment - 1) do
      dev:led(3, i, voi_brightness)
    end

    -- Ring 4: chord length (name string override)
    for i = 1, 64 do dev:led(4, i, 2) end
    local len_idx = params:get("rc_cycling_chord_len")
    if chord_len_overrides[stage_idx] then
      for ci, name in ipairs(CHORD_LEN_NAMES) do
        if name == chord_len_overrides[stage_idx] then len_idx = ci; break end
      end
    end
    local len_segment = math.floor(64 / #CHORD_LEN_NAMES)
    local len_start = (len_idx - 1) * len_segment + 1
    local len_brightness = chord_len_overrides[stage_idx] and 14 or 8
    for i = len_start, math.min(64, len_start + len_segment - 1) do
      dev:led(4, i, len_brightness)
    end

  else
    -- Progression mode: global param positions (beats, spread, strum)

    -- Ring 2: beats (number 1-16) — position dot with halo
    for i = 1, 64 do dev:led(2, i, 2) end
    local beats = params:get("rc_cycling_beats")
    local beats_obj = params:lookup_param("rc_cycling_beats")
    local beat_norm = (beats - beats_obj.min) / (beats_obj.max - beats_obj.min)
    local beat_pos = math.floor(beat_norm * 63) + 1
    dev:led(2, beat_pos, 12)
    if beat_pos > 1 then dev:led(2, beat_pos - 1, 6) end
    if beat_pos < 64 then dev:led(2, beat_pos + 1, 6) end

    -- Ring 3: spread (0-100%) — fill bar
    for i = 1, 64 do dev:led(3, i, 2) end
    local spread = params:get("rc_cycling_spread")
    local spec = params:lookup_param("rc_cycling_spread").controlspec
    local spread_norm = (spread - spec.minval) / (spec.maxval - spec.minval)
    local fill_end = math.floor(spread_norm * 64)
    for i = 1, fill_end do
      dev:led(3, i, 10)
    end

    -- Ring 4: strum order — segment indicator
    for i = 1, 64 do dev:led(4, i, 2) end
    local strum_idx = params:get("rc_cycling_strum_order")
    local strum_obj = params:lookup_param("rc_cycling_strum_order")
    local strum_segment = math.floor(64 / #strum_obj.options)
    local strum_start = (strum_idx - 1) * strum_segment + 1
    for i = strum_start, math.min(64, strum_start + strum_segment - 1) do
      dev:led(4, i, 10)
    end
  end

  dev:refresh()
end

-- Arc display for cv_monitor mode.
-- Rings 1-3: interval, range low, range high param positions.
-- Ring 4: voltage meter for selected output.
function ScreenSaver._update_cv_arc()
  local dev = _seeker.arc
  if not dev then return end

  local selected = ScreenSaver.state.cv_selected
  local mapping = resolve_cv_arc_params(selected)

  -- Helper: draw a param's position on a ring
  local function draw_param_ring(ring, param_id)
    if not param_id or not params.lookup[param_id] then
      for i = 1, 64 do dev:led(ring, i, 1) end
      return
    end
    for i = 1, 64 do dev:led(ring, i, 2) end
    local param_obj = params:lookup_param(param_id)
    local current = params:get(param_id)

    if param_obj.t == params.tOPTION then
      -- Segment indicator for option params
      local total = #param_obj.options
      local segment = math.floor(64 / total)
      local start = (current - 1) * segment + 1
      for i = start, math.min(64, start + segment - 1) do
        dev:led(ring, i, 12)
      end
    elseif param_obj.controlspec then
      -- Position dot for continuous params
      local spec = param_obj.controlspec
      local normalized = util.clamp((current - spec.minval) / (spec.maxval - spec.minval), 0, 1)
      local pos = math.floor(normalized * 63) + 1
      dev:led(ring, pos, 12)
      if pos > 1 then dev:led(ring, pos - 1, 6) end
      if pos < 64 then dev:led(ring, pos + 1, 6) end
    end
  end

  -- Rings 1-3: arc-controlled params
  if mapping then
    draw_param_ring(1, mapping.r1)
    draw_param_ring(2, mapping.r2)
    draw_param_ring(3, mapping.r3)
  else
    for ring = 1, 3 do
      for i = 1, 64 do dev:led(ring, i, 1) end
    end
  end

  -- Ring 4: voltage meter for selected output
  local state = resolve_cv_output(selected)
  if state and state.current then
    for i = 1, 64 do dev:led(4, i, 2) end
    local range = state.max - state.min
    if range > 0 then
      local normalized = util.clamp((state.current - state.min) / range, 0, 1)
      local pos = math.floor(normalized * 63) + 1
      dev:led(4, pos, 15)
      if pos > 1 then dev:led(4, pos - 1, 7) end
      if pos < 64 then dev:led(4, pos + 1, 7) end
    end
  else
    for i = 1, 64 do dev:led(4, i, 1) end
  end

  dev:refresh()
end

-- Set or clear arc display override based on current screensaver state
function ScreenSaver._sync_arc_override()
  local dev = _seeker.arc
  if not dev then return end

  if ScreenSaver.state.is_active and ScreenSaver.state.mode == "cycling" then
    dev.set_display(function() ScreenSaver._update_cycling_arc() end)
  elseif ScreenSaver.state.is_active and ScreenSaver.state.mode == "cv_monitor" then
    dev.set_display(function() ScreenSaver._update_cv_arc() end)
  else
    dev.clear_display()
  end
end

-- Remove arc display override
function ScreenSaver._clear_arc_override()
  local dev = _seeker.arc
  if not dev then return end
  dev.clear_display()
end

-- Draw the complete screensaver (background + screen.update)
function ScreenSaver.draw()
  screen.clear()
  local mode = ScreenSaver.state.mode
  if mode == "cv_monitor" then
    ScreenSaver._draw_cv_monitor()
  elseif mode == "cycling" then
    ScreenSaver._draw_cycling()
  else
    ScreenSaver._draw_background()
  end
  screen.update()
end

return ScreenSaver 