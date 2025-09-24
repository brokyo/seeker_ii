-- arpeggio_keyboard.lua
-- Linear keyboard optimized for sequential note entry in arpeggio mode
-- Uses a more traditional linear layout for easier melodic playing

local theory = include("lib/theory_utils")
local musicutil = require('musicutil')
local GridConstants = include("lib/grid_constants")
local GridLayers = include("lib/grid_layers")

local ArpeggioKeyboard = {}

-- Layout definition - using middle 4 rows for linear scale layout
ArpeggioKeyboard.layout = {
  upper_left_x = 6,
  upper_left_y = 3,
  width = 6,
  height = 4
}

-- Check if coordinates are within arpeggio keyboard area
function ArpeggioKeyboard.contains(x, y)
  return x >= ArpeggioKeyboard.layout.upper_left_x and 
         x < ArpeggioKeyboard.layout.upper_left_x + ArpeggioKeyboard.layout.width and
         y >= ArpeggioKeyboard.layout.upper_left_y and 
         y < ArpeggioKeyboard.layout.upper_left_y + ArpeggioKeyboard.layout.height
end

-- Convert grid coordinates to MIDI note using linear scale layout
function ArpeggioKeyboard.grid_to_note(x, y)
  local root = params:get("root_note")
  local scale_type = params:get("scale_type")
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  local grid_offset = params:get("lane_" .. focused_lane .. "_grid_offset")
  
  -- Linear layout: each key is one scale step
  local rel_x = x - ArpeggioKeyboard.layout.upper_left_x
  local rel_y = y - ArpeggioKeyboard.layout.upper_left_y
  local scale_step = rel_y * ArpeggioKeyboard.layout.width + rel_x + grid_offset
  
  -- Generate scale
  local root_midi = (root - 1)
  local scale = musicutil.generate_scale(root_midi, musicutil.SCALES[scale_type].name, 10)
  
  -- Calculate base note for octave
  local base_root_note = (octave + 1) * 12 + (root - 1)
  local root_index = nil
  for i, note in ipairs(scale) do
    if note >= base_root_note then
      root_index = i
      break
    end
  end
  
  if root_index and scale[root_index + scale_step] then
    return scale[root_index + scale_step]
  end
  
  return nil
end

-- Convert MIDI note back to grid positions (for multi-position illumination)
function ArpeggioKeyboard.note_to_grid(note, octave)
  local root = params:get("root_note")
  local scale_type = params:get("scale_type")
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local grid_offset = params:get("lane_" .. focused_lane .. "_grid_offset")
  
  -- Generate scale
  local root_midi = (root - 1)
  local scale = musicutil.generate_scale(root_midi, musicutil.SCALES[scale_type].name, 10)
  
  -- Find this note in the scale
  local positions = {}
  for i, scale_note in ipairs(scale) do
    if scale_note == note then
      local scale_step = i - 1 - grid_offset
      if scale_step >= 0 and scale_step < (ArpeggioKeyboard.layout.width * ArpeggioKeyboard.layout.height) then
        local rel_y = math.floor(scale_step / ArpeggioKeyboard.layout.width)
        local rel_x = scale_step % ArpeggioKeyboard.layout.width
        local grid_x = ArpeggioKeyboard.layout.upper_left_x + rel_x
        local grid_y = ArpeggioKeyboard.layout.upper_left_y + rel_y
        
        if ArpeggioKeyboard.contains(grid_x, grid_y) then
          table.insert(positions, {x = grid_x, y = grid_y})
        end
      end
    end
  end
  
  return positions
end

-- Create a standardized note event
function ArpeggioKeyboard.create_note_event(x, y, note, velocity)
  local all_positions = ArpeggioKeyboard.note_to_grid(note, params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave"))
  
  return {
    note = note,
    velocity = velocity or 0,
    x = x,
    y = y,
    positions = all_positions or {{x = x, y = y}},
    is_playback = false,
    source = "grid"
  }
end

-- Handle note on event
function ArpeggioKeyboard.note_on(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local note = ArpeggioKeyboard.grid_to_note(x, y)
  
  if note then
    local note_name = musicutil.note_num_to_name(note, true)
    print(string.format("Arpeggio note: %s (MIDI %d) at (%d,%d)", note_name, note, x, y))
    
    -- Get velocity from velocity region
    local velocity_region = include("lib/grid/regions/velocity_region")
    local event = ArpeggioKeyboard.create_note_event(x, y, note, velocity_region.get_current_velocity())

    if _seeker.motif_recorder.is_recording then  
      _seeker.motif_recorder:on_note_on(event)
    end

    focused_lane:on_note_on(event)
  end
end

-- Handle note off event
function ArpeggioKeyboard.note_off(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local note = ArpeggioKeyboard.grid_to_note(x, y)
  
  if note then
    local event = ArpeggioKeyboard.create_note_event(x, y, note, 0)
    
    if _seeker.motif_recorder.is_recording then  
      _seeker.motif_recorder:on_note_off(event)
    end
    
    focused_lane:on_note_off(event)
  end
end

-- Handle key presses
function ArpeggioKeyboard.handle_key(x, y, z)
  if z == 1 then
    ArpeggioKeyboard.note_on(x, y)
  else
    ArpeggioKeyboard.note_off(x, y)
  end
end

-- Draw the linear scale keyboard layout
function ArpeggioKeyboard.draw(layers)
  local root = params:get("root_note")
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  
  for x = 0, ArpeggioKeyboard.layout.width - 1 do
    for y = 0, ArpeggioKeyboard.layout.height - 1 do
      local grid_x = ArpeggioKeyboard.layout.upper_left_x + x
      local grid_y = ArpeggioKeyboard.layout.upper_left_y + y
      local note = ArpeggioKeyboard.grid_to_note(grid_x, grid_y)
      
      local brightness = GridConstants.BRIGHTNESS.LOW
      if note then
        -- Highlight root notes
        local root_pitch_class = (root - 1) % 12
        if note % 12 == root_pitch_class then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        end
      end
      
      GridLayers.set(layers.ui, grid_x, grid_y, brightness)
    end
  end
end

-- Draw motif events for active positions
function ArpeggioKeyboard.draw_motif_events(layers)
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local focused_lane = _seeker.lanes[focused_lane_id]
  
  -- Get active positions from focused lane
  local active_positions = focused_lane:get_active_positions()
  
  -- Illuminate active positions at full brightness
  for _, pos in ipairs(active_positions) do
    if ArpeggioKeyboard.contains(pos.x, pos.y) then
      GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.UI.ACTIVE)
    end
  end
  
  -- Draw MIDI input notes if available
  if _seeker.midi_input then
    local midi_positions = _seeker.midi_input.get_active_positions()
    for _, pos in ipairs(midi_positions) do
      if ArpeggioKeyboard.contains(pos.x, pos.y) then
        GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.FULL)
      end
    end
  end
end

return ArpeggioKeyboard