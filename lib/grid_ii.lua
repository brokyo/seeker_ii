local GridUI = {}
local g = grid.connect()
local theory = include("lib/theory_utils")
local MotifRecorder = include("lib/motif_recorder")
local GridAnimations = include("lib/grid_animations")
local GridLayers = include("lib/grid_layers")
local GridConstants = include("lib/grid_constants")
local VelocityRegion = include("lib/grid/regions/velocity_region")
local ConfigRegion = include("lib/grid/regions/config_region")
local LaneRegion = include("lib/grid/regions/lane_region")
local StageRegion = include("lib/grid/regions/stage_region")
local MotifRegion = include("lib/grid/regions/motif_region")
local OverdubRegion = include("lib/grid/regions/overdub_region")
local RecRegion = include("lib/grid/regions/rec_region")
local GenerateRegion = include("lib/grid/regions/generate_region")
local OctaveRegion = include("lib/grid/regions/octave_region")

-- Keep regions in their own namespace
local regions = {
  velocity = VelocityRegion,
  config = ConfigRegion,
  lane = LaneRegion,
  stage = StageRegion,
  motif = MotifRegion,
  overdub = OverdubRegion,
  rec = RecRegion,
  generate = GenerateRegion,
  octave = OctaveRegion
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
  regions.config.draw(GridUI.layers)
  regions.lane.draw(GridUI.layers)
  regions.stage.draw(GridUI.layers)
  regions.velocity.draw(GridUI.layers)
  regions.motif.draw(GridUI.layers)
  regions.overdub.draw(GridUI.layers)
  regions.rec.draw(GridUI.layers)
  regions.generate.draw(GridUI.layers)
  regions.octave.draw(GridUI.layers)
end

function draw_keyboard()
  local root = params:get("root_note") - 1  -- Convert to 0-based
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  
  for x = 0, Layout.keyboard.width - 1 do
    for y = 0, Layout.keyboard.height - 1 do
      local grid_x = Layout.keyboard.upper_left_x + x
      local grid_y = Layout.keyboard.upper_left_y + y
      local note = theory.grid_to_note(grid_x, grid_y, octave)
      
      -- Check if this note is a root note (same pitch class as root)
      local brightness = GridConstants.BRIGHTNESS.LOW
      if note and note % 12 == root then
        brightness = GridConstants.BRIGHTNESS.MEDIUM
      end
      
      GridLayers.set(GridUI.layers.ui, grid_x, grid_y, brightness)
    end
  end 
end

function draw_motif_events()
    -- Draw events for all lanes, with focused lane brighter
    for lane_id, lane in pairs(_seeker.lanes) do
        -- Get active positions from lane
        local active_positions = lane:get_active_positions()
        
        -- Determine brightness based on whether this is the focused lane
        local brightness = (lane_id == _seeker.ui_state.get_focused_lane()) and 
            GridConstants.BRIGHTNESS.UI.ACTIVE or 
            GridConstants.BRIGHTNESS.UI.UNFOCUSED

        -- Illuminate active positions
        for _, pos in ipairs(active_positions) do
            if is_in_keyboard(pos.x, pos.y) then
                GridLayers.set(GridUI.layers.response, pos.x, pos.y, brightness)
            end
        end
    end
end

function note_on(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local keyboard_octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave")
  
  local event = {
    x = x,
    y = y,
    note = theory.grid_to_note(x, y, keyboard_octave),
    velocity = regions.velocity.get_current_velocity(),
    is_playback = false  -- Explicitly mark as live input
  }

  if _seeker.motif_recorder.is_recording then  
    _seeker.motif_recorder:on_note_on(event)
  end

  focused_lane:on_note_on(event)
end

function note_off(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local keyboard_octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave")
  
  local event = {
    x = x,
    y = y,
    note = theory.grid_to_note(x, y, keyboard_octave),
    velocity = 0,
    is_playback = false  -- Explicitly mark as live input
  }
  
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
    if regions.lane.contains(x, y) then
      regions.lane.handle_key(x, y, z)
    elseif regions.stage.contains(x, y) then
      regions.stage.handle_key(x, y, z)
    elseif regions.rec.contains(x, y) then
      regions.rec.handle_key(x, y, z)
    elseif regions.generate.contains(x, y) then
      regions.generate.handle_key(x, y, z)
    elseif regions.overdub.contains(x, y) then
      regions.overdub.handle_key(x, y, z)
    elseif regions.motif.contains(x, y) then
      regions.motif.handle_key(x, y, z)
    elseif regions.config.contains(x, y) then
      regions.config.handle_key(x, y, z)
    elseif regions.velocity.contains(x, y) then
      regions.velocity.handle_key(x, y, z)
    elseif regions.octave.contains(x, y) then
      regions.octave.handle_key(x, y, z)
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