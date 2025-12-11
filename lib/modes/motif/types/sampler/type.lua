-- type.lua
-- Sampler type definition: declares components and draw/handle behavior
-- Part of lib/modes/motif/types/sampler/

local SamplerType = {}

function SamplerType.draw(layers)
  _seeker.sampler_type.velocity.grid:draw(layers)
  _seeker.sampler_type.stage_nav.grid:draw(layers)
  _seeker.sampler_type.playback.grid:draw(layers)
  _seeker.sampler_type.clear.grid:draw(layers)
  _seeker.sampler_type.create.grid:draw(layers)
  _seeker.sampler_type.perform.grid:draw(layers)
  _seeker.sampler_type.keyboard.grid:draw(layers)
end

function SamplerType.handle_key(x, y, z)
  -- Keyboard (7-10, 3-6)
  if _seeker.sampler_type.keyboard.grid:contains(x, y) then
    _seeker.sampler_type.keyboard.grid:handle_key(x, y, z)
    return true
  end

  -- Velocity buttons (1-4, 3)
  if _seeker.sampler_type.velocity.grid:contains(x, y) then
    _seeker.sampler_type.velocity.grid:handle_key(x, y, z)
    return true
  end

  -- Stage nav buttons (1-4, 2)
  if _seeker.sampler_type.stage_nav.grid:contains(x, y) then
    _seeker.sampler_type.stage_nav.grid:handle_key(x, y, z)
    return true
  end

  -- Playback button (1, 7)
  if _seeker.sampler_type.playback.grid:contains(x, y) then
    _seeker.sampler_type.playback.grid:handle_key(x, y, z)
    return true
  end

  -- Clear button (3, 7)
  if _seeker.sampler_type.clear.grid:contains(x, y) then
    _seeker.sampler_type.clear.grid:handle_key(x, y, z)
    return true
  end

  -- Create button (2, 7)
  if _seeker.sampler_type.create.grid:contains(x, y) then
    _seeker.sampler_type.create.grid:handle_key(x, y, z)
    return true
  end

  -- Perform button (4, 7)
  if _seeker.sampler_type.perform.grid:contains(x, y) then
    _seeker.sampler_type.perform.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return SamplerType
