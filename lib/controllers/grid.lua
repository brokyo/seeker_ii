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
  -- Block grid input during fileselect and show hint overlay
  if _seeker.sampler and _seeker.sampler.file_select_active then
    if _seeker.modal then
      _seeker.modal.draw_status_immediate({ body = "FILE SELECT", hint = "use norns e2/e3/k3" })
      screen.update()
    end
    return
  end

  -- Eurorack output selection: cols 13-16, rows 5 (crow), 6 (TXO TR), 7 (TXO CV)
  -- Works from any eurorack section. Tap = navigate, hold = toggle on/off.
  local eurorack_sections = {
    EURORACK_CONFIG = true, CROW_OUTPUT = true,
    TXO_TR_OUTPUT = true, TXO_CV_OUTPUT = true,
  }
  local current_section = _seeker.ui_state.get_current_section()
  if eurorack_sections[current_section] then
    if x >= 13 and x <= 16 and (y == 5 or y == 6 or y == 7) then
      local output_num = x - 12
      local source
      if y == 5 then source = "crow"
      elseif y == 6 then source = "txo_tr"
      elseif y == 7 then source = "txo_cv"
      end

      if z == 1 then
        -- Start hold tracking for power-up animation
        if _seeker.eurorack then
          _seeker.eurorack.output_hold = {
            x = x, y = y, source = source, num = output_num,
            start_time = util.time()
          }
        end
      else
        -- Release: short press navigates, long press toggles on/off
        local hold = _seeker.eurorack and _seeker.eurorack.output_hold
        if hold and hold.x == x and hold.y == y then
          local duration = util.time() - hold.start_time
          _seeker.eurorack.output_hold = nil

          if duration >= 0.5 then
            -- Hold: toggle output active state via clock_interval
            local prefix = source .. "_" .. output_num
            local interval_id = prefix .. "_clock_interval"
            if params.lookup[interval_id] then
              local turning_on = params:string(interval_id) == "Off"
              if turning_on then
                params:set(interval_id, 5)  -- Default to "4" beats
              else
                params:set(interval_id, 1)  -- "Off"
              end
              -- Auto-select newly activated output in cv_monitor
              if turning_on and _seeker.eurorack.cv_monitor then
                _seeker.eurorack.cv_monitor.select_output(source, output_num)
              end
            end
          else
            -- Tap: select output and navigate to cv_monitor
            if _seeker.eurorack.cv_monitor then
              _seeker.eurorack.cv_monitor.select_output(source, output_num)
            end
            if current_section ~= "EURORACK_CONFIG" then
              _seeker.ui_state.set_current_section("EURORACK_CONFIG")
            end
          end
        end
      end
      _seeker.screen_ui.set_needs_redraw()
      return
    end
  end

  -- Handle active modals
  if _seeker.modal and _seeker.modal.is_active() then
    local modal_type = _seeker.modal.get_type()
    -- Status and Recording modals block all grid input (operations in progress)
    if modal_type == _seeker.modal.TYPE.STATUS or modal_type == _seeker.modal.TYPE.RECORDING then
      return
    end
    -- Warning modals dismiss on grid key press (not release), then allow passthrough
    if modal_type == _seeker.modal.TYPE.WARNING and z == 1 then
      _seeker.modal.dismiss()
      _seeker.screen_ui.set_needs_redraw()
      -- Continue to process the grid input below
    end
    -- Other modals (description, adsr, warning-after-dismiss) allow grid input to reach mode handlers
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