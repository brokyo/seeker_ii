-- screen_saver.lua
local ScreenSaver = {}

ScreenSaver.state = {
  is_active = false,
  mode = "cycling",  -- "background", "cv_monitor", "cycling"
  timeout_seconds = 90,
  lines = {},
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

-- Cycle focused lane during cycling screensaver (K3)
function ScreenSaver.next_cycling_lane()
  local current = _seeker.ui_state.get_focused_lane()
  local next_lane = (current % _seeker.num_lanes) + 1
  _seeker.ui_state.set_focused_lane(next_lane)
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

function ScreenSaver.check_timeout()
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

    -- Reset to default mode when screensaver deactivates
    if not should_be_active then
      ScreenSaver.state.mode = "cycling"
      ScreenSaver._clear_arc_override()
    end

    -- Set arc display override when screensaver activates
    if should_be_active then
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

      -- Draw stage indicator dots
      local num_stages = 4
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
-- bright marker at the current voltage position.
function ScreenSaver._draw_cv_monitor()
  local txo_states = {}
  local crow_states = {}

  if _seeker.eurorack and _seeker.eurorack.txo_cv_output then
    txo_states = _seeker.eurorack.txo_cv_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.crow_output then
    crow_states = _seeker.eurorack.crow_output.get_cv_states()
  end

  -- Collect only active outputs: TXO 1-4 then Crow 1-4
  local active_outputs = {}
  for i = 1, 4 do
    local state = txo_states[i]
    if state and state.active then
      table.insert(active_outputs, { label = "T" .. i, state = state })
    end
  end
  for i = 1, 4 do
    local state = crow_states[i]
    if state and state.active then
      table.insert(active_outputs, { label = "C" .. i, state = state })
    end
  end

  -- Fall through to background if nothing is active
  if #active_outputs == 0 then
    ScreenSaver._draw_background()
    return
  end

  local row_height = math.floor(64 / #active_outputs)
  local show_value = row_height >= 14

  for idx, entry in ipairs(active_outputs) do
    local state = entry.state
    local y_top = (idx - 1) * row_height
    local bar_h = row_height - 1  -- 1px gap between rows

    -- Background rect
    screen.level(2)
    screen.rect(0, y_top, 128, bar_h)
    screen.fill()

    -- Map output's configured range to full bar width
    local range = state.max - state.min
    if range <= 0 then range = 1 end

    -- Range indicator showing the output's voltage span
    screen.level(4)
    screen.rect(0, y_top, 128, bar_h)
    screen.fill()

    -- Current position marker
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
    screen.level(7)
    screen.move(2, y_top + bar_h - 1)
    screen.text(label_text)

    -- Value text right-aligned (only when rows are tall enough)
    if show_value and state.current then
      screen.level(5)
      screen.move(126, y_top + bar_h - 1)
      screen.text_right(string.format("%.1fv", state.current))
    end
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

  local start_degree = params:get("rc_cycling_start")
  local movement = params:get("rc_cycling_movement")
  local num_stages = params:get("rc_cycling_stages")
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local current_stage = math.min(lane.current_stage_index or 1, num_stages)

  local DEGREE_LABELS = {"I", "ii", "iii", "IV", "V", "vi", "vii"}
  local degrees = {}
  for i = 1, num_stages do
    degrees[i] = ((start_degree - 1 + movement * (i - 1)) % 7) + 1
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

  -- Degree labels above each column
  for i = 1, num_stages do
    screen.level(i == current_stage and 12 or 4)
    screen.move(col_x[i], 7)
    screen.text_center(DEGREE_LABELS[degrees[i]])
  end

  -- Lane indicator (top-left)
  screen.level(6)
  screen.move(2, 7)
  screen.text("L" .. lane_id)

  -- Bottom center: show arc param overlay if recent, otherwise current chord
  local overlay = ScreenSaver.state.arc_overlay
  if overlay and (util.time() - overlay.time) < 1.2 then
    local fade = math.max(0, 1 - (util.time() - overlay.time) / 1.2)
    screen.level(math.floor(15 * fade))
    screen.move(64, 62)
    screen.text_center(overlay.name .. ": " .. overlay.value)
  else
    screen.level(12)
    screen.move(64, 62)
    screen.text_center(DEGREE_LABELS[degrees[current_stage]])
  end
end

-- Norns encoder mapping for cycling screensaver mode
-- E1 = beats (stage duration), E2 = start degree, E3 = movement
local CYCLING_ENC_MAP = {
  [1] = "rc_cycling_beats",
  [2] = "rc_cycling_start",
  [3] = "rc_cycling_movement",
}

-- Handle norns encoder during cycling screensaver. Returns true if consumed.
function ScreenSaver.handle_enc(n, d)
  if not params.lookup["rc_cycling_start"] then return false end

  local param_id = CYCLING_ENC_MAP[n]
  if not param_id then return false end

  local param_obj = params:lookup_param(param_id)
  local current = params:get(param_id)
  local new_val = current + d
  if param_obj.min and param_obj.max then
    new_val = util.clamp(new_val, param_obj.min, param_obj.max)
  end
  params:set(param_id, new_val)

  -- Show overlay
  ScreenSaver.state.arc_overlay = {
    name = param_obj.name or param_id,
    value = params:string(param_id),
    time = util.time()
  }

  return true
end

-- Arc ring-to-param mapping for cycling screensaver mode
-- Ring 1: rotation, Ring 2: spread, Ring 3: chord length, Ring 4: voicing
local CYCLING_ARC_MAP = {
  {id = "rc_cycling_rotation", threshold = 12},
  {id = "rc_cycling_spread", threshold = 6, delta = 2},
  {id = "rc_cycling_chord_len", threshold = 12},
  {id = "rc_cycling_voicing", threshold = 16},
}

-- Handle arc button during cycling screensaver: cycle strum order.
-- Returns true if consumed.
function ScreenSaver.handle_arc_key(n, z)
  if z ~= 1 then return true end  -- swallow release
  if not ScreenSaver.state.is_active then return false end
  if ScreenSaver.state.mode ~= "cycling" then return false end
  if not params.lookup["rc_cycling_strum_order"] then return false end

  local current = params:get("rc_cycling_strum_order")
  local num_options = 5  -- Up, Down, Out>In, In>Out, Random
  params:set("rc_cycling_strum_order", (current % num_options) + 1)

  local param_obj = params:lookup_param("rc_cycling_strum_order")
  ScreenSaver.state.arc_overlay = {
    name = param_obj.name or "Strum Order",
    value = params:string("rc_cycling_strum_order"),
    time = util.time()
  }

  return true
end

-- Handle arc delta during cycling screensaver. Returns true if consumed.
function ScreenSaver.handle_arc_delta(n, delta)
  if not ScreenSaver.state.is_active then return false end
  if ScreenSaver.state.mode ~= "cycling" then return false end
  if not params.lookup["rc_cycling_start"] then return false end

  local mapping = CYCLING_ARC_MAP[n]
  if not mapping then return false end

  local state = ScreenSaver.state
  state.arc_accum = state.arc_accum or {0, 0, 0, 0}
  state.arc_accum[n] = state.arc_accum[n] + 1

  if state.arc_accum[n] >= mapping.threshold then
    state.arc_accum[n] = 0
    local direction = delta > 0 and 1 or -1
    local current = params:get(mapping.id)
    local param_obj = params:lookup_param(mapping.id)

    if mapping.delta then
      -- Continuous param
      local new_val = current + direction * mapping.delta
      if param_obj.controlspec then
        new_val = util.clamp(new_val, param_obj.controlspec.minval, param_obj.controlspec.maxval)
      end
      params:set(mapping.id, new_val)
    else
      -- Discrete param (number or option)
      local new_val = current + direction
      if param_obj.min and param_obj.max then
        new_val = util.clamp(new_val, param_obj.min, param_obj.max)
      elseif param_obj.options then
        new_val = util.clamp(new_val, 1, #param_obj.options)
      end
      params:set(mapping.id, new_val)
    end

    -- Show param name and value on screen briefly
    local param_obj_after = params:lookup_param(mapping.id)
    local display_val = params:string(mapping.id)
    state.arc_overlay = {
      name = param_obj_after.name or mapping.id,
      value = display_val,
      time = util.time()
    }

    ScreenSaver._update_cycling_arc()
  end

  return true
end

-- Update arc LEDs to show cycling param values across 4 rings
function ScreenSaver._update_cycling_arc()
  local dev = _seeker.arc
  if not dev then return end
  if not params.lookup["rc_cycling_start"] then return end

  -- Ring 1: rotation (-5 to 5)
  local rotation = params:get("rc_cycling_rotation")
  local rot_pos = math.floor(((rotation + 5) / 10) * 63) + 1
  for i = 1, 64 do dev:led(1, i, 2) end
  for i = math.max(1, rot_pos - 2), math.min(64, rot_pos + 2) do
    dev:led(1, i, 12)
  end

  -- Ring 2: spread (0-100)
  local spread = params:get("rc_cycling_spread")
  local spread_fill = math.max(1, math.floor((spread / 100) * 64))
  for i = 1, 64 do dev:led(2, i, 2) end
  for i = 1, spread_fill do dev:led(2, i, 10) end

  -- Ring 3: chord_len (2-6)
  local chord_len = params:get("rc_cycling_chord_len")
  local len_pos = math.floor(((chord_len - 2) / 4) * 63) + 1
  for i = 1, 64 do dev:led(3, i, 2) end
  for i = math.max(1, len_pos - 3), math.min(64, len_pos + 3) do
    dev:led(3, i, 12)
  end

  -- Ring 4: voicing (1-5)
  local voicing = params:get("rc_cycling_voicing")
  local num_options = 5
  local segment = math.floor(64 / num_options)
  for i = 1, 64 do dev:led(4, i, 2) end
  local start = (voicing - 1) * segment + 1
  for i = start, math.min(64, start + segment - 1) do
    dev:led(4, i, 12)
  end

  dev:refresh()
end

-- Set or clear arc display override based on current screensaver state
function ScreenSaver._sync_arc_override()
  local dev = _seeker.arc
  if not dev then return end

  if ScreenSaver.state.is_active and ScreenSaver.state.mode == "cycling" then
    dev.set_display(function() ScreenSaver._update_cycling_arc() end)
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