-- type.lua
-- Composer type definition: declares components and draw/handle behavior
-- Part of lib/modes/motif/types/composer/

local ComposerType = {}

function ComposerType.draw(layers)
  -- Cycling controls (row 7: mode toggle, +/- chord, randomize)
  _seeker.composer.cycling.grid:draw(layers)

  -- Keyboard and playback visualization
  _seeker.composer.keyboard.grid:draw(layers)
  _seeker.composer.keyboard.grid:draw_motif_events(layers)
end

function ComposerType.handle_key(x, y, z)
  -- Keyboard (6-11, 1-8)
  if _seeker.composer.keyboard.grid:contains(x, y) then
    _seeker.composer.keyboard.grid:handle_key(x, y, z)
    return true
  end

  -- Cycling controls (row 7)
  if _seeker.composer.cycling.grid:contains(x, y) then
    _seeker.composer.cycling.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return ComposerType
