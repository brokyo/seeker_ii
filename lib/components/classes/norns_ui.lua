-- norns_ui.lua
-- Base class for Norns UI components
-- Handles default logic. Can be overridden by individual components (see: @create_motif.lua)

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

  for _, viz_check in ipairs(condition) do
    -- TODO: params:string "Returns the string associated with the current value for a given parameter's id" 
    -- Will this work for number param types?
    local actual_value = params:string(viz_check.id)
    local test_value = viz_check.value

    if viz_check.operator == ">" then
      if actual_value > test_value then
        return true
      end
    elseif viz_check.operator == "<" then
      if actual_value < test_value then
        return true
      end
    elseif viz_check.operator == "=" then
      if actual_value == test_value then
        return true
      end
    elseif viz_check.operator == "!=" then
      if actual_value ~= test_value then
        return true
      end
    else
      return false
    end
  end
  
end

-- Used in components to update dynamic parameter lists
-- Result of conditional logic about params (see: @wtape.lua)
function NornsUI:filter_active_params()
  -- Reset the active params array
  self.active_params = {}

  -- Iterate through all potential params
  for _, potential_param in ipairs(self.params) do
    -- Always show separators and params with no conditions
    if potential_param.separator or not potential_param.view_conditions then
      table.insert(self.active_params, potential_param)
    else
      -- Insert param if it's passes the visibility check
      local is_visible = self:evaluate_condition(potential_param.view_conditions)
      if is_visible then
        table.insert(self.active_params, potential_param)
      end
    end
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

-- Used by encoder handling to modify the value of a parameter
-- Forked logic based on param type

-- TODO: I think I can get rid of all is_custom logic
function NornsUI:modify_param(param, delta)
  -- if param.is_custom then -- Handles custom seeker params which do not use the norns param API
  --   if param.spec.type == "option" then
  --     local options = param.spec.options

  --     -- Find current index
  --     local current_idx = 1
  --     for i, opt in ipairs(options) do
  --       if opt == param.value then
  --         current_idx = i
  --         break
  --       end
  --     end

  --     -- Calculate new index with wrap-around
  --     local new_idx = util.clamp(current_idx + delta, 1, #options)
  --     return options[new_idx]
  --   elseif param.spec.type == "integer" then
  --     -- Handle integer parameters with min/max bounds
  --     local new_value = param.value + delta
  --     return util.clamp(new_value, param.spec.min, param.spec.max)
  --   end
  -- end

  if param.is_action then
    -- Only allow action triggers through button press, not encoder
    if delta ~= 1 then
      return
    end
  end
  
  -- Default implementation for norns params as defined in the API (https://monome.org/docs/norns/api/modules/paramset.html#delta)
  params:delta(param.id, delta)
end

--------------------------------
-- Drawing functions
--------------------------------

-- Draw consistent content (footer, params, etc) without calling screen.clear() or screen.update().
-- Useful for components with animation (@create_motif.lua)
function NornsUI:_draw_standard_ui()
  -- Write description if k3 held
  if self.state.showing_description then
    screen.level(15)
    -- Split description into words
    local words = {}
    for word in self.description:gmatch("%S+") do
      table.insert(words, word)
    end
      
    local line = ""
    local y = 20  -- Start position
    local x = 2   -- Left margin
    local MAX_WIDTH = 124  -- Screen width minus margins
    
    for i, word in ipairs(words) do
      local test_line = line .. (line == "" and "" or " ") .. word
      local width = screen.text_extents(test_line)
      
      if width > MAX_WIDTH then
        -- Draw current line and start new one
        screen.move(x, y)
        screen.text(line)
        line = word
        y = y + 11  -- Line height
      else
        -- Add word to current line
        line = test_line
      end
    end
    
    -- Draw final line
    if line ~= "" then
      screen.move(x, y)
      screen.text(line)
    end
  -- Otherwise draw footer and params
  else 
    self:draw_footer()
    if #self.params > 0 then
      self:draw_params(0)
    end
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
  
  -- Add lane and stage info
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

function NornsUI:draw_params(start_y)
  local FOOTER_Y = 52
  local ITEM_HEIGHT = 10
  local visible_height = FOOTER_Y - start_y
  local max_visible_items = math.floor(visible_height / ITEM_HEIGHT)
 
  -- Filter active_params table to only show params that pass the conditional check
  self:filter_active_params()

  -- Ensure selected_index is valid after filtering
  -- NB: This is defensive and I'm not sure we need it.
  if self.state.selected_index > #self.active_params then
    print("Out of bounds selected index: " .. self.state.selected_index)
    self.state.selected_index = self:find_first_selectable()
  end

  -- Ensure scroll offset stays in valid range
  local max_scroll = math.max(0, #self.active_params - max_visible_items)
  self.state.scroll_offset = util.clamp(self.state.scroll_offset, 0, max_scroll)
  
  -- Draw visible, active parameters
  for i = 1, math.min(max_visible_items, #self.active_params) do
    local param_idx = i + self.state.scroll_offset
    local param = self.active_params[param_idx]

    local y = start_y + (i * ITEM_HEIGHT)
    local is_selected = self.state.selected_index == param_idx
      
    if param.separator then
      -- Draw separator
      screen.level(4)
      screen.move(2, y)
      screen.text(param.title)
      screen.move(2, y + 1)
      screen.line(126, y + 1)
      screen.stroke()
    else
      -- Get param metadata using Norns paramset api
      local param_base = params:lookup_param(param.id)
      local param_name = param.name or param_base.name
      local param_value = params:string(param.id)

      -- Overwrite displayed param value if it's a toggle or trigger
      if param_base.behavior == "toggle" then
        if param_value == 0 then
          param_value = "○"
        else 
          param_value = "◆"
        end
      elseif param_base.behavior == "trigger" then
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
  if n == 2 then
    -- Filter active params first
    self:filter_active_params()
    
    -- Manage index in active_params space
    local new_index = self.state.selected_index + d
    
    -- Skip separators
    while new_index >= 1 and new_index <= #self.active_params and self.active_params[new_index].separator do
      new_index = new_index + d
    end
    
    -- Clamp to valid range
    new_index = util.clamp(new_index, 1, #self.active_params)
    
    -- If we hit a separator at the boundary, find nearest selectable
    if new_index <= #self.active_params and self.active_params[new_index].separator then
      if d > 0 then
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

  -- Toggle description display on K2 press/release
  if n == 2 then
    self.state.showing_description = (z == 1)

    -- Handle K3 press for action items
  elseif n == 3 and z == 1 and self.state.selected_index > 0 then
    local param = self:get_selected_param()
    if param and param.is_action then
      self:modify_param(param, 1)
    end
  end
end

--------------------------------
-- Lifecycle Methods
--------------------------------

function NornsUI:enter()
  print("NornsUI:enter START")
  -- Called when section becomes active
  self.state.is_active = true

  print("NornsUI:enter - filtering active params")
  -- Filter params and set initial selection
  self:filter_active_params()
  print("NornsUI:enter - finding first selectable")
  self.state.selected_index = self:find_first_selectable()

  print("NornsUI:enter - calling arc.new_section with " .. #self.params .. " params")
  -- Get the number of params (and their type) to send to Arc
  -- TODO: This is a bit of a hack. There should probably be a new_section method and update_params method on Arc.
  _seeker.arc.new_section(self.params)

  print("NornsUI:enter - calling update")
  self:update()
  print("NornsUI:enter COMPLETE")
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