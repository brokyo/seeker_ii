-- seeker_ii.lua
-- awakening.systems
--
-- **P*ho**sph*en*e***sn*ap***
--
-- k2 for descriptions


engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")
local Lane = include("lib/sequencing/lane")
local conductor = include("lib/sequencing/conductor")
local lane_archetype = include("lib/sequencing/lane_archetype")
local grid = include("lib/controllers/grid")
local screen_ui = include("/lib/ui/screen")
local params_manager = include('/lib/ui/params')
local ui_state = include('/lib/ui/state')
local MotifRecorder = include("lib/motif_core/recorder")
local MidiInput = include("lib/controllers/midi")
local Arc = include("lib/controllers/arc")
local SamplerManager = include("lib/sampler/manager")

-- Global Config Mode
local Config = include("lib/modes/config/init")
local lane_infrastructure = include("lib/sequencing/lane_infrastructure")

-- Motif Infrastructure
local Keyboard = include("lib/modes/motif/infrastructure/tuning")
local LaneConfig = include("lib/modes/motif/infrastructure/lane_config")

-- Motif Types
local Tape = include("lib/modes/motif/tape/init")
local Sampler = include("lib/modes/motif/sampler/init")
local Composer = include("lib/modes/motif/composer/init")

-- Mode Types
local WTape = include("lib/modes/wtape/init")
local Eurorack = include("lib/modes/eurorack/init")
local Osc = include("lib/modes/osc/init")

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
  keyboards = {}, -- Cache for keyboard instances
  motif_recorder = nil,
  midi_input = nil,
  arc = nil,
  sampler = nil,

  current_mode = nil,

  -- Components
  config = nil,
  lane_config = nil,

  -- Mode Types (initialized via init.lua)
  tape = nil,
  sampler_type = nil,
  composer = nil,
  wtape = nil,
  eurorack = nil,
  osc = nil,
}

--------------------------------------------------
-- Norns lifecycle functions
--------------------------------------------------

function init()
  print('◎ Open The Next')

  -- Add tempo change handler for debugging
  clock.tempo_change_handler = function(bpm)
    local current_beat = clock.get_beats()
    print(string.format("⏱ TEMPO CHANGED TO: %.2f BPM", bpm))
    print(string.format("   clock.get_tempo() = %.2f", clock.get_tempo()))
    print(string.format("   clock.get_beat_sec() = %.4f", clock.get_beat_sec()))
    print(string.format("   clock.get_beats() = %.2f", current_beat))

    -- Debug: show next scheduled event
    if #_seeker.conductor.events > 0 then
      local next_event = _seeker.conductor.events[1]
      print(string.format("   Next event at beat %.2f (%.2f beats away)", next_event.time, next_event.time - current_beat))
    end
  end

  -- Core audio setup
  _seeker.skeys = mxsamples:new()
  _seeker.motif_recorder = MotifRecorder.new()
  _seeker.sampler = SamplerManager
  SamplerManager.init()

  _seeker.ui_state = ui_state.init()

  -- Initialize config first since lane infrastructure now depends on config parameters
  params:add_separator("seeker_ii_header", "seeker_ii")
  _seeker.config = Config.init()

  -- Initialize lane infrastructure to provide parameters for lane.lua
  lane_infrastructure.init()

  -- Keyboard Mode
  _seeker.keyboard = Keyboard.init()
  -- NOTE: LaneConfig must be initialized before type modules to avoid race conditions
  _seeker.lane_config = LaneConfig.init()

  -- Motif Types
  _seeker.tape = Tape.init()
  _seeker.sampler_type = Sampler.init()
  _seeker.composer = Composer.init()

  -- Mode Types
  _seeker.wtape = WTape.init()
  _seeker.eurorack = Eurorack.init()
  _seeker.osc = Osc.init()
  
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

  _seeker.current_mode = "KEYBOARD"
  _seeker.ui_state.set_current_section("LANE_CONFIG")

  -- Start grid redraw clock LAST after everything is initialized
  _seeker.grid_ui.start()

  print('⌬ Seeker Online')
end

function key(n, z)
  _seeker.ui_state.key(n, z)
end

function enc(n, d)
  _seeker.ui_state.enc(n, d)
end

function redraw()
  if _seeker.screen_ui then
    _seeker.screen_ui.redraw()
  end
end

function cleanup()
  print("⌿ Close the world")
end