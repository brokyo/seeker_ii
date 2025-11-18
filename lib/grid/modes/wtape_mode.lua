-- wtape_mode.lua
-- Full-page grid mode for W/Tape
-- Mode button at (13, 2) provides virtual navigation (handled by ModeSwitcher)

local WTapeMode = {}

function WTapeMode.draw_full_page(layers)
  -- Draw wtape playback button
  _seeker.wtape_playback.grid:draw(layers)
end

function WTapeMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  -- Route to wtape playback component
  if _seeker.wtape_playback.grid:contains(x, y) then
    _seeker.wtape_playback.grid:handle_key(x, y, z)
  end

  return true
end

return WTapeMode
