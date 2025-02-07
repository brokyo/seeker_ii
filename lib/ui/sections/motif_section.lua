-- motif_section.lua
local Section = include('lib/ui/section')
local MotifSection = setmetatable({}, { __index = Section })
MotifSection.__index = MotifSection

function MotifSection.new()
  local section = Section.new({
    id = "MOTIF",
    name = "Motif",
    icon = "☸",
    params = {}
  })

  setmetatable(section, MotifSection)

  function section:get_param_value(param)
    if param.id == "recorded_duration" then
      return param.value -- Use the pre-formatted value for read-only param
    end
    return Section.get_param_value(self, param) -- Use default behavior for other params
  end

  function section:modify_param(param, delta)
    if param.readonly then return end -- Don't modify read-only params
    Section.modify_param(self, param, delta)
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
    local recorded_duration = lane and lane.motif and lane.motif.genesis.duration or 0
    
    self.params = {
      { id = "recorded_duration", name = "Recorded Duration", value = string.format("%.2f", recorded_duration), readonly = true },
      { id = "lane_" .. lane_idx .. "_octave", name = "Octave" },
      { id = "lane_" .. lane_idx .. "_volume", name = "Volume" },
      { id = "lane_" .. lane_idx .. "_speed", name = "Speed" },
      { id = "lane_" .. lane_idx .. "_custom_duration", name = "Duration" }
    }

    self.name = string.format("Lane %d Motif", lane_idx)
  end

  -- Initialize with current lane
  local initial_lane = _seeker.ui_state.get_focused_lane()
  section:update_focused_motif(initial_lane)

  return section
end

return MotifSection
