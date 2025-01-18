-- conductor.lua
-- Conductor is responsible for:
-- 1. Managing when motifs play (clock/timing)
-- 2. Controlling how motifs are transformed
-- 3. Synchronizing multiple motifs
-- 4. Managing playback state

local Motif = include('lib/motif')

local Conductor = {}
Conductor.__index = Conductor

-- Default settings
local DEFAULT_TRANSFORM_WAIT = 8  -- Wait 8 bars between transform sequences

--------------------------------------------------
-- Constructor & State Management
--------------------------------------------------

function Conductor.new(args)
  local c = setmetatable({}, Conductor)
  
  -- Voice slots for UI organization
  -- TODO: This will be replaced with a proper voice management system
  -- that separates UI state from playback logic
  c.voices = {}
  for i = 1,4 do
    c.voices[i] = {
      motif = nil,
      is_playing = false
    }
  end
  
  -- Clock and Playback State
  c.master_clock = nil        -- Main clock coroutine ID
  c.playing_motifs = {}       -- Tracks active motifs and their state
  -- playing_motifs structure:
  -- {
  --   [motif_id] = {
  --     motif = <motif_object>,
  --     loop_count = 0,           -- How many times has this motif looped
  --     pattern_loops = 0,        -- Loops in current transform stage
  --     playback_speed = 1.0,     -- Relative to global tempo
  --     current_transform = 1,    -- Index in transform sequence
  --     transform_sequence = {},  -- Sequence of transforms to apply
  --     timing_mode = "free",    -- "free" for human timing, "grid" for quantized
  --     grid_division = 1/16,    -- If grid timing, what division to use
  --     wait_bars = DEFAULT_TRANSFORM_WAIT  -- Bars to wait between transforms
  --   }
  -- }
  
  -- Transform Management
  -- Each motif can have a sequence of transforms
  -- Transform sequence structure:
  -- {
  --   {
  --     transform = function,     -- Transform function to apply
  --     params = {},             -- Parameters for this transform
  --     after_loops = number,    -- How many loops to play this version
  --     sync_with = {motif_ids}, -- Optional: Other motifs to sync with
  --   }
  -- }
  -- Transform function signature:
  -- function(motif, params) -> transformed_motif
  -- Common params might include:
  -- - transpose_amount
  -- - inversion_point
  -- - playback_rate
  -- - quantization_amount
  
  return c
end

--------------------------------------------------
-- Clock Management
--------------------------------------------------

-- Start the master clock
function Conductor:start_clock()
  if self.master_clock then clock.cancel(self.master_clock) end
  
  self.master_clock = clock.run(function()
    while true do
      local now = clock.get_beats()
      
      -- Process each playing motif
      for id, pm in pairs(self.playing_motifs) do
        -- TODO: Handle timing based on mode:
        -- For free timing:
        -- - Calculate exact time to next note using note.time
        -- - Use clock.sleep() for precise delays
        --
        -- For grid timing:
        -- - Quantize to grid_division
        -- - Use clock.sync() for rigid timing
        --
        -- At pattern boundaries:
        -- - Increment pattern_loops
        -- - If pattern_loops >= current_transform.after_loops
        --   - Wait wait_bars if this isn't the first transform
        --   - Apply next transform
        --   - Reset pattern_loops
        --   - Advance current_transform (loop back to 1 if at end)
      end
      
      -- Sleep a very small amount to prevent tight loop
      clock.sleep(0.001)
    end
  end)
end

-- Add a motif to the playback system
function Conductor:play_motif(motif_id, opts)
  -- TODO: opts will include:
  -- - playback_speed
  -- - transform_sequence
  -- - timing_mode ("free" or "grid")
  -- - grid_division (if grid mode)
  -- - wait_bars (optional, defaults to DEFAULT_TRANSFORM_WAIT)
end

-- Add a transform to a motif's sequence
function Conductor:add_transform(motif_id, transform_fn, params, opts)
  -- TODO: opts will include:
  -- - after_loops: number of loops to wait
  -- - sync_with: optional array of other motif_ids to sync with
  -- params: transform-specific parameters
end

-- Schedule synchronized transforms across multiple motifs
function Conductor:sync_transform(motif_ids, transform_fn, params, after_loops)
  -- Helper to add the same transform to multiple motifs
  -- Will ensure they all transform together after the specified number of loops
end

--------------------------------------------------
-- Motif Management
--------------------------------------------------

function Conductor:create_motif(voice_num, recorded_data)
  -- Debug print the recorded data
  print("▼ Creating Motif for Lane " .. voice_num .. " ▼")
  for i, note in ipairs(recorded_data) do
    local note_info = string.format("Note %d: pitch=%d time=%.2f dur=%.2f", 
      i, note.pitch, note.time, note.duration)
    if note.pos then
      note_info = note_info .. string.format(" pos=(%d,%d)", note.pos.x, note.pos.y)
    end
    print(note_info)
  end
  
  local motif = Motif.new({
    notes = recorded_data,
    voice = voice_num
  })
  
  -- Store in voice slot
  self.voices[voice_num].motif = motif
  
  return motif
end

return Conductor
