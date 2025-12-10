-- sampler_pad_config.lua
-- Dedicated UI for configuring sample chop points and envelopes per-pad
-- Pressing pads selects which to edit (when in this section)
--
-- NOTE: Params are a VIEW into SamplerManager storage, not direct storage
-- This means pad configs DO NOT persist with PSETs currently

local NornsUI = include("lib/ui/base/norns_ui")

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
    name = "Pad Config",
    description = "Configure individual pad chop points and envelopes. Press pads to select.",
    params = {}
  })

  -- Build params for current selected pad
  function norns_ui:rebuild_params()
    local lane = SamplerPadConfig.state.current_lane
    local pad = SamplerPadConfig.state.selected_pad
    local filter_type = params:get("spc_filter_type")

    local param_list = {
      {separator = true, title = "Sample Config"},
      {id = "spc_mode"},
      {id = "spc_max_volume", arc_multi_float = {0.1, 0.05, 0.01}},
      {separator = true, title = "Slice Points"},
      {id = "spc_start_pos", arc_multi_float = {1.0, 0.1, 0.01}},
      {id = "spc_stop_pos", arc_multi_float = {1.0, 0.1, 0.01}},
      {separator = true, title = "Playback"},
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
  params:add_group("sampler_pad_config", "SAMPLER PAD CONFIG", 9)

  params:add_control("spc_start_pos", "Start Position",
    controlspec.new(0, 10, 'lin', 0.001, 0, 's'))
  params:set_action("spc_start_pos", function(value)
    SamplerPadConfig.update_segment('start_pos', value)
  end)

  params:add_control("spc_stop_pos", "Stop Position",
    controlspec.new(0, 10, 'lin', 0.001, 0.1, 's'))
  params:set_action("spc_stop_pos", function(value)
    SamplerPadConfig.update_segment('stop_pos', value)
  end)

  params:add_control("spc_attack", "Attack",
    controlspec.new(0.001, 5.0, 'lin', 0.001, 0.01, 's'))
  params:set_action("spc_attack", function(value)
    SamplerPadConfig.update_segment('attack', value)
  end)

  params:add_control("spc_release", "Release",
    controlspec.new(0.001, 5.0, 'lin', 0.001, 0.01, 's'))
  params:set_action("spc_release", function(value)
    SamplerPadConfig.update_segment('release', value)
  end)

  params:add_control("spc_fade_time", "Crossfade",
    controlspec.new(0.0001, 5.0, 'lin', 0.0001, 0.005, 's'))
  params:set_action("spc_fade_time", function(value)
    SamplerPadConfig.update_segment('fade_time', value)
  end)

  params:add_control("spc_rate", "Rate",
    controlspec.new(-2, 2, 'lin', 0.01, 1.0, ''))
  params:set_action("spc_rate", function(value)
    SamplerPadConfig.update_segment('rate', value)
  end)

  params:add_control("spc_max_volume", "Max Volume",
    controlspec.new(0, 1, 'lin', 0.01, 1.0, ''))
  params:set_action("spc_max_volume", function(value)
    SamplerPadConfig.update_segment('max_volume', value)
  end)

  params:add_control("spc_pan", "Pan",
    controlspec.new(-1, 1, 'lin', 0.01, 0, ''))
  params:set_action("spc_pan", function(value)
    SamplerPadConfig.update_segment('pan', value)
  end)

  params:add_option("spc_mode", "Mode", {"Gate", "One-Shot"}, 1)
  params:set_action("spc_mode", function(value)
    SamplerPadConfig.update_segment('mode', value)

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
    SamplerPadConfig.update_segment('filter_type', value)
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
    SamplerPadConfig.update_segment('lpf', value)
  end)

  params:add_control("spc_resonance", "Resonance",
    controlspec.new(0, 4, 'lin', 0.01, 0, ""))
  params:set_action("spc_resonance", function(value)
    SamplerPadConfig.update_segment('resonance', value)
  end)

  params:add_taper("spc_hpf", "HPF Cutoff", 20, 20000, 20, 3, "Hz")
  params:set_action("spc_hpf", function(value)
    SamplerPadConfig.update_segment('hpf', value)
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

-- Load current pad's segment data into params
function SamplerPadConfig.load_pad_params()
  local lane = SamplerPadConfig.state.current_lane
  local pad = SamplerPadConfig.state.selected_pad

  if not _seeker or not _seeker.sampler then return end

  local segment = _seeker.sampler.get_segment(lane, pad)
  if not segment then return end

  -- Update params without triggering actions
  params:set("spc_start_pos", segment.start_pos, true)
  params:set("spc_stop_pos", segment.stop_pos, true)
  params:set("spc_attack", segment.attack, true)
  params:set("spc_release", segment.release, true)
  params:set("spc_fade_time", segment.fade_time or 0.005, true)
  params:set("spc_rate", segment.rate, true)
  params:set("spc_max_volume", segment.max_volume, true)
  params:set("spc_pan", segment.pan or 0, true)
  params:set("spc_mode", segment.mode or 1, true)
  params:set("spc_filter_type", segment.filter_type or 1, true)
  params:set("spc_lpf", segment.lpf or 20000, true)
  params:set("spc_resonance", segment.resonance or 0, true)
  params:set("spc_hpf", segment.hpf or 20, true)

  -- Update max values based on sample duration
  local duration = _seeker.sampler.get_sample_duration(lane)
  if duration > 0 then
    params:lookup_param("spc_start_pos").controlspec.maxval = duration
    params:lookup_param("spc_stop_pos").controlspec.maxval = duration
  end
end

-- Update a segment property for current pad
function SamplerPadConfig.update_segment(key, value)
  local lane = SamplerPadConfig.state.current_lane
  local pad = SamplerPadConfig.state.selected_pad

  if not _seeker or not _seeker.sampler then return end

  _seeker.sampler.update_segment(lane, pad, key, value)

  -- Auto-adjust stop if start moves past it
  if key == "start_pos" then
    local segment = _seeker.sampler.get_segment(lane, pad)
    if segment and value >= segment.stop_pos then
      local new_stop = math.min(value + 0.1, _seeker.sampler.get_sample_duration(lane))
      params:set("spc_stop_pos", new_stop)
    end
  end

  -- Auto-adjust start if stop moves before it
  if key == "stop_pos" then
    local segment = _seeker.sampler.get_segment(lane, pad)
    if segment and value <= segment.start_pos then
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
