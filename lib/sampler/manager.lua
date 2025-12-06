-- manager.lua
-- Manages softcut voices, sample segments, and voice allocation for sampler mode

local SamplerManager = {}

-- Constants
local NUM_VOICES = 6
local NUM_PADS = 16
local BUFFER_ID = 1  -- Use softcut buffer 1 for sampler

-- State
SamplerManager.voices = {}  -- voice[i] = {pad = pad_number, active = bool}
SamplerManager.segments = {} -- segments[pad] = {start_pos, end_pos, duration}
SamplerManager.sample_duration = 0
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

    -- Set loop mode and fade
    softcut.loop(v, 1)  -- Enable looping
    softcut.fade_time(v, 0.01)  -- Quick fade for pad triggering

    -- Initialize loop points (will be updated per segment)
    softcut.loop_start(v, 0)
    softcut.loop_end(v, 1)

    -- Start disabled
    softcut.play(v, 0)

    -- Track voice state
    SamplerManager.voices[v] = {
      pad = nil,
      active = false
    }
  end

  -- Initialize empty segments (16 pads, no sample loaded yet)
  for p = 0, NUM_PADS - 1 do
    SamplerManager.segments[p] = {
      start_pos = 0,
      end_pos = 0,
      duration = 0
    }
  end

  SamplerManager.initialized = true
  print("◎ Sampler: 6 voices initialized, buffer cleared")
end

-- Divide sample into equal segments across all pads
function SamplerManager.set_fixed_segments(sample_duration)
  SamplerManager.sample_duration = sample_duration
  local segment_duration = sample_duration / NUM_PADS

  for p = 0, NUM_PADS - 1 do
    local start_pos = p * segment_duration
    local end_pos = start_pos + segment_duration

    SamplerManager.segments[p] = {
      start_pos = start_pos,
      end_pos = end_pos,
      duration = segment_duration
    }
  end

  print(string.format("◎ Sampler: Divided %.2fs sample into %d segments of %.2fs each",
    sample_duration, NUM_PADS, segment_duration))
end

-- Find a free voice or steal the oldest one
function SamplerManager.allocate_voice(pad)
  -- First, look for a free voice
  for v = 1, NUM_VOICES do
    if not SamplerManager.voices[v].active then
      return v
    end
  end

  -- No free voices, steal voice 1 (simple round-robin)
  print(string.format("◎ Sampler: Voice stealing - reusing voice 1 for pad %d", pad))
  return 1
end

-- Trigger a pad to play its segment
function SamplerManager.trigger_pad(pad)
  if not SamplerManager.initialized then
    print("◎ Sampler: Not initialized")
    return
  end

  local segment = SamplerManager.segments[pad]
  if not segment or segment.duration == 0 then
    print(string.format("◎ Sampler: Pad %d has no segment data", pad))
    return
  end

  -- Allocate a voice
  local voice = SamplerManager.allocate_voice(pad)

  -- Configure voice for this segment
  softcut.loop_start(voice, segment.start_pos)
  softcut.loop_end(voice, segment.end_pos)
  softcut.position(voice, segment.start_pos)

  -- Start playback
  softcut.play(voice, 1)

  -- Track voice state
  SamplerManager.voices[voice].pad = pad
  SamplerManager.voices[voice].active = true

  print(string.format("◎ Sampler: Pad %d → Voice %d [%.3f-%.3f]s",
    pad, voice, segment.start_pos, segment.end_pos))
end

-- Stop a specific pad (find which voice is playing it)
function SamplerManager.stop_pad(pad)
  for v = 1, NUM_VOICES do
    if SamplerManager.voices[v].active and SamplerManager.voices[v].pad == pad then
      softcut.play(v, 0)
      SamplerManager.voices[v].active = false
      SamplerManager.voices[v].pad = nil
      print(string.format("◎ Sampler: Stopped pad %d (voice %d)", pad, v))
      return
    end
  end
end

-- Stop all voices
function SamplerManager.stop_all()
  for v = 1, NUM_VOICES do
    softcut.play(v, 0)
    SamplerManager.voices[v].active = false
    SamplerManager.voices[v].pad = nil
  end
  print("◎ Sampler: All voices stopped")
end

-- Get voice state for a pad (for visualization)
function SamplerManager.get_pad_voice(pad)
  for v = 1, NUM_VOICES do
    if SamplerManager.voices[v].active and SamplerManager.voices[v].pad == pad then
      return v
    end
  end
  return nil
end

-- Load an audio file into the buffer and auto-chop
function SamplerManager.load_file(filepath)
  if not SamplerManager.initialized then
    print("◎ Sampler: Not initialized")
    return false
  end

  -- Stop all playback
  SamplerManager.stop_all()

  -- Clear buffer first
  softcut.buffer_clear()

  print(string.format("◎ Sampler: Loading %s", filepath))

  -- Load file into buffer 1, channel 1
  -- Parameters: (file, start_src, start_dst, dur, ch_src, ch_dst)
  -- -1 for duration means load entire file
  softcut.buffer_read_mono(filepath, 0, 0, -1, 1, 1)

  -- Get file info to determine duration
  local ch, samples, rate = audio.file_info(filepath)

  if samples and rate then
    local duration = samples / rate
    print(string.format("◎ Sampler: File loaded - %.2fs, %dHz, %d channels", duration, rate, ch))

    -- Auto-chop into fixed segments
    SamplerManager.set_fixed_segments(duration)
    return true
  else
    print("◎ Sampler: Failed to load file")
    return false
  end
end

-- Check if buffer has usable content
function SamplerManager.has_buffer()
  return SamplerManager.sample_duration > 0
end

return SamplerManager
