-- rec_section.lua
local Section = include("lib/ui/section")

local RecSection = {}
RecSection.__index = RecSection
setmetatable(RecSection, Section)

function RecSection.new(config)
  local section = Section.new({
    id = "RECORDING",
    name = "Motif:Record",
    icon = "●",
    params = {
      {
        id = "rec_info",
        name = "Recording Info",
        separator = true
      },
      {
        id = "quantize_division",
        name = "Quantize"
      }
    }
  })
  
  setmetatable(section, RecSection)

  -- Override draw to add help text above footer
  function section:draw()
    screen.clear()
    
    -- Draw parameters
    self:draw_params(0)
    
    -- Draw help text just above footer
    screen.level(2)
    
    -- First line
    local text1 = "Long press to start"
    local width1 = screen.text_extents(text1)
    screen.move(64 - width1/2, 42)
    screen.text(text1)
    
    -- Second line
    local text2 = "Short press to stop"
    local width2 = screen.text_extents(text2)
    screen.move(64 - width2/2, 50)
    screen.text(text2)
    
    -- Draw footer
    self:draw_footer()
    
    screen.update()
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