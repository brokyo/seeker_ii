-- tuning_section.lua
local Section = include('lib/ui/section')
local TuningSection = setmetatable({}, { __index = Section })
TuningSection.__index = TuningSection

function TuningSection.new()
  local section = Section.new({
    id = "TUNING",
    name = "TUNING",
    icon = "⚘",
    params = {
      { id = "root_note", name = "Root Note" },
      { id = "scale_type", name = "Scale" }
    }
  })
  setmetatable(section, TuningSection)
  return section
end

return TuningSection 