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
  end
end

return GenerateRegion 