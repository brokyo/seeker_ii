local GridUI = {}
local g = grid.connect()
local theory = include("lib/theory_utils")
local MotifRecorder = include("lib/motif_recorder")
local GridAnimations = include("lib/grid_animations")
local GridLayers = include("lib/grid_layers")
local GridConstants = include("lib/grid_constants")
local VelocityRegion = include("lib/grid/regions/velocity_region")
local MotifRegion = include("lib/grid/regions/motif_region")
local TuningRegion = include("lib/grid/regions/tuning_region")

local musicutil = require('musicutil')

-- Old Component Approach
local ClearMotif = include("lib/components/clear_motif")


-- Keep regions in their own namespace
local regions = {
  velocity = VelocityRegion,
  motif = MotifRegion,
  tuning = TuningRegion,

  -- Old Components
  clear_motif = ClearMotif.init().grid,

  -- New Component Approach
  config = nil,
  create_motif = nil,
  wtape = nil,
  stage_config = nil,
  eurorack_output = nil,
  osc_config = nil,
  lane_config = nil
}

GridUI.layers = nil

local Layout = {
  keyboard = {	
    upper_left_x = 6,
    upper_left_y = 2,
    width = 6,
    height = 6
  },
  fps = 30
}

function GridUI.init()
  if g.device then    
    print("⌇ Grid connected")
    g.key = function(x, y, z)
      GridUI.key(x, y, z)
    end
    
    g.remove = function()
      print("◈ Grid Disconnected") 
    end
  else
    print("⚠ Grid Connect failed")
  end

  -- Initialize grid animation system
  GridUI.layers = GridLayers.init()
  GridAnimations.init(g)

  -- Initialize components
  regions.config = _seeker.config.grid
  regions.create_motif = _seeker.create_motif.grid
  regions.wtape = _seeker.w_tape.grid
  regions.stage_config = _seeker.stage_config.grid
  regions.eurorack_output = _seeker.eurorack_output.grid
  regions.osc_config = _seeker.osc_config.grid
  regions.lane_config = _seeker.lane_config.grid

  return GridUI
end

function GridUI.start()
  -- Start the redraw clock
  clock.run(grid_redraw_clock)
end

function grid_redraw_clock()
  while true do
    clock.sync(1/Layout.fps)
    GridUI.redraw()
  end
end

function is_in_keyboard(x, y)
  return x >= Layout.keyboard.upper_left_x and x < Layout.keyboard.upper_left_x + Layout.keyboard.width and
         y >= Layout.keyboard.upper_left_y and y < Layout.keyboard.upper_left_y + Layout.keyboard.height
end

function draw_controls()
  -- Draw all regions using local regions table
  regions.velocity.draw(GridUI.layers)
  regions.motif.draw(GridUI.layers)
  regions.tuning.draw(GridUI.layers)

  -- Old Components
  regions.clear_motif:draw(GridUI.layers)
  
  -- New Component Approach
  regions.config:draw(GridUI.layers)
  regions.create_motif:draw(GridUI.layers)
  regions.wtape:draw(GridUI.layers)
  regions.stage_config:draw(GridUI.layers)
  regions.eurorack_output:draw(GridUI.layers)
  regions.osc_config:draw(GridUI.layers)
  regions.lane_config:draw(GridUI.layers)

end

function draw_keyboard()
  local root = params:get("root_note")  -- Keep as 1-based for consistency with theory.grid_to_note
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  
  for x = 0, Layout.keyboard.width - 1 do
    for y = 0, Layout.keyboard.height - 1 do
      local grid_x = Layout.keyboard.upper_left_x + x
      local grid_y = Layout.keyboard.upper_left_y + y
      local note = theory.grid_to_note(grid_x, grid_y, octave)
      
      -- Check if this note is a root note by comparing with the actual root pitch class
      local brightness = GridConstants.BRIGHTNESS.LOW
      if note then
        -- Check if this note has the same pitch class as the root note
        local root_pitch_class = (root - 1) % 12  -- Convert to 0-based pitch class
        if note % 12 == root_pitch_class then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        end
      end
      
      GridLayers.set(GridUI.layers.ui, grid_x, grid_y, brightness)
    end
  end 
end

function draw_motif_events()
    -- Only draw events for focused lane
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local focused_lane = _seeker.lanes[focused_lane_id]
    
    -- Get active positions from focused lane
    local active_positions = focused_lane:get_active_positions()
    
    -- Illuminate active positions at full brightness
    for _, pos in ipairs(active_positions) do
        if is_in_keyboard(pos.x, pos.y) then
            GridLayers.set(GridUI.layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.UI.ACTIVE)
        end
    end
    
    -- Draw MIDI input notes if available
    if _seeker.midi_input then
        local midi_positions = _seeker.midi_input.get_active_positions()
        for _, pos in ipairs(midi_positions) do
            if is_in_keyboard(pos.x, pos.y) then
                -- Use a different brightness for MIDI notes to distinguish them
                GridLayers.set(GridUI.layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.FULL)
            end
        end
    end
end

-- Create a standardized note event
function create_note_event(x, y, note, velocity)
  -- Get all positions for this note
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local keyboard_octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  local all_positions = theory.note_to_grid(note, keyboard_octave)
  
  return {
    note = note,
    velocity = velocity or 0,
    x = x,  -- Keep original x,y for reference
    y = y,
    positions = all_positions or {{x = x, y = y}},  -- Use all positions or fallback to original
    is_playback = false,
    source = "grid"
  }
end

function note_on(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local keyboard_octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave")
  local note = theory.grid_to_note(x, y, keyboard_octave)
  
  -- Print the note being played for debugging
  if note then
    local note_name = musicutil.note_num_to_name(note, true)
    -- Extract octave from the note name itself (more reliable)
    local actual_octave = tonumber(string.match(note_name, "%d+"))
    print(string.format("Note played: %s (MIDI %d) at grid position (%d,%d), Octave param: %d, Actual octave: %d", 
          note_name, note, x, y, keyboard_octave, actual_octave))
  end
  
  -- Create standardized note event with all positions
  local event = create_note_event(
    x, 
    y, 
    note,
    regions.velocity.get_current_velocity()
  )

  if _seeker.motif_recorder.is_recording then  
    _seeker.motif_recorder:on_note_on(event)
  end

  focused_lane:on_note_on(event)
end

function note_off(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local keyboard_octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave")
  local note = theory.grid_to_note(x, y, keyboard_octave)
  
  -- Create standardized note event with all positions
  local event = create_note_event(x, y, note, 0)
  
  if _seeker.motif_recorder.is_recording then  
    _seeker.motif_recorder:on_note_off(event)
  end
  
  focused_lane:on_note_off(event)
end

function GridUI.key(x, y, z)
  if is_in_keyboard(x, y) then
    if z == 1 then
      note_on(x, y)
    else
      note_off(x, y)
    end
  else
    -- Register activity for any non-keyboard interaction
    _seeker.ui_state.register_activity()
    
    -- Handle region interactions
    if regions.lane_config:contains(x, y) then
      regions.lane_config:handle_key(x, y, z)
    elseif regions.motif.contains(x, y) then
      regions.motif.handle_key(x, y, z)
    elseif regions.velocity.contains(x, y) then
      regions.velocity.handle_key(x, y, z)
    elseif regions.tuning.contains(x, y) then
      regions.tuning.handle_key(x, y, z)
    -- Components
  elseif regions.clear_motif:contains(x, y) then
    regions.clear_motif:handle_key(x, y, z)
  elseif regions.config:contains(x, y) then
    regions.config:handle_key(x, y, z)
  elseif regions.create_motif:contains(x, y) then
    regions.create_motif:handle_key(x, y, z)
    elseif regions.wtape:contains(x, y) then  
      regions.wtape:handle_key(x, y, z)
    elseif regions.stage_config:contains(x, y) then
      regions.stage_config:handle_key(x, y, z)
    elseif regions.eurorack_output:contains(x, y) then
      regions.eurorack_output:handle_key(x, y, z)
    elseif regions.osc_config:contains(x, y) then
      regions.osc_config:handle_key(x, y, z)
    elseif regions.lane_config:contains(x, y) then
      regions.lane_config:handle_key(x, y, z)
    end
  end
end

function GridUI.redraw()
	-- Clear all layers
	GridLayers.clear_layer(GridUI.layers.background)
	GridLayers.clear_layer(GridUI.layers.ui)
	GridLayers.clear_layer(GridUI.layers.response)
	
	-- Update animations
	GridAnimations.update_background(GridUI.layers.background)
	
	-- Draw UI elements
	draw_controls()
	draw_keyboard()
	
	-- Draw response elements
	draw_motif_events()
	-- Get trails from focused lane
	local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
	GridAnimations.update_trails(GridUI.layers.response, focused_lane.trails)
	
	-- Draw keyboard outline when recording or counting in
	GridAnimations.update_keyboard_outline(GridUI.layers.response, Layout, _seeker.motif_recorder)
	
	-- Apply composite to grid
	GridLayers.apply_to_grid(g, GridUI.layers)
end	

return GridUI