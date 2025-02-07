-- motif_section.lua
local Section = include('lib/ui/section')
local MotifSection = setmetatable({}, { __index = Section })
MotifSection.__index = MotifSection

function MotifSection.new()
  local section = Section.new({
    id = "MOTIF",
    name = "Motif",
    icon = "☸",
    params = {}
  })

  setmetatable(section, MotifSection)

  function section:update_focused_motif(lane_idx)
    self.params = {
      { id = "lane_" .. lane_idx .. "_octave", name = "Octave" },
      { id = "lane_" .. lane_idx .. "_volume", name = "Volume" },
      { id = "lane_" .. lane_idx .. "_speed", name = "Speed" },
      { id = "lane_" .. lane_idx .. "_custom_duration", name = "Duration" }
    }

    self.name = string.format("Lane %d Motif", lane_idx)
  end

  -- Initialize with current lane
  local initial_lane = _seeker.ui_state.get_focused_lane()
  section:update_focused_motif(initial_lane)

  return section
end

return MotifSection
