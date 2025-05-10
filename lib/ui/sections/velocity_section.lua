local Section = include('lib/ui/section')
local VelocityRegion = include('lib/grid/regions/velocity_region')

local VelocitySection = setmetatable({}, { __index = Section })
VelocitySection.__index = VelocitySection

function VelocitySection.new()
  local section = Section.new({
    id = "VELOCITY",
    name = "Velocity",
    description = "Adjust velocity dynamics. Higher values create louder notes.",
    params = {}
  })

  setmetatable(section, VelocitySection)
  
  -- HOTFIX: Skip Arc integration for this section to prevent crashes
  -- TODO: Properly implement Arc integration for this custom UI section
  section.skip_arc = true
  
  function section:draw()
    screen.clear()

    -- Check if showing description
    if self.state.showing_description then
      -- Use parent class's default drawing for description
      Section.draw_default(self)
      return
    end

    local velocity = VelocityRegion.velocity_levels[_seeker.velocity]
    
    -- Draw velocity value
    screen.level(15)
    screen.font_size(32)
    screen.move(32, 28)
    screen.text_center(velocity)
    
    -- Draw velocity abbreviation
    screen.font_size(32)
    screen.move(96, 28)
    local abbrev
    if velocity <= 40 then
      abbrev = "pp"
    elseif velocity <= 70 then
      abbrev = "mp"
    elseif velocity <= 100 then
      abbrev = "f"
    else
      abbrev = "ff"
    end
    screen.text_center(abbrev)
    
    -- Draw labels
    screen.font_size(8)
    screen.level(4)
    screen.move(32, 40)
    screen.text_center("VALUE")
    screen.move(96, 40)
    screen.text_center("DYNAMIC")
    
    -- Draw grid button hints
    screen.move(64, 50)
    screen.text_center("(1-4,7)")

    -- Draw footer
    self:draw_footer()
    
    screen.update()
  end

  -- Add key handler for description
  function section:key(n, z)
    if n == 2 then
      self.state.showing_description = z == 1
      -- Redraw to show/hide description
      self:dirty()
    end
    -- Call parent key handler
    Section.key(self, n, z)
  end

  return section
end

return VelocitySection