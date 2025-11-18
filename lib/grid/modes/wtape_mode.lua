-- wtape_mode.lua
-- Full-page grid mode for W/Tape - shows only w/tape button, no keyboard UI

local WTapeMode = {}

function WTapeMode.draw_full_page(layers)
  -- Draw only the w/tape button itself
  _seeker.w_tape.grid:draw(layers)
end

function WTapeMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  -- Only handle w/tape button
  if _seeker.w_tape.grid:contains(x, y) then
    _seeker.w_tape.grid:handle_key(x, y, z)
  end

  return true
end

return WTapeMode
