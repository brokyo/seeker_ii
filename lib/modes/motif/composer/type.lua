-- type.lua
-- Composer type definition: declares components and draw/handle behavior
-- Part of lib/modes/motif/composer/

local ComposerType = {}

function ComposerType.draw(layers)
  -- Stage navigation rows (harmonic at row 2, expression at row 3)
  _seeker.composer_harmonic_stages.grid:draw(layers)
  _seeker.composer_expression_stages.grid:draw(layers)

  -- Control buttons (row 7)
  _seeker.composer_playback.grid:draw(layers)
  _seeker.composer_clear.grid:draw(layers)
  _seeker.composer_create.grid:draw(layers)
  _seeker.composer_perform.grid:draw(layers)

  -- Keyboard and playback visualization
  _seeker.composer_keyboard.grid:draw(layers)
  _seeker.composer_keyboard.grid:draw_motif_events(layers)
end

function ComposerType.handle_key(x, y, z)
  -- Keyboard (6-11, 1-8)
  if _seeker.composer_keyboard.grid:contains(x, y) then
    _seeker.composer_keyboard.grid:handle_key(x, y, z)
    return true
  end

  -- Harmonic stage buttons (1-4, row 2)
  if _seeker.composer_harmonic_stages.grid:contains(x, y) then
    _seeker.composer_harmonic_stages.grid:handle_key(x, y, z)
    return true
  end

  -- Expression stage buttons (1-4, row 3)
  if _seeker.composer_expression_stages.grid:contains(x, y) then
    _seeker.composer_expression_stages.grid:handle_key(x, y, z)
    return true
  end

  -- Playback button (1, 7)
  if _seeker.composer_playback.grid:contains(x, y) then
    _seeker.composer_playback.grid:handle_key(x, y, z)
    return true
  end

  -- Clear button (3, 7)
  if _seeker.composer_clear.grid:contains(x, y) then
    _seeker.composer_clear.grid:handle_key(x, y, z)
    return true
  end

  -- Create button (2, 7)
  if _seeker.composer_create.grid:contains(x, y) then
    _seeker.composer_create.grid:handle_key(x, y, z)
    return true
  end

  -- Perform button (4, 7)
  if _seeker.composer_perform.grid:contains(x, y) then
    _seeker.composer_perform.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return ComposerType
