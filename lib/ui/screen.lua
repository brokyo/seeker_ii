-- screen.lua
local ScreenSaver = include('lib/ui/screen_saver')

local ScreenUI = {}

ScreenUI.state = {
  fps = 30,
  app_on_screen = true,
  needs_redraw = false
}

ScreenUI.sections = {}

function ScreenUI.init()  
  ScreenUI.sections = {
    CONFIG = _seeker.config.screen,
    KEYBOARD = _seeker.keyboard.screen,
    VELOCITY = _seeker.velocity.screen,
    TUNING = _seeker.tuning.screen,
    MOTIF = _seeker.motif_playback.screen,
    CLEAR_MOTIF = _seeker.clear_motif.screen,
    CREATE_MOTIF = _seeker.create_motif.screen,
    WTAPE = _seeker.w_tape.screen,
    STAGE_CONFIG = _seeker.stage_config.screen,
    EURORACK_CONFIG = _seeker.eurorack_config.screen,
    CROW_OUTPUT = _seeker.crow_output.screen,
    TXO_TR_OUTPUT = _seeker.txo_tr_output.screen,
    TXO_CV_OUTPUT = _seeker.txo_cv_output.screen,
    OSC_CONFIG = _seeker.osc_config.screen,
    OSC_OUTPUT = _seeker.osc_output.screen,
    LANE_CONFIG = _seeker.lane_config.screen
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