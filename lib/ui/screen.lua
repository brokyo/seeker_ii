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
    -- Global
    CONFIG = _seeker.config.screen,

    -- Keyboard Mode
    KEYBOARD = _seeker.keyboard.screen,
    VELOCITY = _seeker.velocity.screen,
    TUNING = _seeker.tuning.screen,
    MOTIF = _seeker.motif_playback.screen,
    CLEAR_MOTIF = _seeker.clear_motif.screen,
    CREATE_MOTIF = _seeker.create_motif.screen,
    LANE_CONFIG = _seeker.lane_config.screen,
    TAPE_STAGE_CONFIG = _seeker.tape_stage_config.screen,
    SAMPLER_PAD_CONFIG = _seeker.sampler_pad_config.screen,
    SAMPLER_CREATOR = _seeker.sampler_creator.screen,
    SAMPLER_STAGE_CONFIG = _seeker.sampler_stage_config.screen,
    SAMPLER_PLAYBACK = _seeker.sampler_playback.screen,
    SAMPLER_CLEAR = _seeker.sampler_clear.screen,
    SAMPLER_VELOCITY = _seeker.sampler_velocity.screen,
    EXPRESSION_CONFIG = _seeker.expression_config.screen,
    HARMONIC_CONFIG = _seeker.harmonic_config.screen,

    -- WTape Mode
    WTAPE = _seeker.w_tape.screen,
    WTAPE_PLAYBACK = _seeker.wtape_playback.screen,
    WTAPE_RECORD = _seeker.wtape_record.screen,
    WTAPE_FF = _seeker.wtape_ff.screen,
    WTAPE_REWIND = _seeker.wtape_rewind.screen,
    WTAPE_LOOP_START = _seeker.wtape_loop_start.screen,
    WTAPE_LOOP_END = _seeker.wtape_loop_end.screen,
    WTAPE_REVERSE = _seeker.wtape_reverse.screen,
    WTAPE_LOOP_ACTIVE = _seeker.wtape_loop_active.screen,

    -- Eurorack Mode
    EURORACK_CONFIG = _seeker.eurorack_config.screen,
    CROW_OUTPUT = _seeker.crow_output.screen,
    TXO_TR_OUTPUT = _seeker.txo_tr_output.screen,
    TXO_CV_OUTPUT = _seeker.txo_cv_output.screen,

    -- OSC Mode
    OSC_CONFIG = _seeker.osc_config.screen,
    OSC_FLOAT = _seeker.osc_float.screen,
    OSC_LFO = _seeker.osc_lfo.screen,
    OSC_TRIGGER = _seeker.osc_trigger.screen,
  }
  
  ScreenSaver.init()
  
  clock.run(function()
    while true do
      if ScreenSaver.check_timeout() then
        redraw()
      else
        -- Refresh visualization-heavy sections during playback
        -- Sections opt-in via needs_playback_refresh property
        local current_section = _seeker.ui_state.get_current_section()
        local section = ScreenUI.sections[current_section]
        local lane_playing = _seeker.lanes[_seeker.ui_state.get_focused_lane()].playing
        if _seeker.motif_recorder.is_recording or
           (section and section.needs_playback_refresh and lane_playing) then
          ScreenUI.set_needs_redraw()
        end

        if ScreenUI.state.needs_redraw then
          redraw()
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