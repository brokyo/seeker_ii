-- seeker_ii.lua
-- Main entry point for Seeker II.

engine.name = "MxSamples"

-- 1. Require libraries
local mxsamples = include("mx.samples/lib/mx.samples")  -- Sample playback engine
local reflection_manager = include("/lib/reflection_manager")
local grid_ui          = include("/lib/grid")
local ui               = include("/lib/ui")
local transformations  = include("/lib/transformations")
local logger           = include("/lib/logger")
local params_manager = include('/lib/params_manager')

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
  
  -- 3. Pattern system
  reflection_manager.init(skeys)
  
  -- 4. UI layer
  grid_ui.init(skeys, reflection_manager)
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
  -- 1. Handle top-level key events
  if n == 2 and z == 1 then
    -- toggle recording
    local pattern = reflection_manager.patterns.main
    if pattern.rec == 1 then
      reflection_manager.stop_recording()
    else
      reflection_manager.start_recording()
    end
  elseif n == 3 and z == 1 then
    -- toggle playback
    local pattern = reflection_manager.patterns.main
    if pattern.play == 1 then
      reflection_manager.stop_playback()
    else
      reflection_manager.start_playback()
    end
  end

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
