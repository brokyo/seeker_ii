-- rec_region.lua
local GridConstants = include("lib/grid_constants")

local RecRegion = {}

RecRegion.layout = {
  x = 3,
  y = 6,
  width = 1,
  height = 1
}

-- Track last press time for double tap detection
RecRegion.last_press = {
  time = 0
}

function RecRegion.contains(x, y)
  return x == RecRegion.layout.x and y == RecRegion.layout.y
end

function RecRegion.draw(layers)
  local brightness
  if _seeker.motif_recorder.is_recording then
    -- Pulsing bright when recording
    brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.CONTROLS.REC_ACTIVE - 3)
  elseif _seeker.ui_state.get_current_section() == "RECORDING" then
    -- Medium brightness when in recording section but not recording
    brightness = GridConstants.BRIGHTNESS.CONTROLS.REC_READY
  else
    -- Dim when inactive
    brightness = GridConstants.BRIGHTNESS.CONTROLS.REC_INACTIVE
  end
  layers.ui[RecRegion.layout.x][RecRegion.layout.y] = brightness
end

function RecRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local current_time = util.time()
    
    -- Always switch to recording section
    _seeker.ui_state.set_current_section("RECORDING")
    
    -- Check for double tap (within 0.3 seconds)
    if (current_time - RecRegion.last_press.time) < 0.3 then
      -- Double tap detected - toggle recording
      if not _seeker.motif_recorder.is_recording then
        -- Get existing motif if we're overdubbing
        local existing_motif = nil
        if params:get("recording_mode") == 2 then -- 2 = Overdub
          local focused_lane = _seeker.ui_state.get_focused_lane()
          existing_motif = _seeker.lanes[focused_lane].motif
          -- Don't allow overdub if no existing motif
          if #existing_motif.events == 0 then
            print("⚠ Cannot overdub: No existing motif")
            return
          end
        end
        
        -- Start recording
        _seeker.motif_recorder:start_recording(existing_motif)
      else
        -- Stop recording and save motif
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local motif = _seeker.motif_recorder:stop_recording()
        _seeker.lanes[focused_lane]:set_motif(motif)
      end
      -- Reset last press to prevent triple-tap
      RecRegion.last_press.time = 0
    else
      -- Update last press info
      RecRegion.last_press.time = current_time
    end
  end
end

return RecRegion 