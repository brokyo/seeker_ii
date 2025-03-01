-- midi_input.lua
-- Handles MIDI input for playing and recording motifs

local MidiInput = {}
local theory = include("lib/theory_utils")

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

-- Handle MIDI note on
function MidiInput.handle_note_on(msg)
  local note = msg.note
  local velocity = msg.vel
  
  -- Map MIDI note to grid position using theory utils
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local keyboard_octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  local grid_pos = theory.note_to_grid(note, keyboard_octave)
    
  -- Create event in the format expected by the motif recorder
  local event = {
    note = note,
    velocity = velocity,
    x = grid_pos and grid_pos.x or nil,
    y = grid_pos and grid_pos.y or nil,
    is_playback = false
  }
  
  -- Store active note for visualization (only if grid position is available)
  if grid_pos then
    MidiInput.active_notes[note] = grid_pos
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
  
  -- Get stored grid position for this note
  local grid_pos = MidiInput.active_notes[note]
  
  -- If we don't have a stored position, try to calculate it
  if not grid_pos then
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local keyboard_octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
    grid_pos = theory.note_to_grid(note, keyboard_octave)
  end
  
  -- Create event in the format expected by the motif recorder
  local event = {
    note = note,
    velocity = 0,
    x = grid_pos and grid_pos.x or nil,
    y = grid_pos and grid_pos.y or nil,
    is_playback = false
  }
  
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
  for note, pos in pairs(MidiInput.active_notes) do
    table.insert(positions, {x = pos.x, y = pos.y})
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