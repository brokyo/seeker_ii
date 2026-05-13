-- Composer type definition: routes grid draw/input for keyboard_mode integration
-- Degree grid (7 degree cols + 1 stage count col) is the main surface.

local ComposerType = {}

function ComposerType.is_fullscreen()
  return false
end

function ComposerType.draw(layers)
  if _seeker.composer_mode.degree_grid then
    _seeker.composer_mode.degree_grid.grid:draw(layers)
  end
  if _seeker.composer_mode.pitch_display then
    _seeker.composer_mode.pitch_display.grid:draw(layers)
  end
end

function ComposerType.handle_key(x, y, z)
  if _seeker.composer_mode.degree_grid and _seeker.composer_mode.degree_grid.grid:contains(x, y) then
    _seeker.composer_mode.degree_grid.grid:handle_key(x, y, z)
    return true
  end
  return false
end

return ComposerType
