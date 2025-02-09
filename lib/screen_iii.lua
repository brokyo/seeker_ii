-- screen_iii.lua
local ConfigSection = include('lib/ui/sections/config_section')
local RecordingSection = include('lib/ui/sections/recording_section')
local LaneSection = include('lib/ui/sections/lane_section')
local StageSection = include('lib/ui/sections/stage_section')
local MotifSection = include('lib/ui/sections/motif_section')
local TransformSection = include('lib/ui/sections/transform_section')
local ScreenSaver = include('lib/ui/screen_saver')

local ScreenUI = {}

ScreenUI.state = {
  app_on_screen = true,
  fps = 30
}

ScreenUI.sections = {}

function ScreenUI.init()  
  -- Initialize sections
  ScreenUI.sections = {
    CONFIG = ConfigSection.new(),
    RECORDING = RecordingSection.new(),
    LANE = LaneSection.new(),
    STAGE = StageSection.new(),
    MOTIF = MotifSection.new(),
    TRANSFORM = TransformSection.new()
  }
  
  -- Initialize screen saver
  ScreenSaver.init()
  
  -- Start redraw clock - constant FPS unless disabled
  clock.run(function()
    while true do
      clock.sync(1/ScreenUI.state.fps)
      -- if ScreenUI.state.app_on_screen then
        ScreenUI.redraw()
      -- end
    end
  end)

  print("⚄ Screen drawing")
  return ScreenUI
end

function ScreenUI.get_active_section()
  return ScreenUI.sections[_seeker.ui_state.get_current_section()]
end

function ScreenUI.key(n, z)
  if n == 1 then
    if z == 1 then
      ScreenUI.state.app_on_screen = not ScreenUI.state.app_on_screen
      return
    end
  end

  ScreenSaver.register_activity()  -- Register any key activity
  local section = ScreenUI.get_active_section()
  if section then
    section:handle_key(n, z)
    ScreenUI.set_needs_redraw()
  end
end

function ScreenUI.enc(n, d)
  ScreenSaver.register_activity()  -- Register any encoder activity
  local section = ScreenUI.get_active_section()
  if section then
    section:handle_enc(n, d)
    ScreenUI.set_needs_redraw()
  end
end

function ScreenUI.set_needs_redraw()
  ScreenUI.state.needs_redraw = true
end

function ScreenUI.redraw()
  local section = ScreenUI.get_active_section()
  if section then
    if ScreenSaver.check_timeout() then
      ScreenSaver.draw()
    else
      section:update()  -- Ensure section is updated before drawing
      section:draw()
    end
  end
end

return ScreenUI 