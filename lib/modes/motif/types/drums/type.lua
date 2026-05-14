-- type.lua
-- Drums grid routing: 4-lane step grid fills cols 1-8, rows 1-8.

local DrumsType = {}

function DrumsType.draw(layers)
  _seeker.drums_type.step_grid.grid:draw(layers)
end

function DrumsType.handle_key(x, y, z)
  if _seeker.drums_type.step_grid.grid:contains(x, y) then
    _seeker.drums_type.step_grid.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return DrumsType
