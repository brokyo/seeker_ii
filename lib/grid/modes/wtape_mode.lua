-- wtape_mode.lua
-- Full-page grid mode for W/Tape
-- Mode button at (13, 2) provides virtual navigation (handled by ModeSwitcher)

local WTapeMode = {}

function WTapeMode.draw_full_page(layers)
  -- Transport row (y=7)
  _seeker.wtape_rewind.grid:draw(layers)
  _seeker.wtape_ff.grid:draw(layers)
  _seeker.wtape_record.grid:draw(layers)
  _seeker.wtape_playback.grid:draw(layers)

  -- Loop row (y=6)
  _seeker.wtape_reverse.grid:draw(layers)
  _seeker.wtape_loop_active.grid:draw(layers)
  _seeker.wtape_loop_start.grid:draw(layers)
  _seeker.wtape_loop_end.grid:draw(layers)
end

function WTapeMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  -- Transport row (y=7)
  if _seeker.wtape_playback.grid:contains(x, y) then
    _seeker.wtape_playback.grid:handle_key(x, y, z)
  elseif _seeker.wtape_record.grid:contains(x, y) then
    _seeker.wtape_record.grid:handle_key(x, y, z)
  elseif _seeker.wtape_ff.grid:contains(x, y) then
    _seeker.wtape_ff.grid:handle_key(x, y, z)
  elseif _seeker.wtape_rewind.grid:contains(x, y) then
    _seeker.wtape_rewind.grid:handle_key(x, y, z)
  -- Loop row (y=6)
  elseif _seeker.wtape_reverse.grid:contains(x, y) then
    _seeker.wtape_reverse.grid:handle_key(x, y, z)
  elseif _seeker.wtape_loop_active.grid:contains(x, y) then
    _seeker.wtape_loop_active.grid:handle_key(x, y, z)
  elseif _seeker.wtape_loop_start.grid:contains(x, y) then
    _seeker.wtape_loop_start.grid:handle_key(x, y, z)
  elseif _seeker.wtape_loop_end.grid:contains(x, y) then
    _seeker.wtape_loop_end.grid:handle_key(x, y, z)
  end

  return true
end

return WTapeMode
