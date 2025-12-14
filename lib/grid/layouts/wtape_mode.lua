-- wtape_mode.lua
-- Full-page grid mode for W/Tape
-- Mode button at (13, 2) provides virtual navigation (handled by ModeSwitcher)

local WTapeMode = {}

function WTapeMode.draw_full_page(layers)
  -- Transport row (y=7): rewind, ff, record, play
  _seeker.wtape.rewind.grid:draw(layers)
  _seeker.wtape.ff.grid:draw(layers)
  _seeker.wtape.record.grid:draw(layers)
  _seeker.wtape.playback.grid:draw(layers)

  -- Loop row (y=6): reverse, loop on/off, frippertronics, decay
  _seeker.wtape.reverse.grid:draw(layers)
  _seeker.wtape.loop_active.grid:draw(layers)
  _seeker.wtape.frippertronics.grid:draw(layers)
  _seeker.wtape.decay.grid:draw(layers)
end

function WTapeMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  -- Transport row (y=7)
  if _seeker.wtape.playback.grid:contains(x, y) then
    _seeker.wtape.playback.grid:handle_key(x, y, z)
  elseif _seeker.wtape.record.grid:contains(x, y) then
    _seeker.wtape.record.grid:handle_key(x, y, z)
  elseif _seeker.wtape.ff.grid:contains(x, y) then
    _seeker.wtape.ff.grid:handle_key(x, y, z)
  elseif _seeker.wtape.rewind.grid:contains(x, y) then
    _seeker.wtape.rewind.grid:handle_key(x, y, z)
  -- Loop row (y=6)
  elseif _seeker.wtape.reverse.grid:contains(x, y) then
    _seeker.wtape.reverse.grid:handle_key(x, y, z)
  elseif _seeker.wtape.loop_active.grid:contains(x, y) then
    _seeker.wtape.loop_active.grid:handle_key(x, y, z)
  elseif _seeker.wtape.frippertronics.grid:contains(x, y) then
    _seeker.wtape.frippertronics.grid:handle_key(x, y, z)
  elseif _seeker.wtape.decay.grid:contains(x, y) then
    _seeker.wtape.decay.grid:handle_key(x, y, z)
  end

  return true
end

return WTapeMode
