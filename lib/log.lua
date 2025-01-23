-- log.lua
--
-- Logging system for Seeker II
-- Provides consistent logging utilities and
-- centralized debug configuration
--
-- Usage:
-- 1. Configure debug flags for your module in Log.GRID_DEBUG
--    Each flag controls a category of logs (e.g. NOTES, STATUS)
--
-- 2. Call Log.log with three parameters:
--    - module: The module name (e.g. "GRID")
--    - category: The type of log (must match a debug flag)
--    - message: The message to log
--
-- Example:
--   Log.log("GRID", "NOTES", "♪ Note ON | C4")
--   Only prints if Log.GRID_DEBUG.NOTES is true
--
--------------------------------------------------

local Log = {}

-- Debug configuration for different modules
Log.GRID_DEBUG = {
  GRID = false,    -- Grid button presses and LED updates
  STATUS = false,   -- Record/play state changes and lane focus
  NOTES = false     -- Note on/off events from grid input
}

Log.SCREEN_DEBUG = {
  STATUS = true    -- Screen state changes
}

Log.PARAMS_DEBUG = {
  STATUS = true    -- Parameter initialization and access
}

Log.TRANSFORM_DEBUG = {
  EVENTS = true,    -- Note sequence before/after transform
  STAGES = true,    -- Stage transitions and transform application
  TIMING = false    -- Detailed timing deltas (for debugging sync)
}

Log.CONDUCTOR_DEBUG = {
  PLAYBACK = false,  -- Note events and timing at execution
  STATUS = true,    -- Loop/stage changes and high-level state
  SCHEDULE = true,  -- Pre-calculated note sequences and transforms
  BOUNDARY = true,  -- Loop and stage boundaries
  TIMING = false     -- Timing synchronization and deltas
}

-- Visual indicators for consistent logging
Log.ICONS = {
  GRID = "⬚",     -- Grid press
  NOTE_ON = "♪",   -- Note on
  NOTE_OFF = "♫",  -- Note off
  RECORD_ON = "●", -- Start recording
  RECORD_OFF = "▣",-- Stop recording
  PLAY = "▶",      -- Start playing
  STOP = "■",      -- Stop playing
  FOCUS = "◆",     -- Lane/UI focus
  STAGE = "□",     -- Stage select
  CLEAR = "✖",     -- Clear lane
  CLOCK = "⧗",     -- Timing events
  TRANSFORM = "↺", -- Pattern transform
  PARAMS = "⚙"    -- Parameter operations
}

-- Module prefix aliases (all 4 chars)
Log.PREFIX = {
  GRID = "GRID",
  CONDUCTOR = "COND",
  SCREEN = "SCRN",
  PARAMS = "PARM",
  TRANSFORM = "TRAN"
}

-- Formatting helpers
Log.format = {
  -- Format beat number to show only last 4 digits for readability
  beat = function(beat)
    local beat_str = string.format("%.3f", beat)
    local len = #beat_str
    if len > 8 then
      return "..." .. string.sub(beat_str, len-7)
    end
    return beat_str
  end,

  -- Format timing delta with sign
  delta = function(actual, target)
    local delta = actual - target
    if math.abs(delta) < 0.001 then return "=0.000" end
    return string.format("%+.3f", delta)
  end,

  -- Format a note event in a consistent way
  note = function(note, index)
    local pitch_class = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'}
    local octave = math.floor(note.pitch / 12) - 1
    local class = pitch_class[(note.pitch % 12) + 1]
    return string.format("%d: %s%d %.2fb", index, class, octave, note.time)
  end,
  
  -- Format a sequence of notes
  sequence = function(notes, total_duration)
    local lines = {}
    for i, note in ipairs(notes) do
      table.insert(lines, "  " .. Log.format.note(note, i))
    end
    if total_duration then
      table.insert(lines, string.format("  Total: %.2f beats", total_duration))
    end
    return table.concat(lines, "\n")
  end
}

-- Transform sequence logging (special case since it needs multi-line output)
Log.TRANSFORM = {
  sequence = function(stage_num, transform_type, notes, total_duration)
    if not Log.TRANSFORM_DEBUG.EVENTS then return end
    local header = transform_type and 
      string.format("Stage %d (%s)", stage_num, transform_type) or
      string.format("Stage %d", stage_num)
    print("\n" .. Log.ICONS.TRANSFORM .. " " .. header)
    print(Log.format.sequence(notes, total_duration))
  end
}

-- Main logging function
function Log.log(module, category, msg)
  local debug_table = Log[module .. "_DEBUG"]
  if debug_table and debug_table[category] then
    local prefix = Log.PREFIX[module] or module
    print(string.format("[%4s] %s", prefix, msg))
  end
end

return Log 