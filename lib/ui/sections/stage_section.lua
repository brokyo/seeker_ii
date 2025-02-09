-- stage_section.lua
local Section = include('lib/ui/section')
local StageSection = setmetatable({}, { __index = Section })
StageSection.__index = StageSection


function StageSection.new()
  local section = Section.new({
    id = "STAGE",
    name = "Stage 0",
    icon = "⌸",
    params = {}
  })
  
  setmetatable(section, StageSection)

  function section:update_focused_stage(new_stage_idx)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    self.params = {
      { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_mute", name = "Mute" },
      { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_reset_motif", name = "Reset Motif" },
      { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_loops", name = "Loops" },
      { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_loop_trigger", name = "Loop Trigger" }
    }

    self.name = string.format("Stage %d", new_stage_idx)
  end

  return section
end

return StageSection

