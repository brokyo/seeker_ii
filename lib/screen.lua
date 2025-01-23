-- lib/screen.lua
--
-- Screen UI component for Seeker II
--
-- Architectural Pattern:
-- The screen component follows the centralized state pattern:
-- 1. Accesses shared services through _seeker
-- 2. Uses _seeker.ui_manager for all UI coordination
-- 3. Maintains only UI-specific state locally (animations, scroll position)
-- 4. Receives initial setup through init() but then uses _seeker references
--
-- Handles all screen-related functionality:
-- 1. UI State and navigation
-- 2. Input processing (enc/key)
-- 3. Drawing and animations
-- 4. Parameter display and editing
--------------------------------------------------

local UI = {}
local Log = include('lib/log')

-- Constants
local SCREEN = {
  SYMBOLS = {
    DOT_FILLED = "●",
    DOT_EMPTY = "○",
    BAR_FULL = "▮",
    BAR_EMPTY = "▯",
    SELECTOR = "►",
    BRACKETS = { "[", "]" },
    DECORATORS = {
      TOP_LEFT = "┌",
      TOP_RIGHT = "┐",
      BOTTOM_LEFT = "└",
      BOTTOM_RIGHT = "┘",
      HORIZONTAL = "─",
      VERTICAL = "│"
    }
  }
}

-- UI State
UI.state = {
  value_flashes = {},      -- Tracks parameter change animations
  scroll_offset = 0,       -- Scroll offset for long parameter lists
  page_pulse = nil,        -- Breathing animation for current page
  value_pulse = nil,       -- Pulse animation for value changes
  header_pulse = nil,      -- Subtle header animation
  transform_params = {}    -- Current transform parameter values
}

-- Animation utilities
local function make_smoother(initial, slew)
  local current = initial or 0
  return function(target)
    current = current + ((target - current) * slew)
    return current
  end
end

local function make_pulse(interval)
  local phase = 0
  return function()
    phase = (phase + 1) % interval
    return math.sin(2 * math.pi * phase / interval) * 0.5 + 0.5
  end
end

--------------------------------------------------
-- Drawing Functions
--------------------------------------------------

local function draw_frame()
  -- Draw retro-future frame with subtle animation
  local pulse = UI.state.header_pulse()
  local brightness = math.floor(pulse * 4) + 11  -- Subtle pulse between 11-15
  screen.level(brightness)
  
  -- Top frame
  screen.move(0, 0)
  screen.text(SCREEN.SYMBOLS.DECORATORS.TOP_LEFT)
  screen.move(127, 0)
  screen.text(SCREEN.SYMBOLS.DECORATORS.TOP_RIGHT)
  
  -- Bottom frame
  screen.move(0, 63)
  screen.text(SCREEN.SYMBOLS.DECORATORS.BOTTOM_LEFT)
  screen.move(127, 63)
  screen.text(SCREEN.SYMBOLS.DECORATORS.BOTTOM_RIGHT)
  
  -- Vertical lines with gaps for text
  screen.level(brightness - 4)  -- Slightly dimmer
  for y = 1, 62 do
    if y < 8 or y > 12 then  -- Gap for header
      screen.pixel(0, y)
      screen.pixel(127, y)
    end
  end
  screen.fill()
end

local function draw_header(lane_num)
  local pulse = UI.state.page_pulse()
  local header_level = math.floor(UI.state.header_pulse() * 4) + 11
  local layout = _seeker.ui_manager:get_layout_info()
  
  -- Draw frame elements
  screen.level(header_level)
  screen.move(0, 0)
  screen.text(SCREEN.SYMBOLS.DECORATORS.TOP_LEFT)
  screen.move(127, 0)
  screen.text(SCREEN.SYMBOLS.DECORATORS.TOP_RIGHT)
  
  -- Draw header bar
  screen.level(2)
  screen.move(1, 0)
  screen.line(126, 0)
  screen.stroke()
  
  -- Draw lane number (left)
  screen.level(15)
  screen.move(4, layout.header_y)
  screen.text(string.format("L%d", lane_num))
  
  -- Draw stage number if on stage page (next to lane)
  if _seeker.ui_manager:get_page_name() == "Stage" then
    screen.level(15)
    screen.move(16, layout.header_y)
    screen.text(string.format("S%d", _seeker.ui_manager.current_stage))
  end
  
  -- Draw page name (centered)
  local page_name = _seeker.ui_manager:get_page_name()
  screen.level(15)
  local name_width = screen.text_extents(page_name)
  screen.move(64 - (name_width/2), layout.header_y)
  screen.text(page_name)
  
  -- Draw page indicators (right aligned)
  local page_count = _seeker.ui_manager:get_page_count()
  for i = 1, page_count do
    screen.level(i == _seeker.ui_manager.current_page and math.floor(pulse * 15) or 2)
    screen.move(110 + (i * 5), layout.header_y)
    screen.text(SCREEN.SYMBOLS.DOT_FILLED)
  end
end

local function draw_param_list(params, selected_index)
  local layout = _seeker.ui_manager:get_layout_info()
  
  -- Calculate visible range based on scroll offset
  local visible_start = UI.state.scroll_offset + 1
  local visible_end = math.min(visible_start + layout.max_visible - 1, #params)
  
  -- Draw scrollbar if needed
  if #params > layout.max_visible then
    screen.level(2)
    screen.move(126, layout.start_y)
    screen.line(126, 63)
    screen.stroke()
    
    local scroll_height = 64 - layout.start_y
    local scroll_pos = layout.start_y + (UI.state.scroll_offset * scroll_height / #params)
    local scroll_size = math.max(4, scroll_height * layout.max_visible / #params)
    
    screen.level(15)
    screen.move(126, scroll_pos)
    screen.line(126, scroll_pos + scroll_size)
    screen.stroke()
  end
  
  -- Draw visible parameters
  for i = visible_start, visible_end do
    local param = params[i]
    local y = layout.start_y + ((i - visible_start) * layout.spacing)
    
    -- Draw parameter
    UI.draw_param(param, 12, y, selected_index == i)
    
    -- Draw selector
    screen.level(selected_index == i and 15 or 2)
    screen.move(4, y)
    screen.text(selected_index == i and SCREEN.SYMBOLS.SELECTOR or " ")
  end
end

-- Get parameters for current transform
local function get_transform_params(lane_num, stage_num)
  if not _seeker.conductor then return {} end
  
  local lane = _seeker.conductor.lanes[lane_num]
  if not lane then return {} end
  
  local transform = lane:get_transform(stage_num)
  if not transform or transform.type == "none" then return {} end
  
  local transform_def = transforms.available[transform.type]
  if not transform_def then return {} end
  
  -- Return current params merged with defaults
  local result = {}
  for name, spec in pairs(transform_def.params or {}) do
    result[name] = transform.params[name] or spec.default
  end
  return result
end

-- Update transform parameters
local function set_transform_param(lane_num, stage_num, param_name, value)
  if not _seeker.conductor then return end
  
  local lane = _seeker.conductor.lanes[lane_num]
  if not lane then return end
  
  local transform = lane:get_transform(stage_num)
  if not transform then return end
  
  -- Update parameter
  transform.params[param_name] = value
  
  -- Store in UI state for immediate feedback
  local key = string.format("l%d_s%d_%s", lane_num, stage_num, param_name)
  UI.state.transform_params[key] = value
end

-- Draw transform parameters for current stage
local function draw_transform_params(lane_num, stage_num, selected_index)
  local layout = _seeker.ui_manager:get_layout_info()
  local lane = _seeker.conductor.lanes[lane_num]
  if not lane then return end
  
  local transform = lane:get_transform(stage_num)
  if not transform then return end
  
  -- Draw transform type selector
  screen.level(15)
  screen.move(4, layout.start_y)
  screen.text("Transform: ")
  screen.move(60, layout.start_y)
  screen.text(transform.type)
  
  -- Get available transforms
  local transform_types = {"none"}
  for name, _ in pairs(transforms.available) do
    table.insert(transform_types, name)
  end
  
  -- Draw parameters if transform selected
  if transform.type ~= "none" then
    local transform_def = transforms.available[transform.type]
    if transform_def and transform_def.params then
      local y = layout.start_y + layout.spacing
      
      for name, spec in pairs(transform_def.params) do
        -- Parameter name
        screen.level(5)
        screen.move(8, y)
        screen.text(name)
        
        -- Parameter value
        local value = transform.params[name] or spec.default
        screen.level(15)
        screen.move(layout.value_x, y)
        screen.text(string.format("%.2f", value))
        
        y = y + layout.spacing
      end
    end
  end
end

--------------------------------------------------
-- Input Handling
--------------------------------------------------

function UI.enc(n, d)
  if n == 1 then
    -- Lane selection (unchanged)
    local new_lane = util.clamp(_seeker.focused_lane + d, 1, 4)
    if new_lane ~= _seeker.focused_lane then
      _seeker.ui_manager:focus_lane(new_lane)
      UI.state.scroll_offset = 0
    end
  elseif n == 2 then
    -- Parameter selection
    local new_index = _seeker.ui_manager:delta_param_index(d)
    local layout = _seeker.ui_manager:get_layout_info()
    
    if new_index > UI.state.scroll_offset + layout.max_visible then
      UI.state.scroll_offset = new_index - layout.max_visible
    elseif new_index <= UI.state.scroll_offset then
      UI.state.scroll_offset = new_index - 1
    end
  elseif n == 3 then
    -- Value adjustment
    if _seeker.ui_manager:delta_param_value(d) then
      local param = _seeker.ui_manager:get_selected_param()
      local timings = _seeker.ui_manager:get_animation_timings()
      if not UI.state.value_flashes[param.id] then
        UI.state.value_flashes[param.id] = {
          brightness = make_smoother(0, timings.flash_slew),
          active = true
        }
      end
    end
  end
end

function UI.key(n, z)
  if z == 1 then
    if n == 2 then
      -- K2: previous page
      _seeker.ui_manager:prev_page()
      UI.state.scroll_offset = 0
    elseif n == 3 then
      -- K3: next page
      _seeker.ui_manager:next_page()
      UI.state.scroll_offset = 0
    end
  end
end

--------------------------------------------------
-- Main Drawing
--------------------------------------------------

function UI.redraw()
  screen.clear()
  
  -- Draw retro-future frame
  draw_frame()
  
  -- Draw header with page indicators
  draw_header(_seeker.focused_lane)
  
  -- Show filtered parameters for current page
  local params = _seeker.ui_manager:get_current_params()
  draw_param_list(params, _seeker.ui_manager.current_param_index)
  
  -- Update animations
  for id, flash in pairs(UI.state.value_flashes) do
    if flash.active then
      local b = flash.brightness(0)
      flash.active = b > 0.01
    end
  end
  
  screen.update()
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------

function UI.init(ui_mgr)
  -- Initialize animations using UI manager timings
  local timings = ui_mgr:get_animation_timings()
  UI.state.page_pulse = make_pulse(timings.page_pulse)
  UI.state.value_pulse = make_pulse(timings.value_pulse)
  UI.state.header_pulse = make_pulse(timings.header_pulse)
  return UI
end

function UI.cleanup()
  -- Clear any animation state
  UI.state.value_flashes = {}
end

function UI.draw_param(param, x, y, selected)
  local value_level = 15  -- Default brightness for values
  local label_level = selected and 15 or 4  -- Brighter when selected
  
  -- Draw parameter label
  screen.level(label_level)
  screen.move(x, y)
  screen.text(param.name)
  
  -- Get and format value
  local value = ""
  if param.id == "stage_select" then
    value = tostring(_seeker.ui_manager.current_stage)
  elseif param.type == "option" then
    value = param.value
  elseif param.type == "number" then
    if param.id:match("_transform_.+$") then
      -- Format transform parameters with 2 decimal places
      value = string.format("%.2f", param.value)
    else
      value = tostring(param.value)
    end
  else
    value = param.value
  end
  
  -- Draw value
  screen.level(value_level)
  screen.move(x + 70, y)
  screen.text(value)
end

return UI 