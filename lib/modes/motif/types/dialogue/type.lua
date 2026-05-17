-- type.lua
-- Dialogue grid routing. Step grid (cols 1-8) and call/response (cols 10-11).

local DialogueType = {}

function DialogueType.draw(layers)
  _seeker.dialogue_type.grid.grid:draw(layers)
end

function DialogueType.handle_key(x, y, z)
  if _seeker.dialogue_type.grid.grid:contains(x, y) then
    _seeker.dialogue_type.grid.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return DialogueType
