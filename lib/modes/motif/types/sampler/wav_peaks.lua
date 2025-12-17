-- wav_peaks.lua
-- Read WAV files and compute peak amplitudes for waveform display
-- Returns array of normalized peak values (0-1) for visualization

local WavPeaks = {}

-- Parse little-endian integer from bytes
local function read_int(file, num_bytes)
  local bytes = file:read(num_bytes)
  if not bytes or #bytes < num_bytes then return nil end

  local value = 0
  for i = 1, num_bytes do
    value = value + (bytes:byte(i) * (256 ^ (i - 1)))
  end
  return value
end

-- Parse signed little-endian integer
local function read_signed_int(file, num_bytes)
  local value = read_int(file, num_bytes)
  if not value then return nil end

  local max_val = 256 ^ num_bytes
  if value >= max_val / 2 then
    value = value - max_val
  end
  return value
end

-- Read WAV header and return format info
local function read_wav_header(file)
  -- RIFF header
  local riff = file:read(4)
  if riff ~= "RIFF" then return nil, "Not a RIFF file" end

  file:read(4)  -- file size

  local wave = file:read(4)
  if wave ~= "WAVE" then return nil, "Not a WAVE file" end

  -- Find fmt chunk
  local fmt_found = false
  local channels, sample_rate, bits_per_sample
  local data_start, data_size

  while true do
    local chunk_id = file:read(4)
    if not chunk_id or #chunk_id < 4 then break end

    local chunk_size = read_int(file, 4)
    if not chunk_size then break end

    if chunk_id == "fmt " then
      local audio_format = read_int(file, 2)
      channels = read_int(file, 2)
      sample_rate = read_int(file, 4)
      file:read(4)  -- byte rate
      file:read(2)  -- block align
      bits_per_sample = read_int(file, 2)

      -- Skip any extra format bytes
      local extra = chunk_size - 16
      if extra > 0 then file:read(extra) end

      fmt_found = true

    elseif chunk_id == "data" then
      data_start = file:seek()
      data_size = chunk_size
      break
    else
      -- Skip unknown chunk
      file:read(chunk_size)
    end
  end

  if not fmt_found then return nil, "No fmt chunk found" end
  if not data_start then return nil, "No data chunk found" end

  return {
    channels = channels,
    sample_rate = sample_rate,
    bits_per_sample = bits_per_sample,
    data_start = data_start,
    data_size = data_size,
    num_samples = data_size / (channels * bits_per_sample / 8)
  }
end

-- Compute peaks from WAV file
-- Returns array of peak values (0-1) with length num_peaks
-- Samples multiple points per peak window and takes max to detect transients accurately
local SAMPLES_PER_WINDOW = 25

function WavPeaks.compute_peaks(filepath, num_peaks, start_pos, end_pos)
  num_peaks = num_peaks or 100

  local file = io.open(filepath, "rb")
  if not file then
    print("WavPeaks: Could not open file: " .. filepath)
    return nil
  end

  local header, err = read_wav_header(file)
  if not header then
    print("WavPeaks: " .. (err or "Unknown error"))
    file:close()
    return nil
  end

  -- Calculate sample range
  local total_samples = header.num_samples
  local duration = total_samples / header.sample_rate

  start_pos = start_pos or 0
  end_pos = end_pos or duration

  local start_sample = math.floor(start_pos * header.sample_rate)
  local end_sample = math.floor(end_pos * header.sample_rate)
  start_sample = math.max(0, math.min(start_sample, total_samples - 1))
  end_sample = math.max(start_sample + 1, math.min(end_sample, total_samples))

  local sample_range = end_sample - start_sample
  local samples_per_peak = math.max(1, math.floor(sample_range / num_peaks))

  local bytes_per_sample = header.bits_per_sample / 8
  local block_size = header.channels * bytes_per_sample
  local max_amplitude = 2 ^ (header.bits_per_sample - 1)

  local peaks = {}

  -- Sample multiple points within each peak window to find maximum amplitude
  for peak_idx = 1, num_peaks do
    local window_start = start_sample + (peak_idx - 1) * samples_per_peak
    local max_val = 0

    -- Sample within the window, taking max amplitude found
    for i = 0, SAMPLES_PER_WINDOW - 1 do
      local sample_pos = window_start + math.floor(i * samples_per_peak / SAMPLES_PER_WINDOW)

      -- Bounds check
      if sample_pos >= end_sample then break end

      local file_pos = header.data_start + (sample_pos * block_size)
      file:seek("set", file_pos)

      local sample = read_signed_int(file, bytes_per_sample)
      if sample then
        local abs_val = math.abs(sample) / max_amplitude
        if abs_val > max_val then
          max_val = abs_val
        end
      end
    end

    peaks[peak_idx] = max_val
  end

  file:close()

  -- Normalize peaks so loudest point reaches 1.0
  local global_max = 0
  for _, v in ipairs(peaks) do
    if v > global_max then global_max = v end
  end
  if global_max > 0 then
    for i = 1, #peaks do
      peaks[i] = peaks[i] / global_max
    end
  end

  return peaks, duration
end

-- Get file duration without computing peaks
function WavPeaks.get_duration(filepath)
  local file = io.open(filepath, "rb")
  if not file then return nil end

  local header, err = read_wav_header(file)
  file:close()

  if not header then return nil end

  return header.num_samples / header.sample_rate
end

return WavPeaks
