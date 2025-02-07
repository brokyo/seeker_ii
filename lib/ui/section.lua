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

function Section:draw_footer()
  -- Draw footer background
  screen.level(8)
  screen.rect(0, 52, 128, 12)
  screen.fill()
  
  -- Draw section name
  screen.level(0)
  screen.move(2, 60)
  screen.text(self.name)
  
  -- Draw subtle moving dot
  screen.level(2)
  local x = 124 + math.sin(util.time() * 2) * 2  -- Move between 122-126
  screen.circle(x, 58, 1)
  screen.fill()
end

-- Draw parameter list with more horizontal space
function Section:draw_params(start_y)
  for i, param in ipairs(self.params) do
    local y = start_y + (i * 10)
    local is_selected = self.state.selected_index == i
    
    -- Simple selection highlight
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
    local value_x = 124 - screen.text_extents(value)
    screen.move(value_x, y)
    screen.text(value)
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
    self.state.selected_index = util.clamp(
      self.state.selected_index + d,
      0,
      #self.params
    )
  elseif n == 3 and self.state.selected_index > 0 then
    -- Modify selected parameter
    local param = self.params[self.state.selected_index]
    self:modify_param(param, d)
  end
end

-- Required interface methods with default implementations
function Section:draw()
  self:draw_default()
end

function Section:handle_enc(n, d)
  self:handle_enc_default(n, d)
end

function Section:handle_key(n, z)
  -- Default implementation does nothing
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