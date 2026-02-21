-- cycling.lua
-- Form chord progression generator with dual-mode NornsUI.
-- Voice leading graph with arc/K3 control. Encoders access form params.
-- Grid: 4 lane rows (rows 4-7). Col 1 = lane button, cols 2-9 = per-lane stages.
-- Hold gestures delegate to _seeker.hold_confirm for full-screen progress bar feedback.
-- Lane tap cycles sections. Lane hold 1.5s = randomize.
-- Stage tap: first click selects + snaps to FORM_LIVE, second click toggles arc page. Hold = set count.
-- Arc: 2-page control (harmony per-stage overrides, articulation globals+strum).

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local Form = {}
Form.__index = Form

local COMPOSER_MODE = 2

-- Guard against set_action firing during param creation
local initialized = false
-- Suppress rebuild while loading a lane's form param snapshot
local loading = false

-- Named option tables for musically meaningful labels
local DEGREE_NAMES = {"I", "ii", "iii", "IV", "V", "vi", "vii"}
local MOVEMENT_NAMES = {
  "7ths Dn", "6ths Dn", "5ths Dn", "4ths Dn", "3rds Dn", "Steps Dn",
  "Pedal",
  "Steps Up", "3rds Up", "4ths Up", "5ths Up", "6ths Up", "7ths Up"
}
local CHORD_LEN_NAMES = {
  "2", "3", "4", "5", "6",
  "7", "8", "9", "10", "11", "12", "13", "14", "15"
}
local ROTATION_NAMES = {
  "-5", "-4", "-3", "-2", "-1",
  "Root", "1st Inv", "2nd Inv", "3rd Inv", "4th Inv", "5th Inv"
}
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
Form.DEGREE_NAMES = DEGREE_NAMES
Form.VOICING_NAMES = VOICING_NAMES
Form.STRUM_ORDER_NAMES = STRUM_ORDER_NAMES
Form.ROTATION_NAMES = ROTATION_NAMES
Form.CHORD_LEN_NAMES = CHORD_LEN_NAMES

-- Option index to actual value conversions
local function movement_value(idx) return idx - 7 end   -- index 7 = Unison (0)
local function rotation_value(idx) return idx - 6 end   -- index 6 = Root (0)
local function chord_len_value(idx) return idx + 1 end   -- index 1 = Dyad (2)

-- Form param definitions for per-lane save/load
local FORM_PARAMS = {
  {id = "rc_form_start", default = 1},
  {id = "rc_form_movement", default = 10},   -- 4th Up
  {id = "rc_form_chord_len", default = 3},    -- Tetrad
  {id = "rc_form_voicing", default = 1},
  {id = "rc_form_strum_order", default = 1},
  {id = "rc_form_rotation", default = 6},     -- Root
  {id = "rc_form_spread", default = 10},
  {id = "rc_form_stages", default = 1},
  {id = "rc_form_loops", default = 2},
  {id = "rc_form_beats", default = 4},
}

-- Stage count brightness: maps 1-8 stages to LED levels
local STAGE_BRIGHTNESS = {3, 4, 6, 7, 9, 10, 12, 13}

---------------------------------------------------------------
-- Module-level state for the live view (edit stage, arc mode, overlay display)
---------------------------------------------------------------
local edit_stage = nil        -- nil = follow playback, 1-8 = explicit
local arc_page = 1            -- 1 = harmony (per-stage), 2 = articulation
local arc_overlay = nil       -- {name, value, time, duration?}
local arc_accum = {0, 0, 0, 0}
-- Arc ring mappings per page.
-- Page 1 (harmony): per-stage overrides via cycle functions.
-- Page 2 (articulation): spread coarse/fine (global), strum (per-stage), loops (global).
local ARC_HARMONY = {
  [1] = {label = "Deg",    fn = "cycle_stage_degree",    threshold = 56},
  [2] = {label = "Len",    fn = "cycle_stage_chord_len", threshold = 56},
  [3] = {label = "Voice",  fn = "cycle_stage_voicing",   threshold = 56},
  [4] = {label = "Rot",    fn = "cycle_stage_rotation",  threshold = 56},
}

local ARC_ARTICULATION = {
  [1] = {label = "Sprd",   param_id = "rc_form_spread",      threshold = 30,  step = 5},
  [2] = {label = "Sprd~",  param_id = "rc_form_spread",      threshold = 80,  step = 1},
  [3] = {label = "Strum",  fn = "cycle_stage_strum",          threshold = 56},
  [4] = {label = "Loops",  param_id = "rc_form_loops",        threshold = 56},
}

local ARC_PAGES = {
  [1] = ARC_HARMONY,
  [2] = ARC_ARTICULATION,
}

local ARC_PAGE_NAMES = {"harmony", "articulation"}

---------------------------------------------------------------
-- Strum ordering utility: reorder notes by strum pattern name.
-- Returns a new array of notes in play order.
---------------------------------------------------------------
function Form.order_notes(notes, strum_name)
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

  local start = params:get("rc_form_start")
  local movement = movement_value(params:get("rc_form_movement"))
  local chord_len = chord_len_value(params:get("rc_form_chord_len"))
  local voicing = VOICING_NAMES[params:get("rc_form_voicing")]
  local rotation = rotation_value(params:get("rc_form_rotation"))
  local spread = params:get("rc_form_spread")
  local base_strum_order = STRUM_ORDER_NAMES[params:get("rc_form_strum_order")]
  local num_stages = params:get("rc_form_stages")
  local loops = params:get("rc_form_loops")
  local beats = params:get("rc_form_beats")

  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local strum_overrides = lane.form_strum_overrides or {}
  local voicing_overrides = lane.form_voicing_overrides or {}
  local chord_len_overrides = lane.form_chord_len_overrides or {}
  local rotation_overrides = lane.form_rotation_overrides or {}

  local stages = {}
  for i = 1, num_stages do
    local degree_overrides = lane.form_degree_overrides or {}
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
        type = "Diatonic",
        dur = beats,
        gate = stage_gate,
        chord_len = stage_chord_len,
        voicing = stage_voicing,
        rotation = stage_rotation,
      }},
      octave = 3,
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
    -- Prepare motif data without starting playback.
    -- Playback starts from explicit gestures (hold stage, hold lane, randomize).
    _seeker.rc.form(lane_id, stages)
  end

  -- Clamp edit stage to valid range
  if edit_stage and edit_stage > num_stages then
    edit_stage = num_stages
  end

  Form.save_form_params(lane_id)

  if _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

---------------------------------------------------------------
-- Arc display helpers
---------------------------------------------------------------

-- Draw option segments on a ring: one bright segment for the current index
local function draw_arc_option_segments(dev, ring, current_idx, num_options, is_overridden)
  for i = 1, 64 do dev:led(ring, i, 2) end
  local segment = math.floor(64 / num_options)
  local start = (current_idx - 1) * segment + 1
  local brightness = is_overridden and 14 or 10
  for i = start, math.min(64, start + segment - 1) do
    dev:led(ring, i, brightness)
  end
end

-- Draw position marker on a ring: dot with flanking glow
local function draw_arc_position(dev, ring, value, min_val, max_val)
  for i = 1, 64 do dev:led(ring, i, 2) end
  local norm = (value - min_val) / (max_val - min_val)
  local pos = math.floor(norm * 63) + 1
  dev:led(ring, pos, 12)
  if pos > 1 then dev:led(ring, pos - 1, 6) end
  if pos < 64 then dev:led(ring, pos + 1, 6) end
end

-- Draw fill bar on a ring: filled from 0 to normalized position
local function draw_arc_fill(dev, ring, value, spec)
  for i = 1, 64 do dev:led(ring, i, 2) end
  local norm = (value - spec.minval) / (spec.maxval - spec.minval)
  local fill_end = math.floor(norm * 64)
  for i = 1, fill_end do dev:led(ring, i, 10) end
end

---------------------------------------------------------------
-- Arc display: update LED rings based on arc page
---------------------------------------------------------------
local function update_arc()
  local dev = _seeker.arc
  if not dev then return end
  if not params.lookup["rc_form_start"] then return end

  if arc_page == 1 then
    -- Harmony page: per-stage overrides with segment displays
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local stage_idx = edit_stage or lane.current_stage_index or 1
    local degree_overrides = lane.form_degree_overrides or {}
    local voicing_overrides = lane.form_voicing_overrides or {}
    local rotation_overrides = lane.form_rotation_overrides or {}
    local chord_len_overrides = lane.form_chord_len_overrides or {}

    -- Ring 1: degree
    local start = params:get("rc_form_start")
    local movement = params:get("rc_form_movement") - 7
    local default_degree = ((start - 1 + movement * (stage_idx - 1)) % 7) + 1
    local current_degree = degree_overrides[stage_idx] or default_degree
    draw_arc_option_segments(dev, 1, current_degree, #DEGREE_NAMES, degree_overrides[stage_idx])

    -- Ring 2: chord length
    local chord_len_idx = params:get("rc_form_chord_len")
    if chord_len_overrides[stage_idx] then
      chord_len_idx = CHORD_LEN_INDEX[chord_len_overrides[stage_idx]] or chord_len_idx
    end
    draw_arc_option_segments(dev, 2, chord_len_idx, #CHORD_LEN_NAMES, chord_len_overrides[stage_idx])

    -- Ring 3: voicing
    local voicing_idx = params:get("rc_form_voicing")
    if voicing_overrides[stage_idx] then
      voicing_idx = VOICING_INDEX[voicing_overrides[stage_idx]] or voicing_idx
    end
    draw_arc_option_segments(dev, 3, voicing_idx, #VOICING_NAMES, voicing_overrides[stage_idx])

    -- Ring 4: rotation
    local rot_idx = params:get("rc_form_rotation")
    if rotation_overrides[stage_idx] then
      rot_idx = ROTATION_INDEX[rotation_overrides[stage_idx]] or rot_idx
    end
    draw_arc_option_segments(dev, 4, rot_idx, #ROTATION_NAMES, rotation_overrides[stage_idx])

  elseif arc_page == 2 then
    -- Articulation page: spread (coarse + fine), strum per-stage, loops
    local spread_spec = params:lookup_param("rc_form_spread").controlspec
    draw_arc_fill(dev, 1, params:get("rc_form_spread"), spread_spec)
    draw_arc_fill(dev, 2, params:get("rc_form_spread"), spread_spec)

    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local stage_idx = edit_stage or lane.current_stage_index or 1
    local strum_overrides = lane.form_strum_overrides or {}
    local strum_idx = params:get("rc_form_strum_order")
    if strum_overrides[stage_idx] then
      strum_idx = STRUM_INDEX[strum_overrides[stage_idx]] or strum_idx
    end
    draw_arc_option_segments(dev, 3, strum_idx, #STRUM_ORDER_NAMES, strum_overrides[stage_idx])

    local loops_obj = params:lookup_param("rc_form_loops")
    draw_arc_position(dev, 4, params:get("rc_form_loops"), loops_obj.min, loops_obj.max)
  end

  dev:refresh()
end

---------------------------------------------------------------
-- Handle arc delta: accumulate and step params based on arc page
---------------------------------------------------------------
local function handle_arc_delta(n, delta)
  if not params.lookup["rc_form_start"] then return end

  local page = ARC_PAGES[arc_page]
  local mapping = page and page[n]
  if not mapping then return end

  arc_accum[n] = arc_accum[n] + 1
  if arc_accum[n] < mapping.threshold then return end
  arc_accum[n] = 0

  local direction = delta > 0 and 1 or -1

  if mapping.fn then
    -- Per-stage override via cycle function (harmony page + articulation strum)
    if Form[mapping.fn] then
      local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
      local stage_idx = edit_stage or lane.current_stage_index or 1
      local new_val = Form[mapping.fn](stage_idx, direction)
      arc_overlay = {
        name = "S" .. stage_idx .. " " .. mapping.label,
        value = new_val,
        time = util.time()
      }
    end
  else
    -- Global param step (articulation spread/loops)
    local param_id = mapping.param_id
    if not params.lookup[param_id] then return end
    _seeker.arc.step_param(param_id, direction, mapping.step)
    arc_overlay = {
      name = mapping.label,
      value = params:string(param_id),
      time = util.time()
    }
  end

  update_arc()
  _seeker.screen_ui.set_needs_redraw()
end

---------------------------------------------------------------
-- Handle arc button: cycle through arc pages
---------------------------------------------------------------
local function handle_arc_key(n, z)
  if z ~= 1 then return end
  arc_page = (arc_page % 2) + 1
  arc_accum = {0, 0, 0, 0}
  arc_overlay = {
    name = ARC_PAGE_NAMES[arc_page],
    value = arc_page .. "/2",
    time = util.time(),
    duration = 0.4,
  }
  update_arc()
  _seeker.screen_ui.set_needs_redraw()
end

---------------------------------------------------------------
-- Voice leading graph drawing (live view)
---------------------------------------------------------------
local function draw_live(norns_ui)
  if not params.lookup["rc_form_start"] then return end

  local start_degree = params:get("rc_form_start")
  local movement = params:get("rc_form_movement") - 7
  local num_stages = params:get("rc_form_stages")
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local current_stage = math.min(lane.current_stage_index or 1, num_stages)

  local degree_overrides = lane.form_degree_overrides or {}
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

  if not has_notes then
    screen.level(3)
    screen.move(64, 32)
    screen.text_center(num_stages .. " stages")
    return
  end

  -- Vertical pitch area with margins for labels
  local Y_TOP = 10
  local Y_BOTTOM = 45
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
  local strum_overrides = lane.form_strum_overrides or {}
  local base_strum = params:string("rc_form_strum_order")

  -- Strum voice lines: connect notes by strum position between adjacent chords
  -- Shows the melodic paths the ear follows (1st-strummed to 1st-strummed, etc.)
  local strum_ordered = {}
  for i = 1, num_stages do
    local strum = strum_overrides[i] or base_strum
    strum_ordered[i] = Form.order_notes(stage_notes[i], strum)
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

  -- Page indicator: small squares top-right (filled = current page)
  for p = 1, 2 do
    local px = 120 + (p - 1) * 5
    screen.level(p == arc_page and 10 or 3)
    screen.rect(px, 2, 3, 3)
    if p == arc_page then screen.fill() else screen.stroke() end
  end

  -- Degree labels above each column
  for i = 1, num_stages do
    local is_playing = (i == current_stage)
    local is_editing = (edit_stage and i == edit_stage)
    screen.level(is_playing and 12 or (is_editing and 10 or 4))
    screen.move(col_x[i], 8)
    screen.text_center(DEGREE_NAMES[degrees[i]])
    if is_editing then
      screen.level(8)
      screen.move(col_x[i] - 4, 9)
      screen.line(col_x[i] + 4, 9)
      screen.stroke()
    end
  end

  -- Footer: arc overlay or 4-column param labels
  screen.level(0)
  screen.rect(0, 46, 128, 18)
  screen.fill()

  local overlay_dur = arc_overlay and arc_overlay.duration or 1.2
  if arc_overlay and (util.time() - arc_overlay.time) < overlay_dur then
    local fade = math.max(0, 1 - (util.time() - arc_overlay.time) / overlay_dur)
    screen.level(math.floor(15 * fade))
    screen.move(64, 59)
    screen.text_center(arc_overlay.name .. ": " .. arc_overlay.value)
  else
    local display_stage = edit_stage or (lane and lane.current_stage_index) or 1
    local cols = {16, 48, 80, 112}
    local labels, values

    if arc_page == 1 then
      local voicing_overrides = lane and lane.form_voicing_overrides or {}
      local rotation_overrides = lane and lane.form_rotation_overrides or {}
      local chord_len_overrides = lane and lane.form_chord_len_overrides or {}
      local rot_idx = params:get("rc_form_rotation")
      if rotation_overrides[display_stage] then
        rot_idx = ROTATION_INDEX[rotation_overrides[display_stage]] or rot_idx
      end
      labels = {"Deg", "Len", "Voice", "Rot"}
      values = {
        DEGREE_NAMES[degrees[display_stage] or 1],
        chord_len_overrides[display_stage] or params:string("rc_form_chord_len"),
        voicing_overrides[display_stage] or params:string("rc_form_voicing"),
        tostring(rot_idx - 6),
      }
    else
      labels = {"Sprd", "Sprd~", "Strum", "Loops"}
      values = {
        params:string("rc_form_spread"),
        params:string("rc_form_spread"),
        strum_overrides[display_stage] or params:string("rc_form_strum_order"),
        params:string("rc_form_loops"),
      }
    end

    screen.level(5)
    for i = 1, 4 do
      screen.move(cols[i], 55)
      screen.text_center(labels[i])
    end
    screen.level(12)
    for i = 1, 4 do
      screen.move(cols[i], 63)
      screen.text_center(values[i])
    end
  end
end

---------------------------------------------------------------
-- NornsUI: dual-mode screen (live view default, K2 toggles params)
---------------------------------------------------------------
local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "FORM_LIVE",
    name = "Form",
    description = Descriptions.COMPOSER_FORM,
    params = {}
  })

  norns_ui.live_view_enabled = true
  norns_ui.needs_playback_refresh = true

  norns_ui.rebuild_params = function(self)
    self.params = {
      { separator = true, title = "Harmony" },
      { id = "rc_form_chord_len" },
      { id = "rc_form_voicing" },
      { id = "rc_form_rotation" },
      { separator = true, title = "Articulation" },
      { id = "rc_form_spread", arc_multi_float = {5, 2, 0.5} },
      { id = "rc_form_strum_order" },
      { id = "rc_form_loops" },
      { separator = true, title = "Structure" },
      { id = "rc_form_start" },
      { id = "rc_form_movement" },
      { id = "rc_form_stages" },
      { id = "rc_form_beats" },
    }
  end

  norns_ui.draw_live = function(self) draw_live(self) end
  norns_ui.update_arc = function(self) update_arc() end
  norns_ui.handle_arc_delta = function(self, n, delta) handle_arc_delta(n, delta) end
  norns_ui.handle_arc_key = function(self, n, z) handle_arc_key(n, z) end

  -- K3 in live view: harmony page = cycle degree, articulation page = cycle strum
  norns_ui.handle_live_key = function(self, n, z)
    if n == 3 and z == 1 then
      local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
      local stage_idx = edit_stage or lane.current_stage_index or 1

      if arc_page == 1 then
        local new_val = Form.cycle_stage_degree(stage_idx)
        arc_overlay = {
          name = "S" .. stage_idx .. " Deg",
          value = new_val,
          time = util.time()
        }
      else
        local new_val = Form.cycle_stage_strum(stage_idx)
        arc_overlay = {
          name = "S" .. stage_idx .. " Strum",
          value = new_val,
          time = util.time()
        }
      end

      update_arc()
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return norns_ui
end

---------------------------------------------------------------
-- Params
---------------------------------------------------------------
local function create_params()
  params:add_group("rc_form_group", "FORM CHORDS", 10)

  params:add_option("rc_form_start", "Start Degree", DEGREE_NAMES, 1)
  params:set_action("rc_form_start", function() rebuild() end)

  params:add_option("rc_form_movement", "Movement", MOVEMENT_NAMES, 10)
  params:set_action("rc_form_movement", function() rebuild() end)

  params:add_option("rc_form_chord_len", "Chord Len", CHORD_LEN_NAMES, 3)
  params:set_action("rc_form_chord_len", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].form_chord_len_overrides = {}
    rebuild()
  end)

  params:add_option("rc_form_voicing", "Voicing", VOICING_NAMES, 1)
  params:set_action("rc_form_voicing", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].form_voicing_overrides = {}
    rebuild()
  end)

  params:add_option("rc_form_strum_order", "Strum Order", STRUM_ORDER_NAMES, 1)
  params:set_action("rc_form_strum_order", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].form_strum_overrides = {}
    rebuild()
  end)

  params:add_option("rc_form_rotation", "Rotation", ROTATION_NAMES, 6)
  params:set_action("rc_form_rotation", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].form_rotation_overrides = {}
    rebuild()
  end)

  params:add_control("rc_form_spread", "Spread",
    controlspec.new(0, 100, "lin", 1, 10, "%"))
  params:set_action("rc_form_spread", function() rebuild() end)

  params:add_number("rc_form_stages", "Stages", 1, 8, 1)
  params:set_action("rc_form_stages", function() rebuild() end)

  params:add_number("rc_form_loops", "Loops", 1, 8, 2)
  params:set_action("rc_form_loops", function() rebuild() end)

  params:add_number("rc_form_beats", "Beats", 1, 16, 4)
  params:set_action("rc_form_beats", function() rebuild() end)

  initialized = true
end

---------------------------------------------------------------
-- Randomize
---------------------------------------------------------------
function Form.randomize()
  loading = true
  params:set("rc_form_start", math.random(1, #DEGREE_NAMES))
  params:set("rc_form_movement", math.random(1, #MOVEMENT_NAMES))
  params:set("rc_form_stages", math.random(2, 5))
  local beat_options = {2, 3, 4, 5, 6, 8, 10, 12}
  params:set("rc_form_beats", beat_options[math.random(1, #beat_options)])
  params:set("rc_form_chord_len", math.random(1, #CHORD_LEN_NAMES))
  params:set("rc_form_voicing", math.random(1, #VOICING_NAMES))
  params:set("rc_form_rotation", math.random(1, #ROTATION_NAMES))
  local spread_options = {0, 10, 20, 30, 50, 70, 100}
  params:set("rc_form_spread", spread_options[math.random(1, #spread_options)])
  params:set("rc_form_strum_order", math.random(1, #STRUM_ORDER_NAMES))
  params:set("rc_form_loops", math.random(1, 4))
  loading = false

  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local num_stages = params:get("rc_form_stages")
  lane.form_degree_overrides = {}
  for i = 1, num_stages do
    lane.form_degree_overrides[i] = math.random(1, 7)
  end
  lane.form_voicing_overrides = {}
  lane.form_chord_len_overrides = {}
  lane.form_strum_overrides = {}
  lane.form_rotation_overrides = {}

  -- Stop existing playback so randomize takes effect immediately
  if lane.playing then
    lane:stop()
  end

  rebuild()
  lane:play({quantize = true})
end

---------------------------------------------------------------
-- Grid UI: 4 lane rows (rows 4-7), each with lane button (col 1)
-- and stage buttons (cols 2-9). All lanes visible simultaneously.
---------------------------------------------------------------
local NUM_FORM_LANES = 4
local FIRST_ROW = 4
local HOLD_THRESHOLD_STAGE = 1.0     -- visible progress duration after display delay
local HOLD_THRESHOLD_RANDOMIZE = 1.5 -- seconds for hold-to-randomize (matches tape clear)

-- Get stage count for a lane (global params if focused, snapshot otherwise)
local function get_lane_stages(lane_idx)
  if lane_idx == _seeker.ui_state.get_focused_lane() then
    return params:get("rc_form_stages")
  end
  local lane = _seeker.lanes[lane_idx]
  if lane.form_param_snapshot then
    return lane.form_param_snapshot.rc_form_stages or 1
  end
  return 1
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "FORM_GRID",
    layout = {
      x = 1,
      y = FIRST_ROW,
      width = 9,
      height = NUM_FORM_LANES
    }
  })



  grid_ui.contains = function(self, x, y)
    if y < FIRST_ROW or y > FIRST_ROW + NUM_FORM_LANES - 1 then return false end
    if x >= 1 and x <= 9 then return true end
    return false
  end

  grid_ui.draw = function(self, layers)
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local DIM = GridConstants.BRIGHTNESS.DIM
    local HIGH = GridConstants.BRIGHTNESS.HIGH

    for i = 1, NUM_FORM_LANES do
      local row = FIRST_ROW + i - 1
      local lane = _seeker.lanes[i]
      local is_focused = i == focused_lane
      local num_stages = get_lane_stages(i)
      local current_stage = lane.current_stage_index or 1

      -- Col 1: lane button
      local lane_brightness
      if is_focused then
        lane_brightness = GridConstants.BRIGHTNESS.FULL
      elseif lane.playing then
        lane_brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
      else
        lane_brightness = GridConstants.BRIGHTNESS.LOW
      end
      layers.ui[1][row] = lane_brightness

      -- Detect active hold gesture: lane hold sweeps all 8, stage hold sweeps to target
      local charge_progress = nil
      local charge_end_stage = 8

      -- Lane button hold (randomize): smooth sweep across all 8 stages
      local lane_key = string.format("1,%d", row)
      local lane_press = self.press_state.pressed_keys[lane_key]
      if lane_press then
        local elapsed = util.time() - lane_press.start_time
        if elapsed > 0.3 then
          local progress = math.min((elapsed - 0.3) / (HOLD_THRESHOLD_RANDOMIZE - 0.3), 1)
          charge_progress = progress * 8
          charge_end_stage = 8
          lane_brightness = math.floor(GridConstants.BRIGHTNESS.LOW + progress * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.LOW))
          layers.ui[1][row] = lane_brightness
        end
      end

      -- Stage button hold (set count): smooth sweep toward target stage
      if not charge_progress then
        for stage = 1, 8 do
          local stage_key = string.format("%d,%d", stage + 1, row)
          local stage_press = self.press_state.pressed_keys[stage_key]
          if stage_press then
            local elapsed = util.time() - stage_press.start_time
            if elapsed > 0.3 then
              local progress = math.min((elapsed - 0.3) / (HOLD_THRESHOLD_STAGE - 0.3), 1)
              charge_progress = progress * stage
              charge_end_stage = stage
              break
            end
          end
        end
      end

      -- Cols 2-9: stage buttons with per-LED charge-up interpolation
      for stage = 1, 8 do
        local col = stage + 1
        local brightness

        if charge_progress and stage <= charge_end_stage then
          -- Smooth charge: each LED fades from DIM to HIGH as the sweep passes it
          local stage_progress = util.clamp(charge_progress - (stage - 1), 0, 1)
          brightness = DIM + math.floor(stage_progress * (HIGH - DIM))
        elseif stage > num_stages then
          brightness = DIM
        elseif lane.playing and stage == current_stage then
          brightness = HIGH
        elseif is_focused and edit_stage and stage == edit_stage then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        else
          brightness = GridConstants.BRIGHTNESS.LOW
        end
        layers.ui[col][row] = brightness
      end
    end
  end

  -- Section cycle order for lane button taps
  local LANE_TAP_SECTIONS = {"FORM_VOICE", "FORM_PLAYBACK", "FORM_LIVE"}

  grid_ui.handle_key = function(self, x, y, z)
    local lane_idx = y - FIRST_ROW + 1
    if lane_idx < 1 or lane_idx > NUM_FORM_LANES then return end

    -- Track whether this press switched lanes
    local old_lane = _seeker.ui_state.get_focused_lane()
    local switched_lane = false

    if z == 1 then
      -- Focus this lane (saves outgoing params, loads incoming snapshot)
      if lane_idx ~= old_lane then
        _seeker.ui_state.set_focused_lane(lane_idx)
        switched_lane = true
      end
    end

    -- Col 1: lane button (tap = cycle sections, hold = randomize)
    if x == 1 then
      local key_id = string.format("1,%d", y)
      if z == 1 then
        self:key_down(key_id)

        if not switched_lane then
          -- Already focused: cycle through sections
          local current = _seeker.ui_state.get_current_section()
          local next_section = LANE_TAP_SECTIONS[1]
          for i, section in ipairs(LANE_TAP_SECTIONS) do
            if current == section then
              next_section = LANE_TAP_SECTIONS[(i % #LANE_TAP_SECTIONS) + 1]
              break
            end
          end
          _seeker.ui_state.set_current_section(next_section)
        else
          -- Switched lane: rebuild current section for new lane's params
          local current = _seeker.ui_state.get_current_section()
          local section = _seeker.screen_ui.sections[current]
          if section and section.rebuild_params then
            section:rebuild_params()
          end
        end

        _seeker.hold_confirm.start({
          text = "randomizing...",
          threshold = HOLD_THRESHOLD_RANDOMIZE,
          on_confirm = function()
            Form.randomize()
            update_arc()
          end
        })

        _seeker.screen_ui.set_needs_redraw()
      else
        _seeker.hold_confirm.cancel()
        self:key_release(key_id)
        _seeker.screen_ui.set_needs_redraw()
      end
      return
    end

    -- Cols 2-9: stage buttons
    -- Tap: first click selects stage + snaps to FORM_LIVE, second click toggles arc page.
    -- Hold: set stage count via HoldConfirm.
    if x >= 2 and x <= 9 then
      local stage = x - 1
      local key_id = string.format("%d,%d", x, y)

      if z == 1 then
        self:key_down(key_id)

        -- Stage tap flow: select or toggle arc page
        local current = _seeker.ui_state.get_current_section()
        if current ~= "FORM_LIVE" or edit_stage ~= stage then
          -- First click: select this stage, snap to live view
          _seeker.ui_state.set_current_section("FORM_LIVE")
          edit_stage = stage
          arc_overlay = {
            name = ARC_PAGE_NAMES[arc_page],
            value = arc_page .. "/2",
            time = util.time(),
            duration = 0.4,
          }
        else
          -- Second click (same stage, already on FORM_LIVE): toggle arc page
          arc_page = (arc_page % 2) + 1
          arc_accum = {0, 0, 0, 0}
          arc_overlay = {
            name = ARC_PAGE_NAMES[arc_page],
            value = arc_page .. "/2",
            time = util.time(),
            duration = 0.4,
          }
        end

        -- Hold: confirm threshold sets stage count and starts playback if stopped
        _seeker.hold_confirm.start({
          text = "stages: " .. stage,
          threshold = HOLD_THRESHOLD_STAGE,
          on_confirm = function()
            params:set("rc_form_stages", stage)
            local lane = _seeker.lanes[lane_idx]
            if not lane.playing then
              lane:play({quantize = true})
            end
            update_arc()
          end
        })

        update_arc()
        _seeker.screen_ui.set_needs_redraw()

      else
        _seeker.hold_confirm.cancel()
        self:key_release(key_id)
        update_arc()
        _seeker.screen_ui.set_needs_redraw()
      end
      return
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
function Form.cycle_stage_degree(stage_index, direction)
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  lane.form_degree_overrides = lane.form_degree_overrides or {}

  local start = params:get("rc_form_start")
  local movement = movement_value(params:get("rc_form_movement"))
  local default_degree = ((start - 1 + movement * (stage_index - 1)) % 7) + 1
  local current = lane.form_degree_overrides[stage_index] or default_degree

  local next_degree
  if direction then
    next_degree = util.clamp(current + direction, 1, 7)
  else
    next_degree = (current % 7) + 1
  end
  lane.form_degree_overrides[stage_index] = next_degree
  rebuild()
  return DEGREE_NAMES[next_degree]
end

function Form.cycle_stage_rotation(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.form_rotation_overrides = lane.form_rotation_overrides or {}
  local base = ROTATION_NAMES[params:get("rc_form_rotation")]
  local result = advance_stage_override(ROTATION_NAMES, ROTATION_INDEX, lane.form_rotation_overrides, stage_index, base, direction)
  rebuild()
  return result
end

function Form.cycle_stage_strum(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.form_strum_overrides = lane.form_strum_overrides or {}
  local base = STRUM_ORDER_NAMES[params:get("rc_form_strum_order")]
  local result = advance_stage_override(STRUM_ORDER_NAMES, STRUM_INDEX, lane.form_strum_overrides, stage_index, base, direction)
  rebuild()
  return result
end

function Form.cycle_stage_voicing(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.form_voicing_overrides = lane.form_voicing_overrides or {}
  local base = VOICING_NAMES[params:get("rc_form_voicing")]
  local result = advance_stage_override(VOICING_NAMES, VOICING_INDEX, lane.form_voicing_overrides, stage_index, base, direction)
  rebuild()
  return result
end

function Form.cycle_stage_chord_len(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.form_chord_len_overrides = lane.form_chord_len_overrides or {}
  local base = CHORD_LEN_NAMES[params:get("rc_form_chord_len")]
  local result = advance_stage_override(CHORD_LEN_NAMES, CHORD_LEN_INDEX, lane.form_chord_len_overrides, stage_index, base, direction)
  rebuild()
  return result
end

---------------------------------------------------------------
-- Save/load cycling param snapshots per lane
---------------------------------------------------------------
function Form.save_form_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  local snapshot = {}
  for _, p in ipairs(FORM_PARAMS) do
    snapshot[p.id] = params:get(p.id)
  end
  snapshot.strum_overrides = lane.form_strum_overrides or {}
  snapshot.voicing_overrides = lane.form_voicing_overrides or {}
  snapshot.chord_len_overrides = lane.form_chord_len_overrides or {}
  snapshot.degree_overrides = lane.form_degree_overrides or {}
  snapshot.rotation_overrides = lane.form_rotation_overrides or {}
  lane.form_param_snapshot = snapshot
end

function Form.load_form_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  loading = true
  if lane.form_param_snapshot then
    for _, p in ipairs(FORM_PARAMS) do
      params:set(p.id, lane.form_param_snapshot[p.id] or p.default)
    end
    lane.form_strum_overrides = lane.form_param_snapshot.strum_overrides or {}
    lane.form_voicing_overrides = lane.form_param_snapshot.voicing_overrides or {}
    lane.form_chord_len_overrides = lane.form_param_snapshot.chord_len_overrides or {}
    lane.form_degree_overrides = lane.form_param_snapshot.degree_overrides or {}
    lane.form_rotation_overrides = lane.form_param_snapshot.rotation_overrides or {}
  else
    for _, p in ipairs(FORM_PARAMS) do
      params:set(p.id, p.default)
    end
    lane.form_strum_overrides = {}
    lane.form_voicing_overrides = {}
    lane.form_chord_len_overrides = {}
    lane.form_degree_overrides = {}
    lane.form_rotation_overrides = {}
  end
  loading = false
end

-- Lane change callback: save outgoing, load incoming, generate chords for new lane
function Form.on_lane_change(old_lane_id, new_lane_id)
  Form.save_form_params(old_lane_id)
  Form.load_form_params(new_lane_id)
  rebuild()
end

-- Trigger a rebuild from outside
function Form.rebuild()
  rebuild()
end

-- Expose param registry for RC save/restore
Form.FORM_PARAMS = FORM_PARAMS

function Form.init()
  Form.screen = create_screen_ui()
  Form.grid = create_grid_ui()
  create_params()
  return Form
end

return Form
