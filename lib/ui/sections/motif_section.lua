-- motif_section.lua
local Section = include('lib/ui/section')
local MotifSection = setmetatable({}, { __index = Section })
MotifSection.__index = MotifSection

function MotifSection.new()
  local section = Section.new({
    id = "MOTIF",
    name = "Motif:Playback",
    icon = "☸",
    params = {}
  })

  setmetatable(section, MotifSection)

  function section:get_param_value(param)
    if param.id == "recorded_duration" then
      local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
      if lane and lane.motif then
        -- Show custom duration if set, otherwise show genesis duration
        if lane.motif.custom_duration then
          return string.format("%.2f", lane.motif.custom_duration)
        else
          return string.format("%.2f", lane.motif.genesis.duration)
        end
      end
      return "0.00"
    end
    return Section.get_param_value(self, param)
  end

  function section:modify_param(param, delta)
    if param.id == "recorded_duration" then
      local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
      if lane and lane.motif then
        -- Get current value (either custom or genesis)
        local current = lane.motif.custom_duration or lane.motif.genesis.duration
        
        -- If this is the first adjustment (no custom duration set), snap to nearest 0.25
        if not lane.motif.custom_duration then
          current = math.floor(current * 4 + 0.5) / 4
        end
        
        local new_value = util.clamp(current + (delta * param.spec.step), param.spec.min, param.spec.max)
        
        -- Store in custom_duration to preserve genesis
        lane.motif.custom_duration = new_value
        
        -- Update displayed value
        param.value = string.format("%.2f", new_value)
      end
    else
      Section.modify_param(self, param, delta)
    end
  end

  function section:handle_key(n, z)
    -- Handle K3 press for resetting duration
    if n == 3 and z == 1 and self.state.selected_index > 0 then
      local param = self.params[self.state.selected_index]
      if param.id == "recorded_duration" then
        local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
        if lane and lane.motif then
          -- Clear custom duration to revert to genesis
          lane.motif.custom_duration = nil
          -- Update displayed value
          param.value = string.format("%.2f", lane.motif.genesis.duration)
        end
      else
        -- For other params, use default behavior
        Section.handle_key(self, n, z)
      end
    else
      Section.handle_key(self, n, z)
    end
  end

  -- Override draw_params to customize read-only parameter display
  function section:draw_params(start_y)
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
        
        -- Simple selection highlight
        if is_selected then
          screen.level(2)
          screen.rect(0, y - 6, 128, 8)
          screen.fill()
        end
        
        -- Parameter name
        screen.level(is_selected and 15 or 4)
        screen.move(2, y)
        if param.readonly then
          screen.text("○ " .. param.name) -- Add circle indicator for read-only
        else
          screen.text(param.name)
        end
        
        -- Parameter value (right-aligned)
        local value = self:get_param_value(param)
        local value_x = 120 - screen.text_extents(value)
        screen.level(param.readonly and 2 or (is_selected and 15 or 4)) -- Dimmer for read-only
        screen.move(value_x, y)
        screen.text(value)
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

  function section:update_focused_motif(lane_idx)
    -- Get the current lane's motif
    local lane = _seeker.lanes[lane_idx]
    local current_duration = lane and lane.motif and (lane.motif.custom_duration or lane.motif.genesis.duration) or 0
    
    self.params = {
      { 
        id = "recorded_duration", 
        name = "Duration (k3 reset)", 
        value = string.format("%.2f", current_duration),
        spec = {
          type = "number",
          min = 0.25,  -- Minimum duration of 1/4 beat
          max = 64,    -- Maximum duration of 64 beats
          step = 0.25  -- Allow quarter beat increments
        }
      },
      { id = "lane_" .. lane_idx .. "_playback_offset", name = "Octave Shift" },
      { id = "lane_" .. lane_idx .. "_volume", name = "Volume" },
      { id = "lane_" .. lane_idx .. "_speed", name = "Speed" }
    }
  end

  -- Initialize with current lane
  local initial_lane = _seeker.ui_state.get_focused_lane()
  section:update_focused_motif(initial_lane)

  return section
end

return MotifSection
