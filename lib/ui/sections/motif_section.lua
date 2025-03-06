-- motif_section.lua
local Section = include('lib/ui/section')
local MotifSection = setmetatable({}, { __index = Section })
MotifSection.__index = MotifSection

function MotifSection.new()
  local section = Section.new({
    id = "MOTIF",
    name = "Motif Playback",
    description = "Configure motifs created in generate or record. Hold grid to start and stop playback.",
  })

  setmetatable(section, MotifSection)

  -- Override draw to add help text
  function section:draw()
    screen.clear()
    
    -- Check if showing description
    if self.state.showing_description then
      -- Use parent class's default drawing for description
      Section.draw_default(self)
      return
    end
    
    -- Draw parameters
    self:draw_params(0)
    
    -- Draw help text
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local help_text
    if lane and lane.playing then
      help_text = "⏹: hold grid key"
    else
      help_text = "⏵: hold grid key"
    end
    local width = screen.text_extents(help_text)
    
    -- Brighten text during long press
    if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "MOTIF" then
      screen.level(15)  -- Full brightness during hold
    else
      screen.level(2)   -- Normal dim state
    end
    
    screen.move(64 - width/2, 46)
    screen.text(help_text)
    
    -- Draw footer
    self:draw_footer()
    
    screen.update()
  end

  function section:get_param_value(param)
    if param.id == "recorded_duration" then
      local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
      if lane and lane.motif then
        -- Show custom duration if set, otherwise show genesis duration
        if lane.motif.custom_duration then
          return string.format("%.2f", lane.motif.custom_duration)
        else
          return string.format("%.2f", lane.motif.genesis.duration)
        end
      end
      return "0.00"
    end
    return Section.get_param_value(self, param)
  end

  function section:modify_param(param, delta)
    if param.id == "recorded_duration" then
      local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
      if lane and lane.motif then
        -- Get current value (either custom or genesis)
        local current = lane.motif.custom_duration or lane.motif.genesis.duration
        
        -- If this is the first adjustment (no custom duration set), snap to nearest 0.25
        if not lane.motif.custom_duration then
          current = math.floor(current * 4 + 0.5) / 4
        end
        
        local new_value = util.clamp(current + (delta * param.spec.step), param.spec.min, param.spec.max)
        
        -- Store in custom_duration to preserve genesis
        lane.motif.custom_duration = new_value
        
        -- Update displayed value
        param.value = string.format("%.2f", new_value)
      end
    else
      Section.modify_param(self, param, delta)
    end
  end

  function section:handle_key(n, z)
    -- Handle K3 press for resetting duration
    if n == 3 and z == 1 and self.state.selected_index > 0 then
      local param = self.params[self.state.selected_index]
      if param.id == "recorded_duration" then
        local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
        if lane and lane.motif then
          -- Clear custom duration to revert to genesis
          lane.motif.custom_duration = nil
          -- Update displayed value
          param.value = string.format("%.2f", lane.motif.genesis.duration)
        end
      else
        -- For other params, use default behavior
        Section.handle_key(self, n, z)
      end
    else
      Section.handle_key(self, n, z)
    end
  end

  function section:update_focused_motif(lane_idx)
    -- Get the current lane's motif
    local lane = _seeker.lanes[lane_idx]
    local current_duration = lane and lane.motif and (lane.motif.custom_duration or lane.motif.genesis.duration) or 0
    
    self.params = {
      {
        id = "motif_info",
        name = "Playback Config",
        separator = true
      },
      { 
        id = "recorded_duration", 
        name = "Duration (k3 reset)", 
        value = string.format("%.2f", current_duration),
        spec = {
          type = "number",
          min = 0.25,
          max = 128,
          step = 0.25  -- Step in beat increment
        }
      },
      { id = "lane_" .. lane_idx .. "_playback_offset", name = "Octave Shift" },
      { id = "lane_" .. lane_idx .. "_scale_degree_offset", name = "Scale Degree Shift" },
      { id = "lane_" .. lane_idx .. "_speed", name = "Speed" }
    }
  end

  -- Initialize with current lane
  local initial_lane = _seeker.ui_state.get_focused_lane()
  section:update_focused_motif(initial_lane)

  -- Add enter method to update when section becomes active
  function section:enter()
    Section.enter(self)  -- Call parent enter method
    self:update_focused_motif(_seeker.ui_state.get_focused_lane())
  end

  return section
end

return MotifSection
