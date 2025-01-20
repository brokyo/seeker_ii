-- ui.lua
-- Manages Norns screen drawing, encoder/key handling for page navigation, etc.

local params_manager = include('lib/params_manager')

local UI = {
  pages = {"LANE", "STAGE"},
  current_page = 1,
  grid_ui = nil,   -- Will store grid_ui reference
  lane_change_callbacks = {},  -- Callbacks for lane changes
  
  -- Parameter navigation state
  current_param_index = 1,
  current_stage = 1,  -- Which stage we're viewing (1-4)
  
  -- Define the parameters we care about for each page type
  lane_params = {
    "lane_%d_instrument",
    "lane_%d_octave",
    "lane_%d_timing_mode"
  },
  
  stage_params = {
    "lane_%d_stage_%d_active",
    "lane_%d_stage_%d_loop_count",
    "lane_%d_stage_%d_loop_rest",
    "lane_%d_stage_%d_stage_rest"
  }
}

--------------------------------------------------
-- Initialization
--------------------------------------------------

function UI.init()
  return UI
end

--------------------------------------------------
-- Parameter Management
--------------------------------------------------

-- Get the current list of relevant parameters based on page
function UI.get_current_params()
  local lane_num = _seeker.focused_lane
  
  if UI.current_page == 1 then
    -- Lane page - return lane-level params
    local param_ids = {}
    for _, pattern in ipairs(UI.lane_params) do
      table.insert(param_ids, string.format(pattern, lane_num))
    end
    return param_ids
  else
    -- Stage page - return stage-specific params
    local param_ids = {}
    for _, pattern in ipairs(UI.stage_params) do
      table.insert(param_ids, string.format(pattern, lane_num, UI.current_stage))
    end
    return param_ids
  end
end

--------------------------------------------------
-- Key & Encoder Input
--------------------------------------------------

function UI.key(n, z)
  if n == 2 and z == 1 then
    -- K2: switch between lane and stage pages
    UI.current_page = UI.current_page % #UI.pages + 1
    UI.current_param_index = 1  -- Reset selection on page change
    UI.redraw()
  elseif n == 3 and z == 1 and UI.current_page == 2 then
    -- K3 on stage page: cycle through stages
    UI.current_stage = (UI.current_stage % 4) + 1
    UI.current_param_index = 1  -- Reset selection on stage change
    UI.redraw()
  end
end

function UI.enc(n, d)
  if n == 1 then
    -- Lane selection
    local new_lane = util.clamp(_seeker.focused_lane + d, 1, 4)
    UI.select_lane(new_lane)
  elseif n == 2 then
    -- Parameter selection
    local param_ids = UI.get_current_params()
    UI.current_param_index = util.clamp(UI.current_param_index + d, 1, #param_ids)
    UI.redraw()
  elseif n == 3 then
    -- Parameter value adjustment
    local param_ids = UI.get_current_params()
    local param_id = param_ids[UI.current_param_index]
    if param_id then
      params:delta(param_id, d)
      UI.redraw()
    end
  end
end

--------------------------------------------------
-- Redraw
--------------------------------------------------

function UI.redraw()
  screen.clear()
  screen.level(15)
  
  -- Show current lane and page
  screen.move(0, 10)
  screen.text("Lane " .. _seeker.focused_lane)
  screen.move(128, 10)
  screen.text_right(UI.pages[UI.current_page])
  
  -- Show stage number if on stage page
  if UI.current_page == 2 then
    screen.move(64, 10)
    screen.text_center("Stage " .. UI.current_stage)
  end
  
  -- Show current parameter and value
  local param_ids = UI.get_current_params()
  local param_id = param_ids[UI.current_param_index]
  if param_id then
    screen.move(0, 30)
    local param = params:lookup_param(param_id)
    screen.text(param.name .. ":")
    screen.move(0, 40)
    screen.text(params:string(param_id))
  end
  
  -- Show lane state if available
  if _seeker.conductor then
    local lane = _seeker.conductor.lanes[_seeker.focused_lane]
    if lane then
      screen.move(0, 20)
      screen.text(lane.is_playing and "Playing" or "Stopped")
    end
  end
  
  screen.update()
end

--------------------------------------------------
-- Lane Selection
--------------------------------------------------

function UI.on_lane_change(callback)
  table.insert(UI.lane_change_callbacks, callback)
end

function UI.select_lane(new_lane)
  if new_lane ~= _seeker.focused_lane then
    _seeker.focused_lane = new_lane
    -- Notify callbacks
    for _, callback in ipairs(UI.lane_change_callbacks) do
      callback(new_lane)
    end
    UI.redraw()
  end
end

return UI
