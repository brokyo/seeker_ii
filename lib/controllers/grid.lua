local GridUI = {}
local g = grid.connect()
local GridAnimations = include("lib/grid/animations")
local GridLayers = include("lib/grid/layers")

-- Grid modes
local GridModeRegistry = include("lib/grid/mode_registry")
local ModeSwitcher = include("lib/grid/mode_switcher")

-- Lazy-loaded mode implementations
local mode_impls = {}

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

-- Get the active grid mode based on current_mode (lazy-loaded from registry)
local function get_active_mode()
  local mode_id = _seeker.current_mode
  if not mode_id then return nil end

  -- Lazy-load mode implementation if not already loaded
  if not mode_impls[mode_id] then
    local config = GridModeRegistry.get_mode(mode_id)
    if config then
      mode_impls[mode_id] = include(config.path)
    end
  end

  return mode_impls[mode_id]
end


function GridUI.key(x, y, z)
  -- Close active modal when user presses grid
  if _seeker.modal and _seeker.modal.is_active() then
    _seeker.modal.dismiss()
  end

  -- Skip mode switcher in dual keyboard mode (fullscreen takes over)
  local dual_state = _seeker.dual_keyboard_state
  local dual_active = dual_state and dual_state.is_active

  -- Handle mode switcher first (global controls)
  if not dual_active and ModeSwitcher.handle_key(x, y, z) then
    return
  end

  -- Delegate to active mode
  local mode = get_active_mode()
  mode.handle_full_page_key(x, y, z)
end

function GridUI.redraw()
	-- Clear all layers
	GridLayers.clear_layer(GridUI.layers.background)
	GridLayers.clear_layer(GridUI.layers.ui)
	GridLayers.clear_layer(GridUI.layers.response)

	-- Update background animations
	GridAnimations.update_background(GridUI.layers.background)

	-- Draw mode switcher buttons (hidden in dual keyboard fullscreen mode)
	local dual_state = _seeker.dual_keyboard_state
	local dual_active = dual_state and dual_state.is_active
	if not dual_active then
		ModeSwitcher.draw(GridUI.layers)
	end

	-- Delegate to active mode for mode-specific content
	local mode = get_active_mode()
	mode.draw_full_page(GridUI.layers)

	-- Apply composite to grid
	GridLayers.apply_to_grid(g, GridUI.layers)
end	

return GridUI