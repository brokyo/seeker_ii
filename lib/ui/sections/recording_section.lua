-- recording_section.lua
local Section = include('lib/ui/section')
local RecordingSection = setmetatable({}, { __index = Section })
RecordingSection.__index = RecordingSection


function RecordingSection.new()
  local section = Section.new({
    id = "RECORDING",
    name = "Recording",
    icon = "⏺",
    params = {
        { id = "quantize_division", name = "Quantize" },
        { id = "count_in_bars", name = "Count-in Bars" }
    }
  })
  setmetatable(section, RecordingSection)

  function section:get_param_value(param)
    if param.id == "count_in_bars" then
      local value = params:get("count_in_bars")
      return value == 0 and "off" or value
    end
    
    -- For other parameters, use default behavior
    return Section.get_param_value(self, param)
  end

  return section
end

return RecordingSection