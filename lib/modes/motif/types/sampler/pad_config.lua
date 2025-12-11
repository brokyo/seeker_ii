-- pad_config.lua
-- Sampler type: per-pad chop configuration (start/stop, envelope, filter, rate)
-- Pressing pads selects which to edit
-- Part of lib/modes/motif/types/sampler/
--
-- NOTE: Params are a VIEW into SamplerManager storage, not direct storage
-- This means pad configs DO NOT persist with PSETs currently

local NornsUI = include("lib/ui/base/norns_ui")
local theory = include("lib/motif_core/theory")

-- Filter type constants
local FILTER_OFF = 1
local FILTER_LOWPASS = 2
local FILTER_HIGHPASS = 3
local FILTER_BANDPASS = 4
local FILTER_NOTCH = 5

local SamplerPadConfig = {
  screen = nil,
  state = {
    selected_pad = 1,
    current_lane = 1
  }
}

-- Create screen UI
local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "SAMPLER_PAD_CONFIG",
    name = "Chop Config",
    description = "Configure individual chop points and envelopes. Each pad controls one chop. Pitch and Speed combine.",
    params = {}
  })

  -- Build params for current selected pad
  function norns_ui:rebuild_params()
    local lane = SamplerPadConfig.state.current_lane
    local pad = SamplerPadConfig.state.selected_pad
    local filter_type = params:get("spc_filter_type")

    local param_list = {
      {separator = true, title = "Chop Config"},
      {id = "spc_mode"},
      {id = "spc_max_volume", arc_multi_float = {0.1, 0.05, 0.01}},
      {separator = true, title = "Slice Points"},
      {id = "spc_start_pos", arc_multi_float = {1.0, 0.1, 0.01}},
      {id = "spc_stop_pos", arc_multi_float = {1.0, 0.1, 0.01}},
      {separator = true, title = "Playback"},
      {id = "spc_pitch"},
      {id = "spc_rate", arc_multi_float = {0.5, 0.1, 0.01}},
      {id = "spc_pan", arc_multi_float = {0.1, 0.05, 0.01}},
      {separator = true, title = "Envelope"},
      {id = "spc_attack", arc_multi_float = {0.1, 0.01, 0.001}},
      {id = "spc_release", arc_multi_float = {0.1, 0.01, 0.001}},
      {id = "spc_fade_time", arc_multi_float = {0.01, 0.001, 0.0001}},
      {separator = true, title = "Filter"},
      {id = "spc_filter_type"}
    }

    -- Add appropriate filter params based on selected type
    if filter_type == FILTER_LOWPASS then
      table.insert(param_list, {id = "spc_lpf", arc_multi_float = {1000, 100, 10}})
      table.insert(param_list, {id = "spc_resonance", arc_multi_float = {0.5, 0.1, 0.05}})
    elseif filter_type == FILTER_HIGHPASS then
      table.insert(param_list, {id = "spc_hpf", arc_multi_float = {1000, 100, 10}})
      table.insert(param_list, {id = "spc_resonance", arc_multi_float = {0.5, 0.1, 0.05}})
    elseif filter_type == FILTER_BANDPASS or filter_type == FILTER_NOTCH then
      -- Reuse lpf param as center frequency for bandpass/notch modes
      table.insert(param_list, {id = "spc_lpf", arc_multi_float = {1000, 100, 10}, custom_name = "Center Freq"})
      table.insert(param_list, {id = "spc_resonance", arc_multi_float = {0.5, 0.1, 0.05}})
    end

    self.params = param_list
  end

  -- Override enter to rebuild params on section entry
  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()  -- Build params FIRST
    original_enter(self)   -- Then send to Arc
  end

  return norns_ui
end

-- Initialize params
function SamplerPadConfig.init()
  -- Create screen UI
  SamplerPadConfig.screen = create_screen_ui()

  -- Create parameter group for pad configuration UI
  params:add_group("sampler_pad_config", "SAMPLER PAD CONFIG", 14)

  params:add_control("spc_start_pos", "Start Position",
    controlspec.new(0, 10, 'lin', 0.001, 0, 's'))
  params:set_action("spc_start_pos", function(value)
    SamplerPadConfig.update_chop('start_pos', value)
  end)

  params:add_control("spc_stop_pos", "Stop Position",
    controlspec.new(0, 10, 'lin', 0.001, 0.1, 's'))
  params:set_action("spc_stop_pos", function(value)
    SamplerPadConfig.update_chop('stop_pos', value)
  end)

  params:add_control("spc_attack", "Attack",
    controlspec.new(0.001, 5.0, 'lin', 0.001, 0.01, 's'))
  params:set_action("spc_attack", function(value)
    SamplerPadConfig.update_chop('attack', value)
  end)

  params:add_control("spc_release", "Release",
    controlspec.new(0.001, 5.0, 'lin', 0.001, 0.01, 's'))
  params:set_action("spc_release", function(value)
    SamplerPadConfig.update_chop('release', value)
  end)

  params:add_control("spc_fade_time", "Crossfade",
    controlspec.new(0.0001, 5.0, 'lin', 0.0001, 0.005, 's'))
  params:set_action("spc_fade_time", function(value)
    SamplerPadConfig.update_chop('fade_time', value)
  end)

  params:add_control("spc_rate", "Speed",
    controlspec.new(-2, 2, 'lin', 0.01, 1.0, ''))
  params:set_action("spc_rate", function(value)
    SamplerPadConfig.update_chop('rate', value)
  end)

  -- Pitch transposition in semitones (-12 to +12, 0 = original)
  local pitch_names = {}
  for semitones = -12, 12 do
    table.insert(pitch_names, theory.offset_to_display(semitones))
  end
  params:add_option("spc_pitch", "Pitch", pitch_names, 13)  -- Index 13 = 0 semitones
  params:set_action("spc_pitch", function(idx)
    local semitones = idx - 13  -- Convert index to semitone offset
    SamplerPadConfig.update_chop('pitch_offset', semitones)
  end)

  params:add_control("spc_max_volume", "Max Volume",
    controlspec.new(0, 1, 'lin', 0.01, 1.0, ''))
  params:set_action("spc_max_volume", function(value)
    SamplerPadConfig.update_chop('max_volume', value)
  end)

  params:add_control("spc_pan", "Pan",
    controlspec.new(-1, 1, 'lin', 0.01, 0, ''))
  params:set_action("spc_pan", function(value)
    SamplerPadConfig.update_chop('pan', value)
  end)

  params:add_option("spc_mode", "Mode", {"Gate", "One-Shot"}, 1)
  params:set_action("spc_mode", function(value)
    SamplerPadConfig.update_chop('mode', value)

    -- Stop currently playing pad so new mode setting takes effect
    local lane = SamplerPadConfig.state.current_lane
    local pad = SamplerPadConfig.state.selected_pad
    if _seeker and _seeker.sampler then
      _seeker.sampler.stop_pad(lane, pad)
    end
  end)

  -- Filter controls
  params:add_option("spc_filter_type", "Filter Type", {"Off", "Lowpass", "Highpass", "Bandpass", "Notch"}, 1)
  params:set_action("spc_filter_type", function(value)
    SamplerPadConfig.update_chop('filter_type', value)
    -- Rebuild UI to show appropriate filter params
    if SamplerPadConfig.screen then
      SamplerPadConfig.screen:rebuild_params()
    end
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)
  params:add_taper("spc_lpf", "LPF Cutoff", 20, 20000, 20000, 3, "Hz")
  params:set_action("spc_lpf", function(value)
    SamplerPadConfig.update_chop('lpf', value)
  end)

  params:add_control("spc_resonance", "Resonance",
    controlspec.new(0, 4, 'lin', 0.01, 0, ""))
  params:set_action("spc_resonance", function(value)
    SamplerPadConfig.update_chop('resonance', value)
  end)

  params:add_taper("spc_hpf", "HPF Cutoff", 20, 20000, 20, 3, "Hz")
  params:set_action("spc_hpf", function(value)
    SamplerPadConfig.update_chop('hpf', value)
  end)

  return SamplerPadConfig
end

-- Select a pad for editing
function SamplerPadConfig.select_pad(pad)
  SamplerPadConfig.state.selected_pad = pad
  SamplerPadConfig.state.current_lane = _seeker.ui_state.get_focused_lane()
  SamplerPadConfig.load_pad_params()

  -- Navigate to config section
  _seeker.ui_state.set_current_section("SAMPLER_PAD_CONFIG")

  -- Rebuild screen to show new pad's config
  if SamplerPadConfig.screen then
    SamplerPadConfig.screen:rebuild_params()
  end

  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

-- Load current pad's chop data into params
function SamplerPadConfig.load_pad_params()
  local lane = SamplerPadConfig.state.current_lane
  local pad = SamplerPadConfig.state.selected_pad

  if not _seeker or not _seeker.sampler then return end

  local chop = _seeker.sampler.get_chop(lane, pad)
  if not chop then return end

  -- Update params without triggering actions
  params:set("spc_start_pos", chop.start_pos, true)
  params:set("spc_stop_pos", chop.stop_pos, true)
  params:set("spc_attack", chop.attack, true)
  params:set("spc_release", chop.release, true)
  params:set("spc_fade_time", chop.fade_time or 0.005, true)
  params:set("spc_rate", chop.rate, true)
  params:set("spc_max_volume", chop.max_volume, true)
  params:set("spc_pan", chop.pan or 0, true)
  params:set("spc_mode", chop.mode or 1, true)
  params:set("spc_filter_type", chop.filter_type or 1, true)
  params:set("spc_lpf", chop.lpf or 20000, true)
  params:set("spc_resonance", chop.resonance or 0, true)
  params:set("spc_hpf", chop.hpf or 20, true)

  -- Convert pitch_offset semitones back to option index (index 13 = 0 semitones)
  local pitch_offset = chop.pitch_offset or 0
  local pitch_idx = pitch_offset + 13
  params:set("spc_pitch", pitch_idx, true)

  -- Update max values based on sample duration
  local duration = _seeker.sampler.get_sample_duration(lane)
  if duration > 0 then
    params:lookup_param("spc_start_pos").controlspec.maxval = duration
    params:lookup_param("spc_stop_pos").controlspec.maxval = duration
  end
end

-- Update a chop property for current pad
function SamplerPadConfig.update_chop(key, value)
  local lane = SamplerPadConfig.state.current_lane
  local pad = SamplerPadConfig.state.selected_pad

  if not _seeker or not _seeker.sampler then return end

  _seeker.sampler.update_chop(lane, pad, key, value)

  -- Auto-adjust stop if start moves past it
  if key == "start_pos" then
    local chop = _seeker.sampler.get_chop(lane, pad)
    if chop and value >= chop.stop_pos then
      local new_stop = math.min(value + 0.1, _seeker.sampler.get_sample_duration(lane))
      params:set("spc_stop_pos", new_stop)
    end
  end

  -- Auto-adjust start if stop moves before it
  if key == "stop_pos" then
    local chop = _seeker.sampler.get_chop(lane, pad)
    if chop and value <= chop.start_pos then
      local new_start = math.max(value - 0.1, 0)
      params:set("spc_start_pos", new_start)
    end
  end
end

-- Get current selected pad (for grid visualization)
function SamplerPadConfig.get_selected_pad()
  return SamplerPadConfig.state.selected_pad
end

return SamplerPadConfig
