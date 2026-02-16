-- remote_control.lua
-- Remote control interface for querying and controlling Seeker II state.
-- All output prefixed with "RC:" for filtering in logs.

local musicutil = require('musicutil')
local theory = include('lib/modes/motif/core/theory')
local chord_generator = include('lib/modes/motif/core/chord_generator')
local RC = {}

local function p(msg)
  print("RC: " .. msg)
end

local function print_separator()
  print("RC: ----------------------------------------")
end

-- Motif type index to name
local MOTIF_TYPES = { "Tape", "Composer", "Sampler" }

local function motif_type_name(lane_id)
  local idx = params:get("lane_" .. lane_id .. "_motif_type")
  return MOTIF_TYPES[idx] or "Unknown"
end

local function voice_list(lane)
  local voices = {}
  if lane.mx_samples_active then table.insert(voices, "MX") end
  if lane.midi_active then table.insert(voices, "MIDI") end
  if lane.eurorack_active then table.insert(voices, "Crow") end
  if lane.just_friends_active then table.insert(voices, "JF") end
  if lane.wsyn_active then table.insert(voices, "WSyn") end
  if lane.osc_active then table.insert(voices, "OSC") end
  if lane.disting_active then table.insert(voices, "Disting") end
  if lane.txo_osc_active then table.insert(voices, "TXO") end
  if lane.disting_nt_active then table.insert(voices, "DistNT") end
  if #voices == 0 then return "none" end
  return table.concat(voices, ", ")
end

local function format_active_stages(lane)
  local parts = {}
  for i = 1, #lane.stages do
    local s = lane.stages[i]
    if s.active then
      local marker = (i == lane.current_stage_index) and "*" or ""
      table.insert(parts, string.format("%d%s(%dL)", i, marker, s.loops))
    end
  end
  if #parts == 0 then return "none active" end
  return table.concat(parts, " ")
end

-- Print overview of all lanes and global state
function RC.snapshot()
  print_separator()
  p("SNAPSHOT")
  print_separator()

  -- Global state
  local root = params:string("root_note")
  local scale_idx = params:get("scale_type")
  local scale_name = musicutil.SCALES[scale_idx] and musicutil.SCALES[scale_idx].name or "?"
  local section = _seeker.ui_state.get_current_section()
  local focused = _seeker.ui_state.get_focused_lane()
  local tempo = params:get("clock_tempo")

  p(string.format("Root: %s  Scale: %s  Tempo: %.0f", root, scale_name, tempo))
  p(string.format("Section: %s  Focused Lane: %d", section, focused))
  print_separator()

  -- Lane summary
  for i = 1, _seeker.num_lanes do
    local lane = _seeker.lanes[i]
    local mtype = motif_type_name(i)
    local status = lane.playing and "PLAYING" or "stopped"
    local events = #lane.motif.events
    local stages = format_active_stages(lane)

    p(string.format("Lane %d: %-8s | %-7s | %3d events | stages: %s",
      i, mtype, status, events, stages))
  end
  print_separator()
end

-- Print detailed state for one lane
function RC.lane(lane_id)
  lane_id = lane_id or _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  if not lane then
    p("ERROR: No lane " .. tostring(lane_id))
    return
  end

  print_separator()
  p(string.format("LANE %d", lane_id))
  print_separator()

  local mtype = motif_type_name(lane_id)
  local status = lane.playing and "PLAYING" or "stopped"
  p(string.format("Type: %s  Status: %s", mtype, status))
  p(string.format("Voices: %s", voice_list(lane)))

  -- Instrument (MX Samples)
  if lane.mx_samples_active then
    p(string.format("Instrument: %s", params:string("lane_" .. lane_id .. "_instrument")))
  end

  -- Playback params
  p(string.format("Speed: %s  Octave Offset: %d",
    params:string("lane_" .. lane_id .. "_speed"),
    params:get("lane_" .. lane_id .. "_octave_offset")))
  p(string.format("Volume: %.2f  Pan: %.2f",
    params:get("lane_" .. lane_id .. "_volume"),
    params:get("lane_" .. lane_id .. "_pan")))

  -- Envelope
  p(string.format("ADSR: %.2f / %.2f / %.2f / %.2f",
    params:get("lane_" .. lane_id .. "_attack"),
    params:get("lane_" .. lane_id .. "_decay"),
    params:get("lane_" .. lane_id .. "_sustain"),
    params:get("lane_" .. lane_id .. "_release")))

  -- Effects
  p(string.format("Delay: %.2f  Reverb: %.2f",
    lane.delay_send, lane.reverb_send))

  -- Motif
  p(string.format("Events: %d  Duration: %.2f beats",
    #lane.motif.events, lane.motif:get_duration()))

  -- Stages
  print_separator()
  for i = 1, #lane.stages do
    local s = lane.stages[i]
    local active = s.active and "ON" or "off"
    local mute = s.mute and " MUTE" or ""
    local current = (i == lane.current_stage_index and lane.playing) and " <-" or ""
    p(string.format("  Stage %d: %s%s  loops: %d/%d  reset: %s%s",
      i, active, mute, s.current_loop, s.loops,
      tostring(s.reset_motif), current))
  end
  print_separator()
end

-- Print composer-specific state with resolved params per stage
function RC.composer(lane_id)
  lane_id = lane_id or _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  if not lane then
    p("ERROR: No lane " .. tostring(lane_id))
    return
  end

  local mtype_idx = params:get("lane_" .. lane_id .. "_motif_type")
  if mtype_idx ~= 2 then
    p(string.format("Lane %d is not in Composer mode (current: %s)", lane_id, MOTIF_TYPES[mtype_idx] or "?"))
    return
  end

  print_separator()
  p(string.format("COMPOSER - Lane %d", lane_id))
  print_separator()

  -- Lane-level composer params
  local stage_mode = params:string("lane_" .. lane_id .. "_composer_stage_mode")
  local step_length = params:string("lane_" .. lane_id .. "_composer_step_length")
  local num_steps = params:get("lane_" .. lane_id .. "_composer_num_steps")

  p(string.format("Stage Mode: %s  Steps: %d  Step Length: %s", stage_mode, num_steps, step_length))

  -- Transform drift params (only meaningful in Transform mode)
  if stage_mode == "Transform" then
    p(string.format("Harmonic Motion: %s", params:string("lane_" .. lane_id .. "_composer_harmonic_motion")))
    p(string.format("Drift - Voice: %d  Octave: %d  Duration: %d%%  Velocity: %d  Strum: %d%%",
      params:get("lane_" .. lane_id .. "_composer_voice_drift"),
      params:get("lane_" .. lane_id .. "_composer_octave_drift"),
      params:get("lane_" .. lane_id .. "_composer_duration_drift"),
      params:get("lane_" .. lane_id .. "_composer_velocity_drift"),
      params:get("lane_" .. lane_id .. "_composer_strum_drift")))
  end

  print_separator()

  -- Resolved params for each stage
  -- Resolve parameters per stage, applying Transform mode derivation rules
  local is_transform = stage_mode == "Transform"
  for stage_id = 1, #lane.stages do
    local s = lane.stages[stage_id]
    local active = s.active and "ON" or "off"
    local current = (stage_id == lane.current_stage_index and lane.playing) and " <-" or ""

    -- Read resolved params (same logic as generator.resolve_stage_params)
    local prefix = "lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_"
    local seed = "lane_" .. lane_id .. "_stage_1_composer_"

    local chord_root, chord_type, chord_length, voice_rotation, voicing_style, octave
    local pattern, note_duration, vel_curve, vel_min, vel_max
    local strum_amount, strum_curve, strum_shape

    if not is_transform or stage_id == 1 then
      chord_root = params:get(prefix .. "chord_root")
      chord_type = params:string(prefix .. "chord_type")
      chord_length = params:get(prefix .. "chord_length")
      voice_rotation = params:get(prefix .. "voice_rotation")
      voicing_style = params:string(prefix .. "voicing_style")
      octave = params:get(prefix .. "octave")
      pattern = params:string(prefix .. "pattern")
      note_duration = params:get(prefix .. "note_duration")
      vel_curve = params:string(prefix .. "velocity_curve")
      vel_min = params:get(prefix .. "velocity_min")
      vel_max = params:get(prefix .. "velocity_max")
      strum_amount = params:get(prefix .. "strum_amount")
      strum_curve = params:string(prefix .. "strum_curve")
      strum_shape = params:string(prefix .. "strum_shape")
    else
      -- Transform mode: derive from Stage 1
      local HARMONIC_MOTION = {0, 1, -1, 2, -2, 3, -3, 4, -4}
      local steps = stage_id - 1
      local degree_offset = HARMONIC_MOTION[params:get("lane_" .. lane_id .. "_composer_harmonic_motion")]
      local v_drift = params:get("lane_" .. lane_id .. "_composer_voice_drift")
      local o_drift = params:get("lane_" .. lane_id .. "_composer_octave_drift")
      local d_drift = params:get("lane_" .. lane_id .. "_composer_duration_drift")
      local vel_drift = params:get("lane_" .. lane_id .. "_composer_velocity_drift")
      local s_drift = params:get("lane_" .. lane_id .. "_composer_strum_drift")

      chord_root = ((params:get(seed .. "chord_root") - 1 + degree_offset * steps) % 7) + 1
      chord_type = params:string(seed .. "chord_type")
      chord_length = params:get(seed .. "chord_length")
      voice_rotation = util.clamp(params:get(seed .. "voice_rotation") + v_drift * steps, -5, 5)
      voicing_style = params:string(seed .. "voicing_style")
      octave = util.clamp(params:get(seed .. "octave") + o_drift * steps, 1, 7)
      pattern = params:string(seed .. "pattern")
      note_duration = util.clamp(params:get(seed .. "note_duration") + d_drift * steps, 1, 300)
      vel_curve = params:string(seed .. "velocity_curve")
      vel_min = util.clamp(params:get(seed .. "velocity_min") + vel_drift * steps, 1, 127)
      vel_max = util.clamp(params:get(seed .. "velocity_max") + vel_drift * steps, 1, 127)
      strum_amount = util.clamp(params:get(seed .. "strum_amount") + s_drift * steps, 0, 100)
      strum_curve = params:string(seed .. "strum_curve")
      strum_shape = params:string(seed .. "strum_shape")
    end

    p(string.format("Stage %d [%s]%s:", stage_id, active, current))
    p(string.format("  Chord: root=%d type=%s len=%d  Voice: rot=%d style=%s",
      chord_root, chord_type, chord_length, voice_rotation, voicing_style))
    p(string.format("  Octave: %d  Pattern: %s  Duration: %d%%",
      octave, pattern, note_duration))
    p(string.format("  Velocity: %s min=%d max=%d",
      vel_curve, vel_min, vel_max))
    p(string.format("  Strum: %d%% curve=%s shape=%s",
      strum_amount, strum_curve, strum_shape))
  end
  print_separator()
end

-- Set a param and print confirmation
function RC.set(param_id, value)
  params:set(param_id, value)
  local display = params:string(param_id)
  p(string.format("SET: %s = %s", param_id, display))
end

-- Use explicit nil check so values like 0 and false are preserved
local function default(val, fallback)
  if val ~= nil then return val end
  return fallback
end

-- Convert 1-based scale degree + octave to MIDI note
-- Scale spans 10 octaves so degree 8+ wraps into higher octaves. Returns nil if out of range.
local function scale_degree_to_midi(degree, octave)
  local root = params:get("root_note")
  local scale = theory.get_scale()

  -- Find root note at target octave in the scale array
  local target_root = (octave + 1) * 12 + (root - 1)
  local root_index = nil
  for i, note in ipairs(scale) do
    if note >= target_root then
      root_index = i
      break
    end
  end

  if not root_index then return nil end

  local index = root_index + (degree - 1)
  if index < 1 or index > #scale then return nil end
  return scale[index]
end

-- Build events from scale degrees or chord voicings without storing to lane motif.
-- Returns {events, duration} table or nil on error.
local function build_motif_events(lane_id, opts)
  opts = opts or {}

  local octave = opts.octave or 4
  local gate = opts.gate or 0.8
  local strum = opts.strum or 0
  local total = opts.total

  -- Resolve notes: each entry is an array of MIDI notes (single note or chord)
  local note_groups = {}

  if opts.chord then
    -- Chord mode: generate full voicing for each degree
    local degrees = opts.degrees or {1}
    local chord_len = opts.chord_len or 4
    local voicing = opts.voicing or "Close"
    local rotation = opts.rotation or 0

    for _, deg in ipairs(degrees) do
      local chord_notes = chord_generator.generate_chord(deg, opts.chord, chord_len, rotation, voicing)
      local midi_notes = {}
      for _, cn in ipairs(chord_notes) do
        table.insert(midi_notes, cn + ((octave + 1) * 12))
      end
      table.insert(note_groups, midi_notes)
    end
  else
    -- Degree mode: single notes from current scale
    local degrees = opts.degrees or {1}
    for _, deg in ipairs(degrees) do
      local midi = scale_degree_to_midi(deg, octave)
      if midi then
        table.insert(note_groups, {midi})
      end
    end
  end

  if #note_groups == 0 then
    p("ERROR: No notes resolved")
    return nil
  end

  -- Rhythm: beat durations per note (cycles if shorter than note_groups)
  local rhythm = opts.rhythm or {}
  if #rhythm == 0 then
    local default_dur = (total or (#note_groups * 2)) / #note_groups
    for i = 1, #note_groups do
      rhythm[i] = default_dur
    end
  end

  local rest = opts.rest or {}

  -- Velocities: single value expands to all notes
  local velocities = opts.velocities
  if type(velocities) == "number" then
    local v = velocities
    velocities = {}
    for i = 1, #note_groups do velocities[i] = v end
  elseif not velocities then
    velocities = {}
    for i = 1, #note_groups do velocities[i] = 100 end
  end

  -- ADSR defaults: opts > lane params
  local lp = "lane_" .. lane_id .. "_"
  local def_attack = default(opts.attack, params:get(lp .. "attack"))
  local def_decay = default(opts.decay, params:get(lp .. "decay"))
  local def_sustain = default(opts.sustain, params:get(lp .. "sustain"))
  local def_release = default(opts.release, params:get(lp .. "release"))
  local def_pan = default(opts.pan, params:get(lp .. "pan"))

  local envelopes = opts.envelopes or {}

  -- Build note_on/note_off event pairs
  local events = {}
  local time = 0

  for i, notes in ipairs(note_groups) do
    local r = rhythm[((i - 1) % #rhythm) + 1]
    local rest_val = (#rest > 0) and rest[((i - 1) % #rest) + 1] or 0
    local vel = velocities[((i - 1) % #velocities) + 1]
    local note_dur = r * gate

    -- Per-note envelope: envelopes[i] > opts > lane params
    local env = envelopes[i]
    local att = default(env and env.attack, def_attack)
    local dec = default(env and env.decay, def_decay)
    local sus = default(env and env.sustain, def_sustain)
    local rel = default(env and env.release, def_release)
    local pan = default(env and env.pan, def_pan)

    local note_start = time + rest_val

    for j, note in ipairs(notes) do
      local strum_offset = (j - 1) * strum

      table.insert(events, {
        time = note_start + strum_offset,
        type = "note_on",
        note = note,
        velocity = vel,
        x = 0, y = 0,
        is_playback = true,
        attack = att,
        decay = dec,
        sustain = sus,
        release = rel,
        pan = pan,
        generation = 1,
      })

      table.insert(events, {
        time = note_start + strum_offset + note_dur,
        type = "note_off",
        note = note,
        x = 0, y = 0,
        generation = 1,
      })
    end

    time = time + rest_val + r
  end

  if not total then total = time end

  table.sort(events, function(a, b) return a.time < b.time end)

  return {events = events, duration = total}
end

-- Compute strum timing for each voice position based on pluck direction.
-- Returns table mapping note index (1-based) to its strum position (0-based).
local function strum_timing(n, order)
  local seq = {}

  if order == "Down" then
    for i = n, 1, -1 do seq[#seq + 1] = i end

  elseif order == "Out>In" then
    local lo, hi = 1, n
    while lo <= hi do
      seq[#seq + 1] = lo
      if lo ~= hi then seq[#seq + 1] = hi end
      lo = lo + 1
      hi = hi - 1
    end

  elseif order == "In>Out" then
    local mid = math.ceil(n / 2)
    seq[#seq + 1] = mid
    for offset = 1, n do
      if mid + offset <= n then seq[#seq + 1] = mid + offset end
      if mid - offset >= 1 then seq[#seq + 1] = mid - offset end
    end

  elseif order == "Random" then
    for i = 1, n do seq[i] = i end
    for i = n, 2, -1 do
      local j = math.random(1, i)
      seq[i], seq[j] = seq[j], seq[i]
    end

  else -- "Up" (default)
    for i = 1, n do seq[i] = i end
  end

  -- Invert: seq[position] = note_index -> timing[note_index] = position
  local timing = {}
  for pos, note_idx in ipairs(seq) do
    timing[note_idx] = pos - 1
  end
  return timing
end

-- Build events from a chord progression sequence without storing to lane motif.
-- Each chord placed sequentially. Returns {events, duration} table or nil on error.
local function build_phrase_events(lane_id, opts)
  opts = opts or {}

  local chords = opts.chords
  if not chords or #chords == 0 then
    p("ERROR: No chords specified")
    return nil
  end

  local octave = opts.octave or 4
  local chord_len = opts.chord_len or 3
  local voicing = opts.voicing or "Close"
  local rotation = opts.rotation or 0
  local gate = opts.gate or 0.8
  local strum = opts.strum or 0
  local strum_order = opts.strum_order or "Up"
  local velocity = opts.velocity or 100

  -- ADSR defaults: opts > lane params
  local lp = "lane_" .. lane_id .. "_"
  local def_attack = default(opts.attack, params:get(lp .. "attack"))
  local def_decay = default(opts.decay, params:get(lp .. "decay"))
  local def_sustain = default(opts.sustain, params:get(lp .. "sustain"))
  local def_release = default(opts.release, params:get(lp .. "release"))
  local def_pan = default(opts.pan, params:get(lp .. "pan"))

  local events = {}
  local time = 0

  for _, chord_def in ipairs(chords) do
    local degree = chord_def.degree or 1
    local chord_type = chord_def.type or "Major"
    local dur = chord_def.dur or 4
    local chord_vel = chord_def.velocity or velocity
    local chord_gate = chord_def.gate or gate

    -- Per-chord envelope overrides
    local att = default(chord_def.attack, def_attack)
    local dec = default(chord_def.decay, def_decay)
    local sus = default(chord_def.sustain, def_sustain)
    local rel = default(chord_def.release, def_release)
    local pan = default(chord_def.pan, def_pan)

    local c_len = chord_def.chord_len or chord_len
    local c_voicing = chord_def.voicing or voicing
    local c_rotation = chord_def.rotation or rotation

    local chord_notes = chord_generator.generate_chord(degree, chord_type, c_len, c_rotation, c_voicing)
    local timing = strum_timing(#chord_notes, strum_order)

    for j, cn in ipairs(chord_notes) do
      local note = cn + ((octave + 1) * 12)
      local strum_offset = timing[j] * strum

      table.insert(events, {
        time = time + strum_offset,
        type = "note_on",
        note = note,
        velocity = chord_vel,
        x = 0, y = 0,
        is_playback = true,
        attack = att,
        decay = dec,
        sustain = sus,
        release = rel,
        pan = pan,
        generation = 1,
      })

      table.insert(events, {
        time = time + strum_offset + (dur * chord_gate),
        type = "note_off",
        note = note,
        x = 0, y = 0,
        generation = 1,
      })
    end

    time = time + dur
  end

  table.sort(events, function(a, b) return a.time < b.time end)

  return {events = events, duration = time}
end

-- Build a scale-aware motif from degrees or chords and store it on a lane.
-- Degree mode: maps scale degrees to single notes.
-- Chord mode: generates full chord voicings per degree.
-- Timing from rhythm/rest/gate arrays, ADSR resolved per-note > motif-level > lane params.
function RC.motif(lane_id, opts)
  local lane = _seeker.lanes[lane_id]
  if not lane then
    p("ERROR: No lane " .. tostring(lane_id))
    return
  end

  local data = build_motif_events(lane_id, opts)
  if not data then return end

  lane.motif:store_events(data)
  p(string.format("MOTIF: Lane %d, %d events, %.1f beats", lane_id, #data.events, data.duration))
end

-- Build a chord progression as a single motif.
-- Each entry in chords = {degree, type, dur} placed sequentially.
function RC.phrase(lane_id, opts)
  local lane = _seeker.lanes[lane_id]
  if not lane then
    p("ERROR: No lane " .. tostring(lane_id))
    return
  end

  local data = build_phrase_events(lane_id, opts)
  if not data then return end

  lane.motif:store_events(data)
  p(string.format("PHRASE: Lane %d, %d chords, %d events, %.1f beats", lane_id, #opts.chords, #data.events, data.duration))
end

-- Flag current stage for regeneration at next loop boundary
function RC.regen(lane_id)
  lane_id = lane_id or _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  if not lane then
    p("ERROR: No lane " .. tostring(lane_id))
    return
  end

  local stage_idx = lane.current_stage_index
  local stage = lane.stages[stage_idx]
  stage.reset_motif = true
  p(string.format("REGEN: Lane %d stage %d flagged for regeneration", lane_id, stage_idx))
end

-- Store events for a specific stage slot on a lane.
-- Accepts same options as motif() and phrase(); uses phrase mode if opts.chords is present.
function RC.stage(lane_id, stage_id, opts)
  local lane = _seeker.lanes[lane_id]
  if not lane then
    p("ERROR: No lane " .. tostring(lane_id))
    return
  end

  local data
  if opts.chords then
    data = build_phrase_events(lane_id, opts)
  else
    data = build_motif_events(lane_id, opts)
  end
  if not data then return end

  lane.rc_stage_motifs[stage_id] = data
  p(string.format("STAGE: Lane %d stage %d, %d events, %.1f beats", lane_id, stage_id, #data.events, data.duration))
end

-- Configure a multi-stage sequence on a lane with activation and loop counts.
-- Each entry contains motif/phrase options plus optional loops. Activates stages 1-N, deactivates the rest.
function RC.form(lane_id, stages)
  local lane = _seeker.lanes[lane_id]
  if not lane then
    p("ERROR: No lane " .. tostring(lane_id))
    return
  end

  local total_loops = 0
  local total_beats = 0

  for i, entry in ipairs(stages) do
    -- Extract loops before passing opts to stage builder
    local loops = entry.loops or 2
    total_loops = total_loops + loops

    -- Build and store events for this stage
    RC.stage(lane_id, i, entry)

    -- Activate this stage and set loop count
    params:set("lane_" .. lane_id .. "_stage_" .. i .. "_active", 2)
    params:set("lane_" .. lane_id .. "_stage_" .. i .. "_loops", loops)

    -- Accumulate total beats
    local data = lane.rc_stage_motifs[i]
    if data then
      total_beats = total_beats + (data.duration * loops)
    end
  end

  -- Deactivate unused stages
  for i = #stages + 1, 8 do
    params:set("lane_" .. lane_id .. "_stage_" .. i .. "_active", 1)
    lane.rc_stage_motifs[i] = nil
  end

  -- Sync stage params into lane state
  lane:sync_all_stages_from_params()

  -- Load stage 1 events into the motif so it's ready for immediate playback
  local first = lane.rc_stage_motifs[1]
  if first then
    lane.motif:store_events(first)
  end

  p(string.format("FORM: Lane %d, %d stages, %d loops, %.1f beats total", lane_id, #stages, total_loops, total_beats))
end

-- Serialize a Lua value (string/number/boolean/table) to a Lua-source string.
-- Handles the flat-with-nested-tables shape of motif events.
local function serialize(val, indent)
  indent = indent or ""
  local t = type(val)
  if t == "number" then
    return tostring(val)
  elseif t == "string" then
    return string.format("%q", val)
  elseif t == "boolean" then
    return tostring(val)
  elseif t == "table" then
    local parts = {}
    local next_indent = indent .. "  "
    -- Array part
    for i, v in ipairs(val) do
      table.insert(parts, next_indent .. serialize(v, next_indent))
    end
    -- Hash part (skip integer keys already covered)
    local array_len = #val
    for k, v in pairs(val) do
      if type(k) ~= "number" or k < 1 or k > array_len or math.floor(k) ~= k then
        local key_str
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
          key_str = k
        else
          key_str = "[" .. serialize(k) .. "]"
        end
        table.insert(parts, next_indent .. key_str .. " = " .. serialize(v, next_indent))
      end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
  end
  return "nil"
end

-- Save all lane motifs and playback state to disk.
-- Params are saved via norns PSET. Motif events serialized as Lua tables.
function RC.save(slot)
  slot = slot or 1
  local data_dir = norns.state.data
  util.make_dir(data_dir)

  -- Collect motif data from all lanes
  local save_data = {}
  local lanes_with_events = 0
  for i = 1, _seeker.num_lanes do
    local lane = _seeker.lanes[i]
    local lane_data = {
      events = lane.motif.events,
      genesis_events = lane.motif.genesis.events,
      duration = lane.motif.duration,
      genesis_duration = lane.motif.genesis.duration,
      playing = lane.playing,
      rc_stage_motifs = lane.rc_stage_motifs,
      cycling_param_snapshot = lane.cycling_param_snapshot,
    }
    save_data[i] = lane_data
    if #lane.motif.events > 0 then
      lanes_with_events = lanes_with_events + 1
    end
  end

  -- Write motif data as Lua source
  local path = data_dir .. "rc_save_" .. slot .. ".lua"
  local file = io.open(path, "w")
  file:write("-- RC save slot " .. slot .. "\n")
  file:write("return " .. serialize(save_data) .. "\n")
  file:close()

  -- Save params via norns PSET
  params:write(50 + slot, "rc_save_" .. slot)

  p(string.format("SAVE: Slot %d, %d lanes with events -> %s", slot, lanes_with_events, path))
end

-- Restore lane motifs and params from a previous save.
function RC.restore(slot)
  slot = slot or 1
  local data_dir = norns.state.data
  local path = data_dir .. "rc_save_" .. slot .. ".lua"

  -- Load motif data
  local loader = loadfile(path)
  if not loader then
    p("ERROR: No save found at slot " .. slot)
    return
  end

  local save_data = loader()

  -- Restore params first
  params:read(50 + slot)

  -- Restore motifs to each lane
  local restored = 0
  for i = 1, _seeker.num_lanes do
    local lane = _seeker.lanes[i]
    local lane_data = save_data[i]
    if lane_data then
      -- Restore RC stage motifs and cycling state
      lane.rc_stage_motifs = lane_data.rc_stage_motifs or {}
      lane.cycling_param_snapshot = lane_data.cycling_param_snapshot

      if #lane_data.events > 0 then
        -- Restore genesis state
        lane.motif.genesis.events = lane_data.genesis_events or {}
        lane.motif.genesis.duration = lane_data.genesis_duration or 0
        -- Restore working state
        lane.motif.events = lane_data.events
        lane.motif.duration = lane_data.duration or 0
        restored = restored + 1
      end
    end
  end

  -- Reload cycling params for the focused lane
  if _seeker.composer and _seeker.composer.cycling_load_params then
    _seeker.composer.cycling_load_params(_seeker.ui_state.get_focused_lane())
  end

  -- Restart lanes that were playing when saved
  local restarted = 0
  for i = 1, _seeker.num_lanes do
    local lane = _seeker.lanes[i]
    local lane_data = save_data[i]
    if lane_data and lane_data.playing and #lane.motif.events > 0 then
      lane:sync_all_stages_from_params()
      lane:play()
      restarted = restarted + 1
    end
  end

  p(string.format("RESTORE: Slot %d, %d lanes restored, %d restarted", slot, restored, restarted))
end

function RC.init()
  p("Remote Control initialized")
end

return RC
