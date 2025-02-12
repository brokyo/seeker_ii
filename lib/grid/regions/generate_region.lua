-- generate_region.lua
local GridConstants = include("lib/grid_constants")
local MotifGenerator = include("lib/motif_generator")

local GenerateRegion = {}

GenerateRegion.layout = {
  x = 2,
  y = 6,
  width = 1,
  height = 1
}

-- Keep track of keyboard flash animation
GenerateRegion.keyboard_flash = {
  active = false,
  start_beat = 0,
  duration = 0.4  -- Longer animation duration
}

function GenerateRegion.contains(x, y)
  return x == GenerateRegion.layout.x and y == GenerateRegion.layout.y
end

function GenerateRegion.draw(layers)
  local brightness
  if _seeker.ui_state.get_current_section() == "GENERATE" then
    -- Medium brightness when in generate section
    brightness = GridConstants.BRIGHTNESS.CONTROLS.REC_READY
  else
    -- Dim when inactive
    brightness = GridConstants.BRIGHTNESS.CONTROLS.REC_INACTIVE
  end
  layers.ui[GenerateRegion.layout.x][GenerateRegion.layout.y] = brightness

  -- Draw keyboard flash if active
  if GenerateRegion.keyboard_flash.active then
    local current_beat = clock.get_beats()
    local elapsed = current_beat - GenerateRegion.keyboard_flash.start_beat
    
    if elapsed < GenerateRegion.keyboard_flash.duration then
      -- Calculate animation phase (0 to 1)
      local phase = elapsed / GenerateRegion.keyboard_flash.duration
      -- Smooth fade out curve
      local fade = 1 - (phase * phase)
      
      -- Flash the keyboard area with center-weighted gradient
      local center_x = 8.5  -- Center of keyboard
      local center_y = 4.5
      for x = 6, 11 do  -- Keyboard width
        for y = 2, 7 do  -- Keyboard height
          -- Calculate distance from center (normalized to 0-1)
          local dist_x = math.abs(x - center_x) / 2.5
          local dist_y = math.abs(y - center_y) / 2.5
          local dist = math.sqrt(dist_x * dist_x + dist_y * dist_y)
          
          -- Add some wave motion based on phase
          local wave = math.sin(phase * math.pi * 2 + dist * 3) * 0.2
          -- Combine distance falloff with wave and fade
          local brightness = math.floor(GridConstants.BRIGHTNESS.MEDIUM * (1 - (dist * 0.7) + wave) * fade)
          
          if brightness > 0 then
            layers.response[x][y] = brightness
          end
        end
      end
    else
      GenerateRegion.keyboard_flash.active = false
    end
  end
end

-- Like `motif_recorder` we use the first press to move to the UI and the second press to generate
function GenerateRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    -- If we're not in generate section, switch to it
    if _seeker.ui_state.get_current_section() ~= "GENERATE" then
      _seeker.ui_state.set_current_section("GENERATE")
      return
    end
    
    -- If we're already in generate section, generate using current settings
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[focused_lane]
    
    -- Generate new motif
    local motif_data = MotifGenerator.generate()
    lane:set_motif(motif_data)
    
    -- Trigger keyboard flash animation
    GenerateRegion.keyboard_flash.active = true
    GenerateRegion.keyboard_flash.start_beat = clock.get_beats()
  end
end

return GenerateRegion 