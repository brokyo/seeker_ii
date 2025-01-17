-- grid.lua
-- Handles incoming grid events, displays keyboard layout, etc.

local GridUI = {}
local g = grid.connect()
local params_manager = include('/lib/params_manager')
local theory = include('/lib/theory_utils')
local MotifRecorder = include('/lib/motif_recorder')
local logger = include("/lib/logger")
local Motif = include('lib/motif')

--------------------------------------------------
-- Initialization
--------------------------------------------------

-- Define brightness levels for LED feedback
local BRIGHTNESS = {
  high = 12,
  medium = 8,
  low = 5,
  inactive = 0
}

function GridUI.init(skeys_instance, conductor, motif_recorder)
  -- Store MXSamples instance
  GridUI.skeys = skeys_instance
  
  -- Store conductor reference
  GridUI.conductor = conductor
  
  -- Store motif recorder reference
  GridUI.motif_recorder = motif_recorder
  
  -- Initialize musical state
  GridUI.root_note = params:get("root_note")
  GridUI.base_octave = params:get("base_octave")
  GridUI.scale_type = params:get("scale_type")
  
  -- Check if grid is connected, set up any initial state
  if g.device then
    logger.status({
      event = "grid_connected",
      device = g.device.name
    }, "⬖ ▣ ▣")
    
    -- Set up the key callback
    g.key = function(x, y, z)
      GridUI.key(x, y, z)
    end
  else
    logger.status({
      event = "grid_connection_failed"
    }, "⬖ ▣ ▣")
  end
end

-- Call this after params and reflection manager are initialized
function GridUI.post_init()
  -- Print initial keyboard layout
  theory.print_keyboard_layout()
end

--------------------------------------------------
-- Grid Event Handlers
--------------------------------------------------

-- Handle recording controls
function GridUI.handle_record_toggle(x, y, z)
  if x == 4 and y == 1 and z == 1 then
    if not GridUI.motif_recorder.is_recording then
      GridUI.motif_recorder:startRecording()
      logger.status({
        event = "grid_recording_started"
      }, "⬖ ▣ ▣")
    else
      local notes = GridUI.motif_recorder:stopRecording()
      
      -- Add the notes to the conductor
      GridUI.conductor:add_motif({
        notes = notes,
        engine = GridUI.skeys
      })
      
      logger.debug({
        event = "motif_recorded",
        motif = notes
      }, "! !")
    end
  end
end

-- Handle playback controls
function GridUI.handle_playback_toggle(x, y, z)
  if x == 5 and y == 1 and z == 1 then  -- Play button at x=5, row 1
    -- Toggle playback of all motifs
    if GridUI.is_playing then
      GridUI.conductor:stop_all()
      GridUI.is_playing = false
    else
      GridUI.conductor:start_all()
      GridUI.is_playing = true
    end
  end
end

-- Handle clear pattern
function GridUI.handle_clear_pattern(x, y, z)
  if x == 12 and y == 1 and z == 1 then  -- Clear button at x=12, row 1

  end
end

-- Handle note record
function GridUI.handle_note_record(x, y, z)
  if x >= 4 and x <= 12 and y >= 6 and y <= 8 then
    local pitch = theory.grid_to_note(x, y)
    if pitch then
      local velocity = z == 1 and 100 or 0
      
      -- Play through MXSamples
      if z == 1 then
        GridUI.skeys:on({
          name = params:string("instrument"),
          midi = pitch,
          velocity = velocity
        })
        -- Record note if recording
        if GridUI.motif_recorder.is_recording then
          GridUI.motif_recorder:onNoteOn(pitch, velocity, {x=x, y=y})
        end
      else
        GridUI.skeys:off({
          name = params:string("instrument"),
          midi = pitch
        })
        -- Record note off if recording
        if GridUI.motif_recorder.is_recording then
          GridUI.motif_recorder:onNoteOff(pitch)
        end
      end
      
      logger.music({
        event = z == 1 and "note_on" or "note_off",
        n = pitch,
        v = velocity,
        pos = string.format("%d,%d", x, y),
        recording = GridUI.motif_recorder.is_recording
      }, "▓▓")
    end
  end
end

-- Main key event handler
function GridUI.key(x, y, z)
  GridUI.handle_record_toggle(x, y, z)
  GridUI.handle_playback_toggle(x, y, z)
  GridUI.handle_clear_pattern(x, y, z)
  GridUI.handle_note_record(x, y, z)
  GridUI.redraw()
end

--------------------------------------------------
-- Grid Refresh
--------------------------------------------------

-- Draw the musical interval keyboard on the grid
function GridUI.draw_keyboard()
  local current_scale = params:get("scale_type")
  
  -- Draw keyboard in original position (x=4-12, y=6-8)
  for x = 4, 12 do
    for y = 6, 8 do
      local interval = x - 8  -- Center on x=8 (-4 to +4 range)
      local importance = theory.get_interval_importance(interval, current_scale)
      local brightness = theory.importance_to_brightness(importance, BRIGHTNESS)
      g:led(x, y, brightness)
    end
  end
end

-- Draw the pattern controls
function GridUI.draw_pattern_lanes()
  -- Draw record button (x=4)
  local rec_brightness = GridUI.motif_recorder.is_recording 
    and BRIGHTNESS.high or BRIGHTNESS.medium
  g:led(4, 1, rec_brightness)
  
  -- Draw play button (x=5)
  local play_brightness = GridUI.is_playing 
    and BRIGHTNESS.high or BRIGHTNESS.medium
  g:led(5, 1, play_brightness)
  
  -- Draw clear button (x=12)
  g:led(12, 1, BRIGHTNESS.medium)
end

-- Refresh the grid display
function GridUI.redraw()
  g:all(0)  -- Clear the grid
  GridUI.draw_keyboard()
  GridUI.draw_pattern_lanes()
  g:refresh()
end

return GridUI
