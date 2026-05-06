-- type.lua
-- Drums grid routing: step grid + transport controls

local DrumsType = {}

function DrumsType.draw(layers)
  _seeker.drums_type.step_grid.grid:draw(layers)
  _seeker.drums_type.playback.grid:draw(layers)
  _seeker.drums_type.clear.grid:draw(layers)
  _seeker.drums_type.perform.grid:draw(layers)
end

function DrumsType.handle_key(x, y, z)
  if _seeker.drums_type.step_grid.grid:contains(x, y) then
    _seeker.drums_type.step_grid.grid:handle_key(x, y, z)
    return true
  end

  if _seeker.drums_type.playback.grid:contains(x, y) then
    _seeker.drums_type.playback.grid:handle_key(x, y, z)
    return true
  end

  if _seeker.drums_type.clear.grid:contains(x, y) then
    _seeker.drums_type.clear.grid:handle_key(x, y, z)
    return true
  end

  if _seeker.drums_type.perform.grid:contains(x, y) then
    _seeker.drums_type.perform.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return DrumsType
