-- overdub_section.lua
local Section = include("lib/ui/section")

local OverdubSection = {}
OverdubSection.__index = OverdubSection
setmetatable(OverdubSection, Section)

function OverdubSection.new(config)
  local section = Section.new({
    id = "OVERDUB",
    name = "Motif Overdub",
    description = "Overdub motifs by holding grid key. Velocity and tuning respected. Visuals get out-of-sync but sound is correct.",
    params = {
      {
        id = "overdub_info",
        name = "Overdub Config",
        get_display_name = function() 
          if _seeker.motif_recorder.is_recording then
            return "Overdub Config [⏺]"
          else
            return "Overdub Config"
          end
        end,
        separator = true
      },
      {
        id = "quantize_division",
        name = "Quantize"
      }
    }
  })
  
  setmetatable(section, OverdubSection)
  
  -- Override draw to add help text and loop visualization
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
    
    -- Draw loop visualization
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[focused_lane]
    local motif = lane.motif
    
    if #motif.events > 0 then
      -- Constants for visualization
      local VIS_Y = 32        -- Vertical position
      local VIS_HEIGHT = 6    -- Height of visualization
      local VIS_X = 8         -- Left margin
      local VIS_WIDTH = 112   -- Width of visualization
      
      -- Get the effective duration (handles custom duration)
      local loop_duration = motif:get_duration()
      
      -- Draw loop outline
      screen.level(4)
      screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
      screen.stroke()
      
      -- First find the maximum generation for brightness scaling
      local max_gen = 1
      for _, event in ipairs(motif.events) do
        if event.generation and event.generation > max_gen then
          max_gen = event.generation
        end
      end

      -- Draw existing event markers with generation-based brightness
      for _, event in ipairs(motif.events) do
        if event.type == "note_on" then
          -- Calculate brightness based on generation (older=dimmer, newer=brighter)
          local gen = event.generation or 1
          -- Scale brightness from 2-12 based on generation
          local brightness = 2 + math.floor((gen / max_gen) * 10)
          screen.level(brightness)
          
          -- Calculate x position based on event time relative to loop duration
          local x = VIS_X + (event.time / loop_duration * VIS_WIDTH)
          -- Draw small vertical line for event
          screen.move(x, VIS_Y)
          screen.line(x, VIS_Y + VIS_HEIGHT)
          screen.stroke()
        end
      end
      
      -- Draw new events being recorded (brightest)
      if _seeker.motif_recorder.is_recording then
        screen.level(15)  -- Brightest
        for _, event in ipairs(_seeker.motif_recorder.events) do
          -- Only show newly added events (not the copied ones from previous generations)
          if event.generation == _seeker.motif_recorder.current_generation and event.type == "note_on" then
            -- Use event time directly from recorder
            local x = VIS_X + (event.time / loop_duration * VIS_WIDTH)
            -- Draw slightly taller line for new events
            screen.move(x, VIS_Y - 1)
            screen.line(x, VIS_Y + VIS_HEIGHT + 1)
            screen.stroke()
          end
        end
      end

      -- Draw playhead when recording or playing
      if _seeker.motif_recorder.is_recording or lane.playing then
        -- Always use current beat position in the loop
        local current_beat = clock.get_beats()
        local position = current_beat % loop_duration
        
        -- If playing, use the lane's timing reference for better sync
        if lane.playing then
          local current_stage = lane.stages[lane.current_stage_index]
          if current_stage.last_start_time then
            -- Calculate elapsed time since stage start
            local elapsed_time = current_beat - current_stage.last_start_time
            -- Adjust for lane speed (multiply by speed to match how far into motif we are)
            position = (elapsed_time * lane.speed) % loop_duration
          end
        end
        
        local x = VIS_X + (position / loop_duration * VIS_WIDTH)
        screen.level(15)  -- Brightest
        screen.move(x, VIS_Y - 1)
        screen.line(x, VIS_Y + VIS_HEIGHT + 1)
        screen.stroke()
      end
    end
    
    -- Draw compact help text
    local help_text
    if _seeker.motif_recorder.is_recording then
      help_text = "⏹: tap grid key"
    else
      help_text = "◉: hold grid key"
    end
    local width = screen.text_extents(help_text)
    
    -- Brighten text during long press
    if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "OVERDUB" then
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

  -- Override draw_params to handle dynamic separator names
  function section:draw_params(start_y)
    local FOOTER_Y = 52
    local ITEM_HEIGHT = 10
    local visible_height = FOOTER_Y - start_y
    local max_visible_items = math.floor(visible_height / ITEM_HEIGHT)
    
    -- Ensure scroll offset stays in valid range
    local max_scroll = math.max(0, #self.params - max_visible_items)
    self.state.scroll_offset = util.clamp(self.state.scroll_offset, 0, max_scroll)
    
    -- Draw visible parameters
    for i = 1, math.min(max_visible_items, #self.params) do
      local param_idx = i + self.state.scroll_offset
      local param = self.params[param_idx]
      if param then
        local y = start_y + (i * ITEM_HEIGHT)
        local is_selected = self.state.selected_index == param_idx
        
        if param.separator then
          -- Draw separator with dynamic name if available
          screen.level(4)
          screen.move(2, y)
          local display_name = param.get_display_name and param.get_display_name() or param.name
          screen.text(display_name)
          screen.move(2, y + 1)
          screen.line(126, y + 1)
          screen.stroke()
        else
          -- Draw normal parameter
          if is_selected then
            screen.level(2)
            screen.rect(0, y - 6, 128, 8)
            screen.fill()
          end
          
          -- Parameter name
          screen.level(is_selected and 15 or 4)
          screen.move(2, y)
          screen.text(param.name)
          
          -- Parameter value (right-aligned)
          local value = self:get_param_value(param)
          local value_x = 120 - screen.text_extents(value)
          screen.move(value_x, y)
          screen.text(value)
        end
      end
    end
    
    -- Draw scroll indicators if needed
    if self.state.scroll_offset > 0 then
      screen.level(4)
      screen.move(123, start_y + 4)
      screen.text("▲")
    end
    if self.state.scroll_offset < max_scroll then
      screen.level(4)
      screen.move(123, FOOTER_Y - 4)
      screen.text("▼")
    end
  end

  -- Override key handler to show/hide description
  function section:key(n, z)
    if n == 2 then
      self.state.showing_description = z == 1
      -- Redraw to show/hide description
      self:dirty()
    end
    -- Call parent key handler
    Section.key(self, n, z)
  end

  -- Remove the K2 check from get_param_value since we're handling it differently now
  function section:get_param_value(param)
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
        return string.format("%d steps", #_seeker.motif_recorder.original_motif.events)
      else
        return string.format("%d steps", #motif.events)
      end
    elseif param.id == "new_events" then
      if _seeker.motif_recorder.is_recording then
        local new_count = _seeker.motif_recorder:get_current_length() - #_seeker.motif_recorder.original_motif.events
        return tostring(new_count)
      end
      return "0"
    end
    
    return Section.get_param_value(self, param)
  end

  return section
end

return OverdubSection.new() 