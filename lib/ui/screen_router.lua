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
    KEYBOARD = _seeker.keyboard.screen,
    LANE_CONFIG = _seeker.lane_config.screen,
  }

  -- Auto-register sections from mode modules (each provides a .sections table)
  local mode_modules = {
    _seeker.tape, _seeker.sampler_type, _seeker.composer,
    _seeker.wtape, _seeker.eurorack, _seeker.osc
  }
  for _, mode_module in ipairs(mode_modules) do
    for section_id, screen in pairs(mode_module.sections) do
      ScreenUI.sections[section_id] = screen
    end
  end
  
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
        if _seeker.motif_recorder.is_recording or
           (section and section.needs_playback_refresh) or
           (_seeker.modal and _seeker.modal.is_active()) then
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
    -- Screensaver appears on top of everything, including modals
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