-- Cycling mode initialization
-- Wheel sub-mode for motif: algorithmic chord progressions.
-- Grid handles lane buttons + per-lane stages directly.

local Cycling = include("lib/modes/motif/types/composer/cycling")

local CyclingMode = {}

function CyclingMode.init()
  local instance = {
    sections = {},
    grids = {}
  }

  -- Initialize cycling component (creates params, screen UI, grid UI)
  instance.cycling = Cycling.init()

  -- Register screen section
  instance.sections["CYCLING_LIVE"] = instance.cycling.screen

  -- Register grid
  instance.grids.cycling = instance.cycling.grid

  return instance
end

return CyclingMode
