-- seeker_ii.lua
-- Main entry point for Seeker II.

engine.name = "MxSamples"

-- 1. Require libraries
local mxsamples = include("mx.samples/lib/mx.samples")  -- Sample playback engine
local grid_ui          = include("/lib/grid")
local ui               = include("/lib/ui")
local transformations  = include("/lib/transformations")
local logger           = include("/lib/logger")
local params_manager = include('/lib/params_manager')
local Conductor = include('lib/conductor')
local MotifRecorder = include('lib/motif_recorder')
local Motif = include('lib/motif')

-- 2. Global state references
local skeys = nil              -- MXSamples instance

--------------------------------------------------
-- Norns lifecycle functions
--------------------------------------------------

function init()
  -- 1. Core audio setup
  skeys = mxsamples:new()
  
  -- 2. Parameter system
  params_manager.init_musical_params(skeys)
  params:read()
  params:bang()
    
  -- Create core components
  local conductor = Conductor.new({})
  local motif_recorder = MotifRecorder.new({})
  
  -- 4. UI layer
  grid_ui.init(skeys, conductor, motif_recorder, Motif)  -- Pass recorder as dependency
  ui.init()
  grid_ui.post_init()
  
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
  -- 1. Basic navigation or parameter changes 
  ui.enc(n, d)
end

function redraw()
  -- 1. Draw the current state (active pattern, loop counts, etc.)
  screen.clear()
  ui.redraw()
  grid_ui.redraw()
  screen.update()
end

function cleanup()
  -- Save parameter values before exiting
  params:write()
end
