local example_pattern = {
    -- Pattern type could be "human" or "arpeggio," or something else
    type = "human",
  
    -- A list of notes. Each note has:
    -- 1) pitch (MIDI note number)
    -- 2) start_beat (when the note starts, in beats from the recording start)
    -- 3) velocity (0–127)
    -- 4) duration_beats (length of the note in beats)
    notes = {
      {
        pitch = 60,          -- C4
        start_beat = 0.0,    -- plays right at pattern start
        velocity = 100,
        duration_beats = 1.0 -- lasts for 1 beat
      },
      {
        pitch = 64,          -- E4
        start_beat = 1.0,    -- starts 1 beat after pattern start
        velocity = 95,
        duration_beats = 0.5
      },
      {
        pitch = 67,          -- G4
        start_beat = 2.0,    -- starts 2 beats in
        velocity = 110,
        duration_beats = 1.5
      },
      -- etc.
    },
  
    -- Optionally track total length, loop counters, transform data, etc.
    total_beats = 3.5,   -- e.g., the sum of start_beat + duration_beats for the last note
    loop_count = 0,      -- how many times this pattern has looped so far
    max_loops = 4,       -- example: transform or switch pattern after 4 loops
  
    -- You might store transform or role references if you want them attached directly:
    role = "TEXTURE",    -- or "MELODY", "BASS", etc.
    transform_info = {}, -- a table for transform-specific data
  }
  