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
        { id = "recording_mode", name = "Mode" },
        { id = "quantize_division", name = "Quantize" }
    }
  })
  setmetatable(section, RecordingSection)

  function section:get_param_value(param)
    -- For other parameters, use default behavior
    return Section.get_param_value(self, param)
  end

  return section
end

return RecordingSection