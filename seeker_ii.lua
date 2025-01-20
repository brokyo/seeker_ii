-- seeker_ii.lua
-- awakening.systems

engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")  -- Sample playback engine
local grid_ui = include("/lib/grid")
local ui = include("/lib/ui")
ui_manager = include("/lib/ui_manager")  -- Make this global (no local)
local transformations = include("/lib/transformations")
local params_manager = include('/lib/params_manager')
local Conductor = include('lib/conductor')
local Motif = include('lib/motif')

-- Global state
_seeker = {
  skeys = nil,           -- MxSamples instance
  conductor = nil,        -- Conductor instance
  tests = nil,            -- Will be loaded after initialization
  focused_lane = 1,       -- Currently focused lane (1-4)
  focused_stage = 1,      -- Currently focused stage (1-4)
  ui_manager = nil        -- UI coordination
}

--------------------------------------------------
-- Norns lifecycle functions
--------------------------------------------------

function init()
  -- Core audio setup
  _seeker.skeys = mxsamples:new()
  _seeker.conductor = Conductor.new({})
  
  -- Parameter system (before anything tries to access params)
  params_manager.init_params()
  params:read()
  params:bang()
  
  -- Initialize UI components
  local grid_ui_instance = grid_ui.init()
  local screen_ui_instance = ui.init()
  
  print("DEBUG Init:")
  print("- grid_ui_instance:", grid_ui_instance)
  print("- screen_ui_instance:", screen_ui_instance)
  
  -- Initialize UI manager with both components
  local ui_manager = include("/lib/ui_manager")
  _seeker.ui_manager = ui_manager.init(grid_ui_instance, screen_ui_instance)
  print("- After ui_manager.init, ui_manager.screen:", _seeker.ui_manager.screen)
  
  -- Load tests after everything is initialized
  _seeker.tests = include('tests/timing_tests')
  
  -- Set up separate grid redraw metro at 30fps
  local grid_metro = metro.init()
  grid_metro.time = 1/30
  grid_metro.event = function()
    _seeker.ui_manager:redraw_all()
  end
  grid_metro:start()
  
  -- Start clock for pattern playback
  clock.run(function()
    while true do
      clock.sync(1/4) -- Sync to quarter notes
    end
  end)
end

function key(n, z)
  ui.key(n, z)
end

function enc(n, d)
  ui.enc(n, d)
end

function redraw()
  screen.clear()
  _seeker.ui_manager:redraw_all()
  screen.update()
end

function cleanup()
  params:write()
end
