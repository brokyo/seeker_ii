-- lane_section.lua
local Section = include('lib/ui/section')
local LaneSection = setmetatable({}, { __index = Section })
LaneSection.__index = LaneSection

function LaneSection.new()
  local section = Section.new({
    id = "LANE",
    name = "Layer 0",
    icon = "⌸",
    params = {} -- Start empty, will be populated when lane focus changes
  })
  
  setmetatable(section, LaneSection)
  
  -- Add method to update params for new lane
  function section:update_focused_lane(new_lane_idx)
    self.params = {
      { separator = true, name = "Engine — Mx Samples" },
      { id = "lane_" .. new_lane_idx .. "_instrument", name = "Instrument" },
      { separator = true, name = "MIDI" },
      { id = "lane_" .. new_lane_idx .. "_midi_device", name = "MIDI Device" },
      { id = "lane_" .. new_lane_idx .. "_midi_channel", name = "MIDI Channel" },
      { separator = true, name = "Eurorack" },
      { id = "lane_" .. new_lane_idx .. "_gate_out", name = "Gate Out" },
      { id = "lane_" .. new_lane_idx .. "_cv_out", name = "CV Out" },
      { id = "lane_" .. new_lane_idx .. "_loop_start_trigger", name = "Loop Trigger" }
    }
    -- Update section name with lane number
    self.name = string.format("Layer %d", new_lane_idx)
  end
  
  -- Initialize with current lane
  local initial_lane = _seeker.ui_state.get_focused_lane()
  section:update_focused_lane(initial_lane)
  
  return section
end

return LaneSection