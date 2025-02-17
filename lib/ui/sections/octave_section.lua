-- octave_section.lua
local Section = include('lib/ui/section')
local OctaveSection = setmetatable({}, { __index = Section })
OctaveSection.__index = OctaveSection

function OctaveSection.new()
  local section = Section.new({
    id = "OCTAVE",
    name = "Keyboard Octave",
    icon = "⌨",
    params = {}
  })
  
  setmetatable(section, OctaveSection)
  
  -- Override draw to show a custom view
  function section:draw()
    screen.clear()
    
    -- Draw the octave number prominently in the center
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local octave = params:get("lane_" .. lane_idx .. "_keyboard_octave")
    
    -- Draw large octave number
    screen.level(15)
    screen.font_size(32)
    screen.move(64, 32)
    screen.text_center(octave)
    
    -- Draw help text
    screen.font_size(8)
    screen.level(4)
    screen.move(64, 45)
    screen.text_center("Use grid buttons to change")
    
    -- Draw footer
    self:draw_footer()
    
    screen.update()
  end
  
  return section
end

return OctaveSection 