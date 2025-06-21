-- screen_iii.lua
local LaneSection = include('lib/ui/sections/lane_section')
local MotifSection = include('lib/ui/sections/motif_section')
local TuningSection = include('lib/ui/sections/tuning_section')
local VelocitySection = include('lib/ui/sections/velocity_section')
local ScreenSaver = include('lib/ui/screen_saver')

-- Old Component Approach
local ClearMotif = include('lib/components/clear_motif')

local ScreenUI = {}

ScreenUI.state = {
  fps = 30,
  app_on_screen = true,
  needs_redraw = false
}

ScreenUI.sections = {}

function ScreenUI.init()  
  -- Initialize sections
  ScreenUI.sections = {
    LANE = LaneSection.new(),
    MOTIF = MotifSection.new(),
    TUNING = TuningSection.new(),
    VELOCITY = VelocitySection.new(),
    
    -- Components
    CONFIG = _seeker.config.screen,
    CLEAR_MOTIF = ClearMotif.init().screen.build(),
    CREATE_MOTIF = _seeker.create_motif.screen,
    WTAPE = _seeker.w_tape.screen,
    STAGE_CONFIG = _seeker.stage_config.screen,
    EURORACK_OUTPUT = _seeker.eurorack_output.screen,
    OSC_CONFIG = _seeker.osc_config.screen
  }
  
  ScreenSaver.init()
  
  clock.run(function()
    while true do
      if ScreenSaver.check_timeout() then
        ScreenUI.redraw()
      else
        -- Hardcode views that should be constantly updating
        -- TODO: I may not stand behind this. Review.
        
        -- When we have a motif or are overdubbing
        if _seeker.motif_recorder.is_recording or 
          (_seeker.ui_state.get_current_section() == "CREATE_MOTIF" and
           _seeker.lanes[_seeker.ui_state.get_focused_lane()].playing) then
          ScreenUI.set_needs_redraw()
        end
        
        if ScreenUI.state.needs_redraw then
          ScreenUI.redraw()
        end
      end
      clock.sync(1/ScreenUI.state.fps)
    end
  end)

  print("⚄ Screen drawing")
  return ScreenUI
end

function ScreenUI.get_active_section()
  return ScreenUI.sections[_seeker.ui_state.get_current_section()]
end

function ScreenUI.key(n, z)
  local section = ScreenUI.get_active_section()
  if section and section.state.is_active then
    section:handle_key(n, z)
    ScreenUI.set_needs_redraw()
  end
end

function ScreenUI.enc(n, d)
  local section = ScreenUI.get_active_section()
  if section and section.state.is_active then
    section:handle_enc(n, d)
    ScreenUI.set_needs_redraw()
  end
end

function ScreenUI.set_needs_redraw()
  ScreenUI.state.needs_redraw = true
end

function ScreenUI.redraw()
  if ScreenSaver.check_timeout() then
    ScreenSaver.draw()
  else
    local section = ScreenUI.get_active_section()
    if section.state.is_active then
      section:draw()
    end
    ScreenUI.state.needs_redraw = false
  end
end

return ScreenUI 