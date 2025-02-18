-- rec_region.lua
local GridConstants = include("lib/grid_constants")
local Section = include("lib/ui/section")

local RecRegion = setmetatable({}, Section)
RecRegion.__index = RecRegion

RecRegion.layout = {
  x = 3,
  y = 7,
  width = 1,
  height = 1
}

-- Shared press state
RecRegion.press_state = {
  start_time = nil,
  pressed_keys = {}
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
  local key_id = string.format("%d,%d", x, y)
  
  if z == 1 then -- Key pressed
    RecRegion:start_press(key_id)
    
    -- Switch to recording section
    _seeker.ui_state.set_current_section("RECORDING")
    
    -- If already recording, stop on any press
    if _seeker.motif_recorder.is_recording then
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local motif = _seeker.motif_recorder:stop_recording()
      _seeker.lanes[focused_lane]:set_motif(motif)
      _seeker.screen_ui.set_needs_redraw()  -- Trigger redraw on stop
      return
    end
    
  else -- Key released
    if RecRegion:is_long_press(key_id) then
      -- Long press - start recording (only if not already recording)
      if not _seeker.motif_recorder.is_recording then
        -- Set recording mode to "New"
        params:set("recording_mode", 1)
        -- Start new recording
        _seeker.motif_recorder:start_recording(nil)
        _seeker.screen_ui.set_needs_redraw()  -- Trigger redraw on start
      end
    end
    
    RecRegion:end_press(key_id)
  end
end

return RecRegion 