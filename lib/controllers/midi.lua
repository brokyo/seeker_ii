-- midi_input.lua
-- Handles MIDI input for playing and recording motifs

local MidiInput = {}
local theory = include("lib/motif_core/theory")
local KeyboardRegion = include("lib/grid/regions/keyboard_region")
local musicutil = require("musicutil")

-- Main MIDI device
MidiInput.device = nil
-- Flag to indicate if MIDI input is enabled
MidiInput.enabled = true
-- Store active notes for visualization
MidiInput.active_notes = {}

-- Initialize MIDI input
function MidiInput.init()
  print("⌇ MIDI Input initializing")
  
  -- Connect to the default MIDI device (port 1)
  MidiInput.device = midi.connect(1)
  
  -- Set up event handler for incoming MIDI data
  MidiInput.device.event = function(data)
    MidiInput.process_midi_event(data)
  end
  
  print("⌇ MIDI device connected: " .. (MidiInput.device.name or "unknown"))
  
  return MidiInput
end

-- Process incoming MIDI events
function MidiInput.process_midi_event(data)
  if not MidiInput.enabled then
    return
  end
  
  local msg = midi.to_msg(data)
  
  -- Handle note on messages
  if msg.type == "note_on" then
    -- Check for record/overdub toggle notes first
    local record_note = params:get("record_midi_note")
    local overdub_note = params:get("overdub_midi_note")
    
    if msg.note == record_note and record_note >= 0 then
      -- Toggle recording
      if _seeker.motif_recorder.is_recording then
        -- Stop recording
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local motif = _seeker.motif_recorder:stop_recording()
        local lane = _seeker.lanes[focused_lane]
        lane:set_motif(motif)
        lane:play()  -- Start playing immediately after recording
      else
        -- Start new recording
        _seeker.motif_recorder:set_recording_mode(1)
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[focused_lane]
        lane:clear()
        _seeker.motif_recorder:start_recording(nil)
      end
      _seeker.screen_ui.set_needs_redraw()
      return
    elseif msg.note == overdub_note and overdub_note >= 0 then
      -- Toggle overdub
      if _seeker.motif_recorder.is_recording then
        -- Stop recording
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local motif = _seeker.motif_recorder:stop_recording()
        _seeker.lanes[focused_lane]:set_motif(motif)
      else
        -- Start overdub if we have a motif
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local existing_motif = _seeker.lanes[focused_lane].motif
        if #existing_motif.events == 0 then
          print("⚠ Cannot overdub: No existing motif")
        else
          _seeker.motif_recorder:set_recording_mode(2)
          _seeker.motif_recorder:start_recording(existing_motif)
        end
      end
      _seeker.screen_ui.set_needs_redraw()
      return
    end
    
    -- Note velocity of 0 is treated as note off in MIDI
    if msg.vel == 0 then
      MidiInput.handle_note_off(msg)
    else
      MidiInput.handle_note_on(msg)
    end
  -- Handle note off messages
  elseif msg.type == "note_off" then
    MidiInput.handle_note_off(msg)
  end
end

-- Create a standardized note event
function MidiInput.create_note_event(note, velocity, grid_positions)
  -- If we got a single position instead of an array, wrap it
  if grid_positions and not grid_positions[1] then
    grid_positions = {grid_positions}
  end
  
  -- Create base event
  local event = {
    note = note,
    velocity = velocity or 0,
    positions = grid_positions or {},  -- Store all positions
    is_playback = false,
    source = "midi"
  }
  
  -- For backward compatibility, include x,y of first position if available
  if grid_positions and grid_positions[1] then
    event.x = grid_positions[1].x
    event.y = grid_positions[1].y
  end
  
  return event
end

-- Handle MIDI note on
function MidiInput.handle_note_on(msg)
  local note = msg.note
  local velocity = msg.vel
  
  -- Apply scale snapping if enabled
  if params:get("snap_midi_to_scale") == 1 then
    local scale_notes = theory.get_scale()
    note = musicutil.snap_note_to_array(note, scale_notes)
  end
  
  -- Map MIDI note to all grid positions
  local grid_positions = KeyboardRegion.note_to_positions(note)
    
  -- Create standardized note event
  local event = MidiInput.create_note_event(note, velocity, grid_positions)
  
  -- Store active note positions for visualization
  if grid_positions then
    MidiInput.active_notes[note] = grid_positions
  end
  
  -- Pass event to focused lane
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  focused_lane:on_note_on(event)
  
  -- Pass to motif recorder if recording
  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_on(event)
  end
end

-- Handle MIDI note off
function MidiInput.handle_note_off(msg)
  local note = msg.note
  
  -- Apply scale snapping if enabled
  if params:get("snap_midi_to_scale") == 1 then
    local scale_notes = theory.get_scale()
    note = musicutil.snap_note_to_array(note, scale_notes)
  end
  
  -- Get stored grid position for this note
  local grid_positions = MidiInput.active_notes[note]
  
  -- If we don't have a stored position, try to calculate it
  if not grid_positions then
    grid_positions = KeyboardRegion.note_to_positions(note)
  end
  
  -- Create standardized note event
  local event = MidiInput.create_note_event(note, 0, grid_positions)
  
  -- Remove from active notes if it was stored
  MidiInput.active_notes[note] = nil
  
  -- Pass event to focused lane
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  focused_lane:on_note_off(event)
  
  -- Pass to motif recorder if recording
  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_off(event)
  end
end

-- Get active positions for grid visualization
function MidiInput.get_active_positions()
  local positions = {}
  for note, pos_array in pairs(MidiInput.active_notes) do
    for _, pos in ipairs(pos_array) do
      table.insert(positions, {x = pos.x, y = pos.y})
    end
  end
  return positions
end

-- Set MIDI device to specified port
function MidiInput.set_device(port)
  if MidiInput.device then
    -- Disconnect current device
    MidiInput.device.event = nil
  end
  
  -- Connect to new device
  MidiInput.device = midi.connect(port)
  MidiInput.device.event = function(data)
    MidiInput.process_midi_event(data)
  end
  
  print("⌇ MIDI device connected to port " .. port .. ": " .. (MidiInput.device.name or "unknown"))
end

-- Enable/disable MIDI input
function MidiInput.set_enabled(enabled)
  MidiInput.enabled = enabled
  if enabled then
    print("⌇ MIDI input enabled")
  else
    print("⌇ MIDI input disabled")
    -- Clear any active notes when disabling MIDI
    MidiInput.active_notes = {}
  end
end

return MidiInput 