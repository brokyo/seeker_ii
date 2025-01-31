-- lib/ui_manager.lua
--
-- UI Manager for Seeker II
--
-- Architectural Pattern:
-- The UI Manager is a central coordinator in the system:
-- 1. Lives in _seeker.ui_manager after initialization
-- 2. Coordinates between grid and screen components
-- 3. Manages shared UI state (focus, pages, parameters)
-- 4. Components access it through _seeker.ui_manager
--
-- This ensures:
-- - Single source of truth for UI state
-- - Coordinated updates between components
-- - Clear ownership of shared UI logic
--------------------------------------------------

-- Dependencies
local Log = include('lib/log')
local transforms = include('lib/transforms')

local UIManager = {}
UIManager.__index = UIManager

-- Constants
local PAGES = {
  VOICE = 1,
  TRANSPORT = 2,
  STAGE = 3
}

function UIManager.init(grid, screen)
  local mgr = {
    grid = grid,
    screen = screen,
    current_param_index = 1,  -- Currently selected parameter
    current_page = 1,         -- Current UI page
    current_stage = 1,        -- Currently selected stage (1-4)
    param_categories = {
      voice = {"keyboard_x", "keyboard_y", "instrument", "midi", "volume"},
      transport = {"record", "recording_mode", "quantize_value", "timing_mode", "grid_division", "gate_length", "grid_speed"},
      stage = {"active", "transform", "loop_count", "loop_rest", "stage_rest"}
    },
    -- UI Configuration
    layout = {
      max_visible = 5,    -- Maximum visible parameters
      start_y = 20,       -- Starting Y position for parameters
      spacing = 10,       -- Spacing between parameters
      value_x = 70,       -- X position for parameter values
      header_y = 7        -- Y position for header text
    },
    animation = {
      page_pulse = 90,    -- Slower pulse for page indicator
      value_pulse = 60,   -- Medium pulse for selector
      header_pulse = 120, -- Very slow pulse for frame
      flash_slew = 0.3    -- Smoothing for value changes
    }
  }
  setmetatable(mgr, UIManager)
  return mgr
end

--------------------------------------------------
-- Page Management
--------------------------------------------------

function UIManager:next_page()
  self.current_page = util.wrap(self.current_page + 1, 1, 3)
  self.current_param_index = 1  -- Reset parameter selection
  self:redraw_all()
end

function UIManager:prev_page()
  self.current_page = util.wrap(self.current_page - 1, 1, 3)
  self.current_param_index = 1  -- Reset parameter selection
  self:redraw_all()
end

function UIManager:get_page_name()
  return self.current_page == 1 and "Voice" or
         self.current_page == 2 and "Transport" or
         "Stage"
end

--------------------------------------------------
-- Focus Management
--------------------------------------------------

function UIManager:focus_lane(lane_num)
  _seeker.focused_lane = lane_num
  self.current_param_index = 1
  self:redraw_all()
end

function UIManager:focus_stage(lane_num, stage_num)
  _seeker.focused_lane = lane_num
  _seeker.focused_stage = stage_num
  self.current_stage = stage_num
  self.current_page = PAGES.STAGE
  self.current_param_index = 1
  self:redraw_all()
end

--------------------------------------------------
-- Parameter Management
--------------------------------------------------

function UIManager:get_current_params()
  local params = {}
  local category_params = self.param_categories[
    self.current_page == 1 and "voice" or 
    self.current_page == 2 and "transport" or 
    "stage"
  ]
  
  -- Get parameters for each category from params_manager
  for _, param_type in ipairs(category_params) do
    local category_params = _seeker.params_manager.get_lane_params(
      _seeker.focused_lane, 
      param_type,
      self.current_page == PAGES.STAGE and self.current_stage or nil
    )
    if category_params then
      for _, param in ipairs(category_params) do
        table.insert(params, param)
      end
    end
  end
  
  -- If we're on the stage page, add stage selection and transform parameters
  if self.current_page == PAGES.STAGE then
    local lane = _seeker.conductor.lanes[_seeker.focused_lane]
    
    -- Add stage selection
    table.insert(params, 1, {
      id = "stage_select",
      name = "Stage",
      value = self.current_stage,
      min = 1,
      max = 4,
      type = "number"
    })
    
    -- Add active state
    table.insert(params, 2, {
      id = string.format("lane_%d_stage_%d_active", _seeker.focused_lane, self.current_stage),
      name = "Active",
      type = "option",
      options = {"Off", "On"},
      value = lane:is_stage_active(self.current_stage) and "On" or "Off"
    })
    
    -- Add transform type
    local transform = lane:get_transform(self.current_stage)
    local transform_id = string.format("lane_%d_stage_%d_transform", _seeker.focused_lane, self.current_stage)
    
    -- Build transform options dynamically from available transforms
    local transform_options = {"none"}
    for name, _ in pairs(transforms.available) do
      table.insert(transform_options, name)
    end
    
    table.insert(params, 3, {
      id = transform_id,
      name = "Transform",
      type = "option",
      options = transform_options,
      value = transform.type
    })
    
    -- If transform is selected and has parameters, add them indented
    if transform.type ~= "none" then
      local transform_def = transforms and transforms.available and transforms.available[transform.type]
      if transform_def and transform_def.params then
        for name, spec in pairs(transform_def.params) do
          table.insert(params, {
            id = transform_id .. "_" .. name,
            name = "  " .. name,  -- Indent parameter name
            type = "number",
            min = spec.min,
            max = spec.max,
            value = transform.params[name] or spec.default
          })
        end
      end
    end
  end
  
  return params
end

function UIManager:delta_param_index(delta)
  local params = self:get_current_params()
  self.current_param_index = util.clamp(
    self.current_param_index + delta,
    1,
    #params
  )
  return self.current_param_index
end

function UIManager:get_selected_param()
  local params = self:get_current_params()
  return params[self.current_param_index]
end

function UIManager:delta_param_value(delta)
  local param = self:get_selected_param()
  if not param then return false end
  
  -- Handle stage selection specially
  if param.id == "stage_select" then
    self.current_stage = util.clamp(self.current_stage + delta, 1, 4)
    self.current_param_index = 1  -- Reset selection when changing stages
    self:redraw_all()
    return true
  end
  
  -- Handle active state toggle
  if param.id:match("_active$") then
    local lane = _seeker.conductor.lanes[_seeker.focused_lane]
    if lane then
      lane:set_stage_active(self.current_stage, delta > 0)
      self:redraw_all()
      return true
    end
    return false
  end
  
  -- Handle transform type selection
  if param.id:match("_transform$") and not param.id:match("_transform_.+$") then
    local lane = _seeker.conductor.lanes[_seeker.focused_lane]
    if lane then
      local transform = lane:get_transform(self.current_stage)
      local options = {"none", "invert", "reverse", "speed", "harmonize"}
      local current_idx = 1
      for i, name in ipairs(options) do
        if name == transform.type then
          current_idx = i
          break
        end
      end
      
      local new_idx = util.wrap(current_idx + delta, 1, #options)
      lane:set_transform(self.current_stage, options[new_idx], {})
      self:redraw_all()
      return true
    end
    return false
  end
  
  -- Handle transform parameter adjustment
  if param.id:match("_transform_.+$") then
    local lane = _seeker.conductor.lanes[_seeker.focused_lane]
    if lane then
      local transform = lane:get_transform(self.current_stage)
      local param_name = param.id:match("_transform_(.+)$")
      local transform_def = transforms and transforms.available and transforms.available[transform.type]
      if transform_def and transform_def.params and transform_def.params[param_name] then
        local spec = transform_def.params[param_name]
        local current = transform.params[param_name] or spec.default
        local new_value = util.clamp(current + delta * 0.01, spec.min, spec.max)
        transform.params[param_name] = new_value
        self:redraw_all()
        return true
      end
    end
    return false
  end
  
  -- Handle normal parameters through the params system
  params:delta(param.id, delta)
  return true
end

function UIManager:key(n, z)
  if z == 1 then
    if n == 2 then
      -- K2: previous page
      self:prev_page()
      self.current_param_index = 1
    elseif n == 3 then
      -- K3: next page
      self:next_page()
      self.current_param_index = 1
    end
  end
end

-- Handle parameter updates and coordinate between components
function UIManager:update_lane_param(lane_num, param_name, value)
  if param_name == "instrument" or param_name == "octave" then
    -- Update conductor state
    if _seeker.conductor and _seeker.conductor.lanes[lane_num] then
      _seeker.conductor.lanes[lane_num][param_name] = value
    end
  end
  
  -- Update grid UI if this is the focused lane
  if lane_num == _seeker.focused_lane then
    self:redraw_all()
  end
end

-- Add a parameter category to a page

--------------------------------------------------
-- Debug Utilities
--------------------------------------------------

function UIManager:debug_current_page()
  local page_name = self:get_page_name()
  print("\n=== Current Page Debug (" .. page_name .. ") ===")
  
  -- Show what categories we're looking for
  local category_params = self.param_categories[
    self.current_page == 1 and "voice" or 
    self.current_page == 2 and "transport" or 
    "stage"
  ]
  print("Looking for categories:", table.concat(category_params, ", "))
  
  -- Show what we get for each category
  for _, param_type in ipairs(category_params) do
    print("\nCategory:", param_type)
    local params = _seeker.params_manager.get_lane_params(_seeker.focused_lane, param_type)
    if params then
      print("Found " .. #params .. " parameters:")
      for _, param in ipairs(params) do
        print(string.format("  %s = %s", param.name, param.value))
      end
    else
      print("  No parameters found")
    end
  end
  
  -- Show current selection
  print("\nCurrent selection:")
  print("  Parameter index:", self.current_param_index)
  local selected = self:get_selected_param()
  if selected then
    print("  Selected:", selected.name, "=", selected.value)
  else
    print("  Nothing selected")
  end
  
  print("\n=== End Debug ===\n")
end

function UIManager:debug_dump_params(lane_num)
  _seeker.params_manager.debug_params(lane_num)
end

--------------------------------------------------
-- Drawing
--------------------------------------------------

function UIManager:redraw_grid()
  if self.grid then self.grid.redraw() end
end

function UIManager:redraw_screen()
  if self.screen then self.screen.redraw() end
end

function UIManager:redraw_all()
  if self.grid then self.grid.redraw() end
  if self.screen then self.screen.redraw() end
end

--------------------------------------------------
-- UI Information
--------------------------------------------------

function UIManager:get_page_count()
  return 3  -- Voice, Transport, Stage
end

function UIManager:get_layout_info()
  return self.layout
end

function UIManager:get_animation_timings()
  return self.animation
end

return UIManager 