-- engine.lua
-- Softcut engine for sampler mode playback and recording
-- NOTE: Chop data stored internally per-lane, params in chop_config are just a UI view

local SamplerEngine = {}

-- Constants
local NUM_PADS = 16
local MAX_LANES = 2  -- Limit to 2 lanes (one per mono buffer)
local LEFT_CHANNEL = 1
local MONO_MIX_LEVEL = 0.707  -- Equal power stereo-to-mono mix (maintains perceived loudness)

-- Playback modes
local MODE_GATE = 1      -- Plays while held, enables looping for sustain (default)
local MODE_ONE_SHOT = 2  -- Plays once, ignores release

-- Recording always uses softcut voice 6, separate from playback voice pool
local RECORDING_VOICE = 6

-- Filter types
local FILTER_OFF = 1
local FILTER_LOWPASS = 2
local FILTER_HIGHPASS = 3
local FILTER_BANDPASS = 4
local FILTER_NOTCH = 5

-- Create a chop with default values
local function create_default_chop(start_pos, stop_pos, overrides)
  local chop = {
    start_pos = start_pos or 0,
    stop_pos = stop_pos or 0,
    duration = (stop_pos or 0) - (start_pos or 0),
    attack = 0.1,
    release = 0.1,
    fade_time = 0.005,
    mode = MODE_GATE,
    rate = 1.0,
    pitch_offset = 0,  -- Semitones to transpose playback (positive = higher, negative = lower)
    max_volume = 1.0,
    pan = 0,
    filter_type = FILTER_OFF,
    lpf = 20000,
    resonance = 0,
    hpf = 20
  }
  if overrides then
    for k, v in pairs(overrides) do
      chop[k] = v
    end
  end
  return chop
end

-- State
SamplerEngine.num_voices = 6  -- Configurable voice count
SamplerEngine.voices = {}  -- voice[i] = {lane = lane_number, pad = pad_number, active = bool}
SamplerEngine.voice_generation = {}  -- Tracks assignment generation to prevent stale clock callbacks
SamplerEngine.lane_chops = {}  -- lane_chops[lane][pad] = working chops (what transforms mutate)
SamplerEngine.lane_genesis_chops = {}  -- lane_genesis_chops[lane][pad] = original chops (captured on load/record)
SamplerEngine.lane_durations = {}  -- lane_durations[lane] = sample_duration
SamplerEngine.lane_to_buffer = {}  -- lane_to_buffer[lane] = buffer_id (1 or 2)
SamplerEngine.buffer_occupied = {false, false}  -- tracks which buffers are in use
SamplerEngine.initialized = false
SamplerEngine.is_recording = false
SamplerEngine.recording_lane = nil
SamplerEngine.recording_voice = nil
SamplerEngine.recording_buffer = nil
SamplerEngine.recording_state = nil  -- nil, "recording", or "saving"
SamplerEngine.record_start_time = 0
SamplerEngine.file_select_active = false  -- true while norns fileselect is open
SamplerEngine.loading_state = nil  -- nil or "loading"

-- Initialize all softcut voices for sampler use
function SamplerEngine.init()
  print("≋ Initializing Sampler Engine")

  -- Ensure audio folder exists
  local audio_path = _path.audio .. "seeker_ii"
  util.make_dir(audio_path)

  -- Clear buffer
  softcut.buffer_clear()

  -- Initialize each voice
  for v = 1, SamplerEngine.num_voices do
    -- Enable voice
    softcut.enable(v, 1)

    -- Set playback parameters
    softcut.level(v, 0)  -- Start at 0 for attack envelope
    softcut.level_slew_time(v, 0)  -- Initialize slew time
    softcut.pan(v, 0)
    softcut.rate(v, 1.0)

    -- Disable recording by default
    softcut.rec(v, 0)
    softcut.rec_level(v, 0)
    softcut.pre_level(v, 0)

    -- Set loop mode
    softcut.loop(v, 1)  -- Enable looping

    -- Initialize loop points (will be updated per chop)
    softcut.loop_start(v, 0)
    softcut.loop_end(v, 1)

    -- Reset post-filter to bypass (prevents stale filter settings from previous scripts)
    softcut.post_filter_dry(v, 1.0)
    softcut.post_filter_lp(v, 0.0)
    softcut.post_filter_hp(v, 0.0)
    softcut.post_filter_bp(v, 0.0)
    softcut.post_filter_br(v, 0.0)

    -- Start disabled
    softcut.play(v, 0)

    -- Track voice state
    SamplerEngine.voices[v] = {
      lane = nil,
      pad = nil,
      active = false
    }
    SamplerEngine.voice_generation[v] = 0
  end

  -- Initialize per-lane storage
  for lane = 1, 8 do
    SamplerEngine.lane_durations[lane] = 0
    SamplerEngine.lane_chops[lane] = {}
    SamplerEngine.lane_genesis_chops[lane] = {}

    -- Initialize empty chops (16 pads per lane)
    for pad = 1, NUM_PADS do
      SamplerEngine.lane_chops[lane][pad] = create_default_chop()
      SamplerEngine.lane_genesis_chops[lane][pad] = create_default_chop()
    end
  end

  SamplerEngine.initialized = true
end

-- Allocate a free buffer for a lane (returns buffer_id 1 or 2, or nil if none available)
function SamplerEngine.allocate_buffer(lane)
  -- Check if lane already has a buffer
  if SamplerEngine.lane_to_buffer[lane] then
    return SamplerEngine.lane_to_buffer[lane]
  end

  -- Find first free buffer
  for buffer_id = 1, 2 do
    if not SamplerEngine.buffer_occupied[buffer_id] then
      SamplerEngine.lane_to_buffer[lane] = buffer_id
      SamplerEngine.buffer_occupied[buffer_id] = true
      return buffer_id
    end
  end

  return nil  -- No free buffers
end

-- Free a buffer when a lane is cleared
function SamplerEngine.free_buffer(lane)
  local buffer_id = SamplerEngine.lane_to_buffer[lane]
  if buffer_id then
    SamplerEngine.buffer_occupied[buffer_id] = false
    SamplerEngine.lane_to_buffer[lane] = nil
    SamplerEngine.lane_durations[lane] = 0
  end
end

-- Get buffer for a lane (returns nil if no buffer assigned)
function SamplerEngine.get_buffer_for_lane(lane)
  return SamplerEngine.lane_to_buffer[lane]
end

-- Clear all chop data and stop playback for a lane
function SamplerEngine.clear_lane_chops(lane)
  -- Stop all voices playing from this lane
  for v = 1, SamplerEngine.num_voices do
    if SamplerEngine.voices[v].active and SamplerEngine.voices[v].lane == lane then
      softcut.play(v, 0)
      SamplerEngine.voices[v].active = false
      SamplerEngine.voices[v].lane = nil
      SamplerEngine.voices[v].pad = nil
    end
  end

  -- Reset all chops to default empty state
  for pad = 1, NUM_PADS do
    SamplerEngine.lane_chops[lane][pad] = create_default_chop()
    SamplerEngine.lane_genesis_chops[lane][pad] = create_default_chop()
  end

  SamplerEngine.lane_durations[lane] = 0
end

-- Divide sample into equal chops across all pads for a specific lane
-- Captures to both genesis (original) and working chops
function SamplerEngine.set_fixed_chops(lane, sample_duration)
  SamplerEngine.lane_durations[lane] = sample_duration
  local chop_duration = sample_duration / NUM_PADS

  for pad = 1, NUM_PADS do
    local start_pos = (pad - 1) * chop_duration
    local stop_pos = start_pos + chop_duration
    local chop = create_default_chop(start_pos, stop_pos)
    -- Deep copy to genesis (original state)
    SamplerEngine.lane_genesis_chops[lane][pad] = create_default_chop(start_pos, stop_pos)
    -- Working copy for transforms to mutate
    SamplerEngine.lane_chops[lane][pad] = chop
  end
end

-- Get working chop data for a specific lane and pad
function SamplerEngine.get_chop(lane, pad)
  if not SamplerEngine.lane_chops[lane] then return nil end
  return SamplerEngine.lane_chops[lane][pad]
end

-- Get genesis (original) chop data for a specific lane and pad
function SamplerEngine.get_genesis_chop(lane, pad)
  if not SamplerEngine.lane_genesis_chops[lane] then return nil end
  return SamplerEngine.lane_genesis_chops[lane][pad]
end

-- Update a specific property of a working chop
-- Also updates genesis for user-configured properties (not transform results)
function SamplerEngine.update_chop(lane, pad, key, value)
  if not SamplerEngine.lane_chops[lane] or not SamplerEngine.lane_chops[lane][pad] then
    return
  end

  SamplerEngine.lane_chops[lane][pad][key] = value

  -- Recalculate duration if start or stop changed
  if key == "start_pos" or key == "stop_pos" then
    local chop = SamplerEngine.lane_chops[lane][pad]
    chop.duration = chop.stop_pos - chop.start_pos
  end

  -- User-configured properties persist to genesis (survive reset_to_genesis)
  -- These are set via pad_config UI, not by transforms
  local genesis_properties = {
    start_pos = true, stop_pos = true,
    attack = true, release = true, fade_time = true,
    mode = true, rate = true, pitch_offset = true,
    max_volume = true, pan = true,
    filter_type = true, lpf = true, resonance = true, hpf = true
  }

  if genesis_properties[key] and SamplerEngine.lane_genesis_chops[lane] then
    SamplerEngine.lane_genesis_chops[lane][pad][key] = value
    -- Also update genesis duration
    if key == "start_pos" or key == "stop_pos" then
      local genesis = SamplerEngine.lane_genesis_chops[lane][pad]
      genesis.duration = genesis.stop_pos - genesis.start_pos
    end
  end
end

-- Reset a pad's working chop to its genesis state
function SamplerEngine.reset_chop_to_genesis(lane, pad)
  local genesis = SamplerEngine.lane_genesis_chops[lane][pad]
  if not genesis then return end

  -- Deep copy genesis to working
  SamplerEngine.lane_chops[lane][pad] = create_default_chop(genesis.start_pos, genesis.stop_pos, {
    attack = genesis.attack,
    release = genesis.release,
    fade_time = genesis.fade_time,
    mode = genesis.mode,
    rate = genesis.rate,
    pitch_offset = genesis.pitch_offset,
    max_volume = genesis.max_volume,
    pan = genesis.pan,
    filter_type = genesis.filter_type,
    lpf = genesis.lpf,
    resonance = genesis.resonance,
    hpf = genesis.hpf
  })
end

-- Reset all working chops to genesis state for a lane
function SamplerEngine.reset_lane_to_genesis(lane)
  for pad = 1, NUM_PADS do
    SamplerEngine.reset_chop_to_genesis(lane, pad)
  end
end

-- Get sample duration for a lane
function SamplerEngine.get_sample_duration(lane)
  return SamplerEngine.lane_durations[lane] or 0
end

-- Configure post-filter for a voice based on chop settings
local function apply_filter(voice, chop)
  if chop.filter_type == FILTER_OFF then
    softcut.post_filter_dry(voice, 1.0)
    softcut.post_filter_lp(voice, 0.0)
    softcut.post_filter_hp(voice, 0.0)
    softcut.post_filter_bp(voice, 0.0)
    softcut.post_filter_br(voice, 0.0)
  else
    -- All filtered modes disable dry signal
    softcut.post_filter_dry(voice, 0.0)

    -- Convert resonance to softcut's reciprocal Q format
    -- When resonance=0, use Butterworth response (rq=√2) for maximally flat passband
    local rq = chop.resonance > 0 and (1 / chop.resonance) or 1.414
    softcut.post_filter_rq(voice, rq)

    -- Set filter type outputs and frequency
    if chop.filter_type == FILTER_LOWPASS then
      softcut.post_filter_fc(voice, chop.lpf)
      softcut.post_filter_lp(voice, 1.0)
      softcut.post_filter_hp(voice, 0.0)
      softcut.post_filter_bp(voice, 0.0)
      softcut.post_filter_br(voice, 0.0)
    elseif chop.filter_type == FILTER_HIGHPASS then
      softcut.post_filter_fc(voice, chop.hpf)
      softcut.post_filter_lp(voice, 0.0)
      softcut.post_filter_hp(voice, 1.0)
      softcut.post_filter_bp(voice, 0.0)
      softcut.post_filter_br(voice, 0.0)
    elseif chop.filter_type == FILTER_BANDPASS then
      softcut.post_filter_fc(voice, chop.lpf)
      softcut.post_filter_lp(voice, 0.0)
      softcut.post_filter_hp(voice, 0.0)
      softcut.post_filter_bp(voice, 1.0)
      softcut.post_filter_br(voice, 0.0)
    elseif chop.filter_type == FILTER_NOTCH then
      softcut.post_filter_fc(voice, chop.lpf)
      softcut.post_filter_lp(voice, 0.0)
      softcut.post_filter_hp(voice, 0.0)
      softcut.post_filter_bp(voice, 0.0)
      softcut.post_filter_br(voice, 1.0)
    end
  end
end

-- Find a free voice or steal the first available playback voice
function SamplerEngine.allocate_voice(lane, pad)
  -- First, look for a free voice (exclude recording voice if recording)
  for v = 1, SamplerEngine.num_voices do
    local is_recording_voice = (SamplerEngine.is_recording and v == RECORDING_VOICE)
    if not SamplerEngine.voices[v].active and not is_recording_voice then
      return v
    end
  end

  -- No free voices, steal voice 1 (or voice 2 if voice 1 is recording)
  if SamplerEngine.is_recording and RECORDING_VOICE == 1 then
    return 2
  end
  return 1
end

-- Trigger a pad to play its chop
function SamplerEngine.trigger_pad(lane, pad, velocity)
  if not SamplerEngine.initialized then
    print("≋ Sampler: Not initialized")
    return
  end

  -- Check if lane has a buffer assigned
  local buffer_id = SamplerEngine.get_buffer_for_lane(lane)
  if not buffer_id then
    print(string.format("≋ Sampler: Lane %d has no buffer assigned", lane))
    return
  end

  local chop = SamplerEngine.get_chop(lane, pad)
  if not chop or chop.duration == 0 then
    print(string.format("≋ Sampler: Lane %d pad %d has no chop data", lane, pad))
    return
  end

  -- Allocate a voice
  local voice = SamplerEngine.allocate_voice(lane, pad)

  -- Assign voice to lane's buffer
  softcut.buffer(voice, buffer_id)

  -- Configure voice for this chop
  softcut.loop_start(voice, chop.start_pos)
  softcut.loop_end(voice, chop.stop_pos)

  -- Position at end for reverse playback, start for forward
  local start_position = chop.rate < 0 and chop.stop_pos or chop.start_pos
  softcut.position(voice, start_position)

  -- Set loop mode based on playback mode
  -- Enable looping for Gate mode, disable for One-shot mode
  local loop_enabled = (chop.mode == MODE_GATE) and 1 or 0
  softcut.loop(voice, loop_enabled)

  -- Set crossfade time for smooth loop points (prevents clicks)
  softcut.fade_time(voice, chop.fade_time or 0.005)

  -- Combine speed and pitch: speed * semitone-derived rate
  local semitone_rate = 2 ^ ((chop.pitch_offset or 0) / 12)
  local final_rate = chop.rate * semitone_rate
  softcut.rate(voice, final_rate)

  -- Set pan (-1 left, 0 center, 1 right)
  softcut.pan(voice, chop.pan)

  -- Configure post-filter
  apply_filter(voice, chop)

  -- Calculate target volume (scale max_volume by velocity)
  velocity = velocity or 127
  local volume = chop.max_volume * (velocity / 127)

  -- Attack envelope: Ramp volume from 0 to target over attack time
  -- First set level to 0 instantly, then enable slew and ramp to target volume
  -- Playback starts immediately so audio is heard during envelope ramp
  softcut.level_slew_time(voice, 0)
  softcut.level(voice, 0)
  softcut.play(voice, 1)
  softcut.level_slew_time(voice, chop.attack)
  softcut.level(voice, volume)

  -- Track voice state and increment generation counter for this assignment
  SamplerEngine.voices[voice].lane = lane
  SamplerEngine.voices[voice].pad = pad
  SamplerEngine.voices[voice].active = true
  SamplerEngine.voice_generation[voice] = SamplerEngine.voice_generation[voice] + 1
  local trigger_generation = SamplerEngine.voice_generation[voice]

  -- For one-shot mode, apply release envelope and cleanup after playback finishes
  if chop.mode == MODE_ONE_SHOT then
    local playback_time = chop.duration / math.abs(chop.rate)

    clock.run(function()
      -- Wait for playback to finish (attack happens automatically at start)
      clock.sleep(playback_time)

      -- Only apply release if voice hasn't been reassigned
      if SamplerEngine.voice_generation[voice] == trigger_generation then
        -- Apply release envelope by ramping level to 0
        softcut.level_slew_time(voice, chop.release)
        softcut.level(voice, 0)

        -- Wait for release to complete
        clock.sleep(chop.release)

        -- Stop playback and free voice if still assigned to this trigger
        if SamplerEngine.voice_generation[voice] == trigger_generation then
          softcut.play(voice, 0)
          SamplerEngine.voices[voice].active = false
          SamplerEngine.voices[voice].lane = nil
          SamplerEngine.voices[voice].pad = nil
        end
      end
    end)
  end
end

-- Stop a specific pad (stops all voices playing it and applies release envelope)
function SamplerEngine.stop_pad(lane, pad)
  for v = 1, SamplerEngine.num_voices do
    if SamplerEngine.voices[v].active and
       SamplerEngine.voices[v].lane == lane and
       SamplerEngine.voices[v].pad == pad then

      local chop = SamplerEngine.get_chop(lane, pad)
      if chop and chop.release > 0 then
        -- Release envelope: Ramp volume to 0 over release time, then stop playback
        -- Cleanup scheduled after envelope completes
        softcut.level_slew_time(v, chop.release)
        softcut.level(v, 0)

        -- Capture generation counter for this release
        local release_generation = SamplerEngine.voice_generation[v]
        clock.run(function()
          clock.sleep(chop.release)

          -- Only cleanup if voice hasn't been reassigned
          if SamplerEngine.voice_generation[v] == release_generation then
            softcut.play(v, 0)
            SamplerEngine.voices[v].active = false
            SamplerEngine.voices[v].lane = nil
            SamplerEngine.voices[v].pad = nil
          end
        end)
      else
        -- No release time, stop immediately
        softcut.play(v, 0)
        SamplerEngine.voices[v].active = false
        SamplerEngine.voices[v].lane = nil
        SamplerEngine.voices[v].pad = nil
      end
      -- Don't return - continue checking for other voices playing this pad
    end
  end
end

-- Stop all voices
function SamplerEngine.stop_all()
  for v = 1, SamplerEngine.num_voices do
    softcut.play(v, 0)
    SamplerEngine.voices[v].active = false
    SamplerEngine.voices[v].lane = nil
    SamplerEngine.voices[v].pad = nil
  end
end

-- Get voice state for a pad (for visualization)
function SamplerEngine.get_pad_voice(lane, pad)
  for v = 1, SamplerEngine.num_voices do
    if SamplerEngine.voices[v].active and
       SamplerEngine.voices[v].lane == lane and
       SamplerEngine.voices[v].pad == pad then
      return v
    end
  end
  return nil
end

-- Load an audio file into the buffer and auto-chop for a specific lane
function SamplerEngine.load_file(lane, filepath)
  if not SamplerEngine.initialized then
    print("≋ Sampler: Not initialized")
    return false
  end

  -- Try to allocate a buffer for this lane
  local buffer_id = SamplerEngine.allocate_buffer(lane)
  if not buffer_id then
    print(string.format("≋ Sampler: Cannot load - maximum %d lanes supported, buffers full", MAX_LANES))
    print("≋ Sampler: Clear an existing lane first")
    return false
  end

  -- Show loading overlay
  SamplerEngine.loading_state = "loading"
  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end

  -- Clear existing sample data for this lane (stops voices, resets chops)
  SamplerEngine.clear_lane_chops(lane)

  -- Clear this lane's buffer
  softcut.buffer_clear_channel(buffer_id)

  -- Get file info to determine duration and channel count
  local ch, samples, rate = audio.file_info(filepath)

  print(string.format("≋ Sampler: Loading %s into lane %d (buffer %d)", filepath, lane, buffer_id))

  -- Load mono to lane's buffer (reads left channel from stereo files)
  softcut.buffer_read_mono(filepath, 0, 0, -1, LEFT_CHANNEL, buffer_id)

  if samples and rate then
    local duration = samples / rate
    print(string.format("≋ Sampler: File loaded - %.2fs, %dHz, %d channels", duration, rate, ch))

    -- Auto-chop into fixed chops
    SamplerEngine.set_fixed_chops(lane, duration)

    -- Clear loading overlay after brief delay (buffer_read_mono has no completion callback)
    clock.run(function()
      clock.sleep(1.0)
      SamplerEngine.loading_state = nil
      if _seeker and _seeker.screen_ui then
        _seeker.screen_ui.set_needs_redraw()
      end
    end)

    return true
  else
    print("≋ Sampler: Failed to load file")
    -- Free the buffer since load failed
    SamplerEngine.free_buffer(lane)
    SamplerEngine.loading_state = nil
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
    return false
  end
end

-- Check if a lane has usable buffer content
function SamplerEngine.has_buffer(lane)
  return SamplerEngine.lane_durations[lane] > 0
end

-- Start recording audio input to buffer
function SamplerEngine.start_recording(lane)
  if not SamplerEngine.initialized then
    print("≋ Sampler: Not initialized")
    return false
  end

  if SamplerEngine.is_recording then
    print("≋ Sampler: Already recording")
    return false
  end

  -- Allocate a buffer for this lane using the allocation system
  local buffer_id = SamplerEngine.allocate_buffer(lane)
  if not buffer_id then
    print(string.format("≋ Sampler: Cannot record - maximum %d lanes supported, buffers full", MAX_LANES))
    print("≋ Sampler: Clear an existing lane first")
    return false
  end

  -- Clear existing sample data for this lane (stops voices, resets chops)
  SamplerEngine.clear_lane_chops(lane)

  -- Clear this lane's buffer
  softcut.buffer_clear_channel(buffer_id)

  -- Use dedicated recording voice
  local rec_voice = RECORDING_VOICE

  -- Configure voice for recording
  softcut.buffer(rec_voice, buffer_id)
  softcut.level(rec_voice, 0)  -- Silent output during recording (input monitoring is separate)
  softcut.rec(rec_voice, 1)
  softcut.rec_level(rec_voice, 1.0)
  softcut.pre_level(rec_voice, 0)

  -- Route stereo input to recording voice (mix to mono)
  softcut.level_input_cut(1, rec_voice, MONO_MIX_LEVEL)
  softcut.level_input_cut(2, rec_voice, MONO_MIX_LEVEL)

  -- Set position and disable looping
  softcut.position(rec_voice, 0)
  softcut.loop(rec_voice, 0)
  softcut.loop_start(rec_voice, 0)
  softcut.loop_end(rec_voice, softcut.BUFFER_SIZE)

  -- Ensure recording happens at normal speed
  softcut.rate(rec_voice, 1.0)

  -- Start recording
  softcut.play(rec_voice, 1)

  -- Update state
  SamplerEngine.is_recording = true
  SamplerEngine.recording_lane = lane
  SamplerEngine.recording_voice = rec_voice
  SamplerEngine.recording_buffer = buffer_id
  SamplerEngine.recording_state = "recording"
  SamplerEngine.record_start_time = util.time()

  -- Request redraw to show recording overlay
  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end

  print(string.format("≋ Sampler: Recording started for lane %d (buffer %d, voice %d)", lane, buffer_id, rec_voice))
  return true
end

-- Stop recording and save to disk
function SamplerEngine.stop_recording(lane)
  if not SamplerEngine.is_recording then
    print("≋ Sampler: Not recording")
    return false
  end

  local rec_voice = SamplerEngine.recording_voice

  -- Stop recording
  softcut.play(rec_voice, 0)
  softcut.rec(rec_voice, 0)

  -- Disable input routing
  softcut.level_input_cut(1, rec_voice, 0)
  softcut.level_input_cut(2, rec_voice, 0)

  -- Calculate duration
  local duration = util.time() - SamplerEngine.record_start_time

  -- Create filename with timestamp
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local filename = string.format("lane_%d_%s.wav", lane, timestamp)
  local audio_path = _path.audio .. "seeker_ii"
  util.make_dir(audio_path)
  local filepath = audio_path .. "/" .. filename

  -- Update state to show saving overlay
  SamplerEngine.recording_state = "saving"
  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end

  -- Save to disk
  print(string.format("≋ Sampler: Saving %.2fs recording to %s", duration, filename))
  local buffer_id = SamplerEngine.recording_buffer
  softcut.buffer_write_mono(filepath, 0, duration, buffer_id)

  -- Clear recording state immediately
  SamplerEngine.is_recording = false
  SamplerEngine.recording_lane = nil
  SamplerEngine.recording_voice = nil
  SamplerEngine.recording_buffer = nil
  SamplerEngine.record_start_time = 0

  -- Auto-load after delay (buffer_write_mono has no completion callback)
  clock.run(function()
    clock.sleep(1.0)  -- Wait for write to complete
    SamplerEngine.load_file(lane, filepath)
    print(string.format("≋ Sampler: Recording loaded into lane %d", lane))

    -- Clear recording state to hide overlay
    SamplerEngine.recording_state = nil
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)

  return true
end

return SamplerEngine
