-- grid_constants.lua
-- Central source for all grid-related constants
--------------------------------------------------

local GridConstants = {
  -- Grid dimensions
  GRID_WIDTH = 16,
  GRID_HEIGHT = 8,

  -- Layer priorities (higher = more important)
  LAYER_PRIORITY = {
    BACKGROUND = 1,
    UI = 2,
    RESPONSE = 3
  },

  -- Brightness levels
  BRIGHTNESS = {
    -- Core levels
    FULL = 15,
    HIGH = 12,
    MEDIUM = 8,
    LOW = 4,
    DIM = 2,
    OFF = 0,

    -- UI-specific levels
    UI = {
      FOCUSED = 15,
      ACTIVE = 12,
      NORMAL = 8,
      INACTIVE = 4
    },
    -- Control states
    CONTROLS = {
      REC_ACTIVE = 15,    -- Bright red for recording
      REC_INACTIVE = 2,   -- Very dim for inactive rec
      PLAY_ACTIVE = 12,   -- Medium-bright for playing
      PLAY_INACTIVE = 4   -- Slightly brighter than rec inactive
    }
  }
}

return GridConstants 