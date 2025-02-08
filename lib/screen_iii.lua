-- screen_iii.lua
local ConfigSection = include('lib/ui/sections/config_section')
local RecordingSection = include('lib/ui/sections/recording_section')
local LaneSection = include('lib/ui/sections/lane_section')
local StageSection = include('lib/ui/sections/stage_section')
local MotifSection = include('lib/ui/sections/motif_section')
local TransformSection = include('lib/ui/sections/transform_section')

local ScreenUI = {}

ScreenUI.state = {
  needs_redraw = true,
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
  
  -- Start redraw clock - always redraw for smooth animation
  clock.run(function()
    while true do
      clock.sync(1/ScreenUI.state.fps)
      ScreenUI.redraw()
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
  if section then
    section:handle_key(n, z)
    ScreenUI.set_needs_redraw()
  end
end

function ScreenUI.enc(n, d)
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
    section:update()  -- Ensure section is updated before drawing
    section:draw()
  end
end

return ScreenUI 