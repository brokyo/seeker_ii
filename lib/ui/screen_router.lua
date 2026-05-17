-- screen_router.lua
-- Routes screen drawing/input to section modules
-- NOTE: Variable still named screen_ui throughout codebase - rename debt for later
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

    -- Motif Mode
    MOTIF = _seeker.motif_config.screen,
    TAPE_HOME = _seeker.motif_config.tape_home_screen,
    LANE_CONFIG = _seeker.lane_config.screen,
  }

  -- Auto-register sections from mode modules (each provides a .sections table)
  local mode_modules = {
    _seeker.tape, _seeker.sampler_type, _seeker.dialogue_type,
    _seeker.composer_mode,
    _seeker.wtape, _seeker.eurorack, _seeker.osc
  }
  for _, mode_module in ipairs(mode_modules) do
    for section_id, screen in pairs(mode_module.sections) do
      ScreenUI.sections[section_id] = screen
    end
  end
  
  ScreenSaver.init()
  _seeker.screen_saver = ScreenSaver

  clock.run(function()
    local was_screensaver_active = false

    while true do
      local screensaver_active = ScreenSaver.check_timeout()

      if screensaver_active then
        redraw()
      else
        -- Force redraw when exiting screensaver to restore normal UI
        if was_screensaver_active then
          ScreenUI.set_needs_redraw()
        end

        -- Refresh visualization-heavy sections during playback
        -- Sections opt-in via needs_playback_refresh property
        local current_section = _seeker.ui_state.get_current_section()
        local section = ScreenUI.sections[current_section]
        if _seeker.motif_recorder.is_recording or
           (section and section.needs_playback_refresh) or
           (_seeker.modal and _seeker.modal.is_active()) or
           (_seeker.modal and _seeker.modal.is_toast_active()) or
           (_seeker.hold_confirm and _seeker.hold_confirm.is_active()) then
          ScreenUI.set_needs_redraw()
        end

        if ScreenUI.state.needs_redraw then
          redraw()
        end
      end

      was_screensaver_active = screensaver_active
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

-- Router owns screen lifecycle: clear before drawing, update after
function ScreenUI.redraw()
  screen.clear()
  if ScreenSaver.check_timeout() then
    ScreenSaver.draw()
  elseif _seeker.modal and _seeker.modal.is_active() then
    _seeker.modal.draw()
  elseif _seeker.hold_confirm and _seeker.hold_confirm.is_active() then
    _seeker.hold_confirm.draw()
  else
    local section = ScreenUI.get_active_section()
    if section and section.state.is_active then
      section:draw()
    end
    -- Toast draws on top of the active section (non-intrusive bottom text)
    if _seeker.modal then
      _seeker.modal.draw_toast()
    end
  end
  screen.update()
  ScreenUI.state.needs_redraw = false
end

return ScreenUI 