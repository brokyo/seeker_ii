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
local HoldConfirm = include("lib/ui/components/hold_confirm")

-- Global Config Mode
local Config = include("lib/modes/config/init")
local lane_infrastructure = include("lib/modes/motif/sequencing/lane_infrastructure")

-- Motif Infrastructure
local MotifConfig = include("lib/modes/motif/infrastructure/motif_config")
local LaneConfig = include("lib/modes/motif/infrastructure/lane_config")
local mx_samples = include("lib/modes/motif/infrastructure/voices/mx_samples")

-- Motif Types
local Tape = include("lib/modes/motif/types/tape/init")
local Sampler = include("lib/modes/motif/types/sampler/init")
local Drums = include("lib/modes/motif/types/drums/init")

-- Mode Types
local WTape = include("lib/modes/wtape/init")
local Eurorack = include("lib/modes/eurorack/init")
local Osc = include("lib/modes/osc/init")
local ComposerMode = include("lib/modes/composer/init")

-- Remote Control
local RemoteControl = include("lib/remote_control/init")
local rc_overlay = include("lib/remote_control/rc_overlay")
local LaneMap = include("lib/lanes/lane_map")

-- Global state
_seeker = {
  skeys = nil,
  conductor = conductor,
  lanes = {},
  num_lanes = LaneMap.ACTIVE_LANES,
  lane_map = LaneMap,
  last_focused = { tape = 1, composer = 5, sampler = 9, drums = 13 },
  ui_state = nil,
  screen_ui = nil,
  grid_ui = nil,
  motif_recorder = nil,
  midi_input = nil,
  arc = nil,
  sampler = nil,
  modal = Modal,  -- Single shared Modal instance
  hold_confirm = HoldConfirm,

  current_mode = nil,
  current_sub_mode = nil,

  -- Remote Control
  rc = nil,

  -- Components
  config = nil,
  lane_config = nil,

  -- Mode Types (initialized via init.lua)
  tape = nil,
  sampler_type = nil,
  composer_mode = nil,
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
  _seeker.drums_type = Drums.init()

  -- Mode Types
  _seeker.composer_mode = ComposerMode.init()
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
  params:set("clock_tempo", 80)

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
  
  -- Initialize lanes: each sub-mode owns its own 4 lanes
  for i = 1, _seeker.num_lanes do
    _seeker.lanes[i] = Lane.new({ id = i })
    _seeker.lanes[i].midi_out_device = midi.connect(1)
    local sub_mode = LaneMap.from_flat(i)
    local motif_type = LaneMap.motif_type_for_mode(sub_mode)
    if motif_type then
      params:set("lane_" .. i .. "_motif_type", motif_type, true)
    end
  end

  -- Initialize drum motifs now that lanes exist (needs non-zero duration to play)
  local DrumStepGrid = include("lib/modes/motif/types/drums/step_grid")
  for _, lane_id in ipairs(LaneMap.lanes_for_mode("drums")) do
    DrumStepGrid.rebuild_motif(lane_id)
  end

  -- Tape lane 1 defaults: MX Samples epiano
  params:set("lane_1_mx_samples_active", 1)
  local instruments = mx_samples.get_instrument_list()
  for idx, name in ipairs(instruments) do
    if name:lower():find("epiano") or name:lower():find("e.piano") or name:lower():find("electric_piano") then
      params:set("lane_1_instrument", idx)
      break
    end
  end

  -- Remote control interface
  _seeker.rc = RemoteControl
  _seeker.rc.init()
  _seeker.rc_overlay = rc_overlay

  _seeker.current_mode = "music"
  _seeker.current_sub_mode = "tape"
  _seeker.ui_state.set_current_section("MOTIF")

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