-- rec_section.lua
local Section = include("lib/ui/section")

local RecSection = {}
RecSection.__index = RecSection
setmetatable(RecSection, Section)

function RecSection.new(config)
  local section = Section.new({
    id = "RECORDING",
    name = "Motif Recorder",
    description = "Record motifs by holding grid key. Recording starts on first note and ends when you press the grid to stop.",
    params = {
      {
        id = "rec_info",
        name = "Recording Config",
        get_display_name = function()
          if _seeker.motif_recorder.is_recording then
            return "Recording Config ⏺"
          else
            return "Recording Config"
          end
        end,
        separator = true
      },
      {
        id = "quantize_division",
        name = "Quantize"
      }
    }
  })
  
  setmetatable(section, RecSection)

  -- Override draw to add help text
  function section:draw()
    screen.clear()
    
    -- Check if showing description
    if self.state.showing_description then
      -- Use parent class's default drawing for description
      Section.draw_default(self)
      return
    end
    
    -- Draw parameters
    self:draw_params(0)
    
    -- Draw help text
    local help_text
    if _seeker.motif_recorder.is_recording then
      help_text = "⏹: tap grid key"
    else
      help_text = "⏺: hold grid key"
    end
    local width = screen.text_extents(help_text)
    
    -- Brighten text during long press
    if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "RECORDING" then
      screen.level(15)  -- Full brightness during hold
    else
      screen.level(2)   -- Normal dim state
    end
    
    screen.move(64 - width/2, 46)
    screen.text(help_text)
    
    -- Draw footer
    self:draw_footer()
    
    screen.update()
  end

  -- Override draw_params to handle dynamic separator names
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
        
        if param.separator then
          -- Draw separator with dynamic name if available
          screen.level(4)
          screen.move(2, y)
          local display_name = param.get_display_name and param.get_display_name() or param.name
          screen.text(display_name)
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

  return section
end

function RecSection:get_param_value(param)
  if param.id == "rec_status" then
    if _seeker.motif_recorder.is_recording then
      return "Recording..."
    else
      return "Ready"
    end
  elseif param.id == "rec_length" then
    if _seeker.motif_recorder.is_recording then
      return string.format("%d steps", _seeker.motif_recorder:get_current_length())
    else
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local motif = _seeker.lanes[focused_lane].motif
      return string.format("%d steps", #motif.events)
    end
  end
  
  return Section.get_param_value(self, param)
end

return RecSection.new() 