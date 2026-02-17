-- cycling.lua
-- Cycling chord progression generator with dual-mode NornsUI.
-- Live view (default): voice leading graph with arc/K3 control.
-- Param view (K2 toggle): standard param list for all cycling params.
-- Grid row 7 controls: mode toggle, +/- stages, hold-to-randomize.

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local Cycling = {}
Cycling.__index = Cycling

local COMPOSER_MODE = 2

-- Guard against set_action firing during param creation
local initialized = false
-- Suppress rebuild while loading a lane's cycling param snapshot
local loading = false

-- Named option tables for musically meaningful labels
local DEGREE_NAMES = {"I", "ii", "iii", "IV", "V", "vi", "vii"}
local MOVEMENT_NAMES = {
  "7ths Dn", "6ths Dn", "5ths Dn", "4ths Dn", "3rds Dn", "Steps Dn",
  "Pedal",
  "Steps Up", "3rds Up", "4ths Up", "5ths Up", "6ths Up", "7ths Up"
}
local CHORD_LEN_NAMES = {
  "Dyad", "Triad", "Tetrad", "Pentad", "Hexad",
  "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"
}
local ROTATION_NAMES = {
  "-5", "-4", "-3", "-2", "-1",
  "Root", "1st Inv", "2nd Inv", "3rd Inv", "4th Inv", "5th Inv"
}
local QUALITY_NAMES = {"Diatonic", "Major", "Minor", "Sus4", "Min7", "Maj7", "Dom7"}
local VOICING_NAMES = {"Close", "Open", "Drop 2", "Drop 3", "Spread"}
local STRUM_ORDER_NAMES = {"Up", "Down", "Out>In", "In>Out", "Random"}

-- Name-to-index lookup tables (avoid linear search in hot paths)
local VOICING_INDEX = {}
for i, name in ipairs(VOICING_NAMES) do VOICING_INDEX[name] = i end
local STRUM_INDEX = {}
for i, name in ipairs(STRUM_ORDER_NAMES) do STRUM_INDEX[name] = i end
local ROTATION_INDEX = {}
for i, name in ipairs(ROTATION_NAMES) do ROTATION_INDEX[name] = i end
local CHORD_LEN_INDEX = {}
for i, name in ipairs(CHORD_LEN_NAMES) do CHORD_LEN_INDEX[name] = i end

-- Export name arrays for RC and other modules
Cycling.DEGREE_NAMES = DEGREE_NAMES
Cycling.VOICING_NAMES = VOICING_NAMES
Cycling.STRUM_ORDER_NAMES = STRUM_ORDER_NAMES
Cycling.ROTATION_NAMES = ROTATION_NAMES
Cycling.CHORD_LEN_NAMES = CHORD_LEN_NAMES

-- Option index to actual value conversions
local function movement_value(idx) return idx - 7 end   -- index 7 = Unison (0)
local function rotation_value(idx) return idx - 6 end   -- index 6 = Root (0)
local function chord_len_value(idx) return idx + 1 end   -- index 1 = Dyad (2)

-- Cycling param definitions for per-lane save/load
local CYCLING_PARAMS = {
  {id = "rc_cycling_flavor", default = 1},
  {id = "rc_cycling_start", default = 1},
  {id = "rc_cycling_movement", default = 10},   -- 4th Up
  {id = "rc_cycling_quality", default = 1},
  {id = "rc_cycling_chord_len", default = 3},    -- Tetrad
  {id = "rc_cycling_voicing", default = 1},
  {id = "rc_cycling_strum_order", default = 1},
  {id = "rc_cycling_rotation", default = 6},     -- Root
  {id = "rc_cycling_octave", default = 3},
  {id = "rc_cycling_spread", default = 10},
  {id = "rc_cycling_stages", default = 1},
  {id = "rc_cycling_loops", default = 2},
  {id = "rc_cycling_beats", default = 4},
}

-- Flavor presets: named recipes combining movement, voicing, chord length, rotation.
local FLAVOR_NAMES = {"Folk", "Jazz", "Ambient", "Minimal", "Orchestral"}
local FLAVOR_RECIPES = {
  {movement = 10, voicing = 1, chord_len = 2, rotation = 6},  -- 4ths, Close, Triad, Root
  {movement = 10, voicing = 3, chord_len = 3, rotation = 6},  -- 4ths, Drop 2, Tetrad, Root
  {movement = 9,  voicing = 2, chord_len = 2, rotation = 7},  -- 3rds Up, Open, Triad, 1st Inv
  {movement = 8,  voicing = 1, chord_len = 1, rotation = 6},  -- Steps Up, Close, Dyad, Root
  {movement = 11, voicing = 5, chord_len = 4, rotation = 6},  -- 5ths Up, Spread, Pentad, Root
}

-- Stage count brightness: maps 1-8 stages to LED levels
local STAGE_BRIGHTNESS = {3, 4, 6, 7, 9, 10, 12, 13}

---------------------------------------------------------------
-- Cycling view state (module-local, previously on ScreenSaver)
---------------------------------------------------------------
local edit_stage = nil        -- nil = follow playback, 1-8 = explicit
local control_mode = "chord"  -- "chord" = per-stage, "progression" = global
local arc_overlay = nil       -- {name, value, time, duration?}
local arc_accum = {0, 0, 0, 0}

-- Arc ring mappings: chord mode (per-stage overrides via cycle functions)
local ARC_CHORD = {
  [1] = {param = "Rot",    fn = "cycle_stage_rotation",  threshold = 56},
  [2] = {param = "Degree", fn = "cycle_stage_degree",    threshold = 56},
  [3] = {param = "Voice",  fn = "cycle_stage_voicing",   threshold = 56},
  [4] = {param = "Strum",  fn = "cycle_stage_strum",     threshold = 56},
}

-- Arc ring mappings: progression mode (global params)
local ARC_PROGRESSION = {
  [1] = {param = "Beat",   param_id = "rc_cycling_beats",      threshold = 56},
  [2] = {param = "Spread", param_id = "rc_cycling_spread",    threshold = 40, delta = 5},
  [3] = {param = "Spread", param_id = "rc_cycling_spread",    threshold = 20, delta = 1},
  [4] = {param = "Len",    param_id = "rc_cycling_chord_len",  threshold = 56},
}

---------------------------------------------------------------
-- Strum ordering utility: reorder notes by strum pattern name.
-- Returns a new array of notes in play order.
---------------------------------------------------------------
function Cycling.order_notes(notes, strum_name)
  local ordered = {}
  if strum_name == "Up" then
    for _, n in ipairs(notes) do table.insert(ordered, n) end
  elseif strum_name == "Down" then
    for j = #notes, 1, -1 do table.insert(ordered, notes[j]) end
  elseif strum_name == "Out>In" then
    local lo, hi = 1, #notes
    while lo <= hi do
      table.insert(ordered, notes[lo])
      if lo ~= hi then table.insert(ordered, notes[hi]) end
      lo = lo + 1
      hi = hi - 1
    end
  elseif strum_name == "In>Out" then
    local mid = math.ceil(#notes / 2)
    table.insert(ordered, notes[mid])
    for offset = 1, #notes do
      if mid + offset <= #notes then table.insert(ordered, notes[mid + offset]) end
      if mid - offset >= 1 then table.insert(ordered, notes[mid - offset]) end
    end
  end
  -- Random: empty (no deterministic path to show)
  return ordered
end

---------------------------------------------------------------
-- Build chord progression from cycling params and apply via RC.form()
---------------------------------------------------------------
local function rebuild()
  if not initialized then return end
  if loading then return end
  if not _seeker or not _seeker.rc then return end

  local start = params:get("rc_cycling_start")
  local movement = movement_value(params:get("rc_cycling_movement"))
  local quality = QUALITY_NAMES[params:get("rc_cycling_quality")]
  local chord_len = chord_len_value(params:get("rc_cycling_chord_len"))
  local voicing = VOICING_NAMES[params:get("rc_cycling_voicing")]
  local rotation = rotation_value(params:get("rc_cycling_rotation"))
  local spread = params:get("rc_cycling_spread")
  local base_strum_order = STRUM_ORDER_NAMES[params:get("rc_cycling_strum_order")]
  local octave = params:get("rc_cycling_octave")
  local num_stages = params:get("rc_cycling_stages")
  local loops = params:get("rc_cycling_loops")
  local beats = params:get("rc_cycling_beats")

  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local strum_overrides = lane.cycling_strum_overrides or {}
  local voicing_overrides = lane.cycling_voicing_overrides or {}
  local chord_len_overrides = lane.cycling_chord_len_overrides or {}
  local rotation_overrides = lane.cycling_rotation_overrides or {}

  local stages = {}
  for i = 1, num_stages do
    local degree_overrides = lane.cycling_degree_overrides or {}
    local degree = degree_overrides[i] or ((start - 1 + movement * (i - 1)) % 7) + 1
    local stage_strum_order = strum_overrides[i] or base_strum_order
    local stage_voicing = voicing_overrides[i] or voicing

    -- Per-chord rotation: override is a name string, convert to value
    local stage_rotation = rotation
    if rotation_overrides[i] then
      local idx = ROTATION_INDEX[rotation_overrides[i]]
      if idx then stage_rotation = rotation_value(idx) end
    end

    -- Per-chord chord_len: override is a name string, convert to value
    local stage_chord_len = chord_len
    if chord_len_overrides[i] then
      local idx = CHORD_LEN_INDEX[chord_len_overrides[i]]
      if idx then stage_chord_len = chord_len_value(idx) end
    end

    local stage_strum = (spread / 100) * beats / stage_chord_len
    local stage_gate = 0.8 * (1 - spread / 100 * (1 - 1 / stage_chord_len))

    table.insert(stages, {
      chords = {{
        degree = degree,
        type = quality,
        dur = beats,
        gate = stage_gate,
        chord_len = stage_chord_len,
        voicing = stage_voicing,
        rotation = stage_rotation,
      }},
      octave = octave,
      strum = stage_strum,
      strum_order = stage_strum_order,
      loops = loops,
    })
  end

  if lane.playing then
    -- Lane is mid-cycle: update stage data without resetting playback position.
    for i, entry in ipairs(stages) do
      _seeker.rc.stage(lane_id, i, entry)
      params:set("lane_" .. lane_id .. "_stage_" .. i .. "_active", 2)
      params:set("lane_" .. lane_id .. "_stage_" .. i .. "_loops", entry.loops or 2)
    end
    for i = num_stages + 1, 8 do
      params:set("lane_" .. lane_id .. "_stage_" .. i .. "_active", 1)
      lane.rc_stage_motifs[i] = nil
    end
    lane:sync_all_stages_from_params()
    _seeker.rc.regen(lane_id)
  else
    _seeker.rc.form(lane_id, stages)
    lane:play({quantize = true})
  end

  -- Clamp edit stage to valid range
  if edit_stage and edit_stage > num_stages then
    edit_stage = num_stages
  end

  Cycling.save_cycling_params(lane_id)

  if _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

---------------------------------------------------------------
-- Arc display: update LED rings based on control mode
---------------------------------------------------------------
local function update_arc()
  local dev = _seeker.arc
  if not dev then return end
  if not params.lookup["rc_cycling_flavor"] then return end

  if control_mode == "chord" then
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local stage_idx = edit_stage or lane.current_stage_index or 1
    local degree_overrides = lane.cycling_degree_overrides or {}
    local voicing_overrides = lane.cycling_voicing_overrides or {}
    local strum_overrides = lane.cycling_strum_overrides or {}
    local rotation_overrides = lane.cycling_rotation_overrides or {}

    -- Ring 1: rotation/inversion
    for i = 1, 64 do dev:led(1, i, 2) end
    local rot_idx = params:get("rc_cycling_rotation")
    if rotation_overrides[stage_idx] then
      rot_idx = ROTATION_INDEX[rotation_overrides[stage_idx]] or rot_idx
    end
    local rot_segment = math.floor(64 / #ROTATION_NAMES)
    local rot_start = (rot_idx - 1) * rot_segment + 1
    local rot_brightness = rotation_overrides[stage_idx] and 14 or 8
    for i = rot_start, math.min(64, rot_start + rot_segment - 1) do
      dev:led(1, i, rot_brightness)
    end

    -- Ring 2: degree
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

    -- Ring 3: voicing
    for i = 1, 64 do dev:led(3, i, 2) end
    local voicing_idx = params:get("rc_cycling_voicing")
    if voicing_overrides[stage_idx] then
      voicing_idx = VOICING_INDEX[voicing_overrides[stage_idx]] or voicing_idx
    end
    local voi_segment = math.floor(64 / #VOICING_NAMES)
    local voi_start = (voicing_idx - 1) * voi_segment + 1
    local voi_brightness = voicing_overrides[stage_idx] and 14 or 8
    for i = voi_start, math.min(64, voi_start + voi_segment - 1) do
      dev:led(3, i, voi_brightness)
    end

    -- Ring 4: strum order
    for i = 1, 64 do dev:led(4, i, 2) end
    local strum_idx = params:get("rc_cycling_strum_order")
    if strum_overrides[stage_idx] then
      strum_idx = STRUM_INDEX[strum_overrides[stage_idx]] or strum_idx
    end
    local strum_segment = math.floor(64 / #STRUM_ORDER_NAMES)
    local strum_start = (strum_idx - 1) * strum_segment + 1
    local strum_brightness = strum_overrides[stage_idx] and 14 or 8
    for i = strum_start, math.min(64, strum_start + strum_segment - 1) do
      dev:led(4, i, strum_brightness)
    end

  else
    -- Progression mode: global params

    -- Ring 1: beats
    for i = 1, 64 do dev:led(1, i, 2) end
    local beats = params:get("rc_cycling_beats")
    local beats_obj = params:lookup_param("rc_cycling_beats")
    local beat_norm = (beats - beats_obj.min) / (beats_obj.max - beats_obj.min)
    local beat_pos = math.floor(beat_norm * 63) + 1
    dev:led(1, beat_pos, 12)
    if beat_pos > 1 then dev:led(1, beat_pos - 1, 6) end
    if beat_pos < 64 then dev:led(1, beat_pos + 1, 6) end

    -- Rings 2-3: spread (same fill bar on both)
    local spread = params:get("rc_cycling_spread")
    local spec = params:lookup_param("rc_cycling_spread").controlspec
    local spread_norm = (spread - spec.minval) / (spec.maxval - spec.minval)
    local fill_end = math.floor(spread_norm * 64)
    for ring = 2, 3 do
      for i = 1, 64 do dev:led(ring, i, 2) end
      for i = 1, fill_end do
        dev:led(ring, i, 10)
      end
    end

    -- Ring 4: chord length segment
    for i = 1, 64 do dev:led(4, i, 2) end
    local len_idx = params:get("rc_cycling_chord_len")
    local len_obj = params:lookup_param("rc_cycling_chord_len")
    local len_segment = math.floor(64 / #len_obj.options)
    local len_start = (len_idx - 1) * len_segment + 1
    for i = len_start, math.min(64, len_start + len_segment - 1) do
      dev:led(4, i, 10)
    end
  end

  dev:refresh()
end

---------------------------------------------------------------
-- Handle arc delta: accumulate and step params
---------------------------------------------------------------
local function handle_arc_delta(n, delta)
  if not params.lookup["rc_cycling_flavor"] then return end

  if control_mode == "chord" then
    local mapping = ARC_CHORD[n]
    if not mapping then return end

    arc_accum[n] = arc_accum[n] + 1
    if arc_accum[n] >= mapping.threshold then
      arc_accum[n] = 0
      if Cycling[mapping.fn] then
        local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
        local stage_idx = edit_stage or lane.current_stage_index or 1
        local direction = delta > 0 and 1 or -1
        local new_val = Cycling[mapping.fn](stage_idx, direction)
        arc_overlay = {
          name = "S" .. stage_idx .. " " .. mapping.param,
          value = new_val,
          time = util.time()
        }
        update_arc()
        _seeker.screen_ui.set_needs_redraw()
      end
    end
  else
    -- Progression mode
    local mapping = ARC_PROGRESSION[n]
    if not mapping then return end

    arc_accum[n] = arc_accum[n] + 1
    if arc_accum[n] >= mapping.threshold then
      arc_accum[n] = 0
      local param_id = mapping.param_id
      if not params.lookup[param_id] then return end

      local direction = delta > 0 and 1 or -1
      local param_obj = params:lookup_param(param_id)
      local current = params:get(param_id)

      if mapping.delta then
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

      arc_overlay = {
        name = mapping.param,
        value = params:string(param_id),
        time = util.time()
      }
      update_arc()
      _seeker.screen_ui.set_needs_redraw()
    end
  end
end

---------------------------------------------------------------
-- Handle arc button: step through edit stages
---------------------------------------------------------------
local function handle_arc_key(n, z)
  if z ~= 1 then return end
  -- Switch to chord mode and advance edit stage
  control_mode = "chord"
  local num_stages = params:get("rc_cycling_stages")
  local current_edit = edit_stage
    or (_seeker.lanes[_seeker.ui_state.get_focused_lane()].current_stage_index or 1)
  local next_edit = (current_edit % num_stages) + 1
  edit_stage = next_edit
  update_arc()
  _seeker.screen_ui.set_needs_redraw()
end

---------------------------------------------------------------
-- Voice leading graph drawing (live view)
---------------------------------------------------------------
local function draw_live(norns_ui)
  if not params.lookup["rc_cycling_start"] then return end

  local start_degree = params:get("rc_cycling_start")
  local movement = params:get("rc_cycling_movement") - 7
  local num_stages = params:get("rc_cycling_stages")
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local current_stage = math.min(lane.current_stage_index or 1, num_stages)

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

  if not has_notes then return end

  -- Vertical pitch area with margins for labels
  local Y_TOP = 14
  local Y_BOTTOM = 54
  local MIN_RANGE = 24
  local raw_range = global_max - global_min + 4
  local padding = math.max(2, math.floor((MIN_RANGE - raw_range) / 2))
  local pitch_min = global_min - padding
  local pitch_max = global_max + padding
  local pitch_range = pitch_max - pitch_min

  local col_x = {}
  local col_spacing = 128 / (num_stages + 1)
  for i = 1, num_stages do
    col_x[i] = math.floor(col_spacing * i)
  end

  local function note_to_y(note)
    return Y_BOTTOM - ((note - pitch_min) / pitch_range) * (Y_BOTTOM - Y_TOP)
  end

  local active_notes = lane.active_notes or {}
  local strum_overrides = lane.cycling_strum_overrides or {}
  local base_strum = params:string("rc_cycling_strum_order")

  -- Strum voice lines: connect notes by strum position between adjacent chords
  -- Shows the melodic paths the ear follows (1st-strummed to 1st-strummed, etc.)
  local strum_ordered = {}
  for i = 1, num_stages do
    local strum = strum_overrides[i] or base_strum
    strum_ordered[i] = Cycling.order_notes(stage_notes[i], strum)
  end

  for i = 1, num_stages - 1 do
    local from = strum_ordered[i]
    local to = strum_ordered[i + 1]
    local n = math.min(#from, #to)
    local is_active_edge = (i + 1 == current_stage)
    for j = 1, n do
      -- First-strummed voice brightest, fading for later voices
      local voice_fade = 1 - ((j - 1) / math.max(n, 2))
      local base = is_active_edge and 12 or 6
      screen.level(math.floor(base * voice_fade) + 1)
      screen.move(col_x[i], note_to_y(from[j]))
      screen.line(col_x[i + 1], note_to_y(to[j]))
      screen.stroke()
    end
  end


  -- Chord tone dots
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
    local is_playing = (i == current_stage)
    local is_editing = (edit_stage and i == edit_stage)
    screen.level(is_playing and 12 or (is_editing and 10 or 4))
    screen.move(col_x[i], 7)
    screen.text_center(DEGREE_NAMES[degrees[i]])
    if is_editing then
      screen.level(8)
      screen.move(col_x[i] - 4, 9)
      screen.line(col_x[i] + 4, 9)
      screen.stroke()
    end
  end

  -- Lane indicator
  screen.level(6)
  screen.move(2, 7)
  screen.text("L" .. lane_id)

  -- Bottom: arc param overlay or current values per ring
  local overlay_dur = arc_overlay and arc_overlay.duration or 1.2
  if arc_overlay and (util.time() - arc_overlay.time) < overlay_dur then
    local fade = math.max(0, 1 - (util.time() - arc_overlay.time) / overlay_dur)
    screen.level(math.floor(15 * fade))
    screen.move(64, 62)
    screen.text_center(arc_overlay.name .. ": " .. arc_overlay.value)
  else
    local es = edit_stage or (lane and lane.current_stage_index) or 1

    if control_mode == "chord" then
      local rotation_overrides = lane and lane.cycling_rotation_overrides or {}
      local voicing_overrides = lane and lane.cycling_voicing_overrides or {}
      local strum_overrides = lane and lane.cycling_strum_overrides or {}

      local rot_idx = params:get("rc_cycling_rotation")
      if rotation_overrides[es] then
        rot_idx = ROTATION_INDEX[rotation_overrides[es]] or rot_idx
      end
      local rot_val = rot_idx - 6

      local deg_val = DEGREE_NAMES[degrees[es] or 1]
      local voice_val = voicing_overrides[es] or params:string("rc_cycling_voicing")
      local strum_val = strum_overrides[es] or params:string("rc_cycling_strum_order")

      screen.level(6)
      screen.move(2, 62)
      screen.text(tostring(rot_val))
      screen.move(40, 62)
      screen.text(deg_val)
      screen.move(74, 62)
      screen.text(voice_val)
      screen.move(126, 62)
      screen.text_right(strum_val)
    else
      local len_val = params:get("rc_cycling_chord_len") + 1
      screen.level(6)
      screen.move(2, 62)
      screen.text(params:string("rc_cycling_beats"))
      screen.move(48, 62)
      screen.text(params:string("rc_cycling_spread"))
      screen.move(126, 62)
      screen.text_right(tostring(len_val))
    end
  end
end

---------------------------------------------------------------
-- NornsUI: dual-mode screen (live view default, K2 toggles params)
---------------------------------------------------------------
local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "COMPOSER_CYCLING",
    name = "Cycling",
    description = Descriptions.COMPOSER_CYCLING,
    params = {}
  })

  -- Opt-in to 30fps redraws during playback
  norns_ui.needs_playback_refresh = true

  -- Live view is the default display mode
  norns_ui.state.live_view = true

  norns_ui.rebuild_params = function(self)
    self.params = {
      { separator = true, title = "Cycle Shape" },
      { id = "rc_cycling_start" },
      { id = "rc_cycling_movement" },
      { id = "rc_cycling_quality" },
      { separator = true, title = "Texture" },
      { id = "rc_cycling_chord_len" },
      { id = "rc_cycling_voicing" },
      { id = "rc_cycling_rotation" },
      { id = "rc_cycling_octave" },
      { id = "rc_cycling_spread", arc_multi_float = {5, 2, 0.5} },
      { id = "rc_cycling_strum_order" },
      { separator = true, title = "Structure" },
      { id = "rc_cycling_stages" },
      { id = "rc_cycling_loops" },
      { id = "rc_cycling_beats" },
    }
  end

  -- Draw: dispatch to live view or param view
  norns_ui.draw = function(self)
    screen.clear()
    if self.state.live_view then
      draw_live(self)
    else
      self:_draw_standard_ui()
    end
    screen.update()
  end

  -- K2: toggle live/param view. K3: mode-dependent per-stage cycling.
  norns_ui.handle_key = function(self, n, z)
    if n == 2 then
      if z == 1 then
        self.state.live_view = not self.state.live_view
        -- When switching to param view, hand arc back to NornsUI param control
        if not self.state.live_view then
          if _seeker.arc then
            _seeker.arc.clear_display()
            _seeker.arc.new_section(self.params)
            _seeker.arc.sync_display()
          end
        else
          -- Switching back to live view: take arc for cycling display
          if _seeker.arc then
            _seeker.arc.set_display(function() update_arc() end)
          end
        end
        _seeker.screen_ui.set_needs_redraw()
      end
      return
    end

    if n == 3 and z == 1 then
      if self.state.live_view then
        -- Live view K3: mode-dependent
        local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
        local stage_idx = edit_stage or lane.current_stage_index or 1

        if control_mode ~= "chord" then
          -- Progression mode: cycle strum order (wrap)
          local new_val = Cycling.cycle_stage_strum(stage_idx)
          arc_overlay = {
            name = "S" .. stage_idx .. " Strum",
            value = new_val,
            time = util.time()
          }
        end

        update_arc()
        _seeker.screen_ui.set_needs_redraw()
        return
      end
    end

    -- In param view: default NornsUI key handling
    if not self.state.live_view then
      NornsUI.handle_key(self, n, z)
    end
  end

  -- Encoders: in live view, silently consume. In param view, default behavior.
  norns_ui.handle_enc = function(self, n, d)
    if self.state.live_view then
      return  -- Encoders silently consumed in live view
    end
    self:handle_enc_default(n, d)
  end

  -- Lifecycle: enter sets up arc override and rebuilds
  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)

    -- Ensure stage motifs exist (first entry after reload, or lane switch)
    rebuild()

    -- Default to live view on enter
    self.state.live_view = true

    -- Take over arc display for cycling
    if _seeker.arc then
      _seeker.arc.set_display(function() update_arc() end)
    end
  end

  local original_exit = norns_ui.exit
  norns_ui.exit = function(self)
    -- Release arc display override
    if _seeker.arc then
      _seeker.arc.clear_display()
    end
    original_exit(self)
  end

  return norns_ui
end

---------------------------------------------------------------
-- Params
---------------------------------------------------------------
local function create_params()
  params:add_group("rc_cycling_group", "CYCLING CHORDS", 13)

  params:add_option("rc_cycling_flavor", "Flavor", FLAVOR_NAMES, 1)
  params:set_action("rc_cycling_flavor", function(value)
    if not initialized then return end
    local recipe = FLAVOR_RECIPES[value]
    if not recipe then return end
    loading = true
    params:set("rc_cycling_movement", recipe.movement)
    params:set("rc_cycling_voicing", recipe.voicing)
    params:set("rc_cycling_chord_len", recipe.chord_len)
    params:set("rc_cycling_rotation", recipe.rotation)
    loading = false
    local lane_id = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_id]
    lane.cycling_voicing_overrides = {}
    lane.cycling_chord_len_overrides = {}
    lane.cycling_strum_overrides = {}
    lane.cycling_degree_overrides = {}
    lane.cycling_rotation_overrides = {}
    rebuild()
  end)

  params:add_option("rc_cycling_start", "Start Degree", DEGREE_NAMES, 1)
  params:set_action("rc_cycling_start", function() rebuild() end)

  params:add_option("rc_cycling_movement", "Movement", MOVEMENT_NAMES, 10)
  params:set_action("rc_cycling_movement", function() rebuild() end)

  params:add_option("rc_cycling_quality", "Quality", QUALITY_NAMES, 1)
  params:set_action("rc_cycling_quality", function() rebuild() end)

  params:add_option("rc_cycling_chord_len", "Chord Len", CHORD_LEN_NAMES, 3)
  params:set_action("rc_cycling_chord_len", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].cycling_chord_len_overrides = {}
    rebuild()
  end)

  params:add_option("rc_cycling_voicing", "Voicing", VOICING_NAMES, 1)
  params:set_action("rc_cycling_voicing", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].cycling_voicing_overrides = {}
    rebuild()
  end)

  params:add_option("rc_cycling_strum_order", "Strum Order", STRUM_ORDER_NAMES, 1)
  params:set_action("rc_cycling_strum_order", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].cycling_strum_overrides = {}
    rebuild()
  end)

  params:add_option("rc_cycling_rotation", "Rotation", ROTATION_NAMES, 6)
  params:set_action("rc_cycling_rotation", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].cycling_rotation_overrides = {}
    rebuild()
  end)

  params:add_number("rc_cycling_octave", "Octave", 1, 7, 3)
  params:set_action("rc_cycling_octave", function() rebuild() end)

  params:add_control("rc_cycling_spread", "Spread",
    controlspec.new(0, 100, "lin", 1, 10, "%"))
  params:set_action("rc_cycling_spread", function() rebuild() end)

  params:add_number("rc_cycling_stages", "Stages", 1, 8, 1)
  params:set_action("rc_cycling_stages", function() rebuild() end)

  params:add_number("rc_cycling_loops", "Loops", 1, 8, 2)
  params:set_action("rc_cycling_loops", function() rebuild() end)

  params:add_number("rc_cycling_beats", "Beats", 1, 16, 4)
  params:set_action("rc_cycling_beats", function() rebuild() end)

  initialized = true
end

---------------------------------------------------------------
-- Randomize
---------------------------------------------------------------
function Cycling.randomize()
  params:set("rc_cycling_flavor", math.random(1, #FLAVOR_NAMES))

  loading = true
  params:set("rc_cycling_stages", math.random(2, 5))
  local beat_options = {2, 3, 4, 5, 6, 8, 10, 12}
  params:set("rc_cycling_beats", beat_options[math.random(1, #beat_options)])
  local spread_options = {0, 10, 20, 30, 50, 70, 100}
  params:set("rc_cycling_spread", spread_options[math.random(1, #spread_options)])
  loading = false

  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local num_stages = params:get("rc_cycling_stages")
  lane.cycling_degree_overrides = {}
  for i = 1, num_stages do
    lane.cycling_degree_overrides[i] = math.random(1, 7)
  end
  lane.cycling_voicing_overrides = {}
  lane.cycling_chord_len_overrides = {}
  lane.cycling_strum_overrides = {}
  lane.cycling_rotation_overrides = {}

  rebuild()
end

---------------------------------------------------------------
-- Grid UI: row 7 controls
---------------------------------------------------------------
local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "COMPOSER_CYCLING",
    layout = {
      x = 1,
      y = 7,
      width = 4,
      height = 1
    }
  })

  grid_ui.long_press_threshold = 1.0

  grid_ui.draw = function(self, layers)
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")
    if motif_type ~= COMPOSER_MODE then return end

    -- Col 1: control mode toggle (chord / progression)
    local in_progression = control_mode == "progression"
    layers.ui[1][7] = in_progression
      and GridConstants.BRIGHTNESS.UI.FOCUSED
      or GridConstants.BRIGHTNESS.UI.NORMAL

    local num_stages = params:get("rc_cycling_stages")

    -- Col 2: remove chord
    layers.ui[2][7] = num_stages > 1
      and (STAGE_BRIGHTNESS[num_stages - 1] or 4)
      or 2

    -- Col 3: add chord
    layers.ui[3][7] = num_stages < 8
      and (STAGE_BRIGHTNESS[num_stages + 1] or 4)
      or 2

    -- Col 4: hold-to-randomize (long press fill animation)
    local randomize_brightness = GridConstants.BRIGHTNESS.UI.NORMAL
    if self:is_holding_long_press() then
      local key_id = "4,7"
      local press = self.press_state.pressed_keys[key_id]
      if press then
        local elapsed = util.time() - press.start_time
        local progress = math.min(elapsed / self.long_press_threshold, 1)
        randomize_brightness = math.floor(3 + progress * 12)
      end
    end
    layers.ui[4][7] = randomize_brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")
    if motif_type ~= COMPOSER_MODE then return end

    -- Randomize button (4,7): hold to confirm, release early to cancel
    if x == 4 and y == 7 then
      local key_id = "4,7"
      if z == 1 then
        self:key_down(key_id)
        -- Navigate to cycling section
        if _seeker.ui_state.get_current_section() ~= "COMPOSER_CYCLING" then
          _seeker.ui_state.set_current_section("COMPOSER_CYCLING")
        end
        -- Show hold prompt and start countdown clock
        if _seeker.modal then
          _seeker.modal.show_warning({ body = "Hold to randomize..." })
        end
        self.randomize_clock = clock.run(function()
          clock.sleep(self.long_press_threshold)
          -- Still holding: fire randomize
          if self.press_state.pressed_keys[key_id] then
            Cycling.randomize()
            update_arc()
            if _seeker.modal then
              _seeker.modal.dismiss()
              _seeker.modal.show_status({ body = "RANDOMIZED" })
            end
            clock.sleep(0.5)
            if _seeker.modal then _seeker.modal.dismiss() end
            _seeker.screen_ui.set_needs_redraw()
          end
        end)
        _seeker.screen_ui.set_needs_redraw()
      else
        -- Release: cancel countdown if not yet fired
        if self.randomize_clock then
          clock.cancel(self.randomize_clock)
          self.randomize_clock = nil
        end
        if _seeker.modal and _seeker.modal.is_active() then
          _seeker.modal.dismiss()
        end
        self:key_release(key_id)
        _seeker.screen_ui.set_needs_redraw()
      end
      return
    end

    -- All other buttons: press-only
    if z ~= 1 then return end

    -- Navigate to cycling section on any button press
    if _seeker.ui_state.get_current_section() ~= "COMPOSER_CYCLING" then
      _seeker.ui_state.set_current_section("COMPOSER_CYCLING")
    end

    if x == 1 and y == 7 then
      -- Toggle arc control mode: chord (per-stage) vs progression (global)
      control_mode = control_mode == "chord" and "progression" or "chord"
      arc_overlay = {
        name = "Mode",
        value = control_mode == "chord" and "Chord" or "Progression",
        time = util.time(),
        duration = 0.4,
      }
      update_arc()
      _seeker.screen_ui.set_needs_redraw()

    elseif x == 2 and y == 7 then
      local current = params:get("rc_cycling_stages")
      if current > 1 then
        params:set("rc_cycling_stages", current - 1)
        arc_overlay = { name = "Stages", value = tostring(current - 1), time = util.time() }
        _seeker.screen_ui.set_needs_redraw()
      end

    elseif x == 3 and y == 7 then
      local current = params:get("rc_cycling_stages")
      if current < 8 then
        params:set("rc_cycling_stages", current + 1)
        arc_overlay = { name = "Stages", value = tostring(current + 1), time = util.time() }
        _seeker.screen_ui.set_needs_redraw()
      end
    end
  end

  return grid_ui
end

---------------------------------------------------------------
-- Per-stage override helpers
---------------------------------------------------------------

-- Advance a per-stage override within a named option list.
-- direction nil = wrap (button press), +1/-1 = clamp at edges (arc).
local function advance_stage_override(names, index_lookup, overrides, stage_index, base_name, direction)
  local current = overrides[stage_index] or base_name
  local current_idx = index_lookup[current] or 1

  local next_idx
  if direction then
    next_idx = util.clamp(current_idx + direction, 1, #names)
  else
    next_idx = (current_idx % #names) + 1
  end
  overrides[stage_index] = names[next_idx]
  return names[next_idx]
end

-- Cycle degree for a specific stage. direction: nil=wrap, +1/-1=clamp.
function Cycling.cycle_stage_degree(stage_index, direction)
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  lane.cycling_degree_overrides = lane.cycling_degree_overrides or {}

  local start = params:get("rc_cycling_start")
  local movement = movement_value(params:get("rc_cycling_movement"))
  local default_degree = ((start - 1 + movement * (stage_index - 1)) % 7) + 1
  local current = lane.cycling_degree_overrides[stage_index] or default_degree

  local next_degree
  if direction then
    next_degree = util.clamp(current + direction, 1, 7)
  else
    next_degree = (current % 7) + 1
  end
  lane.cycling_degree_overrides[stage_index] = next_degree
  rebuild()
  return DEGREE_NAMES[next_degree]
end

function Cycling.cycle_stage_rotation(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.cycling_rotation_overrides = lane.cycling_rotation_overrides or {}
  local base = ROTATION_NAMES[params:get("rc_cycling_rotation")]
  local result = advance_stage_override(ROTATION_NAMES, ROTATION_INDEX, lane.cycling_rotation_overrides, stage_index, base, direction)
  rebuild()
  return result
end

function Cycling.cycle_stage_strum(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.cycling_strum_overrides = lane.cycling_strum_overrides or {}
  local base = STRUM_ORDER_NAMES[params:get("rc_cycling_strum_order")]
  local result = advance_stage_override(STRUM_ORDER_NAMES, STRUM_INDEX, lane.cycling_strum_overrides, stage_index, base, direction)
  rebuild()
  return result
end

function Cycling.cycle_stage_voicing(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.cycling_voicing_overrides = lane.cycling_voicing_overrides or {}
  local base = VOICING_NAMES[params:get("rc_cycling_voicing")]
  local result = advance_stage_override(VOICING_NAMES, VOICING_INDEX, lane.cycling_voicing_overrides, stage_index, base, direction)
  rebuild()
  return result
end

function Cycling.cycle_stage_chord_len(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.cycling_chord_len_overrides = lane.cycling_chord_len_overrides or {}
  local base = CHORD_LEN_NAMES[params:get("rc_cycling_chord_len")]
  local result = advance_stage_override(CHORD_LEN_NAMES, CHORD_LEN_INDEX, lane.cycling_chord_len_overrides, stage_index, base, direction)
  rebuild()
  return result
end

---------------------------------------------------------------
-- Save/load cycling param snapshots per lane
---------------------------------------------------------------
function Cycling.save_cycling_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  local snapshot = {}
  for _, p in ipairs(CYCLING_PARAMS) do
    snapshot[p.id] = params:get(p.id)
  end
  snapshot.strum_overrides = lane.cycling_strum_overrides or {}
  snapshot.voicing_overrides = lane.cycling_voicing_overrides or {}
  snapshot.chord_len_overrides = lane.cycling_chord_len_overrides or {}
  snapshot.degree_overrides = lane.cycling_degree_overrides or {}
  snapshot.rotation_overrides = lane.cycling_rotation_overrides or {}
  lane.cycling_param_snapshot = snapshot
end

function Cycling.load_cycling_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  loading = true
  if lane.cycling_param_snapshot then
    for _, p in ipairs(CYCLING_PARAMS) do
      params:set(p.id, lane.cycling_param_snapshot[p.id] or p.default)
    end
    lane.cycling_strum_overrides = lane.cycling_param_snapshot.strum_overrides or {}
    lane.cycling_voicing_overrides = lane.cycling_param_snapshot.voicing_overrides or {}
    lane.cycling_chord_len_overrides = lane.cycling_param_snapshot.chord_len_overrides or {}
    lane.cycling_degree_overrides = lane.cycling_param_snapshot.degree_overrides or {}
    lane.cycling_rotation_overrides = lane.cycling_param_snapshot.rotation_overrides or {}
  else
    for _, p in ipairs(CYCLING_PARAMS) do
      params:set(p.id, p.default)
    end
    lane.cycling_strum_overrides = {}
    lane.cycling_voicing_overrides = {}
    lane.cycling_chord_len_overrides = {}
    lane.cycling_degree_overrides = {}
    lane.cycling_rotation_overrides = {}
  end
  loading = false
end

-- Lane change callback: save outgoing, load incoming
function Cycling.on_lane_change(old_lane_id, new_lane_id)
  Cycling.save_cycling_params(old_lane_id)
  Cycling.load_cycling_params(new_lane_id)
end

-- Trigger a rebuild from outside
function Cycling.rebuild()
  rebuild()
end

-- Arc handlers exposed for screensaver/state routing during transition
Cycling.handle_arc_delta = handle_arc_delta
Cycling.handle_arc_key = handle_arc_key
Cycling.update_arc = update_arc

-- Expose param registry for RC save/restore
Cycling.CYCLING_PARAMS = CYCLING_PARAMS

function Cycling.init()
  Cycling.screen = create_screen_ui()
  Cycling.grid = create_grid_ui()
  create_params()
  return Cycling
end

return Cycling
