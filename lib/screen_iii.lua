-- screen_iii.lua
local ConfigSection = include('lib/ui/sections/config_section')
local RecSection = include('lib/ui/sections/rec_section')
local LaneSection = include('lib/ui/sections/lane_section')
local StageSection = include('lib/ui/sections/stage_section')
local MotifSection = include('lib/ui/sections/motif_section')
local GenerateSection = include('lib/ui/sections/generate_section')
local TuningSection = include('lib/ui/sections/tuning_section')
local OverdubSection = include('lib/ui/sections/overdub_section')
local VelocitySection = include('lib/ui/sections/velocity_section')
local EurorackOutputSection = include('lib/ui/sections/eurorack_output_section')
local ScreenSaver = include('lib/ui/screen_saver')

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
    CONFIG = ConfigSection.new(),
    RECORDING = RecSection.new(),
    LANE = LaneSection.new(),
    STAGE = StageSection.new(),
    MOTIF = MotifSection.new(),
    GENERATE = GenerateSection.new(),
    TUNING = TuningSection.new(),
    OVERDUB = OverdubSection.new(),
    VELOCITY = VelocitySection.new(),
    EURORACK_OUTPUT = EurorackOutputSection.new()
  }
  
  ScreenSaver.init()
  
  clock.run(function()
    while true do
      if ScreenSaver.check_timeout() then
        ScreenUI.redraw()
      else
        -- TODO: I may not stand behind this. Review.
        -- Force redraw when recording or when showing active motif playhead
        if _seeker.motif_recorder.is_recording or 
          (_seeker.ui_state.get_current_section() == "OVERDUB" and 
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