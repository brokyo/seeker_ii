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

Log.MOTIF_REC_DEBUG = {  -- Renamed from MOTIF_DEBUG to be more specific
  STATUS = true,    -- Recording state changes and configuration
  NOTES = false,     -- Note capture events
  TIMING = false    -- Detailed timing and quantization info
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
  TRANSFORM = "TRFM",
  MOTIF_REC = "MREC"  -- Changed from MOTF to MREC to be more specific
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
  end,

  -- Format a table of conductor events (scheduling)
  conductor_table = function(events)
    if #events == 0 then return "No events scheduled" end
    
    -- Define our fields in order with their formatting
    local fields = {
      {name = "loop", width = 4, fmt = "%-4d", get = function(evt) return evt.loop end},
      {name = "type", width = 12, fmt = "%-12s", get = function(evt) return evt.type end},
      {name = "pitch", width = 5, fmt = "%-5s", get = function(evt) return evt.note and evt.note.pitch end},
      {name = "time", width = 10, fmt = "%.3f", get = function(evt) return evt.time end},
      {name = "delta", width = 7, fmt = "%+.3f", get = function(evt, i, events) 
        if i == 1 then return 0.0 end
        return evt.time - events[i-1].time
      end},
      {name = "duration", width = 8, fmt = "%.3f", get = function(evt) return evt.note and evt.note.duration end},
      {name = "velocity", width = 3, fmt = "%-3s", get = function(evt) return evt.note and evt.note.velocity end}
    }
    
    -- Build header
    local lines = {"Scheduled Events:"}
    local header = {}
    local separator = {}
    
    for _, field in ipairs(fields) do
      table.insert(header, string.format("%-"..field.width.."s", field.name))
      table.insert(separator, string.rep("-", field.width))
    end
    
    table.insert(lines, table.concat(header, " | "))
    table.insert(lines, table.concat(separator, "-|-"))
    
    -- Build each row
    for i, evt in ipairs(events) do
      local values = {}
      for _, field in ipairs(fields) do
        local value = field.get(evt, i, events)
        local formatted
        
        if value == nil then
          formatted = string.format("%-"..field.width.."s", "-")
        elseif type(value) == "number" then
          formatted = string.format(field.fmt, value)
        else
          formatted = string.format("%-"..field.width.."s", tostring(value))
        end
        
        table.insert(values, formatted)
      end
      table.insert(lines, table.concat(values, " | "))
    end
    
    return table.concat(lines, "\n")
  end,

  -- Format a table of motif recorder events (recording)
  motif_table = function(events)
    if #events == 0 then return "No events recorded" end
    
    -- Define our fields in order with their formatting
    local fields = {
      {name = "pitch", width = 5, fmt = "%-5s", get = function(evt) return evt.pitch end},
      {name = "time", width = 8, fmt = "%.3f", get = function(evt) return evt.time end},
      {name = "duration", width = 8, fmt = "%.3f", get = function(evt) return evt.duration end},
      {name = "velocity", width = 3, fmt = "%-3s", get = function(evt) return evt.velocity end}
    }
    
    -- Build header
    local lines = {"Recorded Events:"}
    local header = {}
    local separator = {}
    
    for _, field in ipairs(fields) do
      table.insert(header, string.format("%-"..field.width.."s", field.name))
      table.insert(separator, string.rep("-", field.width))
    end
    
    table.insert(lines, table.concat(header, " | "))
    table.insert(lines, table.concat(separator, "-|-"))
    
    -- Build each row
    for _, evt in ipairs(events) do
      local values = {}
      for _, field in ipairs(fields) do
        local value = field.get(evt)
        local formatted
        
        if value == nil then
          formatted = string.format("%-"..field.width.."s", "-")
        elseif type(value) == "number" then
          formatted = string.format(field.fmt, value)
        else
          formatted = string.format("%-"..field.width.."s", tostring(value))
        end
        
        table.insert(values, formatted)
      end
      table.insert(lines, table.concat(values, " | "))
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