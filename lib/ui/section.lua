-- section.lua
-- Base class for UI sections

local Section = {}
Section.__index = Section

function Section.new(config)
  local section = setmetatable({}, Section)
  section.id = config.id
  section.name = config.name
  section.icon = config.icon
  section.params = config.params or {}
  section.state = {
    selected_index = 0,
    scroll_offset = 0
  }
  return section
end

function Section:get_param_value(param)
  -- Default implementation just returns the parameter's string value
  return params:string(param.id) or ""
end

function Section:modify_param(param, delta)
  -- Default implementation just deltas the parameter
  params:delta(param.id, delta)
end

function Section:draw_blinkenlights()
  local lights = {}
  local FOOTER_CENTER_Y = 56  -- Footer spans 52-64, so center is at 58
  local START_Y = FOOTER_CENTER_Y - 3  -- Center the 4 rows (3px up from center)
  
  -- Lane status lights (right-aligned, starting at 106)
  for lane_idx = 1, 4 do
    local lane = _seeker.lanes[lane_idx]
    local is_focused = lane_idx == _seeker.ui_state.get_focused_lane()
    
    -- Lane activity light
    table.insert(lights, {
      x = 106,
      y = START_Y + (lane_idx * 2),
      is_active = lane.playing,
      speed = 0,  -- No pulse when playing, just steady light
      base_level = is_focused and 4 or 2  -- Brighter when focused, still visible when playing
    })
    
    -- Stage status lights for this lane
    for stage_idx = 1, 4 do
      local stage = lane.stages[stage_idx]
      local is_stage_focused = is_focused and stage_idx == _seeker.ui_state.get_focused_stage()
      local is_stage_active = lane.playing and stage_idx == lane.current_stage_index  -- Only active if lane is playing
      local has_active_notes = stage and stage.active_notes and #stage.active_notes > 0
      
      table.insert(lights, {
        x = 110 + ((stage_idx - 1) * 4),
        y = START_Y + (lane_idx * 2),
        is_active = is_stage_active or has_active_notes,
        speed = has_active_notes and 8 or 0,  -- Quick flash for note events
        base_level = is_stage_focused and 4 or (is_stage_active and 2 or 1)
      })
    end
  end
  
  -- Draw all lights
  for _, light in ipairs(lights) do
    local brightness = light.base_level
    
    if light.is_active then
      if light.speed > 0 then
        -- Pulsing light (for stages)
        local activity = (util.time() * light.speed) % 1
        if activity < 0.1 then
          brightness = 15
        elseif activity < 0.2 then
          brightness = math.floor((0.2 - activity) * 150)
        end
      else
        -- Steady light (for playing lanes)
        brightness = 12
      end
    end
    
    screen.level(brightness)
    screen.circle(light.x, light.y, 1.25)  -- Slightly smaller circles to fit better
    screen.fill()
  end
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
  local stage_idx = _seeker.ui_state.get_focused_stage()
  local info_text = string.format("L%d S%d", lane_idx, stage_idx)
  
  -- Calculate position to be right-aligned with some padding from blinkenlights
  local SCREEN_WIDTH = 128
  local BLINK_PADDING = 26  -- Leave space for blinkenlights
  local text_width = screen.text_extents(info_text)
  local x = SCREEN_WIDTH - BLINK_PADDING - text_width
  
  screen.level(0)
  screen.move(x, 60)
  screen.text(info_text)
  
  -- Draw system status lights
  self:draw_blinkenlights()
end

-- Draw parameter list with more horizontal space
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

-- Default drawing implementation
function Section:draw_default()
  screen.clear()
  
  -- Draw vertical header on left
  self:draw_footer()
  
  -- Draw parameters with full width
  if #self.params > 0 then
    self:draw_params(0)
  end
  
  screen.update()
end

-- Default parameter navigation
function Section:handle_enc_default(n, d)
  if n == 2 then
    -- Navigate parameters
    local new_index = util.clamp(
      self.state.selected_index + d,
      0,
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
  -- Handle K3 press for action items
  if n == 3 and z == 1 and self.state.selected_index > 0 then
    local param = self.params[self.state.selected_index]
    if param.action then
      self:modify_param(param, 1)
    end
  end
end

function Section:handle_grid_key(x, y, z)
  -- Default implementation does nothing
end

-- Optional lifecycle methods
function Section:enter()
  -- Called when section becomes active
end

function Section:exit()
  -- Called when leaving this section
end

function Section:update()
  -- Called on each UI update
end

return Section 