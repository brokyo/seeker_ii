-- norns_ui.lua
-- Base class for Norns UI components with parameter navigation, drawing, and input handling

-- Use global Modal singleton to avoid multiple include() instances
local function get_modal()
  return _seeker and _seeker.modal
end

local NornsUI = {}
NornsUI.__index = NornsUI

function NornsUI.new(config)
  local norns_ui = setmetatable({}, NornsUI)
  --  Base metadata properties for navigation
  norns_ui.id = config.id
  norns_ui.name = config.name
  norns_ui.icon = config.icon
  norns_ui.params = config.params
  norns_ui.active_params = {}
  norns_ui.description = config.description or "No description available"
  
  -- State properties for UI management
  norns_ui.state = {
    selected_index = 1,
    scroll_offset = 0,
    is_active = false,
    showing_description = false
  }
  
  norns_ui.long_press_threshold = config.long_press_threshold or 0.5  -- Time in seconds to trigger long press
  -- Keypress state properties for long press detection
  norns_ui.press_state = {
    start_time = nil,
    pressed_keys = {}
  }
  
  return norns_ui
end

--------------------------------
-- Long press helper functions
--------------------------------

-- Begins a timer on Norns key press
function NornsUI:start_press(key_id)
  self.press_state.pressed_keys[key_id] = {
    start_time = util.time(),
    long_press_triggered = false
  }
end

-- Resets the timer on Norns key release
function NornsUI:end_press(key_id)
  self.press_state.pressed_keys[key_id] = nil
end

-- Checks if the key has been pressed for longer than the threshold
function NornsUI:is_long_press(key_id)
  local press = self.press_state.pressed_keys[key_id]
  if press then
    local elapsed = util.time() - press.start_time
    if elapsed >= self.long_press_threshold and not press.long_press_triggered then
      press.long_press_triggered = true
      return true
    end
  end
  return false
end

function NornsUI:get_press_duration(key_id)
  local press = self.press_state.pressed_keys[key_id]
  if press then
    return util.time() - press.start_time
  end
  return 0
end

--------------------------------
-- Parameter interaction
--------------------------------

function NornsUI:evaluate_condition(condition)
  if not condition then
    return true
  end

  for _, rule in ipairs(condition) do
    local actual_value = params:string(rule.id)
    local test_value = rule.value

    if rule.operator == ">" then
      if actual_value > test_value then
        return true
      end
    elseif rule.operator == "<" then
      if actual_value < test_value then
        return true
      end
    elseif rule.operator == "=" then
      if actual_value == test_value then
        return true
      end
    elseif rule.operator == "!=" then
      if actual_value ~= test_value then
        return true
      end
    else
      return false
    end
  end
  
end

-- Filters parameter list based on view_conditions to show/hide params dynamically
function NornsUI:filter_active_params()
  -- Reset the active params array
  self.active_params = {}

  -- Iterate through all potential params
  for _, potential_param in ipairs(self.params) do
    -- Always show separators and params with no conditions
    if potential_param.separator or not potential_param.view_conditions then
      table.insert(self.active_params, potential_param)
    else
      -- Add parameter if visibility conditions are met
      local is_visible = self:evaluate_condition(potential_param.view_conditions)
      if is_visible then
        table.insert(self.active_params, potential_param)
      end
    end
  end

  -- Ensure selection points to a selectable param (not a separator)
  local current = self.active_params[self.state.selected_index]
  if not current or current.separator then
    self.state.selected_index = self:find_first_selectable()
  end
end


-- Used by drawing methods to display the value of a parameter on screen
-- This exists because we may eventually have custom parameters that need a conditional tree
function NornsUI:get_param_value(param)
  local param_value = nil

  if param.is_action then
    param_value = "○"
  else
    param_value = params:string(param.id)
  end

  return param_value
end

-- Modifies parameter value via encoder delta, with special handling for actions and binary params
function NornsUI:modify_param(param, delta)
  if param.is_action then
    -- Only allow action triggers through button press, not encoder
    if delta ~= 1 then
      return
    end
  end

  -- Prevent binary params from wrapping at boundaries
  local param_type = params:t(param.id)
  if param_type == params.tBINARY then
    local current = params:get(param.id)
    if (current == 0 and delta < 0) or (current == 1 and delta > 0) then
      return
    end
  end

  -- Default implementation for norns params as defined in the API (https://monome.org/docs/norns/api/modules/paramset.html#delta)
  params:delta(param.id, delta)
end

--------------------------------
-- Drawing functions
--------------------------------

-- Draw consistent content (footer, params, modal) without screen.clear() or screen.update()
-- For use by components that need custom rendering or animation
function NornsUI:_draw_standard_ui()
  local Modal = get_modal()
  -- Draw modal overlay if any modal is active
  local modal_active = Modal and Modal.is_active()
  if modal_active then
    Modal.draw()
  -- Otherwise draw params then footer (footer draws last to clip overflow)
  else
    if #self.params > 0 then
      self:draw_params(0)
    end
    self:draw_footer()
  end
end

function NornsUI:draw_footer()
  -- Draw footer background
  screen.level(8)
  screen.rect(0, 52, 128, 12)
  screen.fill()

  -- Draw section name
  screen.level(0)
  screen.move(2, 60)
  screen.text(self.name)

  -- Only show lane/stage info in Motif mode
  if _seeker.current_mode == "motif" then
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_idx]
    local stage_idx = lane.current_stage_index
    local info_text = string.format("L%d:S%d", lane_idx, stage_idx)

    -- Calculate position to be right-aligned
    local SCREEN_WIDTH = 128
    local PADDING = 6
    local text_width = screen.text_extents(info_text)
    local x = SCREEN_WIDTH - PADDING - text_width

    screen.level(0)
    screen.move(x, 60)
    screen.text(info_text)
  end
end

function NornsUI:draw_params(start_y)
  local FOOTER_Y = 52
  local ITEM_HEIGHT = 10
  local SEPARATOR_PADDING = 4
  local visible_height = FOOTER_Y - start_y
  local max_visible_items = math.floor(visible_height / ITEM_HEIGHT)

  -- Filter active_params table to only show params that pass the conditional check
  self:filter_active_params()

  -- Ensure scroll offset stays in valid range
  local max_scroll = math.max(0, #self.active_params - max_visible_items)
  self.state.scroll_offset = util.clamp(self.state.scroll_offset, 0, max_scroll)

  -- Track if we've seen a separator (to skip padding on first)
  local separator_count = 0
  local y_offset = 0

  -- Draw visible, active parameters
  for i = 1, math.min(max_visible_items, #self.active_params) do
    local param_idx = i + self.state.scroll_offset
    local param = self.active_params[param_idx]

    -- Add padding before non-first separators
    if param.separator then
      separator_count = separator_count + 1
      if separator_count > 1 then
        y_offset = y_offset + SEPARATOR_PADDING
      end
    end

    local y = start_y + (i * ITEM_HEIGHT) + y_offset
    local is_selected = self.state.selected_index == param_idx

    if param.separator then
      -- Centered uppercase title with horizontal lines on each side
      local title = param.title or ""
      local center_x = 64
      local line_start = 4
      local line_end = 124
      local title_margin = 4

      screen.font_face(1)
      screen.font_size(8)
      local upper_title = string.upper(title)
      local title_width = screen.text_extents(upper_title)

      -- Left line up to title
      screen.level(3)
      screen.move(line_start, y - 3)
      screen.line(center_x - title_width/2 - title_margin, y - 3)
      screen.stroke()

      -- Title text
      screen.level(6)
      screen.move(center_x - title_width/2, y)
      screen.text(upper_title)

      -- Right line from title to edge
      screen.level(3)
      screen.move(center_x + title_width/2 + title_margin, y - 3)
      screen.line(line_end, y - 3)
      screen.stroke()
    else
      -- Get param metadata using Norns paramset api
      local param_base = params:lookup_param(param.id)
      local param_name = param.custom_name or param.name or param_base.name
      local param_value = param.custom_value or params:string(param.id)

      -- Overwrite displayed param value if it's a toggle or trigger (unless custom_value provided)
      if not param.custom_value and param_base.behavior == "toggle" then
        if param_value == 0 then
          param_value = "○"
        else
          param_value = "◆"
        end
      elseif not param.custom_value and param_base.behavior == "trigger" then
        local recently_triggered = _seeker.ui_state.is_recently_triggered(param.id)
        
        if recently_triggered then
          param_value = "✓"
        else
          param_value = "␣"
        end
      end

      -- Draw normal parameter
      if is_selected then
        screen.level(2)
        screen.rect(0, y - 6, 128, 8)
        screen.fill()
      end
      
      -- Parameter name
      screen.level(is_selected and 15 or 4)
      screen.move(2, y)
      screen.text(param_name)
      
      -- Parameter value (right-aligned)
      local value_x = 120 - screen.text_extents(param_value)
      screen.move(value_x, y)
      screen.text(param_value)
    end
  end
  
  -- Draw scroll indicators if needed
  if self.state.scroll_offset > 0 then
    screen.level(4)
    screen.move(123, start_y + 4)
    screen.text("▲")
  end
  if self.state.scroll_offset < max_scroll then
    screen.level(4)
    screen.move(123, FOOTER_Y - 4)
    screen.text("▼")
  end
end

function NornsUI:draw_default()
  local Modal = get_modal()
  screen.clear()
  self:_draw_standard_ui()
  screen.update()
end

function NornsUI:draw()
  self:draw_default()
end

--------------------------------
-- Norns button/encoder handling
--------------------------------

function NornsUI:handle_enc_default(n, d)
  local Modal = get_modal()
  -- Modal handles encoder input first when active
  if Modal and Modal.handle_enc(n, d, "norns") then
    return
  end

  if n == 2 then
    -- Filter active params first
    self:filter_active_params()

    -- Guard against components with no params (e.g., action-only components)
    if #self.active_params == 0 then return end

    -- Manage index in active_params space
    local delta = util.round(d)
    local new_index = self.state.selected_index + delta

    -- Skip separators
    while new_index >= 1 and new_index <= #self.active_params and self.active_params[new_index].separator do
      new_index = new_index + delta
    end
    
    -- Clamp to valid range
    new_index = util.clamp(new_index, 1, #self.active_params)
    
    -- If we hit a separator at the boundary, find nearest selectable
    if new_index <= #self.active_params and self.active_params[new_index].separator then
      if delta > 0 then
        -- Moving down, find next selectable
        for i = new_index + 1, #self.active_params do
          if not self.active_params[i].separator then
            new_index = i
            break
          end
        end
      else
        -- Moving up, find previous selectable
        for i = new_index - 1, 1, -1 do
          if not self.active_params[i].separator then
            new_index = i
            break
          end
        end
      end
    end
    
    self.state.selected_index = new_index
    
    -- Adjust scroll offset to keep selection visible
    local FOOTER_Y = 52
    local ITEM_HEIGHT = 10
    local visible_height = FOOTER_Y
    local max_visible_items = math.floor(visible_height / ITEM_HEIGHT)
    
    -- Scroll up if selection is above visible area
    if new_index <= self.state.scroll_offset then
      self.state.scroll_offset = new_index - 1
    end
    
    -- Scroll down if selection is below visible area
    if new_index > self.state.scroll_offset + max_visible_items then
      self.state.scroll_offset = new_index - max_visible_items
    end
    
  elseif n == 3 and self.state.selected_index > 0 then
    -- Modify selected parameter using helper method
    local param = self:get_selected_param()
    if param then
      self:modify_param(param, d)
    end
  end
end

function NornsUI:handle_enc(n, d)
  self:handle_enc_default(n, d)
end

function NornsUI:handle_key(n, z)
  local Modal = get_modal()

  -- Modal handles input first when active
  if Modal and Modal.handle_key(n, z) then
    return
  end

  -- Toggle description display on K2 press/release
  if n == 2 then
    if z == 1 then
      self.state.showing_description = true
      if Modal then
        Modal.show_description({
          body = self.description,
          hint = "e3 scroll · release k2"
        })
      end
    else
      self.state.showing_description = false
      if Modal then Modal.dismiss() end
    end

  -- Handle K3 press for action items
  elseif n == 3 and z == 1 and self.state.selected_index > 0 then
    local param = self:get_selected_param()
    if param and param.is_action then
      -- Action params are executed, not modified - use set() to fire the action
      params:set(param.id, 1)
    end
  end
end

--------------------------------
-- Lifecycle Methods
--------------------------------

function NornsUI:enter()
  -- Called when section becomes active
  self.state.is_active = true

  -- Filter params and set initial selection
  self:filter_active_params()
  self.state.selected_index = self:find_first_selectable()

  -- Initialize Arc with current parameter list
  _seeker.arc.new_section(self.params)

  self:update()
end

function NornsUI:exit()
  -- Called when leaving this section
  self.state.is_active = false
  
  -- Reset to first selectable item
  self.state.selected_index = 1
  self.state.scroll_offset = 0
end

function NornsUI:update()
  -- Override in child classes to update section state/handle dynamic params
end

-- Helper method to find first selectable item in active_params
function NornsUI:find_first_selectable()
  for i, param in ipairs(self.active_params) do
    if not param.separator then
      return i
    end
  end
  return 1  -- Fallback
end

-- Helper method to get currently selected parameter
function NornsUI:get_selected_param()
  if self.state.selected_index > 0 and self.state.selected_index <= #self.active_params then
    return self.active_params[self.state.selected_index]
  end
  return nil
end

return NornsUI 