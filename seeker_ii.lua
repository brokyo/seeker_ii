-- seeker_ii.lua
-- awakening.systems
--
-- Close the world, Open the nExt?
--------------------------------------------------

engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")  -- Sample playback engine
local Lane = include("lib/lane")  -- Lane management
local conductor = include("lib/conductor")
local lane_archetype = include("lib/lane_archetype")  -- Lane configuration templates
local grid = include("lib/grid_ii")
-- local ui = include("/lib/ui")
local params_manager = include('/lib/params_manager_ii')

-- Global state
_seeker = {
  skeys = nil,           -- MxSamples instance
  conductor = conductor,
  lanes = {},            -- Collection of all lanes
  active_lane = 1,       -- Currently selected lane
  num_lanes = 4,         -- Number of lanes to create (configurable)
  ui_state = {
    focused_lane = 1,
    focused_stage = 1
  },
  -- ui_manager = nil,       -- UI coordination
  -- params_manager = nil,   -- Parameter management
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
  grid.init()
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

  -- Initialize lanes with default configurations
  for i = 1, _seeker.num_lanes do
    _seeker.lanes[i] = Lane.new({ id = i })
  end

  -- Create a test lane for debugging
  -- _seeker.debug_lane = lane_archetype.create_debug_lane()
  -- _seeker.debug_lane:play()

  print('⌬ Seeker Online')
end

function key(n, z)
  -- ui.key(n, z)
end

function enc(n, d)
  -- ui.enc(n, d)
end

function redraw()
  -- _seeker.ui_manager:redraw_all()
  -- screen.update()
end

function cleanup()
  print("⌿ Phosphene snap")
  -- params:write()
end
