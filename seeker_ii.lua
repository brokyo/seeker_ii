-- seeker_ii.lua
-- awakening.systems
--
-- **P*ho**sph*en*e***sn*ap***

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

-- Components
local Config = include("lib/components/global_config")
local Keyboard = include("lib/components/keyboard/keyboard_config")
local CreateMotif = include("lib/components/keyboard/create_motif")
local ClearMotif = include("lib/components/keyboard/clear_motif")
local WTape = include("lib/components/wtape/wtape_config")
local WTapePlayback = include("lib/components/wtape/wtape_playback")
local StageConfig = include("lib/components/lanes/stage_config")
local EurorackConfig = include("lib/components/eurorack/eurorack_config")
local CrowOutput = include("lib/components/eurorack/crow_output")
local TxoTrOutput = include("lib/components/eurorack/txo_tr_output")
local TxoCvOutput = include("lib/components/eurorack/txo_cv_output")
local OscConfig = include("lib/components/osc/osc_config")
local OscOutput = include("lib/components/osc/osc_output")
local LaneConfig = include("lib/components/lanes/lane_config")
local Velocity = include("lib/components/keyboard/velocity")
local MotifPlayback = include("lib/components/keyboard/motif_playback")
local Tuning = include("lib/components/keyboard/tuning")
local lane_infrastructure = include("lib/sequencing/lane_infrastructure")
local arpeggio_params = include("lib/motif_core/arpeggio_params")

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
  keyboard_region = nil,
  keyboards = {}, -- Cache for keyboard instances
  motif_recorder = nil,
  midi_input = nil,
  arc = nil,
  -- This one is a hack to get the velocity section to work. There's got to be a better way.
  velocity = 3,

  current_mode = nil,

  -- Component Approach
  config = nil,
  create_motif = nil,
  w_tape = nil,
  stage_config = nil,
  eurorack_config = nil,
  crow_output = nil,
  txo_tr_output = nil,
  txo_cv_output = nil,
  osc_config = nil,
  lane_config = nil,
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

  _seeker.ui_state = ui_state.init()

  -- Initialize config first since lane infrastructure now depends on config parameters
  params:add_separator("seeker_ii_header", "seeker_ii")
  _seeker.config = Config.init()

  -- Initialize lane infrastructure to provide parameters for lane.lua
  lane_infrastructure.init()
  arpeggio_params.init()
  _seeker.keyboard = Keyboard.init()
  _seeker.velocity = Velocity.init()
  _seeker.tuning = Tuning.init()
  _seeker.motif_playback = MotifPlayback.init()
  _seeker.create_motif = CreateMotif.init()
  _seeker.clear_motif = ClearMotif.init()
  _seeker.w_tape = WTape.init()
  _seeker.wtape_playback = WTapePlayback.init()
  -- NOTE: LaneConfig must be initialized before StageConfig to avoid race conditions
  -- LaneConfig creates stage parameters that StageConfig references
  _seeker.lane_config = LaneConfig.init()
  _seeker.stage_config = StageConfig.init()
  _seeker.eurorack_config = EurorackConfig.init()
  _seeker.crow_output = CrowOutput.init()
  _seeker.txo_tr_output = TxoTrOutput.init()
  _seeker.txo_cv_output = TxoCvOutput.init()
  _seeker.osc_config = OscConfig.init()
  _seeker.osc_output = OscOutput.init()
  
  -- UI Setup and global access
  params_manager.init_params()

  _seeker.screen_ui = screen_ui.init()
  _seeker.grid_ui = grid.init()
  _seeker.keyboard_region = include("lib/grid/keyboard_region")
  
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
  _seeker.ui_state.set_current_section("KEYBOARD")

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