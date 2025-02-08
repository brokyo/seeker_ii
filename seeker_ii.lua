-- seeker_ii.lua
-- awakening.systems
--
-- Phosphene snap

engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")  -- Sample playback engine
local Lane = include("lib/lane")  -- Lane management
local conductor = include("lib/conductor")
local lane_archetype = include("lib/lane_archetype")  -- Lane configuration templates
local grid = include("lib/grid_ii")
local screen_ui = include("/lib/screen_iii")
local params_manager = include('/lib/params_manager_ii')
local ui_state = include('/lib/ui_state_ii')

-- Global state
_seeker = {
  skeys = nil,
  conductor = conductor,
  lanes = {},            -- Collection of all lanes
  active_lane = 1,       -- Currently selected lane
  num_lanes = 4,         -- Number of lanes to create (configurable)
  debug_lane = nil,
  ui_state = nil,        -- Will hold UIState instance
  screen_ui = nil,       -- Will hold ScreenUI instance
  grid_ui = nil          -- Will hold GridUI instance
}

--------------------------------------------------
-- Norns lifecycle functions
--------------------------------------------------

function init()
  print('◎ Open The Next')
  -- Core audio setup
  _seeker.skeys = mxsamples:new()
    
  -- Initialize UI state first and store instance
  _seeker.ui_state = ui_state.init()
  
  -- Initialize parameter system
  params_manager.init_params()
  
  -- Initialize UI components in sequence
  _seeker.screen_ui = screen_ui.init()
  _seeker.grid_ui = grid.init()
 
  -- Start the clock
  -- Check the event queue every 1/64 to see if there are any new events
  clock.run(function()
    print("⎆ Conductor watching")
    while true do
      clock.sync(1/64)
      if #_seeker.conductor.events > 0 then
        _seeker.conductor.process_events()
      end
    end
  end)

  -- Initialize lanes with default configurations
  for i = 1, _seeker.num_lanes do
    _seeker.lanes[i] = Lane.new({ id = i })
    _seeker.lanes[i].midi_out_device = midi.connect(1)
  end

  print('⌬ Seeker Online')
end

function key(n, z)
  _seeker.screen_ui.key(n, z)
end

function enc(n, d)
  _seeker.screen_ui.enc(n, d)
end

function redraw()
  _seeker.screen_ui.set_needs_redraw()
end

function cleanup()
  print("⌿ Close the world")
  -- params:write()
end