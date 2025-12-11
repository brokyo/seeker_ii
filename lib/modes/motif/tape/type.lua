-- type.lua
-- Tape type definition: declares components and draw/handle behavior
-- Part of lib/modes/motif/tape/

local TapeType = {}

function TapeType.draw(layers)
  _seeker.tape.velocity.grid:draw(layers)
  _seeker.tape.stage_nav.grid:draw(layers)
  _seeker.tape.playback.grid:draw(layers)
  _seeker.tape.clear.grid:draw(layers)
  _seeker.tape.create.grid:draw(layers)
  _seeker.tape.perform.grid:draw(layers)
  _seeker.tape.keyboard.grid:draw(layers)
  _seeker.tape.keyboard.grid:draw_motif_events(layers)
end

function TapeType.handle_key(x, y, z)
  -- Keyboard (6-11, 2-7)
  if _seeker.tape.keyboard.grid:contains(x, y) then
    _seeker.tape.keyboard.grid:handle_key(x, y, z)
    return true
  end

  -- Velocity buttons (1-4, 3)
  if _seeker.tape.velocity.grid:contains(x, y) then
    _seeker.tape.velocity.grid:handle_key(x, y, z)
    return true
  end

  -- Stage nav buttons (1-4, 2)
  if _seeker.tape.stage_nav.grid:contains(x, y) then
    _seeker.tape.stage_nav.grid:handle_key(x, y, z)
    return true
  end

  -- Playback button (1, 7)
  if _seeker.tape.playback.grid:contains(x, y) then
    _seeker.tape.playback.grid:handle_key(x, y, z)
    return true
  end

  -- Clear button (3, 7)
  if _seeker.tape.clear.grid:contains(x, y) then
    _seeker.tape.clear.grid:handle_key(x, y, z)
    return true
  end

  -- Create button (2, 7)
  if _seeker.tape.create.grid:contains(x, y) then
    _seeker.tape.create.grid:handle_key(x, y, z)
    return true
  end

  -- Perform button (4, 7)
  if _seeker.tape.perform.grid:contains(x, y) then
    _seeker.tape.perform.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return TapeType
