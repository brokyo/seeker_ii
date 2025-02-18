local Section = include('lib/ui/section')
local VelocityRegion = include('lib/grid/regions/velocity_region')

local VelocitySection = setmetatable({}, { __index = Section })
VelocitySection.__index = VelocitySection

function VelocitySection.new()
  local section = Section.new({
    id = "VELOCITY",
    name = "Velocity",
    icon = "🎯",
    params = {}
  })

  setmetatable(section, VelocitySection)

  function section:draw()
    screen.clear()

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

  return section
end

return VelocitySection