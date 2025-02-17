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
        id = "rec_status",
        name = "Status",
        value = "Ready",
        spec = {
          type = "string"
        }
      },
      {
        id = "rec_length",
        name = "Length",
        value = "0 steps",
        spec = {
          type = "string"
        }
      }
    }
  })
  
  setmetatable(section, RecSection)
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