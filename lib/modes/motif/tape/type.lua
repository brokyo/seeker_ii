-- type.lua
-- Tape type definition: declares components and draw/handle behavior
-- Part of lib/modes/motif/tape/

local TapeType = {}

function TapeType.draw(layers)
  _seeker.tape_velocity.grid:draw(layers)
  _seeker.tape_stage_nav.grid:draw(layers)
  _seeker.tape_playback.grid:draw(layers)
  _seeker.tape_clear.grid:draw(layers)
  _seeker.tape_create.grid:draw(layers)
  _seeker.tape_perform.grid:draw(layers)
  _seeker.tape_keyboard.grid:draw(layers)
  _seeker.tape_keyboard.grid:draw_motif_events(layers)
end

function TapeType.handle_key(x, y, z)
  -- Keyboard (6-11, 2-7)
  if _seeker.tape_keyboard.grid:contains(x, y) then
    _seeker.tape_keyboard.grid:handle_key(x, y, z)
    return true
  end

  -- Velocity buttons (1-4, 3)
  if _seeker.tape_velocity.grid:contains(x, y) then
    _seeker.tape_velocity.grid:handle_key(x, y, z)
    return true
  end

  -- Stage nav buttons (1-4, 2)
  if _seeker.tape_stage_nav.grid:contains(x, y) then
    _seeker.tape_stage_nav.grid:handle_key(x, y, z)
    return true
  end

  -- Playback button (1, 7)
  if _seeker.tape_playback.grid:contains(x, y) then
    _seeker.tape_playback.grid:handle_key(x, y, z)
    return true
  end

  -- Clear button (3, 7)
  if _seeker.tape_clear.grid:contains(x, y) then
    _seeker.tape_clear.grid:handle_key(x, y, z)
    return true
  end

  -- Create button (2, 7)
  if _seeker.tape_create.grid:contains(x, y) then
    _seeker.tape_create.grid:handle_key(x, y, z)
    return true
  end

  -- Perform button (4, 7)
  if _seeker.tape_perform.grid:contains(x, y) then
    _seeker.tape_perform.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return TapeType
