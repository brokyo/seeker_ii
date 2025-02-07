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
  
  -- Lane status lights (90-102)
  for i = 1, 4 do
    local lane = _seeker.lanes[i]
    local is_focused = i == _seeker.ui_state.get_focused_lane()
    table.insert(lights, {
      x = 86 + (i * 4),
      is_active = lane.playing,
      speed = 0,  -- No pulse when playing, just steady light
      base_level = is_focused and 4 or 2  -- Brighter when focused, still visible when playing
    })
  end
  
  -- Stage status lights (106-118)
  for i = 1, 4 do
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local stage = lane.stages[i]
    local is_focused = i == _seeker.ui_state.get_focused_stage()
    local is_active = stage and stage.active_notes and #stage.active_notes > 0
    
    table.insert(lights, {
      x = 106 + (i * 4),  -- Start at 106 to leave room for all 4 stages before BPM light
      is_active = is_active,  -- Flash on note events
      speed = 8,  -- Quick flash for note events
      base_level = is_focused and 2 or 1
    })
  end
  
  -- BPM indicator (124)
  local bpm_phase = (util.time() * params:get("clock_tempo") / 60) % 1
  table.insert(lights, {
    x = 124,
    is_active = true,
    speed = 0,
    base_level = bpm_phase < 0.1 and 4 or 1  -- Simple on/off at quarter note
  })
  
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
    screen.circle(light.x, 58, 1.5)
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
  
  -- Draw system status lights
  self:draw_blinkenlights()
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