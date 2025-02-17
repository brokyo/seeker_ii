-- overdub_region.lua
local GridConstants = include("lib/grid_constants")
local Section = include("lib/ui/section")

local OverdubRegion = setmetatable({}, Section)
OverdubRegion.__index = OverdubRegion

OverdubRegion.layout = {
  x = 4,  -- Taking over play region's position
  y = 6,
  width = 1,
  height = 1
}

-- Shared press state
OverdubRegion.press_state = {
  start_time = nil,
  pressed_keys = {}
}

function OverdubRegion.contains(x, y)
  return x == OverdubRegion.layout.x and y == OverdubRegion.layout.y
end

function OverdubRegion.draw(layers)
  local brightness
  if _seeker.motif_recorder.is_recording then
    -- Pulsing bright when overdubbing
    brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.CONTROLS.REC_ACTIVE - 3)
  else
    -- Check if lane has a motif to overdub
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local has_motif = #_seeker.lanes[focused_lane].motif.events > 0
    
    if has_motif then
      -- Medium brightness when lane has content to overdub
      brightness = GridConstants.BRIGHTNESS.CONTROLS.REC_READY
    else
      -- Dim when no content to overdub
      brightness = GridConstants.BRIGHTNESS.CONTROLS.REC_INACTIVE
    end
  end
  layers.ui[OverdubRegion.layout.x][OverdubRegion.layout.y] = brightness
end

function OverdubRegion.handle_key(x, y, z)
  local key_id = string.format("%d,%d", x, y)
  
  if z == 1 then -- Key pressed
    OverdubRegion:start_press(key_id)
    
    -- Switch to overdub section
    _seeker.ui_state.set_current_section("OVERDUB")
    
    -- If already recording, stop on any press
    if _seeker.motif_recorder.is_recording then
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local motif = _seeker.motif_recorder:stop_recording()
      _seeker.lanes[focused_lane]:set_motif(motif)
      return
    end
    
  else -- Key released
    if OverdubRegion:is_long_press(key_id) then
      -- Long press - start overdub (only if not already recording)
      if not _seeker.motif_recorder.is_recording then
        -- Check if lane has a motif to overdub
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local existing_motif = _seeker.lanes[focused_lane].motif
        
        -- Don't allow overdub if no existing motif
        if #existing_motif.events == 0 then
          print("⚠ Cannot overdub: No existing motif")
          return
        end
        
        -- Set recording mode to "Overdub"
        params:set("recording_mode", 2)
        -- Start overdub recording
        _seeker.motif_recorder:start_recording(existing_motif)
      end
    end
    
    OverdubRegion:end_press(key_id)
  end
end

return OverdubRegion 