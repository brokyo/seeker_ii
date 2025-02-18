-- generate_region.lua
local GridConstants = include("lib/grid_constants")
local GridAnimations = include("lib/grid_animations")

local GenerateRegion = {}

GenerateRegion.layout = {
  x = 2,
  y = 7,
  width = 1,
  height = 1
}

-- Track last press time for double tap detection
GenerateRegion.last_press = {
  time = 0
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

function GenerateRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local current_time = util.time()
    
    -- Always switch to generate section
    _seeker.ui_state.set_current_section("GENERATE")
    
    -- Check for double tap (within 0.3 seconds)
    if (current_time - GenerateRegion.last_press.time) < 0.3 then
      -- Double tap detected - generate new motif
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[focused_lane]
      local section = _seeker.screen_ui.sections.GENERATE
      local motif_data = section:generate_motif()
      lane:set_motif(motif_data)
      -- Flash keyboard to confirm generation
      GridAnimations.flash_keyboard()
      -- Reset last press to prevent triple-tap
      GenerateRegion.last_press.time = 0
    else
      -- Update last press info
      GenerateRegion.last_press.time = current_time
    end
  end
end

return GenerateRegion 