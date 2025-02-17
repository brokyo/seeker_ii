-- overdub_section.lua
local Section = include("lib/ui/section")

local OverdubSection = {}
OverdubSection.__index = OverdubSection
setmetatable(OverdubSection, Section)

function OverdubSection.new(config)
  local section = Section.new({
    id = "OVERDUB",
    name = "Motif:Overdub",
    icon = "⊕",
    params = {
      {
        id = "overdub_info",
        name = "Overdub Info",
        separator = true
      },
      {
        id = "overdub_status",
        name = "Status",
        value = "Ready",
        spec = {
          type = "string"
        }
      },
      {
        id = "original_length",
        name = "Original Length",
        value = "0 steps",
        spec = {
          type = "string"
        }
      },
      {
        id = "new_events",
        name = "New Events",
        value = "0",
        spec = {
          type = "string"
        }
      }
    }
  })
  
  setmetatable(section, OverdubSection)
  return section
end

function OverdubSection:get_param_value(param)
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local motif = _seeker.lanes[focused_lane].motif
  
  if param.id == "overdub_status" then
    if _seeker.motif_recorder.is_recording then
      return "Overdubbing..."
    elseif #motif.events == 0 then
      return "No motif to overdub"
    else
      return "Ready"
    end
  elseif param.id == "original_length" then
    if _seeker.motif_recorder.is_recording then
      -- Show original motif length during overdub
      return string.format("%d steps", #_seeker.motif_recorder.original_motif.events)
    else
      return string.format("%d steps", #motif.events)
    end
  elseif param.id == "new_events" then
    if _seeker.motif_recorder.is_recording then
      -- Show count of new events added during overdub
      local new_count = _seeker.motif_recorder:get_current_length() - #_seeker.motif_recorder.original_motif.events
      return tostring(new_count)
    end
    return "0"
  end
  
  return Section.get_param_value(self, param)
end

return OverdubSection.new() 