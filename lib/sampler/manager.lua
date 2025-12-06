-- manager.lua
-- Manages softcut voices, sample segments, and voice allocation for sampler mode
-- NOTE: Segment data stored internally per-lane, params in sampler_pad_config are just a UI view

local SamplerManager = {}

-- Constants
local NUM_PADS = 16
local MAX_LANES = 2  -- Limit to 2 lanes (one per stereo buffer)
local LEFT_CHANNEL = 1
local MONO_MIX_LEVEL = 0.5  -- Equal power stereo-to-mono mix

-- State
SamplerManager.num_voices = 6  -- Configurable voice count
SamplerManager.voices = {}  -- voice[i] = {lane = lane_number, pad = pad_number, active = bool}
SamplerManager.lane_segments = {}  -- lane_segments[lane][pad] = {start_pos, end_pos, duration, fade_in, fade_out}
SamplerManager.lane_durations = {}  -- lane_durations[lane] = sample_duration
SamplerManager.lane_to_buffer = {}  -- lane_to_buffer[lane] = buffer_id (1 or 2)
SamplerManager.buffer_occupied = {false, false}  -- tracks which buffers are in use
SamplerManager.initialized = false
SamplerManager.is_recording = false
SamplerManager.recording_lane = nil
SamplerManager.recording_voice = nil
SamplerManager.record_start_time = 0

-- Initialize all softcut voices for sampler use
function SamplerManager.init()
  print("◎ Initializing Sampler Manager")

  -- Ensure audio folder exists
  local audio_path = _path.audio .. "seeker_ii"
  util.make_dir(audio_path)

  -- Clear buffer
  softcut.buffer_clear()

  -- Initialize each voice
  for v = 1, SamplerManager.num_voices do
    -- Enable voice
    softcut.enable(v, 1)

    -- Voices will be assigned to buffers dynamically based on lane
    -- (buffer assignment happens in trigger_pad)

    -- Set playback parameters
    softcut.level(v, 1.0)
    softcut.pan(v, 0)
    softcut.rate(v, 1.0)

    -- Disable recording by default
    softcut.rec(v, 0)
    softcut.rec_level(v, 0)
    softcut.pre_level(v, 0)

    -- Set loop mode
    softcut.loop(v, 1)  -- Enable looping

    -- Initialize loop points (will be updated per segment)
    softcut.loop_start(v, 0)
    softcut.loop_end(v, 1)

    -- Start disabled
    softcut.play(v, 0)

    -- Track voice state
    SamplerManager.voices[v] = {
      lane = nil,
      pad = nil,
      active = false
    }
  end

  -- Initialize per-lane storage
  for lane = 1, 8 do
    SamplerManager.lane_durations[lane] = 0
    SamplerManager.lane_segments[lane] = {}

    -- Initialize empty segments (16 pads per lane)
    for pad = 1, NUM_PADS do
      SamplerManager.lane_segments[lane][pad] = {
        start_pos = 0,
        stop_pos = 0,
        duration = 0,
        attack = 0.1,
        release = 0.1,
        mode = 3,          -- 1=One-Shot, 2=Loop, 3=Gate
        rate = 1.0,        -- Playback rate (negative for reverse)
        max_volume = 1.0,  -- Volume ceiling
        pan = 0            -- Stereo position (-1 left, 0 center, 1 right)
      }
    end
  end

  SamplerManager.initialized = true
  print(string.format("◎ Sampler: %d voices initialized, 8 lanes prepared, 2 buffers available", SamplerManager.num_voices))
end

-- Allocate a free buffer for a lane (returns buffer_id 1 or 2, or nil if none available)
function SamplerManager.allocate_buffer(lane)
  -- Check if lane already has a buffer
  if SamplerManager.lane_to_buffer[lane] then
    return SamplerManager.lane_to_buffer[lane]
  end

  -- Find first free buffer
  for buffer_id = 1, 2 do
    if not SamplerManager.buffer_occupied[buffer_id] then
      SamplerManager.lane_to_buffer[lane] = buffer_id
      SamplerManager.buffer_occupied[buffer_id] = true
      return buffer_id
    end
  end

  return nil  -- No free buffers
end

-- Free a buffer when a lane is cleared
function SamplerManager.free_buffer(lane)
  local buffer_id = SamplerManager.lane_to_buffer[lane]
  if buffer_id then
    SamplerManager.buffer_occupied[buffer_id] = false
    SamplerManager.lane_to_buffer[lane] = nil
    SamplerManager.lane_durations[lane] = 0
  end
end

-- Get buffer for a lane (returns nil if no buffer assigned)
function SamplerManager.get_buffer_for_lane(lane)
  return SamplerManager.lane_to_buffer[lane]
end

-- Clear all segment data and stop playback for a lane
function SamplerManager.clear_lane_segments(lane)
  -- Stop all voices playing from this lane
  for v = 1, SamplerManager.num_voices do
    if SamplerManager.voices[v].active and SamplerManager.voices[v].lane == lane then
      softcut.play(v, 0)
      SamplerManager.voices[v].active = false
      SamplerManager.voices[v].lane = nil
      SamplerManager.voices[v].pad = nil
    end
  end

  -- Reset all segments to default empty state
  for pad = 1, NUM_PADS do
    SamplerManager.lane_segments[lane][pad] = {
      start_pos = 0,
      stop_pos = 0,
      duration = 0,
      attack = 0.1,
      release = 0.1,
      mode = 3,
      rate = 1.0,
      max_volume = 1.0,
      pan = 0
    }
  end

  SamplerManager.lane_durations[lane] = 0
end

-- Divide sample into equal segments across all pads for a specific lane
function SamplerManager.set_fixed_segments(lane, sample_duration)
  SamplerManager.lane_durations[lane] = sample_duration
  local segment_duration = sample_duration / NUM_PADS

  for pad = 1, NUM_PADS do
    local start_pos = (pad - 1) * segment_duration
    local stop_pos = start_pos + segment_duration

    SamplerManager.lane_segments[lane][pad] = {
      start_pos = start_pos,
      stop_pos = stop_pos,
      duration = segment_duration,
      attack = 0.1,
      release = 0.1,
      mode = 3,
      rate = 1.0,
      max_volume = 1.0,
      pan = 0
    }
  end
end

-- Get segment data for a specific lane and pad
function SamplerManager.get_segment(lane, pad)
  if not SamplerManager.lane_segments[lane] then return nil end
  return SamplerManager.lane_segments[lane][pad]
end

-- Update a specific property of a segment
function SamplerManager.update_segment(lane, pad, key, value)
  if not SamplerManager.lane_segments[lane] or not SamplerManager.lane_segments[lane][pad] then
    return
  end

  SamplerManager.lane_segments[lane][pad][key] = value

  -- Recalculate duration if start or stop changed
  if key == "start_pos" or key == "stop_pos" then
    local segment = SamplerManager.lane_segments[lane][pad]
    segment.duration = segment.stop_pos - segment.start_pos
  end
end

-- Reset a pad to its auto-divided position
function SamplerManager.reset_segment_to_auto(lane, pad)
  local sample_duration = SamplerManager.lane_durations[lane]
  if sample_duration == 0 then return end

  local segment_duration = sample_duration / NUM_PADS
  local start_pos = (pad - 1) * segment_duration
  local stop_pos = start_pos + segment_duration

  SamplerManager.lane_segments[lane][pad] = {
    start_pos = start_pos,
    stop_pos = stop_pos,
    duration = segment_duration,
    attack = 0.1,
    release = 0.1,
    mode = 3,
    rate = 1.0,
    max_volume = 1.0,
    pan = 0
  }
end

-- Get sample duration for a lane
function SamplerManager.get_sample_duration(lane)
  return SamplerManager.lane_durations[lane] or 0
end

-- Find a free voice or steal the oldest one
function SamplerManager.allocate_voice(lane, pad)
  -- First, look for a free voice
  for v = 1, SamplerManager.num_voices do
    if not SamplerManager.voices[v].active then
      return v
    end
  end

  -- No free voices, steal voice 1 (simple round-robin)
  return 1
end

-- Trigger a pad to play its segment
function SamplerManager.trigger_pad(lane, pad, velocity)
  if not SamplerManager.initialized then
    print("◎ Sampler: Not initialized")
    return
  end

  -- Check if lane has a buffer assigned
  local buffer_id = SamplerManager.get_buffer_for_lane(lane)
  if not buffer_id then
    print(string.format("◎ Sampler: Lane %d has no buffer assigned", lane))
    return
  end

  local segment = SamplerManager.get_segment(lane, pad)
  if not segment or segment.duration == 0 then
    print(string.format("◎ Sampler: Lane %d pad %d has no segment data", lane, pad))
    return
  end

  -- Allocate a voice
  local voice = SamplerManager.allocate_voice(lane, pad)

  -- Assign voice to lane's buffer
  softcut.buffer(voice, buffer_id)

  -- Configure voice for this segment
  softcut.loop_start(voice, segment.start_pos)
  softcut.loop_end(voice, segment.stop_pos)

  -- Position at end for reverse playback, start for forward
  local start_position = segment.rate < 0 and segment.stop_pos or segment.start_pos
  softcut.position(voice, start_position)

  -- Set loop mode based on playback mode
  -- 1=One-Shot (no loop), 2=Loop (loop), 3=Gate (no loop, stops on release)
  local loop_enabled = (segment.mode == 2) and 1 or 0
  softcut.loop(voice, loop_enabled)

  -- Set playback rate (supports reverse with negative values)
  softcut.rate(voice, segment.rate)

  -- Set volume (scale max_volume by velocity)
  velocity = velocity or 127
  local volume = segment.max_volume * (velocity / 127)
  softcut.level(voice, volume)

  -- Set pan (-1 left, 0 center, 1 right)
  softcut.pan(voice, segment.pan)

  -- Apply attack envelope
  softcut.fade_time(voice, segment.attack)

  -- Start playback
  softcut.play(voice, 1)

  -- Track voice state
  SamplerManager.voices[voice].lane = lane
  SamplerManager.voices[voice].pad = pad
  SamplerManager.voices[voice].active = true

  -- For one-shot mode only, schedule voice cleanup after playback finishes
  -- (Gate mode frees on pad_off, loop mode never auto-frees)
  if segment.mode == 1 then  -- One-shot
    local playback_time = segment.duration / math.abs(segment.rate)
    local total_time = playback_time + segment.attack + segment.release

    clock.run(function()
      clock.sleep(total_time)
      -- Only free if this voice is still playing this same lane/pad
      if SamplerManager.voices[voice].active and
         SamplerManager.voices[voice].lane == lane and
         SamplerManager.voices[voice].pad == pad then
        SamplerManager.voices[voice].active = false
        SamplerManager.voices[voice].lane = nil
        SamplerManager.voices[voice].pad = nil
      end
    end)
  end
end

-- Stop a specific pad (find which voice is playing it)
function SamplerManager.stop_pad(lane, pad)
  for v = 1, SamplerManager.num_voices do
    if SamplerManager.voices[v].active and
       SamplerManager.voices[v].lane == lane and
       SamplerManager.voices[v].pad == pad then
      softcut.play(v, 0)
      SamplerManager.voices[v].active = false
      SamplerManager.voices[v].lane = nil
      SamplerManager.voices[v].pad = nil
      return
    end
  end
end

-- Stop all voices
function SamplerManager.stop_all()
  for v = 1, SamplerManager.num_voices do
    softcut.play(v, 0)
    SamplerManager.voices[v].active = false
    SamplerManager.voices[v].lane = nil
    SamplerManager.voices[v].pad = nil
  end
end

-- Get voice state for a pad (for visualization)
function SamplerManager.get_pad_voice(lane, pad)
  for v = 1, SamplerManager.num_voices do
    if SamplerManager.voices[v].active and
       SamplerManager.voices[v].lane == lane and
       SamplerManager.voices[v].pad == pad then
      return v
    end
  end
  return nil
end

-- Load an audio file into the buffer and auto-chop for a specific lane
function SamplerManager.load_file(lane, filepath)
  if not SamplerManager.initialized then
    print("◎ Sampler: Not initialized")
    return false
  end

  -- Try to allocate a buffer for this lane
  local buffer_id = SamplerManager.allocate_buffer(lane)
  if not buffer_id then
    print(string.format("◎ Sampler: Cannot load - maximum %d lanes supported, buffers full", MAX_LANES))
    print("◎ Sampler: Clear an existing lane first")
    return false
  end

  -- Clear existing sample data for this lane (stops voices, resets segments)
  SamplerManager.clear_lane_segments(lane)

  -- Clear this lane's buffer
  softcut.buffer_clear_channel(buffer_id)

  -- Get file info to determine duration and channel count
  local ch, samples, rate = audio.file_info(filepath)

  print(string.format("◎ Sampler: Loading %s into lane %d (buffer %d)", filepath, lane, buffer_id))

  -- Load mono to lane's buffer (reads left channel from stereo files)
  softcut.buffer_read_mono(filepath, 0, 0, -1, LEFT_CHANNEL, buffer_id)

  if samples and rate then
    local duration = samples / rate
    print(string.format("◎ Sampler: File loaded - %.2fs, %dHz, %d channels", duration, rate, ch))

    -- Auto-chop into fixed segments
    SamplerManager.set_fixed_segments(lane, duration)
    return true
  else
    print("◎ Sampler: Failed to load file")
    -- Free the buffer since load failed
    SamplerManager.free_buffer(lane)
    return false
  end
end

-- Check if a lane has usable buffer content
function SamplerManager.has_buffer(lane)
  return SamplerManager.lane_durations[lane] > 0
end

-- Start recording audio input to buffer
function SamplerManager.start_recording(lane)
  if not SamplerManager.initialized then
    print("◎ Sampler: Not initialized")
    return false
  end

  if SamplerManager.is_recording then
    print("◎ Sampler: Already recording")
    return false
  end

  -- Use lane's buffer for recording (lane 1 → buffer 1, lane 2 → buffer 2)
  local buffer_id = lane

  -- Clear existing sample data for this lane (stops voices, resets segments)
  SamplerManager.clear_lane_segments(lane)

  -- Clear this lane's buffer
  softcut.buffer_clear_channel(buffer_id)

  -- Use the last voice for recording
  local rec_voice = 6

  -- Configure voice for recording
  softcut.buffer(rec_voice, buffer_id)
  softcut.level(rec_voice, 1.0)
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

  -- Start recording
  softcut.play(rec_voice, 1)

  -- Update state
  SamplerManager.is_recording = true
  SamplerManager.recording_lane = lane
  SamplerManager.recording_voice = rec_voice
  SamplerManager.record_start_time = util.time()

  print(string.format("◎ Sampler: Recording started for lane %d (buffer %d, voice %d)", lane, buffer_id, rec_voice))
  return true
end

-- Stop recording and save to disk
function SamplerManager.stop_recording(lane)
  if not SamplerManager.is_recording then
    print("◎ Sampler: Not recording")
    return false
  end

  local rec_voice = SamplerManager.recording_voice

  -- Stop recording
  softcut.play(rec_voice, 0)
  softcut.rec(rec_voice, 0)

  -- Disable input routing
  softcut.level_input_cut(1, rec_voice, 0)
  softcut.level_input_cut(2, rec_voice, 0)

  -- Calculate duration
  local duration = util.time() - SamplerManager.record_start_time

  -- Create filename with timestamp
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local filename = string.format("lane_%d_%s.wav", lane, timestamp)
  local audio_path = _path.audio .. "seeker_ii"
  util.make_dir(audio_path)
  local filepath = audio_path .. "/" .. filename

  -- Save to disk
  print(string.format("◎ Sampler: Saving %.2fs recording to %s", duration, filename))
  local buffer_id = lane  -- Use lane's buffer channel
  softcut.buffer_write_mono(filepath, 0, duration, buffer_id)

  -- Clear recording state immediately
  SamplerManager.is_recording = false
  SamplerManager.recording_lane = nil
  SamplerManager.recording_voice = nil
  SamplerManager.record_start_time = 0

  -- Auto-load after delay (buffer_write_stereo has no callback)
  clock.run(function()
    clock.sleep(0.5)
    SamplerManager.load_file(lane, filepath)
    print(string.format("◎ Sampler: Recording loaded into lane %d", lane))
  end)

  return true
end

return SamplerManager
