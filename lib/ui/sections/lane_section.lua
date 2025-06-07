-- lane_section.lua
local Section = include('lib/ui/section')
local LaneSection = setmetatable({}, { __index = Section })
LaneSection.__index = LaneSection

function LaneSection.new()
  local section = Section.new({
    id = "LANE",
    name = "Layer 0",
    icon = "⌸",
    description = "Configure a layer's output. Control over norns engine, MIDI, and Eurorack.",
    params = {}
  })
  
  setmetatable(section, LaneSection)
  
  -- Add method to update params for new lane
  function section:update_focused_lane(new_lane_idx)
    -- Get the current visible voice setting
    local visible_voice = params:get("lane_" .. new_lane_idx .. "_visible_voice")
    
    -- Start with common params
    self.params = {
      { separator = true, name = string.format("Lane %d Config", new_lane_idx) },
      { id = "lane_" .. new_lane_idx .. "_volume", name = "Volume" },
      { id = "lane_" .. new_lane_idx .. "_visible_voice", name = "Config Voice" }
    }
    
    -- Add params based on visible voice selection
    if visible_voice == 1 then -- MX Samples
      table.insert(self.params, { separator = true, name = "Mx Samples" })
      table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_mx_samples_active", name = "MX Samples Active" })
      
      -- Only show additional MX Samples params if active
      if params:get("lane_" .. new_lane_idx .. "_mx_samples_active") == 1 then
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_mx_voice_volume", name = "Voice Volume" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_instrument", name = "Instrument" })
        table.insert(self.params, { separator = true, name = "Individual Event" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_pan", name = "Pan" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_attack", name = "Attack" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_decay", name = "Decay" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_sustain", name = "Sustain" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_release", name = "Release" })
        table.insert(self.params, { separator = true, name = "Lane Effects" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_lpf", name = "LPF Cutoff" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_resonance", name = "LPF Resonance" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_hpf", name = "HPF Cutoff" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_delay_send", name = "Delay Send" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_reverb_send", name = "Reverb Send" })
      end
    elseif visible_voice == 2 then -- MIDI
      table.insert(self.params, { separator = true, name = "MIDI" })
      table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_midi_active", name = "MIDI Active" })
      
      -- Only show additional MIDI params if active
      if params:get("lane_" .. new_lane_idx .. "_midi_active") == 1 then
        table.insert(self.params, { id = 'lane_' .. new_lane_idx .. '_midi_voice_volume', name = 'MIDI Volume' })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_midi_device", name = "MIDI Device" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_midi_channel", name = "MIDI Channel" })
      end
    elseif visible_voice == 3 then -- Crow/TXO
      table.insert(self.params, { separator = true, name = "CV/Gate" })
      table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_eurorack_active", name = "CV/Gate Active" })
      
      -- Only show additional Crow/TXO params if active
      if params:get("lane_" .. new_lane_idx .. "_eurorack_active") == 1 then
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_euro_voice_volume", name = "Voice Volume" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_gate_out", name = "Gate Out" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_cv_out", name = "CV Out" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_loop_start_trigger", name = "Loop Start Out" })
      end
    elseif visible_voice == 4 then -- Just Friends
      table.insert(self.params, { separator = true, name = "Just Friends" })
      table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_just_friends_active", name = "Just Friends Active" })
      
      -- Only show additional Just Friends params if active
      if params:get("lane_" .. new_lane_idx .. "_just_friends_active") == 1 then
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_just_friends_voice_volume", name = "Voice Volume" })
      end
    elseif visible_voice == 5 then -- w/syn
      table.insert(self.params, { separator = true, name = "w/syn" })
      table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_active", name = "w/syn Active" })
      
      -- Only show additional w/syn params if active
      if params:get("lane_" .. new_lane_idx .. "_wsyn_active") == 1 then
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_ar_mode", name = "Pluck Mode" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_voice_volume", name = "Voice Volume" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_curve", name = "Curve" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_ramp", name = "Ramp" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_fm_index", name = "FM Index" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_fm_env", name = "FM Env" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_fm_ratio_num", name = "FM Ratio Numerator" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_fm_ratio_denom", name = "FM Ratio Denominator" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_lpg_time", name = "LPG Time" })
        table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_wsyn_lpg_symmetry", name = "LPG Symmetry" })

      end
    elseif visible_voice == 6 then -- OSC
      table.insert(self.params, { separator = true, name = "OSC" })
      table.insert(self.params, { id = "lane_" .. new_lane_idx .. "_osc_active", name = "OSC Active" })
    end
    
    -- Update section name with lane number
    self.name = string.format("Lane %d", new_lane_idx)
  end
  
  -- Initialize with current lane
  local initial_lane = _seeker.ui_state.get_focused_lane()
  section:update_focused_lane(initial_lane)
  
  -- Add enter method to ensure section is initialized with current lane
  function section:enter()
    -- Update params for current lane first
    self:update_focused_lane(_seeker.ui_state.get_focused_lane())
    
    -- Then call parent enter method (which calls arc.new_section)
    Section.enter(self)
  end
  
  return section
end

return LaneSection