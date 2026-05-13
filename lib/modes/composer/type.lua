-- Composer type definition: routes grid draw/input for keyboard_mode integration
-- Degree grid replaces the keyboard area; bottom row has play/smooth/clear/randomize

local ComposerType = {}

function ComposerType.is_fullscreen()
  return false
end

function ComposerType.draw(layers)
  if _seeker.composer_mode.degree_grid then
    _seeker.composer_mode.degree_grid.grid:draw(layers)
  end
  if _seeker.composer_mode.stage_nav then
    _seeker.composer_mode.stage_nav.grid:draw(layers)
  end
  if _seeker.composer_mode.playback then
    _seeker.composer_mode.playback.grid:draw(layers)
  end
  if _seeker.composer_mode.smooth then
    _seeker.composer_mode.smooth.grid:draw(layers)
  end
  if _seeker.composer_mode.clear then
    _seeker.composer_mode.clear.grid:draw(layers)
  end
  if _seeker.composer_mode.perform then
    _seeker.composer_mode.perform.grid:draw(layers)
  end
end

function ComposerType.handle_key(x, y, z)
  if _seeker.composer_mode.degree_grid and _seeker.composer_mode.degree_grid.grid:contains(x, y) then
    _seeker.composer_mode.degree_grid.grid:handle_key(x, y, z)
    return true
  end
  if _seeker.composer_mode.stage_nav and _seeker.composer_mode.stage_nav.grid:contains(x, y) then
    _seeker.composer_mode.stage_nav.grid:handle_key(x, y, z)
    return true
  end
  if _seeker.composer_mode.playback and _seeker.composer_mode.playback.grid:contains(x, y) then
    _seeker.composer_mode.playback.grid:handle_key(x, y, z)
    return true
  end
  if _seeker.composer_mode.smooth and _seeker.composer_mode.smooth.grid:contains(x, y) then
    _seeker.composer_mode.smooth.grid:handle_key(x, y, z)
    return true
  end
  if _seeker.composer_mode.clear and _seeker.composer_mode.clear.grid:contains(x, y) then
    _seeker.composer_mode.clear.grid:handle_key(x, y, z)
    return true
  end
  if _seeker.composer_mode.perform and _seeker.composer_mode.perform.grid:contains(x, y) then
    _seeker.composer_mode.perform.grid:handle_key(x, y, z)
    return true
  end
  return false
end

return ComposerType
