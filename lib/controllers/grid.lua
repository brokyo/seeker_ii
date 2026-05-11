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

-- Resolve the grid layout path for the current mode/sub-mode
-- Parent modes with sub_modes have no layout of their own (uses sub-mode layout)
local function get_layout_path()
  local mode_id = _seeker.current_mode
  if not mode_id then return nil end

  local config = GridModeRegistry.get_mode(mode_id)
  if not config then return nil end

  if config.sub_modes then
    local sub_mode_id = _seeker.current_sub_mode
    if sub_mode_id and config.sub_modes[sub_mode_id] then
      return config.sub_modes[sub_mode_id].path
    end
    return nil
  end

  return config.path
end

-- Get the active grid mode based on current_mode (lazy-loaded from registry)
local function get_active_mode()
  local path = get_layout_path()
  if not path then return nil end

  -- Lazy-load mode implementation by path
  if not mode_impls[path] then
    mode_impls[path] = include(path)
  end

  return mode_impls[path]
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
            -- Tap: navigate to dedicated output section, re-tap cycles arc page
            local section_map = {
              crow = "CROW_OUTPUT",
              txo_tr = "TXO_TR_OUTPUT",
              txo_cv = "TXO_CV_OUTPUT",
            }
            local target = section_map[source]
            if target then
              -- Check if already focused BEFORE updating selection
              local sel = _seeker.eurorack.cv_monitor and _seeker.eurorack.cv_monitor.get_selected()
              local is_focused = sel and sel.source == source and sel.num == output_num
                  and current_section == target

              -- Update cv_monitor and param selection
              if _seeker.eurorack.cv_monitor then
                _seeker.eurorack.cv_monitor.select_output(source, output_num)
              end

              local component_map = {
                crow = _seeker.eurorack.crow_output,
                txo_tr = _seeker.eurorack.txo_tr_output,
                txo_cv = _seeker.eurorack.txo_cv_output,
              }
              local component = component_map[source]

              if is_focused then
                -- Re-tap: cycle arc page within the dedicated section
                if component and component.screen and component.screen.cycle_page then
                  component.screen:cycle_page()
                end
              else
                -- Switch section (triggers enter if section changes)
                _seeker.ui_state.set_current_section(target)
                -- If section didn't change, enter() didn't fire — rebuild manually
                if current_section == target and component and component.screen then
                  component.screen:enter()
                end
              end
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

  -- Delegate to active mode (nil when parent config has no grid layout)
  local mode = get_active_mode()
  if mode then
    mode.handle_full_page_key(x, y, z)
  end
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

	-- Delegate to active mode for mode-specific content (nil when parent config has no grid layout)
	local mode = get_active_mode()
	if mode then
		mode.draw_full_page(GridUI.layers)
	end

	-- Apply composite to grid
	GridLayers.apply_to_grid(g, GridUI.layers)
end	

return GridUI