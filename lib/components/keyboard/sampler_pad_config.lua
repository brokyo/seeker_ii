-- sampler_pad_config.lua
-- Dedicated UI for configuring sample chop points and envelopes per-pad
-- Pressing pads selects which to edit (when in this section)
--
-- NOTE: Params are a VIEW into SamplerManager storage, not direct storage
-- This means pad configs DO NOT persist with PSETs currently

local NornsUI = include("lib/ui/base/norns_ui")

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

    self.params = {
      {separator = true, title = string.format("Pad %d Config", pad)},
      {id = "spc_mode"},
      {separator = true, title = string.format("Envelope")},
      {id = "spc_start_pos", arc_multi_float = {1.0, 0.1, 0.01}},
      {id = "spc_stop_pos", arc_multi_float = {1.0, 0.1, 0.01}},
      {id = "spc_attack", arc_multi_float = {0.1, 0.01, 0.001}},
      {id = "spc_release", arc_multi_float = {0.1, 0.01, 0.001}},
      {separator = true, title = string.format("Tuning")},
      {id = "spc_rate", arc_multi_float = {0.5, 0.1, 0.01}},
      {id = "spc_max_volume", arc_multi_float = {0.1, 0.05, 0.01}}
    }
  end

  -- Override enter to rebuild params on section entry
  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    original_enter(self)
    self:rebuild_params()
  end

  return norns_ui
end

-- Initialize params
function SamplerPadConfig.init()
  print("◎ Initializing Sampler Pad Config")

  -- Create screen UI
  SamplerPadConfig.screen = create_screen_ui()

  -- Create parameter group for pad configuration UI
  params:add_group("sampler_pad_config", "SAMPLER PAD CONFIG", 7)

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
    controlspec.new(0.001, 1.0, 'lin', 0.001, 0.01, 's'))
  params:set_action("spc_attack", function(value)
    SamplerPadConfig.update_segment('attack', value)
  end)

  params:add_control("spc_release", "Release",
    controlspec.new(0.001, 1.0, 'lin', 0.001, 0.01, 's'))
  params:set_action("spc_release", function(value)
    SamplerPadConfig.update_segment('release', value)
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

  params:add_option("spc_mode", "Mode", {"One-Shot", "Loop", "Gate"}, 3)
  params:set_action("spc_mode", function(value)
    SamplerPadConfig.update_segment('mode', value)

    -- Stop currently playing pad so new mode setting takes effect
    local lane = SamplerPadConfig.state.current_lane
    local pad = SamplerPadConfig.state.selected_pad
    if _seeker and _seeker.sampler then
      _seeker.sampler.stop_pad(lane, pad)
    end
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
  params:set("spc_rate", segment.rate, true)
  params:set("spc_max_volume", segment.max_volume, true)
  params:set("spc_mode", segment.mode or 1, true)

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
