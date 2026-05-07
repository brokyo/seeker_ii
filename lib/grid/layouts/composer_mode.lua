-- composer_mode.lua
-- Full-page grid layout for composer mode.
-- The composer grid handles lane buttons + per-lane stages (rows 4-7, cols 1-9).

local ComposerMode = {}

function ComposerMode.draw_full_page(layers)
  _seeker.composer_mode.grids.composer:draw(layers)
end

function ComposerMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  if _seeker.composer_mode.grids.composer:contains(x, y) then
    _seeker.composer_mode.grids.composer:handle_key(x, y, z)
  end

  return true
end

return ComposerMode
