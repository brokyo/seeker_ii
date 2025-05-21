-- seeker_ii.lua
-- awakening.systems
--
-- **P*ho**sph*en*e***sn*ap***

engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")
local Lane = include("lib/lane")
local conductor = include("lib/conductor")
local lane_archetype = include("lib/lane_archetype")
local grid = include("lib/grid_ii")
local screen_ui = include("/lib/screen_iii")
local params_manager = include('/lib/params_manager_ii')
local ui_state = include('/lib/ui_state_ii')
local MotifRecorder = include("lib/motif_recorder")
local MidiInput = include("lib/midi_input")
local Arc = include("lib/arc")

-- Components
local WTape = include("lib/components/w_tape")
local StageConfig = include("lib/components/stage_config")

-- Global state
_seeker = {
  skeys = nil,
  conductor = conductor,
  lanes = {},
  active_lane = 1,
  num_lanes = 8,
  debug_lane = nil,
  ui_state = nil,
  screen_ui = nil,
  grid_ui = nil,
  motif_recorder = nil,
  midi_input = nil,
  arc = nil,
  -- This one is a hack to get the velocity section to work. There's got to be a better way.
  velocity = 3,

  -- Component Approach
  w_tape = nil,
  stage_config = nil
}

--------------------------------------------------
-- Norns lifecycle functions
--------------------------------------------------

function init()
  print('◎ Open The Next')
  -- Core audio setup
  _seeker.skeys = mxsamples:new()
  _seeker.motif_recorder = MotifRecorder.new()
    
  _seeker.ui_state = ui_state.init()

  -- Initialize components
  _seeker.w_tape = WTape.init()
  _seeker.stage_config = StageConfig.init()
  -- UI Setup and global access
  params_manager.init_params()  

  _seeker.screen_ui = screen_ui.init()
  _seeker.grid_ui = grid.init()
  
  -- Initialize MIDI input
  _seeker.midi_input = MidiInput.init()
  
  -- Initialize Arc
  _seeker.arc = Arc.init()
  
  -- Start the clock
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
  
  _seeker.grid_ui.start()
  _seeker.ui_state.set_current_section("CONFIG")
  print('⌬ Seeker Online')
end

function key(n, z)
  _seeker.ui_state.key(n, z)
end

function enc(n, d)
  _seeker.ui_state.enc(n, d)
end

function redraw()
  _seeker.screen_ui.set_needs_redraw()
end

function cleanup()
  print("⌿ Close the world")
end