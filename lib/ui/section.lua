-- section.lua
-- Base class for UI sections

local Section = {}
Section.__index = Section

-- Constants for long press detection
Section.LONG_PRESS_THRESHOLD = 0.5  -- Time in seconds to trigger long press

function Section.new(config)
  local section = setmetatable({}, Section)
  section.id = config.id
  section.name = config.name
  section.icon = config.icon
  section.params = config.params or {}
  section.description = config.description or "No description available"
  section.state = {
    selected_index = 0,
    scroll_offset = 0,
    is_active = false,     -- Track if section is currently active
    showing_description = false  -- Track if we're showing the description
  }
  
  -- Long press tracking
  section.press_state = {
    start_time = nil,
    pressed_keys = {}  -- Track multiple simultaneous presses
  }
  
  return section
end

-- Long press helper functions
function Section:start_press(key_id)
  self.press_state.pressed_keys[key_id] = {
    start_time = util.time(),
    long_press_triggered = false
  }
end

function Section:end_press(key_id)
  self.press_state.pressed_keys[key_id] = nil
end

function Section:is_long_press(key_id)
  local press = self.press_state.pressed_keys[key_id]
  if press then
    local elapsed = util.time() - press.start_time
    if elapsed >= Section.LONG_PRESS_THRESHOLD and not press.long_press_triggered then
      press.long_press_triggered = true
      return true
    end
  end
  return false
end

function Section:get_press_duration(key_id)
  local press = self.press_state.pressed_keys[key_id]
  if press then
    return util.time() - press.start_time
  end
  return 0
end

-- Helper function to format binary values
function Section:format_binary_value(value)
  if value == 1 then
    return "true"
  else
    return "false"
  end
end

function Section:get_param_value(param)
  if param.id then
    local param_info = params:lookup_param(param.id)
    if param_info.t == params.tBINARY then
      return self:format_binary_value(params:get(param.id))
    elseif param_info.t == params.tOPTION then
      return param_info.options[params:get(param.id)]
    end
    return params:string(param.id)
  end
  return param.value or ""
end

function Section:modify_param(param, delta)
  -- Check if the parameter is one of our custom cases that doesn't use the norns PARAM system
  if param.spec then
    if param.spec.type == "option" then
      local options = param.spec.options
      -- Find current index
      local current_idx = 1
      for i, opt in ipairs(options) do
        if opt == param.value then
          current_idx = i
          break
        end
      end
      -- Calculate new index with wrap-around
      local new_idx = ((current_idx - 1 + delta) % #options) + 1
      return options[new_idx]
    elseif param.spec.type == "integer" then
      -- Handle integer parameters with min/max bounds
      local new_value = param.value + delta
      return util.clamp(new_value, param.spec.min, param.spec.max)
    end
  end
  
  -- Default implementation for norns params
  params:delta(param.id, delta)
end

function Section:draw_blinkenlights()
  -- Temporarily disabled while we optimize screen drawing
end

function Section:draw_footer()
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
  
  -- Calculate position to be right-aligned with some padding from blinkenlights
  local SCREEN_WIDTH = 128
  local PADDING = 6  -- Leave space for blinkenlights
  local text_width = screen.text_extents(info_text)
  local x = SCREEN_WIDTH - PADDING - text_width
  
  screen.level(0)
  screen.move(x, 60)
  screen.text(info_text)
  
  self:draw_blinkenlights()
end

function Section:draw_params(start_y)
  local FOOTER_Y = 52
  local ITEM_HEIGHT = 10
  local visible_height = FOOTER_Y - start_y
  local max_visible_items = math.floor(visible_height / ITEM_HEIGHT)
  
  -- Ensure scroll offset stays in valid range
  local max_scroll = math.max(0, #self.params - max_visible_items)
  self.state.scroll_offset = util.clamp(self.state.scroll_offset, 0, max_scroll)
  
  -- Draw visible parameters
  for i = 1, math.min(max_visible_items, #self.params) do
    local param_idx = i + self.state.scroll_offset
    local param = self.params[param_idx]
    if param then
      local y = start_y + (i * ITEM_HEIGHT)
      local is_selected = self.state.selected_index == param_idx
      
      if param.separator then
        -- Draw separator
        screen.level(4)
        screen.move(2, y)
        screen.text(param.name)
        screen.move(2, y + 1)
        screen.line(126, y + 1)
        screen.stroke()
      else
        -- Draw normal parameter
        if is_selected then
          screen.level(2)
          screen.rect(0, y - 6, 128, 8)
          screen.fill()
        end
        
        -- Parameter name
        screen.level(is_selected and 15 or 4)
        screen.move(2, y)
        screen.text(param.name)
        
        -- Parameter value (right-aligned)
        local value = self:get_param_value(param)
        local value_x = 120 - screen.text_extents(value)
        screen.move(value_x, y)
        screen.text(value)
      end
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

function Section:draw_default()
  screen.clear()
  
  if self.state.showing_description then
    -- Draw description with manual text wrapping
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
  else
    self:draw_footer()
    if #self.params > 0 then
      self:draw_params(0)
    end
  end
  
  screen.update()
end

function Section:handle_enc_default(n, d)
  if n == 2 then
    -- Navigate parameters
    local new_index = util.clamp(
      self.state.selected_index + d,
      1,
      #self.params
    )
    
    -- Update selected index
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
    -- Modify selected parameter
    local param = self.params[self.state.selected_index]
    self:modify_param(param, d)
  end
end

function Section:draw()
  self:draw_default()
end

function Section:handle_enc(n, d)
  self:handle_enc_default(n, d)
end

function Section:handle_key(n, z)
  if n == 2 then
    -- Toggle description display on K2 press/release
    self.state.showing_description = (z == 1)
  -- Handle K3 press for action items
  elseif n == 3 and z == 1 and self.state.selected_index > 0 then
    local param = self.params[self.state.selected_index]
    if param.action then
      self:modify_param(param, 1)
    end
  end
end

function Section:handle_grid_key(x, y, z)
  -- Default implementation does nothing
end

-- Lifecycle Methods --

function Section:enter()
  -- Called when section becomes active
  self.state.is_active = true

  -- Ensure selected_index is valid for this section's params
  -- TODO: This is intended to support @arc.lua while refactoring out of sections
  if #self.params > 0 then
    self.state.selected_index = math.max(1, math.min(self.state.selected_index, #self.params))
  else
    self.state.selected_index = 0
  end

  -- Get the number of params (and their type) to send to Arc
  _seeker.arc.new_section(self.params)

  self:update()
end

function Section:exit()
  -- Called when leaving this section
  self.state.is_active = false
end

function Section:update()
  -- Override in child classes to update section state
end

return Section 