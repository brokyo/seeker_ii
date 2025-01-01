--[[
  theory_utils.lua
  Musical theory and timing utilities for Seeker II

  Handles:
  - Clock division definitions
  - Musical note length definitions
  - Note name mappings
]]--

-- Commonly reused musical stuff

local theory_utils = {}

-- Clock division options (for clock behavior)
theory_utils.clock_divisions = {
    "/16", "/8", "/7", "/6", "/5", "/4", "/3", "/2", "1", "*2", "*3", "*4", "*5", "*6", "*7", "*8", "*16"
  }
  
  -- Note length options (for musical rhythms)
  theory_utils.note_lengths = {
    "1/16", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "16"
  }
  
  -- Function to get a clock division
  function theory_utils.get_clock_division(index)
    return theory_utils.clock_divisions[index] or "unknown"
  end
  
  -- Function to get a note length
  function theory_utils.get_note_length(index)
    return theory_utils.note_lengths[index] or "unknown"
  end
  
  -- Note names
  theory_utils.note_names = {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
  }
  
  -- Note names
  theory_utils.note_names = {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
  }

return theory_utils
