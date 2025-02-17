-- octave_section.lua
local Section = include('lib/ui/section')
local musicutil = require('musicutil')
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
  
  -- Initialize state properly
  section.state = {
    selected_index = 0,
    scroll_offset = 0,
    is_active = false
  }
  
  -- Override draw to show a custom view
  function section:draw()
    screen.clear()
    
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local octave = params:get("lane_" .. lane_idx .. "_keyboard_octave")
    local offset = params:get("lane_" .. lane_idx .. "_grid_offset")
    
    -- Draw octave number
    screen.level(15)
    screen.font_size(32)
    screen.move(32, 28)
    screen.text_center(octave)
    
    -- Draw grid offset
    screen.font_size(32)
    screen.move(96, 28)
    if offset >= 0 then
      screen.text_center("+" .. offset)
    else
      screen.text_center(offset)  -- No need for + sign on negative numbers
    end
    
    -- Draw labels
    screen.font_size(8)
    screen.level(4)
    screen.move(32, 40)
    screen.text_center("OCTAVE")
    screen.move(96, 40)
    screen.text_center("OFFSET")
    
    -- Draw grid button hints
    screen.move(32, 50)
    screen.text_center("(1,5) (2,5)")
    screen.move(96, 50)
    screen.text_center("(3,5) (4,5)")

    -- Draw footer
    self:draw_footer()
    
    screen.update()
  end
  
  -- Override encoder handling
  function section:handle_enc(n, d)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    
    if n == 2 then
      -- E2 controls octave
      local current = params:get("lane_" .. lane_idx .. "_keyboard_octave")
      params:set("lane_" .. lane_idx .. "_keyboard_octave", 
        util.clamp(current + d, 1, 7))
    elseif n == 3 then
      -- E3 controls grid offset
      local current = params:get("lane_" .. lane_idx .. "_grid_offset")
      params:set("lane_" .. lane_idx .. "_grid_offset", 
        util.clamp(current + d, -8, 8))
    end
  end
  
  return section
end

return OctaveSection 