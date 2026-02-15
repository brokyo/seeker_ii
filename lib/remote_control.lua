-- remote_control.lua
-- Remote control interface for querying and controlling Seeker II state.
-- All output prefixed with "RC:" for filtering in logs.

local musicutil = require('musicutil')
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
  for i = 1, 4 do
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
  for i = 1, 4 do
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
  for stage_id = 1, 4 do
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

function RC.init()
  p("Remote Control initialized")
end

return RC
