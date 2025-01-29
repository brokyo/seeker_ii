local GridUI = {}
local g = grid.connect()
local theory = include("lib/theory_utils")
local MotifRecorder = include("lib/motif_recorder")
local GridAnimations = include("lib/grid_animations")
local UIState = include("lib/ui_state")

local motif_recorder = MotifRecorder.new({})

local Layout = {
  -- Brightness levels
  BRIGHT = 15,
  ACTIVE = 12,
  UI = 10,
  MED = 4,
  DIM = 2,
  OFF = 0,

  keyboard = {	
    upper_left_x = 6,
    upper_left_y = 2,
    width = 6,
    height = 6
  },

  rec_buttons = {
	{x = 1, y = 3},
	{x = 1, y = 6},
	{x = 16, y = 3},
	{x = 16, y = 6},
  },

  lanes = {
    {x = 1, y = 2, width = 4, height = 1},
    {x = 1, y = 7, width = 4, height = 1},
    {x = 13, y = 2, width = 4, height = 1},
    {x = 13, y = 7, width = 4, height = 1},
  },

  play_buttons = {
	{x = 4, y = 3},
	{x = 4, y = 6},
	{x = 13, y = 3},
	{x = 13, y = 6},
  },

  fps = 30
}

function GridUI.init()
  if g.device then    
	print("⌇ Grid Connected")
	g.key = function(x, y, z)
      GridUI.key(x, y, z)
    end
    
    g.remove = function()
      print("◈ Grid Disconnected") 
    end
  else
    print("⚠ Grid Connect failed")
  end

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

function is_in_lane(x, y)
  for _, lane in ipairs(Layout.lanes) do
    if x >= lane.x and x < lane.x + lane.width and
       y >= lane.y and y < lane.y + lane.height then
      return true
    end
  end
  return false
end

function is_rec_button(x, y)
  for _, button in ipairs(Layout.rec_buttons) do
    if x == button.x and y == button.y then
      return true
    end
  end
  return false
end

function is_play_button(x, y)
  for _, button in ipairs(Layout.play_buttons) do
    if x == button.x and y == button.y then
      return true
    end
  end
  return false
end

function draw_controls()
	draw_rec_buttons()
	draw_lanes()
	draw_play_buttons()
end

function draw_rec_buttons()
	for _, button in ipairs(Layout.rec_buttons) do
		g:led(button.x, button.y, Layout.UI)
	end
end

function toggle_rec_button(x, y)
	if not motif_recorder.is_recording then
		motif_recorder:start_recording()
	else
		local focused_lane = UIState.get_focused_lane()
		local motif = motif_recorder:stop_recording()
		_seeker.lanes[focused_lane]:set_motif(motif)
	end
end


-- TODO: This is wrong. We should just get the lane the play button is in.
function toggle_play_button(x, y)
	if _seeker.lanes[UIState.get_focused_lane()].playing then
		_seeker.lanes[UIState.get_focused_lane()]:stop()
	else
		_seeker.lanes[UIState.get_focused_lane()]:play()
	end
end

function draw_lanes()
  for _, lane in ipairs(Layout.lanes) do
    for x = 0, lane.width - 1 do
      for y = 0, lane.height - 1 do
        g:led(lane.x + x, lane.y + y, Layout.UI)
      end
    end
  end
end

function draw_play_buttons()
	for _, button in ipairs(Layout.play_buttons) do
		g:led(button.x, button.y, Layout.UI)
	end
end

function draw_keyboard()
	for x = 0, Layout.keyboard.width - 1 do
		for y = 0, Layout.keyboard.height - 1 do
			g:led(Layout.keyboard.upper_left_x + x, Layout.keyboard.upper_left_y + y, Layout.MED)
		end
	end	
end

-- Returns lane_idx and stage_idx from grid coordinates
function get_lane_and_stage(x, y)
  -- Find which lane was pressed by checking if x and y fall within lane bounds
  local lane_idx
  local current_lane
  for i, lane in ipairs(Layout.lanes) do
    if x >= lane.x and x < lane.x + lane.width and
       y >= lane.y and y < lane.y + lane.height then
      lane_idx = i
      current_lane = lane
      break
    end
  end
  
  -- Calculate stage index (1-based) based on x position relative to the current lane
  local stage_idx
  if current_lane then
    stage_idx = x - current_lane.x + 1
  end
  
  -- Only return if both indices are valid
  if lane_idx and stage_idx >= 1 and stage_idx <= current_lane.width then
    local position = {
      lane_idx = lane_idx,
      stage_idx = stage_idx
    }
    return position
  end
  return nil
end

function focus_lane(x, y)
  local position = get_lane_and_stage(x, y)
  UIState.set_focused_lane(position.lane_idx)
end

function focus_stage(x, y)
  local position = get_lane_and_stage(x, y)
  UIState.set_focused_lane(position.lane_idx)
  UIState.set_focused_stage(position.stage_idx)
end

function note_on(x, y)
	local event = {
		x = x,
		y = y,
		note = theory.grid_to_note(x, y),
		velocity = 127
	}

	if motif_recorder.is_recording then	
		motif_recorder:on_note_on(event)
	end
	_seeker.lanes[UIState.get_focused_lane()]:on_note_on(event)
	GridAnimations.add_trail(x, y)  -- Add visual feedback for key press
	print(string.format("♪ Note ON  | %s", event.note))
end

function note_off(x, y)
	local event = {
		x = x,
		y = y,
		note = theory.grid_to_note(x, y),
		velocity = 0
	}
	if motif_recorder.is_recording then	
		motif_recorder:on_note_off(event)
	end
	_seeker.lanes[UIState.get_focused_lane()]:on_note_off(event)
	print(string.format("♪ Note OFF | %s", event.note))
end

function GridUI.key(x, y, z)
  if is_in_keyboard(x, y) then
	if z == 1 then
		note_on(x, y)
	else
		note_off(x, y)
	end
  elseif is_in_lane(x, y) then
	if z == 1 then
		focus_stage(x, y)
	end
  elseif is_rec_button(x, y) then
	if z == 1 then
		toggle_rec_button(x, y, z)
	end
  elseif is_play_button(x, y) then
	if z == 1 then
		toggle_play_button(x, y, z)
	end
  end
end

function GridUI.redraw()
	g:all(0)
	GridAnimations.update()
	draw_controls()
	draw_keyboard()
	g:refresh()
end	

return GridUI