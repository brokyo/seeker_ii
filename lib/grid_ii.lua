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
local KeyboardRegion = include("lib/grid/regions/keyboard_region")

local musicutil = require('musicutil')

-- Old Component Approach
local ClearMotif = include("lib/components/clear_motif")


-- Keep regions in their own namespace
local regions = {
  velocity = VelocityRegion,
  motif = MotifRegion,
  tuning = TuningRegion,
  keyboard = KeyboardRegion,

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
  return regions.keyboard.contains(x, y)
end

-- Determine which regions should be visible based on current mode/state
local function should_draw_region(region_name)
  local motif_type = params:get("create_motif_type")

  -- Handle mode-specific region visibility
  if motif_type == 3 then -- Trigger mode
    -- Hide velocity and tuning regions since trigger mode uses step states and chord parameters
    return not (region_name == "velocity" or region_name == "tuning")
  end

  -- TODO: Future wholesale UI replacements could be handled here
  -- For example: if current_section == "EURORACK_OUTPUT" then return region_name == "eurorack_grid"

  -- Default: show all regions
  return true
end

function draw_controls()
  -- Draw all regions using local regions table with visibility checks
  if should_draw_region("velocity") then
    regions.velocity.draw(GridUI.layers)
  end
  regions.motif.draw(GridUI.layers)
  if should_draw_region("tuning") then
    regions.tuning.draw(GridUI.layers)
  end

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
  regions.keyboard.draw(GridUI.layers)
end

function draw_motif_events()
    regions.keyboard.draw_motif_events(GridUI.layers)
end


function GridUI.key(x, y, z)
  if is_in_keyboard(x, y) then
    regions.keyboard.handle_key(x, y, z)
  else
    -- Register activity for any non-keyboard interaction
    _seeker.ui_state.register_activity()
    
    -- Handle region interactions
    if regions.lane_config:contains(x, y) then
      regions.lane_config:handle_key(x, y, z)
    elseif regions.motif.contains(x, y) then
      regions.motif.handle_key(x, y, z)
    elseif regions.velocity.contains(x, y) and should_draw_region("velocity") then
      regions.velocity.handle_key(x, y, z)
    elseif regions.tuning.contains(x, y) and should_draw_region("tuning") then
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