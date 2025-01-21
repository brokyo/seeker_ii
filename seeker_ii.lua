-- seeker_ii.lua
-- awakening.systems
--
-- Architectural Pattern:
-- This is the main entry point and state container for Seeker II.
-- The system follows a centralized state pattern where:
-- 1. All shared state lives in the _seeker table
-- 2. Components access shared services through _seeker (never globals)
-- 3. UI coordination happens through _seeker.ui_manager
-- 4. Components own their internal state
--
-- Initialization order is critical:
-- 1. Core setup (audio)
-- 2. Parameter system
-- 3. UI components (grid → ui_manager → screen)
--------------------------------------------------

engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")  -- Sample playback engine
local grid_ui = include("/lib/grid")
local ui = include("/lib/ui")
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
  ui_manager = nil,       -- UI coordination
  params_manager = nil    -- Parameter management
}

--------------------------------------------------
-- Norns lifecycle functions
--------------------------------------------------

function init()
  -- Core audio setup
  _seeker.skeys = mxsamples:new()
  _seeker.conductor = Conductor.new({})
  
  -- Initialize parameter system first
  _seeker.params_manager = params_manager
  params_manager.init_params()
  params:read()
  params:bang()
  
  -- Initialize UI components in sequence
  local grid_ui_instance = grid_ui.init()
  _seeker.ui_manager = include("/lib/ui_manager").init(grid_ui_instance, nil)  -- Pass nil for screen initially
  local screen_ui_instance = ui.init(_seeker.ui_manager)
  _seeker.ui_manager.screen = screen_ui_instance
  
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
  
  -- Set up parameter write callback to trigger UI updates
  local params_action_write = params.action_write -- Store the existing callback
  params.action_write = function(filename, name, number)
    -- Call the existing params callback first
    if params_action_write then
      params_action_write(filename, name, number)
    end
    
    -- Then trigger UI update
    if _seeker and _seeker.ui_manager then
      _seeker.ui_manager:redraw_all()
    end
  end
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
