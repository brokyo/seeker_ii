-- chop_config.lua
-- Sampler type: per-pad chop configuration (start/stop, envelope, filter, rate)
-- Pressing pads selects which to edit
-- Part of lib/modes/motif/types/sampler/
--
-- NOTE: Params are a VIEW into SamplerManager storage, not direct storage
-- This means pad configs DO NOT persist with PSETs currently

local NornsUI = include("lib/ui/base/norns_ui")
local theory = include("lib/modes/motif/core/theory")
local Descriptions = include("lib/ui/component_descriptions")
local WavPeaks = include("lib/modes/motif/types/sampler/wav_peaks")

-- Filter type constants
local FILTER_OFF = 1
local FILTER_LOWPASS = 2
local FILTER_HIGHPASS = 3
local FILTER_BANDPASS = 4
local FILTER_NOTCH = 5

local SamplerChopConfig = {
  screen = nil,
  state = {
    selected_pad = 1,
    current_lane = 1
  }
}

-- Create screen UI
local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "SAMPLER_CHOP_CONFIG",
    name = "Chop Config",
    description = Descriptions.SAMPLER_CHOP_CONFIG,
    params = {}
  })

  -- Build params for current selected pad
  function norns_ui:rebuild_params()
    local lane = SamplerChopConfig.state.current_lane
    local pad = SamplerChopConfig.state.selected_pad
    local filter_type = params:get("spc_filter_type")

    -- Check if chop is using global settings
    local uses_global_filter = true
    local uses_global_envelope = true
    if _seeker and _seeker.sampler then
      local chop = _seeker.sampler.get_chop(lane, pad)
      if chop then
        uses_global_filter = chop.uses_global_filter ~= false
        uses_global_envelope = chop.uses_global_envelope ~= false
      end
    end
    local filter_title = uses_global_filter and "Global Filter" or "Filter"
    local envelope_title = uses_global_envelope and "Global Envelope" or "Envelope"

    local param_list = {
      {separator = true, title = "Chop Config"},
      {id = "spc_mode"},
      {id = "spc_max_volume", arc_multi_float = {0.1, 0.05, 0.01}},
      {separator = true, title = "Slice Points"},
      {id = "spc_visual_edit", is_action = true, custom_name = "Visual Edit"},
      {id = "spc_start_pos", arc_multi_float = {1.0, 0.1, 0.01}},
      {id = "spc_stop_pos", arc_multi_float = {1.0, 0.1, 0.01}},
      {separator = true, title = "Playback"},
      {id = "spc_pitch"},
      {id = "spc_rate", arc_multi_float = {0.5, 0.1, 0.01}},
      {id = "spc_pan", arc_multi_float = {0.1, 0.05, 0.01}},
      {separator = true, title = envelope_title},
      {id = "spc_attack", arc_multi_float = {0.1, 0.01, 0.001}},
      {id = "spc_release", arc_multi_float = {0.1, 0.01, 0.001}},
      {id = "spc_fade_time", arc_multi_float = {0.01, 0.001, 0.0001}},
      {separator = true, title = filter_title},
      {id = "spc_filter_type"}
    }

    -- Add filter params based on chop's filter type
    if filter_type == FILTER_LOWPASS then
      table.insert(param_list, {id = "spc_lpf", arc_multi_float = {1000, 100, 10}})
      table.insert(param_list, {id = "spc_resonance", arc_multi_float = {0.5, 0.1, 0.05}})
    elseif filter_type == FILTER_HIGHPASS then
      table.insert(param_list, {id = "spc_hpf", arc_multi_float = {1000, 100, 10}})
      table.insert(param_list, {id = "spc_resonance", arc_multi_float = {0.5, 0.1, 0.05}})
    elseif filter_type == FILTER_BANDPASS or filter_type == FILTER_NOTCH then
      table.insert(param_list, {id = "spc_lpf", arc_multi_float = {1000, 100, 10}})
      table.insert(param_list, {id = "spc_hpf", arc_multi_float = {1000, 100, 10}})
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
function SamplerChopConfig.init()
  -- Create screen UI
  SamplerChopConfig.screen = create_screen_ui()

  -- Create parameter group for pad configuration UI
  params:add_group("sampler_pad_config", "SAMPLER PAD CONFIG", 15)

  -- Visual edit trigger for waveform modal
  params:add_binary("spc_visual_edit", "Visual Edit", "trigger", 0)
  params:set_action("spc_visual_edit", function()
    SamplerChopConfig.show_waveform()
  end)

  params:add_control("spc_start_pos", "Start Position",
    controlspec.new(0, 10, 'lin', 0.001, 0, 's'))
  params:set_action("spc_start_pos", function(value)
    SamplerChopConfig.update_chop('start_pos', value)
  end)

  params:add_control("spc_stop_pos", "Stop Position",
    controlspec.new(0, 10, 'lin', 0.001, 0.1, 's'))
  params:set_action("spc_stop_pos", function(value)
    SamplerChopConfig.update_chop('stop_pos', value)
  end)

  params:add_control("spc_attack", "Attack",
    controlspec.new(0.001, 5.0, 'lin', 0.001, 0.01, 's'))
  params:set_action("spc_attack", function(value)
    SamplerChopConfig.update_chop('attack', value)
    SamplerChopConfig.update_chop('uses_global_envelope', false)
    if SamplerChopConfig.screen then
      SamplerChopConfig.screen:rebuild_params()
    end
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)

  params:add_control("spc_release", "Release",
    controlspec.new(0.001, 5.0, 'lin', 0.001, 0.01, 's'))
  params:set_action("spc_release", function(value)
    SamplerChopConfig.update_chop('release', value)
    SamplerChopConfig.update_chop('uses_global_envelope', false)
    if SamplerChopConfig.screen then
      SamplerChopConfig.screen:rebuild_params()
    end
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)

  params:add_control("spc_fade_time", "Crossfade",
    controlspec.new(0.0001, 5.0, 'lin', 0.0001, 0.005, 's'))
  params:set_action("spc_fade_time", function(value)
    SamplerChopConfig.update_chop('fade_time', value)
  end)

  params:add_control("spc_rate", "Speed",
    controlspec.new(-2, 2, 'lin', 0.01, 1.0, ''))
  params:set_action("spc_rate", function(value)
    SamplerChopConfig.update_chop('rate', value)
  end)

  -- Pitch transposition in semitones (-12 to +12, 0 = original)
  local pitch_names = {}
  for semitones = -12, 12 do
    table.insert(pitch_names, theory.offset_to_display(semitones))
  end
  params:add_option("spc_pitch", "Pitch", pitch_names, 13)  -- Index 13 = 0 semitones
  params:set_action("spc_pitch", function(idx)
    local semitones = idx - 13  -- Convert index to semitone offset
    SamplerChopConfig.update_chop('pitch_offset', semitones)
  end)

  params:add_control("spc_max_volume", "Max Volume",
    controlspec.new(0, 1, 'lin', 0.01, 1.0, ''))
  params:set_action("spc_max_volume", function(value)
    SamplerChopConfig.update_chop('max_volume', value)
  end)

  params:add_control("spc_pan", "Pan",
    controlspec.new(-1, 1, 'lin', 0.01, 0, ''))
  params:set_action("spc_pan", function(value)
    SamplerChopConfig.update_chop('pan', value)
  end)

  params:add_option("spc_mode", "Mode", {"Gate", "One-Shot", "Loop"}, 1)
  params:set_action("spc_mode", function(value)
    SamplerChopConfig.update_chop('mode', value)

    -- Stop currently playing pad so new mode setting takes effect
    local lane = SamplerChopConfig.state.current_lane
    local pad = SamplerChopConfig.state.selected_pad
    if _seeker and _seeker.sampler then
      _seeker.sampler.stop_pad(lane, pad)
    end
  end)

  -- Filter controls (editing any filter param marks chop as locally modified)
  params:add_option("spc_filter_type", "Filter Type", {"Off", "Lowpass", "Highpass", "Bandpass", "Notch"}, 1)
  params:set_action("spc_filter_type", function(value)
    SamplerChopConfig.update_chop('filter_type', value)
    SamplerChopConfig.update_chop('uses_global_filter', false)
    if SamplerChopConfig.screen then
      SamplerChopConfig.screen:rebuild_params()
    end
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)

  params:add_taper("spc_lpf", "LPF Cutoff", 20, 20000, 20000, 3, "Hz")
  params:set_action("spc_lpf", function(value)
    SamplerChopConfig.update_chop('lpf', value)
    SamplerChopConfig.update_chop('uses_global_filter', false)
  end)

  params:add_control("spc_resonance", "Resonance",
    controlspec.new(0, 4, 'lin', 0.01, 0, ""))
  params:set_action("spc_resonance", function(value)
    SamplerChopConfig.update_chop('resonance', value)
    SamplerChopConfig.update_chop('uses_global_filter', false)
  end)

  params:add_taper("spc_hpf", "HPF Cutoff", 20, 20000, 20, 3, "Hz")
  params:set_action("spc_hpf", function(value)
    SamplerChopConfig.update_chop('hpf', value)
    SamplerChopConfig.update_chop('uses_global_filter', false)
  end)

  return SamplerChopConfig
end

-- Select a pad for editing
function SamplerChopConfig.select_pad(pad)
  SamplerChopConfig.state.selected_pad = pad
  SamplerChopConfig.state.current_lane = _seeker.ui_state.get_focused_lane()
  SamplerChopConfig.load_pad_params()

  -- Navigate to config section
  _seeker.ui_state.set_current_section("SAMPLER_CHOP_CONFIG")

  -- Rebuild screen to show new pad's config
  if SamplerChopConfig.screen then
    SamplerChopConfig.screen:rebuild_params()
  end

  -- Update waveform modal if open (keeps modal up when switching pads)
  SamplerChopConfig.update_waveform_if_open()

  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

-- Load current pad's chop data into params
function SamplerChopConfig.load_pad_params()
  local lane = SamplerChopConfig.state.current_lane
  local pad = SamplerChopConfig.state.selected_pad

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
  params:set("spc_hpf", chop.hpf or 20, true)
  params:set("spc_resonance", chop.resonance or 0, true)

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
function SamplerChopConfig.update_chop(key, value)
  local lane = SamplerChopConfig.state.current_lane
  local pad = SamplerChopConfig.state.selected_pad

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
function SamplerChopConfig.get_selected_pad()
  return SamplerChopConfig.state.selected_pad
end

-- Compute peaks for a zoomed view around a chop region
local function compute_zoomed_peaks(lane, chop_start, chop_stop)
  local filepath = _seeker.sampler.get_sample_filepath(lane)
  if not filepath then return nil, 0, 0 end

  local duration = _seeker.sampler.get_sample_duration(lane)
  if duration <= 0 then return nil, 0, 0 end

  -- Calculate view window: chop region + 30% padding on each side (min 0.2s)
  local chop_length = chop_stop - chop_start
  local padding = math.max(0.2, chop_length * 0.3)

  local view_start = math.max(0, chop_start - padding)
  local view_end = math.min(duration, chop_stop + padding)

  local peaks = WavPeaks.compute_peaks(filepath, 100, view_start, view_end)

  return peaks, view_start, view_end
end

-- Show waveform modal for current pad
function SamplerChopConfig.show_waveform()
  local lane = SamplerChopConfig.state.current_lane
  local pad = SamplerChopConfig.state.selected_pad

  if not _seeker or not _seeker.sampler then return end

  local chop = _seeker.sampler.get_chop(lane, pad)
  if not chop then return end

  local duration = _seeker.sampler.get_sample_duration(lane)
  if duration <= 0 then return end

  local filepath = _seeker.sampler.get_sample_filepath(lane)
  if not filepath then return end

  local peaks, view_start, view_end = compute_zoomed_peaks(lane, chop.start_pos, chop.stop_pos)
  if not peaks then return end

  -- Reload callback for when markers cross view boundary
  local function reload_view(new_start, new_stop)
    local new_peaks, new_view_start, new_view_end = compute_zoomed_peaks(lane, new_start, new_stop)
    if new_peaks then
      _seeker.modal.update_waveform_chop({
        peaks = new_peaks,
        view_start = new_view_start,
        view_end = new_view_end
      })
      if _seeker and _seeker.screen_ui then
        _seeker.screen_ui.set_needs_redraw()
      end
    end
  end

  _seeker.modal.show_waveform({
    peaks = peaks,
    duration = duration,
    start_pos = chop.start_pos,
    stop_pos = chop.stop_pos,
    view_start = view_start,
    view_end = view_end,
    pad = pad,
    lane = lane,
    filepath = filepath,
    on_change = function(start_pos, stop_pos)
      -- Update chop positions
      params:set("spc_start_pos", start_pos)
      params:set("spc_stop_pos", stop_pos)
      if _seeker and _seeker.screen_ui then
        _seeker.screen_ui.set_needs_redraw()
      end
    end,
    on_reload = reload_view
  })

  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end

  -- Update Arc display to show waveform controls
  if _seeker and _seeker.arc then
    _seeker.arc.update_param_value_display()
  end
end

-- Update waveform modal with new pad data without closing
function SamplerChopConfig.update_waveform_if_open()
  if not _seeker or not _seeker.modal then return end
  if _seeker.modal.get_type() ~= _seeker.modal.TYPE.WAVEFORM then return end

  local lane = SamplerChopConfig.state.current_lane
  local pad = SamplerChopConfig.state.selected_pad

  local chop = _seeker.sampler.get_chop(lane, pad)
  if not chop then return end

  -- Recompute zoomed peaks for new chop
  local peaks, view_start, view_end = compute_zoomed_peaks(lane, chop.start_pos, chop.stop_pos)

  _seeker.modal.update_waveform_chop({
    peaks = peaks,
    view_start = view_start,
    view_end = view_end,
    start_pos = chop.start_pos,
    stop_pos = chop.stop_pos,
    pad = pad,
    on_change = function(start_pos, stop_pos)
      params:set("spc_start_pos", start_pos)
      params:set("spc_stop_pos", stop_pos)
      if _seeker and _seeker.screen_ui then
        _seeker.screen_ui.set_needs_redraw()
      end
    end
  })

  -- Update Arc display for new pad values
  if _seeker.arc then
    _seeker.arc.update_param_value_display()
  end
end

return SamplerChopConfig
