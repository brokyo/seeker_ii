local sample_sequencer = {
    current_step = 1,  -- which step of the sequence we're on
  
    steps = {
      {
        pattern_index = 1,            -- We'll play pattern #1 from our 'patterns' list
        loops = 4,                    -- Play it 4 times
        transform_key = "harmonize",  -- After 4 loops, apply 'harmonize' transform
        transform_args = {
          interval = 2,       -- e.g. "fifth" or 7 semitones if your code maps it differently
          probability = 50,   -- 50% chance of harmony
        }
      },
      {
        pattern_index = 2,
        loops = 2,
        transform_key = "partial",
        transform_args = {
          subsetSize = 3      -- Only play the first 3 notes in the pattern, for example
        }
      },
      {
        pattern_index = 1,
        loops = 2,
        transform_key = "transpose",
        transform_args = {
          interval = 12       -- Transpose by an octave
        }
      },
      -- ... add as many steps as you like
    }
  }
  