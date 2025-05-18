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
        { id = "mode", name = "Mode", custom = true },
        { id = "quantize_division", name = "Quantize" }
    }
  })
  setmetatable(section, RecordingSection)

  function section:get_param_value(param)
    -- Handle our custom mode parameter
    if param.id == "mode" then
      local mode_names = {"New", "Overdub"}
      return mode_names[_seeker.motif_recorder.recording_mode]
    end
    
    -- For other parameters, use default behavior
    return Section.get_param_value(self, param)
  end

  return section
end

return RecordingSection