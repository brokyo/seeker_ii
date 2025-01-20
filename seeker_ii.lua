-- seeker_ii.lua
-- awakening.systems

engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")  -- Sample playback engine
local grid_ui          = include("/lib/grid")
local ui               = include("/lib/ui")
local transformations  = include("/lib/transformations")
local params_manager = include('/lib/params_manager')
local Conductor = include('lib/conductor')
local Motif = include('lib/motif')

-- Global state
_seeker = {
  focused_lane = 1,       -- Currently focused lane (1-4)
  skeys = nil,           -- MxSamples instance
  conductor = nil,        -- Conductor instance
  tests = nil            -- Will be loaded after initialization
}

--------------------------------------------------
-- Norns lifecycle functions
--------------------------------------------------

function init()
  -- Core audio setup
  _seeker.skeys = mxsamples:new()
  _seeker.conductor = Conductor.new({})
  
  -- Parameter system (before anything tries to access params)
  params_manager.init_params()  -- No need to pass skeys/conductor anymore
  params:read()
  params:bang()
  
  -- Components that need params
  local ui_instance = ui.init()  -- No need to pass conductor
  local grid_ui = grid_ui.init()  -- No need to pass skeys/conductor
  
  -- Passing UI to grid
  ui_instance.grid_ui = grid_ui
  
  -- Load tests after everything is initialized
  _seeker.tests = include('tests/timing_tests')
  
  -- Set up separate grid redraw metro at 30fps
  local grid_metro = metro.init()
  grid_metro.time = 1/30
  grid_metro.event = function()
    grid_ui.redraw()
  end
  grid_metro:start()
  
  -- 5. Start clock for pattern playback
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
  ui.redraw()
  screen.update()
end

function cleanup()
  params:write()
end
