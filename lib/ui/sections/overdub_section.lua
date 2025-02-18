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
        id = "quantize_division",
        name = "Quantize"
      }
    }
  })
  
  setmetatable(section, OverdubSection)
  
  -- Add redraw clock
  function section:enter()
    Section.enter(self)
    -- Start redraw clock when entering section
    self.redraw_clock = clock.run(function()
      while self.state.is_active do
        _seeker.screen_ui.set_needs_redraw()
        clock.sleep(1/30) -- 30fps to match screen refresh
      end
    end)
  end
  
  function section:exit()
    -- Stop redraw clock when leaving section
    if self.redraw_clock then
      clock.cancel(self.redraw_clock)
      self.redraw_clock = nil
    end
    Section.exit(self)
  end

  -- Override draw to add help text and loop visualization
  function section:draw()
    screen.clear()
    
    -- Draw parameters
    self:draw_params(0)
    
    -- Draw loop visualization
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local motif = _seeker.lanes[focused_lane].motif
    
    if #motif.events > 0 then
      -- Constants for visualization
      local VIS_Y = 32        -- Vertical position
      local VIS_HEIGHT = 6    -- Height of visualization
      local VIS_X = 8         -- Left margin
      local VIS_WIDTH = 112   -- Width of visualization
      
      -- Draw loop outline
      screen.level(4)
      screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
      screen.stroke()
      
      -- Draw existing event markers
      screen.level(2)
      for _, event in ipairs(motif.events) do
        if event.type == "note_on" then
          -- Calculate x position based on event time
          local x = VIS_X + (event.time / motif.genesis.duration * VIS_WIDTH)
          -- Draw small vertical line for event
          screen.move(x, VIS_Y)
          screen.line(x, VIS_Y + VIS_HEIGHT)
          screen.stroke()
        end
      end
      
      -- Draw new events being recorded (brighter)
      if _seeker.motif_recorder.is_recording then
        local now = clock.get_beats()
        local start = _seeker.motif_recorder.start_time
        
        screen.level(8)  -- Brighter than existing events
        for _, event in ipairs(_seeker.motif_recorder.events) do
          -- Only show new events (ones added during this overdub session)
          if event.type == "note_on" then
            -- Calculate time relative to start of recording
            local event_time = (event.time - start) % motif.genesis.duration
            local x = VIS_X + (event_time / motif.genesis.duration * VIS_WIDTH)
            -- Draw slightly taller line for new events
            screen.move(x, VIS_Y - 1)
            screen.line(x, VIS_Y + VIS_HEIGHT + 1)
            screen.stroke()
          end
        end
        
        -- Draw playhead (brightest)
        local elapsed = now - start
        local position = elapsed % motif.genesis.duration
        local x = VIS_X + (position / motif.genesis.duration * VIS_WIDTH)
        
        screen.level(15)
        screen.move(x, VIS_Y - 1)
        screen.line(x, VIS_Y + VIS_HEIGHT + 1)
        screen.stroke()
      end
    end
    
    -- Draw help text just above footer
    screen.level(2)
    
    -- First line
    local text1 = "Long press to start"
    local width1 = screen.text_extents(text1)
    screen.move(64 - width1/2, 42)
    screen.text(text1)
    
    -- Second line
    local text2 = "Short press to stop"
    local width2 = screen.text_extents(text2)
    screen.move(64 - width2/2, 50)
    screen.text(text2)
    
    -- Draw footer
    self:draw_footer()
    
    screen.update()
  end

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