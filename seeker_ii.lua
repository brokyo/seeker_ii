-- seeker_ii.lua
-- awakening.systems
--
-- Close the world, Open the nExt?
--------------------------------------------------

engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")  -- Sample playback engine
local Lane = include("lib/lane")  -- Lane management
-- local event_queue = include("lib/event_queue") -- Core event system
local conductor = include("lib/conductor")
local lane_archetype = include("lib/lane_archetype")  -- Lane configuration templates
-- local grid_ui = include("/lib/grid")
-- local clock_manager = include("/lib/clock_manager")
-- local ui = include("/lib/ui")
-- local transformations = include("/lib/transformations")
local params_manager = include('/lib/params_manager_ii')
-- local Motif = include('lib/motif')
-- local Log = include('lib/log')

-- Global state
_seeker = {
  skeys = nil,           -- MxSamples instance
  conductor = conductor,
  -- event_queue = event_queue,  -- Event scheduling
  lanes = {},            -- Collection of all lanes
  active_lane = 1,       -- Currently selected lane
  num_lanes = 4,         -- Number of lanes to create (configurable)
  -- tests = nil,            -- Will be loaded after initialization
  -- focused_lane = 1,       -- Currently focused lane (1-4)
  -- focused_stage = 1,      -- Currently focused stage (1-4)
  -- ui_manager = nil,       -- UI coordination
  -- params_manager = nil,   -- Parameter management
  -- clock_manager = nil     -- Clock and event management
  debug_lane = nil
}

--------------------------------------------------
-- Norns lifecycle functions
--------------------------------------------------

function init()
  print('◎ Open The Next')
  -- Core audio setup
  _seeker.skeys = mxsamples:new()
    
  -- Initialize parameter system first
  _seeker.params_manager = params_manager
  params_manager.init_params()
  -- params:read()
  -- params:bang()
  
  -- Initialize UI components in sequence
  -- local grid_ui_instance = grid_ui.init()
  -- _seeker.ui_manager = include("/lib/ui_manager").init(grid_ui_instance, nil)  -- Pass nil for screen initially
  -- local screen_ui_instance = ui.init(_seeker.ui_manager)
  -- _seeker.ui_manager.screen = screen_ui_instance
  
  -- -- Set up separate grid redraw metro at 30fps
  -- local grid_metro = metro.init()
  -- grid_metro.time = 1/30
  -- grid_metro.event = function()
  --   _seeker.ui_manager:redraw_grid()
  -- end
  -- grid_metro:start()
    
  -- TODO: Should this be on params_manager? seems like a params_manager thing? 
  -- Set up parameter write callback to trigger UI updates
  -- local params_action_write = params.action_write -- Store the existing callback
  -- params.action_write = function(filename, name, number)
  --   -- Call the existing params callback first
  --   if params_action_write then
  --     params_action_write(filename, name, number)
  --   end
    
  --   -- Then trigger UI update
  --   if _seeker and _seeker.ui_manager then
  --     _seeker.ui_manager:redraw_all()
  --   end
  -- end

  -- Set initial tempo
  -- TODO: Get this from params
  params:set("clock_tempo", 120)
    
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

  -- Initialize lanes with empty configurations ready for recording
  for i = 1, _seeker.num_lanes do
    _seeker.lanes[i] = Lane.new(lane_archetype.create_empty(i))
  end

  -- Create a test lane using the full example configuration for debugging
  _seeker.debug_lane = Lane.new(lane_archetype.create_example(99))
  _seeker.debug_lane:play() -- start scheduling

  print('⌬ Seeker Online')
end

function key(n, z)
  ui.key(n, z)
end

function enc(n, d)
  ui.enc(n, d)
end

function redraw()
  screen.clear()
  -- _seeker.ui_manager:redraw_all()
  screen.update()
end

function cleanup()
  -- params:write()
end
