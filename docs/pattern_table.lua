local pattern_example = {
    -- Identifies the kind of pattern: "human", "arpeggio", etc.
    type = "human",
  
    -- The original notes as captured during recording
    -- Typically sorted by start_beat in ascending order
    original_notes = {
      {
        pitch = 60,           -- MIDI note: C4
        velocity = 100,       -- MIDI velocity (0–127)
        start_beat = 0.0,     -- offset in beats from the start of the pattern
        duration_beats = 1.0  -- length in beats
      },
      {
        pitch = 64,           -- E4
        velocity = 95,
        start_beat = 1.0,
        duration_beats = 0.5
      },
      -- ... more notes
    },
  
    -- After applying a transform (e.g., transpose, harmonize), we store 
    -- the resulting notes here so we can replay them without losing the original.
    transformed_notes = {
      -- (Same note structure as original_notes)
      -- This table can be empty until a transform is applied
    },
  
    -- You can track how many times this pattern has looped, 
    -- when to apply transforms, etc.:
    loop_count = 0,
    max_loops = 4,
  
    -- Optionally store metadata, like total length in beats, roles, etc.
    total_beats = 2.5,   
    role = "TEXTURE",    -- Or another musical role
  }
  