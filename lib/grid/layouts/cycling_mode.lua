-- cycling_mode.lua
-- Full-page grid layout for cycling mode.
-- The cycling grid handles lane buttons + per-lane stages (rows 4-7, cols 1-9).

local CyclingMode = {}

function CyclingMode.draw_full_page(layers)
  _seeker.cycling_mode.cycling.grid:draw(layers)
end

function CyclingMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  if _seeker.cycling_mode.cycling.grid:contains(x, y) then
    _seeker.cycling_mode.cycling.grid:handle_key(x, y, z)
  end

  return true
end

return CyclingMode
