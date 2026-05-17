-- type.lua
-- Drums grid routing. Step grid (cols 1-8) and call/response (cols 10-11).

local DrumsType = {}

function DrumsType.draw(layers)
  _seeker.drums_type.grid.grid:draw(layers)
end

function DrumsType.handle_key(x, y, z)
  if _seeker.drums_type.grid.grid:contains(x, y) then
    _seeker.drums_type.grid.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return DrumsType
