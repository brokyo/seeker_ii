-- type.lua
-- Sampler type definition: declares components and draw/handle behavior
-- Part of lib/modes/motif/sampler/

local SamplerType = {}

function SamplerType.draw(layers)
  _seeker.sampler_velocity.grid:draw(layers)
  _seeker.sampler_stage_nav.grid:draw(layers)
  _seeker.sampler_playback.grid:draw(layers)
  _seeker.sampler_clear.grid:draw(layers)
  _seeker.sampler_create.grid:draw(layers)
  _seeker.sampler_perform.grid:draw(layers)
  _seeker.sampler_keyboard.grid:draw(layers)
end

function SamplerType.handle_key(x, y, z)
  -- Keyboard (7-10, 3-6)
  if _seeker.sampler_keyboard.grid:contains(x, y) then
    _seeker.sampler_keyboard.grid:handle_key(x, y, z)
    return true
  end

  -- Velocity buttons (1-4, 3)
  if _seeker.sampler_velocity.grid:contains(x, y) then
    _seeker.sampler_velocity.grid:handle_key(x, y, z)
    return true
  end

  -- Stage nav buttons (1-4, 2)
  if _seeker.sampler_stage_nav.grid:contains(x, y) then
    _seeker.sampler_stage_nav.grid:handle_key(x, y, z)
    return true
  end

  -- Playback button (1, 7)
  if _seeker.sampler_playback.grid:contains(x, y) then
    _seeker.sampler_playback.grid:handle_key(x, y, z)
    return true
  end

  -- Clear button (3, 7)
  if _seeker.sampler_clear.grid:contains(x, y) then
    _seeker.sampler_clear.grid:handle_key(x, y, z)
    return true
  end

  -- Create button (2, 7)
  if _seeker.sampler_create.grid:contains(x, y) then
    _seeker.sampler_create.grid:handle_key(x, y, z)
    return true
  end

  -- Perform button (4, 7)
  if _seeker.sampler_perform.grid:contains(x, y) then
    _seeker.sampler_perform.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return SamplerType
