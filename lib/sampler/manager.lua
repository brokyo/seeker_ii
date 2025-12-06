-- manager.lua
-- Manages softcut voices, sample segments, and voice allocation for sampler mode
-- NOTE: Segment data stored internally per-lane, params in sampler_pad_config are just a UI view
-- TODO: If PSET persistence needed, move storage to per-lane-per-pad params (512 total)

local SamplerManager = {}

-- Constants
local NUM_VOICES = 6
local NUM_PADS = 16
local BUFFER_ID = 1  -- Use softcut buffer 1 for sampler

-- State
SamplerManager.voices = {}  -- voice[i] = {lane = lane_number, pad = pad_number, active = bool}
SamplerManager.lane_segments = {}  -- lane_segments[lane][pad] = {start_pos, end_pos, duration, fade_in, fade_out}
SamplerManager.lane_durations = {}  -- lane_durations[lane] = sample_duration
SamplerManager.initialized = false
SamplerManager.recording = false
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
  for v = 1, NUM_VOICES do
    -- Enable voice
    softcut.enable(v, 1)

    -- Assign to buffer 1
    softcut.buffer(v, BUFFER_ID)

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
        attack = 0.01,
        release = 0.01,
        loop = false
      }
    end
  end

  SamplerManager.initialized = true
  print("◎ Sampler: 6 voices initialized, 8 lanes prepared")
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
      attack = 0.01,
      release = 0.01,
      loop = false
    }
  end

  print(string.format("◎ Sampler: Lane %d divided %.2fs sample into %d segments of %.2fs each",
    lane, sample_duration, NUM_PADS, segment_duration))
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
    attack = 0.01,
    release = 0.01,
    loop = false
  }

  print(string.format("◎ Sampler: Reset lane %d pad %d to auto position", lane, pad))
end

-- Get sample duration for a lane
function SamplerManager.get_sample_duration(lane)
  return SamplerManager.lane_durations[lane] or 0
end

-- Find a free voice or steal the oldest one
function SamplerManager.allocate_voice(lane, pad)
  -- First, look for a free voice
  for v = 1, NUM_VOICES do
    if not SamplerManager.voices[v].active then
      return v
    end
  end

  -- No free voices, steal voice 1 (simple round-robin)
  print(string.format("◎ Sampler: Voice stealing - reusing voice 1 for lane %d pad %d", lane, pad))
  return 1
end

-- Trigger a pad to play its segment
function SamplerManager.trigger_pad(lane, pad)
  if not SamplerManager.initialized then
    print("◎ Sampler: Not initialized")
    return
  end

  local segment = SamplerManager.get_segment(lane, pad)
  if not segment or segment.duration == 0 then
    print(string.format("◎ Sampler: Lane %d pad %d has no segment data", lane, pad))
    return
  end

  -- Allocate a voice
  local voice = SamplerManager.allocate_voice(lane, pad)

  -- Configure voice for this segment
  softcut.loop_start(voice, segment.start_pos)
  softcut.loop_end(voice, segment.stop_pos)
  softcut.position(voice, segment.start_pos)

  -- Set loop mode
  local loop_value = segment.loop and 1 or 0
  softcut.loop(voice, loop_value)

  -- Apply attack envelope
  softcut.fade_time(voice, segment.attack)

  -- Start playback
  softcut.play(voice, 1)

  -- Track voice state
  SamplerManager.voices[voice].lane = lane
  SamplerManager.voices[voice].pad = pad
  SamplerManager.voices[voice].active = true

  print(string.format("◎ Sampler: Lane %d Pad %d → Voice %d [%.3f-%.3f]s loop:%s atk:%.3fs rel:%.3fs",
    lane, pad, voice, segment.start_pos, segment.stop_pos, segment.loop and "on" or "off", segment.attack, segment.release))
end

-- Stop a specific pad (find which voice is playing it)
function SamplerManager.stop_pad(lane, pad)
  for v = 1, NUM_VOICES do
    if SamplerManager.voices[v].active and
       SamplerManager.voices[v].lane == lane and
       SamplerManager.voices[v].pad == pad then
      softcut.play(v, 0)
      SamplerManager.voices[v].active = false
      SamplerManager.voices[v].lane = nil
      SamplerManager.voices[v].pad = nil
      print(string.format("◎ Sampler: Stopped lane %d pad %d (voice %d)", lane, pad, v))
      return
    end
  end
end

-- Stop all voices
function SamplerManager.stop_all()
  for v = 1, NUM_VOICES do
    softcut.play(v, 0)
    SamplerManager.voices[v].active = false
    SamplerManager.voices[v].lane = nil
    SamplerManager.voices[v].pad = nil
  end
  print("◎ Sampler: All voices stopped")
end

-- Get voice state for a pad (for visualization)
function SamplerManager.get_pad_voice(lane, pad)
  for v = 1, NUM_VOICES do
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

  -- Stop all playback
  SamplerManager.stop_all()

  -- Clear buffer first
  softcut.buffer_clear()

  print(string.format("◎ Sampler: Loading %s into lane %d", filepath, lane))

  -- Load file into buffer 1, channel 1
  softcut.buffer_read_mono(filepath, 0, 0, -1, 1, 1)

  -- Get file info to determine duration
  local ch, samples, rate = audio.file_info(filepath)

  if samples and rate then
    local duration = samples / rate
    print(string.format("◎ Sampler: File loaded - %.2fs, %dHz, %d channels", duration, rate, ch))

    -- Auto-chop into fixed segments
    SamplerManager.set_fixed_segments(lane, duration)
    return true
  else
    print("◎ Sampler: Failed to load file")
    return false
  end
end

-- Check if a lane has usable buffer content
function SamplerManager.has_buffer(lane)
  return SamplerManager.lane_durations[lane] > 0
end

return SamplerManager
