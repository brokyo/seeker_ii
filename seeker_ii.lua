-- seeker_ii.lua
-- awakening.systems
--
-- **P*ho**sph*en*e***sn*ap***
--
-- k2 for descriptions


engine.name = "MxSamples"

-- Libraries
local mxsamples = include("mx.samples/lib/mx.samples")
local Lane = include("lib/modes/motif/sequencing/lane")
local conductor = include("lib/modes/motif/sequencing/conductor")
local grid = include("lib/controllers/grid")
local screen_ui = include("/lib/ui/screen_router")
local ui_state = include('/lib/ui/state')
local MotifRecorder = include("lib/modes/motif/core/recorder")
local MidiInput = include("lib/controllers/midi")
local Arc = include("lib/controllers/arc")
local SamplerEngine = include("lib/modes/motif/types/sampler/engine")
local Modal = include("lib/ui/components/modal")

-- Global Config Mode
local Config = include("lib/modes/config/init")
local lane_infrastructure = include("lib/modes/motif/sequencing/lane_infrastructure")

-- Motif Infrastructure
local MotifConfig = include("lib/modes/motif/infrastructure/motif_config")
local LaneConfig = include("lib/modes/motif/infrastructure/lane_config")

-- Motif Types
local Tape = include("lib/modes/motif/types/tape/init")
local Sampler = include("lib/modes/motif/types/sampler/init")
local Composer = include("lib/modes/motif/types/composer/init")

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
  ui_state = nil,
  screen_ui = nil,
  grid_ui = nil,
  motif_recorder = nil,
  midi_input = nil,
  arc = nil,
  sampler = nil,
  modal = Modal,  -- Single shared Modal instance

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

  -- Core audio setup
  _seeker.skeys = mxsamples:new()
  _seeker.motif_recorder = MotifRecorder.new()
  _seeker.sampler = SamplerEngine
  SamplerEngine.init()

  _seeker.ui_state = ui_state.init()

  -- Initialize config first since lane infrastructure now depends on config parameters
  params:add_separator("seeker_ii_header", "seeker_ii")
  _seeker.config = Config.init()

  -- Initialize lane infrastructure to provide parameters for lane.lua
  lane_infrastructure.init()

  -- Motif Config
  _seeker.motif_config = MotifConfig.init()
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
  
  -- UI Setup
  _seeker.screen_ui = screen_ui.init()
  _seeker.grid_ui = grid.init()

  -- Initialize MIDI input
  _seeker.midi_input = MidiInput.init()
  
  -- Initialize Arc
  _seeker.arc = Arc.init()

  -- Centralized tempo change handler (syncs all clocked outputs)
  params:set_action("clock_tempo", function(_)
    if _seeker.eurorack then
      _seeker.eurorack.crow_output.sync()
      _seeker.eurorack.txo_cv_output.sync()
      _seeker.eurorack.txo_tr_output.sync()
    end
    if _seeker.osc then
      _seeker.osc.lfo.sync()
      _seeker.osc.trigger.sync()
    end
  end)

  -- Set default tempo
  params:set("clock_tempo", 60)

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

  _seeker.current_mode = "motif"
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
  -- Skip redraw during fileselect (norns owns the screen)
  if _seeker.sampler and _seeker.sampler.file_select_active then
    return
  end
  if _seeker.screen_ui then
    _seeker.screen_ui.redraw()
  end
end

function cleanup()
  print("⌿ Close the world")
end