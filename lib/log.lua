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
  STATUS = true,   -- Record/play state changes and lane focus
  NOTES = true     -- Note on/off events from grid input
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
  TRANSFORM = "↺"  -- Pattern transform
}

-- Main logging function
function Log.log(module, category, msg)
  local debug_table = Log[module .. "_DEBUG"]
  if debug_table and debug_table[category] then
    print(msg)
  end
end

return Log 