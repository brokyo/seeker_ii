local GridUI = {}
local g = grid.connect()
local theory = include("lib/theory_utils")
local MotifRecorder = include("lib/motif_recorder")
local GridAnimations = include("lib/grid_animations")
local GridLayers = include("lib/grid_layers")
local GridConstants = include("lib/grid_constants")

local motif_recorder = MotifRecorder.new({})
local layers = nil

local Layout = {
  keyboard = {	
    upper_left_x = 6,
    upper_left_y = 2,
    width = 6,
    height = 6
  },
  motif_button = {x = 1, y = 6},
  rec_button = {x = 3, y = 6},
  play_button = {x = 4, y = 6},
  tuning_button = {x = 1, y = 8},
  lane_select = {x = 1, y = 7, width = 4},
  stage_select = {x = 13, y = 7, width = 4},
  fps = 30,
  transform_chain = {x = 13, y = 6, width = 4},
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
  
  layers = GridLayers.init()
  GridAnimations.init(g)
  clock.run(grid_redraw_clock)

  return GridUI
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

function is_rec_button(x, y)
  return x == Layout.rec_button.x and y == Layout.rec_button.y
end

function is_play_button(x, y)
  return x == Layout.play_button.x and y == Layout.play_button.y
end

function is_motif_button(x, y)
  return x == Layout.motif_button.x and y == Layout.motif_button.y
end

function is_tuning_button(x, y)
  return x == Layout.tuning_button.x and y == Layout.tuning_button.y
end

function is_in_lane_select(x, y)
  return x >= Layout.lane_select.x and 
         x < Layout.lane_select.x + Layout.lane_select.width and 
         y == Layout.lane_select.y
end

function is_in_stage_select(x, y)
  return x >= Layout.stage_select.x and 
         x < Layout.stage_select.x + Layout.stage_select.width and 
         y == Layout.stage_select.y
end

function is_in_transform_chain(x, y)
  return x >= Layout.transform_chain.x and 
         x < Layout.transform_chain.x + Layout.transform_chain.width and 
         y == Layout.transform_chain.y
end

function draw_controls()
  -- Rec button
  local rec_brightness
  if motif_recorder.is_recording then
    -- Pulsing bright when recording
    rec_brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.CONTROLS.REC_ACTIVE - 3)
  elseif _seeker.ui_state.get_current_section() == "RECORDING" then
    -- Medium brightness when in recording section but not recording
    rec_brightness = GridConstants.BRIGHTNESS.CONTROLS.REC_READY
  else
    -- Dim when inactive
    rec_brightness = GridConstants.BRIGHTNESS.CONTROLS.REC_INACTIVE
  end
  GridLayers.set(layers.ui, Layout.rec_button.x, Layout.rec_button.y, rec_brightness)
  
  -- Play button
  local play_brightness = _seeker.lanes[_seeker.ui_state.get_focused_lane()].playing and 
    GridConstants.BRIGHTNESS.CONTROLS.PLAY_ACTIVE or 
    GridConstants.BRIGHTNESS.CONTROLS.PLAY_INACTIVE
  GridLayers.set(layers.ui, Layout.play_button.x, Layout.play_button.y, play_brightness)
  
  -- Motif button
  local motif_brightness = (_seeker.ui_state.get_current_section() == "MOTIF") and 
    GridConstants.BRIGHTNESS.UI.FOCUSED or 
    GridConstants.BRIGHTNESS.UI.NORMAL
  GridLayers.set(layers.ui, Layout.motif_button.x, Layout.motif_button.y, motif_brightness)
  
  -- Tuning button
  local tuning_brightness = (_seeker.ui_state.get_current_section() == "TUNING") and 
    GridConstants.BRIGHTNESS.UI.FOCUSED or 
    GridConstants.BRIGHTNESS.UI.NORMAL
  GridLayers.set(layers.ui, Layout.tuning_button.x, Layout.tuning_button.y, tuning_brightness)
 
  -- Lane selector
  for i = 0, Layout.lane_select.width - 1 do
    local brightness = (i + 1 == _seeker.ui_state.get_focused_lane()) and 
      GridConstants.BRIGHTNESS.UI.FOCUSED or 
      GridConstants.BRIGHTNESS.UI.NORMAL
    GridLayers.set(layers.ui, Layout.lane_select.x + i, Layout.lane_select.y, brightness)
  end
  
  -- Stage selector
  for i = 0, Layout.stage_select.width - 1 do
    local brightness = (i + 1 == _seeker.ui_state.get_focused_stage()) and 
      GridConstants.BRIGHTNESS.UI.FOCUSED or 
      GridConstants.BRIGHTNESS.UI.NORMAL
    GridLayers.set(layers.ui, Layout.stage_select.x + i, Layout.stage_select.y, brightness)
  end

  -- Transform chain indicators
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  
  for i = 0, Layout.transform_chain.width - 1 do
    local stage_idx = i + 1
    local x = Layout.transform_chain.x + i
    local stage = lane.stages[stage_idx]
    
    -- Only show focused brightness if we're in the transform section
    -- and this is the focused stage
    local is_transform_focused = _seeker.ui_state.get_current_section() == "TRANSFORM" and 
                               stage_idx == _seeker.ui_state.get_focused_stage()
    
    -- Set brightness based on focus state only, ensure we use valid brightness values
    local brightness = 0  -- Default to off
    if is_transform_focused then
      brightness = GridConstants.BRIGHTNESS.UI.FOCUSED or 15  -- Fallback to max brightness
    else
      brightness = GridConstants.BRIGHTNESS.UI.LOW or 2  -- Fallback to dim
    end
    
    GridLayers.set(layers.ui, x, Layout.transform_chain.y, brightness)
  end
end

function toggle_rec_button(x, y)
  if not motif_recorder.is_recording then
    -- If we're not in recording section, just switch to it
    if _seeker.ui_state.get_current_section() ~= "RECORDING" then
      _seeker.ui_state.set_current_section("RECORDING")
      return
    end
    
    -- Get existing motif if we're overdubbing
    local existing_motif = nil
    if params:get("recording_mode") == 2 then -- 2 = Overdub
      local focused_lane = _seeker.ui_state.get_focused_lane()
      existing_motif = _seeker.lanes[focused_lane].motif
      -- Don't allow overdub if no existing motif
      if #existing_motif.events == 0 then
        print("⚠ Cannot overdub: No existing motif")
        return
      end
    end
    
    -- Only start recording if we're already in recording section
    motif_recorder:start_recording(existing_motif)
  else
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local motif = motif_recorder:stop_recording()
    _seeker.lanes[focused_lane]:set_motif(motif)
  end
end

function toggle_play_button(x, y)
	if _seeker.lanes[_seeker.ui_state.get_focused_lane()].playing then
		_seeker.lanes[_seeker.ui_state.get_focused_lane()]:stop()
	else
		_seeker.lanes[_seeker.ui_state.get_focused_lane()]:play()
	end
end

function draw_keyboard()
  local root = params:get("root_note") - 1  -- Convert to 0-based
  local octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_octave")
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
      
      GridLayers.set(layers.ui, grid_x, grid_y, brightness)
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
                GridLayers.set(layers.response, pos.x, pos.y, brightness)
            end
        end
    end
end

function focus_motif()
  _seeker.ui_state.set_current_section("MOTIF")
  _seeker.screen_ui.sections.MOTIF:update_focused_motif(_seeker.ui_state.get_focused_lane())
end

function focus_lane(x, y)
  if is_in_lane_select(x, y) then
    local new_lane_idx = (x - Layout.lane_select.x) + 1
    _seeker.ui_state.set_focused_lane(new_lane_idx)
    _seeker.ui_state.set_current_section("LANE")
  end
end

function focus_stage(x, y)
  if is_in_stage_select(x, y) then
    local new_stage_idx = (x - Layout.stage_select.x) + 1
    _seeker.ui_state.set_focused_stage(new_stage_idx)
    _seeker.ui_state.set_current_section("STAGE")
  end
end

function note_on(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_octave")
  local event = {
    x = x,
    y = y,
    note = theory.grid_to_note(x, y, octave),
    velocity = 127
  }

  if motif_recorder.is_recording then  
    motif_recorder:on_note_on(event)
  end

  focused_lane:on_note_on(event)
end

function note_off(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_octave")
  local event = {
    x = x,
    y = y,
    note = theory.grid_to_note(x, y, octave),
    velocity = 0
  }
  if motif_recorder.is_recording then  
    motif_recorder:on_note_off(event)
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
  elseif is_in_lane_select(x, y) then
    if z == 1 then
      focus_lane(x, y)
    end
  elseif is_in_stage_select(x, y) then
    if z == 1 then
      focus_stage(x, y)
    end
  elseif is_rec_button(x, y) then
    if z == 1 then
      toggle_rec_button(x, y)
    end
  elseif is_play_button(x, y) then
    if z == 1 then
      toggle_play_button(x, y)
    end
  elseif is_motif_button(x, y) then
    if z == 1 then
      focus_motif()
    end
  elseif is_tuning_button(x, y) then
    if z == 1 then
      _seeker.ui_state.set_current_section("TUNING")
    end
  elseif is_in_transform_chain(x, y) then
    if z == 1 then
      local stage_idx = (x - Layout.transform_chain.x) + 1
      _seeker.ui_state.set_focused_stage(stage_idx)
      _seeker.ui_state.set_current_section("TRANSFORM")
    end
  end
end

function GridUI.redraw()
	-- Clear all layers
	GridLayers.clear_layer(layers.background)
	GridLayers.clear_layer(layers.ui)
	GridLayers.clear_layer(layers.response)
	
	-- Update animations
	GridAnimations.update_background(layers.background)
	
	-- Draw UI elements
	draw_controls()
	draw_keyboard()
	
	-- Draw response elements
	draw_motif_events()
	-- Get trails from focused lane
	local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
	GridAnimations.update_trails(layers.response, focused_lane.trails)
	
	-- Draw keyboard outline when recording or counting in
	GridAnimations.update_keyboard_outline(layers.response, Layout, motif_recorder)
	
	-- Apply composite to grid
	GridLayers.apply_to_grid(g, layers)
end	

return GridUI