--[[
  channel.lua
  Core channel functionality for Seeker II

  Handles:
  - Channel state management (start/stop)
  - Clock division and sync
  - Pulse behaviors (simple, strum, burst)
  - Parameter management

  Dependencies:
  - utils.lua: Debug and utility functions
  - theory_utils.lua: Musical timing constants
  - clock_utils.lua: Clock division handling
  - params_manager.lua: Parameter visibility management
  - default_channel_params.lua: Default parameter values
  - nb/lib/nb: Norns voice management
]]--

-- All logic relates to the channel

local utils = include('lib/utils')
local theory_utils = include('lib/theory_utils')
local clock_utils = include('lib/clock_utils')
local default_channel_params = include("lib/default_channel_params")
local params_manager = include("lib/params_manager")
local nb = require("nb/lib/nb")
local musicutil = require("musicutil")

-- Define the class
local Channel = {}
Channel.__index = Channel

-- Constructor for new instances
function Channel.new(id)
    local self = setmetatable({}, Channel)
    self.id = id
    self.running = false
    self.clock_id = nil
    self.pulse_callbacks = {}
    self.note_callbacks = {}  -- Add note callbacks

    local defaults = utils.deep_copy(default_channel_params)
    for k, v in pairs(defaults) do
        self[k] = v
    end

    return self
end

-- Add a callback to be triggered on each pulse
function Channel:add_pulse_callback(callback)
    table.insert(self.pulse_callbacks, callback)
end

-- Add a callback to be triggered when notes start/stop
function Channel:add_note_callback(callback)
    table.insert(self.note_callbacks, callback)
end

function Channel:add_clock_params(channel_id)
    -- Count:
    -- 1 separator (Clock Config)
    -- 3 parameters (source, mod, behavior)
    -- 1 separator (Strum Config)
    -- 4 strum parameters (duration, pulses, clustering, variation)
    -- 1 separator (Burst Config)
    -- 2 burst parameters (window, style)
    -- Total: 12 parameters
    params:add_group("clock_" .. channel_id, "Clock", 12)
    params:add_separator("clock_section_header_" .. channel_id, "Clock Config")
    
    params:add {
      id = "clock_source_" .. channel_id,
      name = "Clock Source",
      type = "option",
      options = {"internal", "external"},
        default = 1,
      action = function(value)
        utils.debug_print("Channel " .. channel_id .. " clock source set to " .. (value == 1 and "internal" or "external"))
      end
    }
  
    params:add {
      id = "clock_mod_" .. channel_id,
      name = "Clock Mod",
      type = "option",
        options = clock_utils.divisions,
        default = 9,
      action = function(value)
            local division = clock_utils.get_division(value)
        utils.debug_print("Channel " .. channel_id .. " clock mod set to " .. division)
      end
    }
  
    params:add {
      id = "clock_pulse_behavior_" .. channel_id,
      name = "Clock Pulse Behavior",
      type = "option",
      options = {"Pulse", "Strum", "Burst"},
        default = 1,
      action = function(value)
        utils.debug_print("Channel " .. channel_id .. " pulse behavior set to " .. ({"Pulse", "Strum", "Burst"})[value])
            params_manager.update_behavior_visibility(channel_id, value)
        end
    }

    -- Strum Parameters
    params:add_separator("strum_header_" .. channel_id, "Strum Config")
    params:add {
        id = "strum_duration_" .. channel_id,
        name = "Strum Window",
        type = "option",
        options = theory_utils.note_lengths,
        default = 5,
        action = function(value)
            local length = theory_utils.get_note_length(value)
            utils.debug_print("Channel " .. channel_id .. " strum window set to " .. length)
        end
    }
    
    params:add {
        id = "strum_pulses_" .. channel_id,
        name = "Strum Events",
        type = "number",
        min = 2,
        max = 12,
        default = 3,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " strum events set to " .. value)
        end
    }
    
    params:add {
        id = "strum_clustering_" .. channel_id,
        name = "Motion Shape",
        type = "number",
        min = 0,
        max = 100,
        default = 50,
        action = function(value)
            local description = value < 50 and "losing energy" or "gaining energy"
            utils.debug_print("Channel " .. channel_id .. " strum motion: " .. description)
        end
    }
    
    params:add {
        id = "strum_variation_" .. channel_id,
        name = "Human Feel",
        type = "number",
        min = 0,
        max = 100,
        default = 15,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " human feel set to " .. value .. "%")
        end
    }

    -- Burst Parameters
    params:add_separator("burst_header_" .. channel_id, "Burst Config")
    params:add {
        id = "burst_window_" .. channel_id,
        name = "Burst Window",
      type = "option",
        options = theory_utils.note_lengths,
        default = 5,
      action = function(value)
        local length = theory_utils.get_note_length(value)
            utils.debug_print("Channel " .. channel_id .. " burst window set to " .. length)
        end
    }
    
    params:add {
        id = "burst_style_" .. channel_id,
        name = "Burst Style",
        type = "option",
        options = {
            "Spray",      -- Like throwing a handful of pebbles, scattered and wild
            "Accelerate", -- A gentle roll building into an avalanche
            "Decelerate", -- Tumbling down stairs in slow motion
            "Crescendo",  -- The sound of anticipation becoming reality
            "Cascade",    -- Three waves breaking one after another
            "Pulse",      -- A steady heart with the occasional skip
            "Bounce",     -- A rubber ball caught in a cosmic groove
            "Chaos"       -- Order and disorder playing cat and mouse
        },
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " burst style set to " .. value)
        end
    }
end

function Channel:add_voice_params(channel_id)
    -- Count:
    -- 1 separator (Voice Config)
    -- 1 voice parameter
    -- Total: 2 parameters
    params:add_group("voice_" .. channel_id, "Voice", 2)
    params:add_separator("voice_header_" .. channel_id, "Voice Config")
    local voice_id = "channel_voice_" .. channel_id
    nb:add_param(voice_id, "Voice " .. channel_id)
end

function Channel:add_arp_params(channel_id)
    -- Count:
    -- 1 separator (Chord)
    -- 6 chord parameters
    -- 1 separator (Pattern)
    -- 2 arp parameters
    -- Total: 10 parameters
    params:add_group("arp_" .. channel_id, "Arpeggiation", 10)
    
    -- Chord Selection
    params:add_separator("chord_header_" .. channel_id, "Chord")
    
    params:add {
        type = "option",
        id = "chord_degree_" .. channel_id,
        name = "Degree",
        options = {"I", "II", "III", "IV", "V", "VI", "VII"},
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " chord degree set to " .. ({"I", "II", "III", "IV", "V", "VI", "VII"})[value])
            -- Regenerate notes when degree changes
            self:generate_chord_notes(channel_id)
        end
    }
    
    params:add {
        type = "option",
        id = "chord_quality_" .. channel_id,
        name = "Quality",
        options = {"Major", "Minor", "Diminished", "Augmented"},
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " chord quality set to " .. ({"Major", "Minor", "Diminished", "Augmented"})[value])
            self:generate_chord_notes(channel_id)
        end
    }
    
    params:add {
        type = "option",
        id = "chord_extension_" .. channel_id,
        name = "Extension",
        options = {"None", "7", "9", "11", "13"},
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " chord extension set to " .. ({"None", "7", "9", "11", "13"})[value])
            self:generate_chord_notes(channel_id)
        end
    }
    
    params:add {
        type = "option",
        id = "chord_inversion_" .. channel_id,
        name = "Inversion",
        options = {"Root", "First", "Second", "Third"},
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " chord inversion set to " .. ({"Root", "First", "Second", "Third"})[value])
            self:generate_chord_notes(channel_id)
        end
    }

    params:add {
        type = "number",
        id = "chord_octave_" .. channel_id,
        name = "Start Octave",
        min = 0,
        max = 8,
        default = 4,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " chord octave set to " .. value)
            self:generate_chord_notes(channel_id)
        end
    }
    
    params:add {
        type = "number",
        id = "chord_range_" .. channel_id,
        name = "Note Count",
        min = 3,
        max = 12,
        default = 4,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " chord range set to " .. value .. " notes")
            self:generate_chord_notes(channel_id)
        end
    }
    
    -- Arpeggiator Behavior
    params:add_separator("arp_behavior_" .. channel_id, "Pattern")
    
    params:add {
        type = "option",
        id = "arp_style_" .. channel_id,
        name = "Style",
        options = {"Up", "Down", "Up-Down", "Random", "Random-Lock"},
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " arp style set to " .. ({"Up", "Down", "Up-Down", "Random", "Random-Lock"})[value])
        end
    }
    
    params:add {
        type = "number",
        id = "arp_step_" .. channel_id,
        name = "Step Size",
        min = -4,
        max = 4,
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " arp step size set to " .. value)
      end
    }
end

function Channel:add_expression_params(channel_id)
    -- Count:
    -- 1 separator
    -- 4 parameters (preset, period, min, max)
    -- Total: 5 parameters
    params:add_group("expression_" .. channel_id, "Expression", 5)
    params:add_separator("expression_header_" .. channel_id, "Expression")
    
    params:add {
        type = "option",
        id = "velocity_preset_" .. channel_id,
        name = "Velocity Pattern",
        options = {"Static", "Rise", "Fall", "Steps"},
        default = 1,
        action = function(value)
            if SEEKER_VERBOSE then
                utils.debug_print("Channel " .. channel_id .. " velocity preset set to " .. ({"Static", "Rise", "Fall", "Steps"})[value])
            end
            -- Reset any preset-specific state
            self.expression_state = self.expression_state or {}
            self.expression_state[channel_id] = {}
        end
    }
    
    params:add {
        type = "control",
        id = "velocity_period_" .. channel_id,
        name = "Pattern Period",
        controlspec = controlspec.new(0.25, 32, 'exp', 0.25, 4, 'b'),
        action = function(value)
            if SEEKER_VERBOSE then
                utils.debug_print("Channel " .. channel_id .. " velocity period set to " .. value .. " beats")
            end
        end
    }
    
    params:add {
        type = "control",
        id = "velocity_min_" .. channel_id,
        name = "Min Velocity",
        controlspec = controlspec.new(0, 127, 'lin', 1, 32, ''),
        action = function(value)
            if SEEKER_VERBOSE then
                utils.debug_print("Channel " .. channel_id .. " min velocity set to " .. value)
            end
        end
    }
    
    params:add {
        type = "control",
        id = "velocity_max_" .. channel_id,
        name = "Max Velocity",
        controlspec = controlspec.new(0, 127, 'lin', 1, 96, ''),
        action = function(value)
            if SEEKER_VERBOSE then
                utils.debug_print("Channel " .. channel_id .. " max velocity set to " .. value)
            end
        end
    }
end

function Channel:add_rhythm_params(channel_id)
    -- Count:
    -- 1 separator
    -- Total: 1 parameter
    params:add_group("rhythm_" .. channel_id, "Rhythm", 1)
    params:add_separator("rhythm_header_" .. channel_id, "Rhythm (Coming Soon)")
end

function Channel:add_duration_params(channel_id)
    -- Count:
    -- 1 separator (Duration Config)
    -- 3 base parameters (mode, base, humanize)
    -- 1 separator (Pattern Config)
    -- 4 pattern parameters (length, shape, min, max)
    -- Total: 9 parameters
    params:add_group("duration_" .. channel_id, "Duration", 9)
    params:add_separator("duration_header_" .. channel_id, "Duration Config")
    
    params:add {
        type = "option",
        id = "duration_mode_" .. channel_id,
        name = "Mode",
        options = {"Fixed", "Pattern"},
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " duration mode set to " .. ({"Fixed", "Pattern"})[value])
            params_manager.update_duration_visibility(channel_id, value)
        end
    }
    
    params:add {
        type = "option",
        id = "duration_base_" .. channel_id,
        name = "Base Duration",
        options = theory_utils.note_lengths,
        default = 9,  -- "1" beat
        action = function(value)
            local length = theory_utils.get_note_length(value)
            utils.debug_print("Channel " .. channel_id .. " base duration set to " .. length)
        end
    }
    
    params:add {
        type = "number",
        id = "duration_variance_" .. channel_id,
        name = "Variance",
        min = 0,
        max = 25,
        default = 0,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " variance set to " .. value .. "%")
        end
    }
    
    -- Pattern mode parameters
    params:add_separator("duration_pattern_header_" .. channel_id, "Pattern Config")
    
    params:add {
        type = "number",
        id = "duration_pattern_length_" .. channel_id,
        name = "Pattern Length",
        min = 2,
        max = 16,
        default = 4,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " pattern length set to " .. value)
            -- Reset pattern state when length changes
            if self.duration_state and self.duration_state[channel_id] then
                self.duration_state[channel_id].pattern_position = 1
            end
        end
    }
    
    params:add {
        type = "option",
        id = "duration_pattern_shape_" .. channel_id,
        name = "Pattern Shape",
        options = {
            "Pendulum",    -- Long-short alternation
            "Mountain",    -- Build up and down
            "Valley",      -- Drop down and up
            "Steps",       -- Random but repeating sequence
            "Gather",      -- Short to long progression
            "Scatter"      -- Long to short progression
        },
        default = 1,
        action = function(value)
            utils.debug_print("Channel " .. channel_id .. " pattern shape set to " .. ({"Pendulum", "Mountain", "Valley", "Steps", "Gather", "Scatter"})[value])
            -- Generate new random pattern ONLY for Steps
            if value == 4 then  -- Steps
                self:generate_locked_duration_sequence(channel_id)
            end
        end
    }
    
    params:add {
        type = "option",
        id = "duration_min_" .. channel_id,
        name = "Min Duration",
        options = theory_utils.note_lengths,
        default = 5,  -- "1/4" beat
        action = function(value)
            local length = theory_utils.get_note_length(value)
            utils.debug_print("Channel " .. channel_id .. " min duration set to " .. length)
        end
    }
    
    params:add {
        type = "option",
        id = "duration_max_" .. channel_id,
        name = "Max Duration",
        options = theory_utils.note_lengths,
        default = 13,  -- "2" beats
        action = function(value)
            local length = theory_utils.get_note_length(value)
            utils.debug_print("Channel " .. channel_id .. " max duration set to " .. length)
        end
    }
    
    -- Set initial visibility based on default mode (Fixed)
    params_manager.update_duration_visibility(channel_id, 1)
end

function Channel:add_params(channel_id)
    -- Main channel section
    params:add_separator("channel_header_" .. channel_id, "Seeker: Channel " .. channel_id)
    
    -- Add all parameter groups
    self:add_clock_params(channel_id)
    self:add_voice_params(channel_id)
    self:add_duration_params(channel_id)  -- Add duration params
    self:add_arp_params(channel_id)
    self:add_expression_params(channel_id)
    self:add_rhythm_params(channel_id)
end

function Channel:start(channel_id)
  if not self.running then
    utils.debug_print("Starting Channel", channel_id)
    self.running = true
    self.last_pulse_time = nil
    
    -- Initialize arp state and generate initial notes
    self:init_arp_state(channel_id)
    self:generate_chord_notes(channel_id)
    
    self.clock_id = clock.run(function()
      while self.running do
        -- Trigger the channel's pulse action here
        self:pulse_channel(channel_id)
        -- Get the clock time directly from param index
        local clock_mod_value = params:get("clock_mod_" .. channel_id)
        local sync_time = clock_utils.index_to_time(clock_mod_value)
        -- Log the wait time
        if SEEKER_VERBOSE then
            utils.debug_print(string.format("Waiting %.3f beats", sync_time), channel_id)
        end
        -- Wait for the channel's modified time interval
        clock.sync(sync_time)
      end
    end)
  end
end

function Channel:stop_channel(channel_id)
  if self.running then
    utils.debug_print("Stopping Channel", channel_id)
    self.running = false
    if self.clock_id then
      clock.cancel(self.clock_id)
      self.clock_id = nil
    end
  end
end

function Channel:generate_strum_timing(channel_id)
    local duration_idx = params:get("strum_duration_" .. channel_id)
    local duration_beats = theory_utils.get_note_length(duration_idx)
    local duration_value = load("return " .. duration_beats)()
    local total_duration = clock.get_beat_sec() * duration_value
    local num_pulses = params:get("strum_pulses_" .. channel_id)
    local clustering = params:get("strum_clustering_" .. channel_id)
    local variation = params:get("strum_variation_" .. channel_id)

    utils.debug_print(string.format(
        "Generating strum: duration=%.3f beats (%.3fs), pulses=%d, clustering=%d, variation=%d",
        duration_value, total_duration, num_pulses, clustering, variation
    ), channel_id)

    local pulse_times = {}
    local min_time = 0.005 -- Increased minimum time to 5ms for better reliability
    
    -- Position-based clustering
    for i = 1, num_pulses do
        local normalized_index = (i - 1) / (num_pulses - 1)
        local t
        
        if clustering < 33 then
            -- Cluster near start
            local cluster_strength = (33 - clustering) / 33  -- 1 at 0, 0 at 33
            t = total_duration * (normalized_index * (1 - cluster_strength) + 
                math.pow(normalized_index, 3) * cluster_strength)
        elseif clustering > 66 then
            -- Cluster near end
            local cluster_strength = (clustering - 66) / 33  -- 0 at 66, 1 at 100
            t = total_duration * (normalized_index * (1 - cluster_strength) + 
                math.pow(normalized_index, 1/3) * cluster_strength)
        else
            -- Even spacing
            t = total_duration * normalized_index
        end
        
        -- Add human-like variation
        if variation > 0 then
            local variance_shape = math.sin(normalized_index * math.pi)
            local max_variation = total_duration * (variation/100) / num_pulses
            local raw_shift = (math.random() - 0.5) * max_variation
            local variation_amount = raw_shift * variance_shape
            t = t + variation_amount
        end
        
        -- Ensure first event has enough delay to be triggered
        if i == 1 then
            t = math.max(min_time, t)
        end
        
        -- Ensure last event doesn't exceed total duration
        if i == num_pulses then
            t = math.min(t, total_duration)
        end
        
        table.insert(pulse_times, t)
    end
    
    -- Sort to maintain forward motion
    table.sort(pulse_times)
    
    -- Ensure minimum spacing between events
    for i = 2, #pulse_times do
        if pulse_times[i] - pulse_times[i-1] < min_time then
            pulse_times[i] = pulse_times[i-1] + min_time
        end
    end

    -- After generating all event times, log them in a table format
    if SEEKER_DEBUG then
        utils.debug_table("Event sequence:", channel_id)
        utils.debug_table(string.format(
            "%-6s %-8s %-12s %s", 
            "Event", "Time", "Duration", "Note"
        ), channel_id)
        utils.debug_table(string.format(
            "%-6s %-8s %-12s %s", 
            "-----", "----", "--------", "----"
        ), channel_id)
        
        -- Make a copy of arp state for preview
        local preview_state = {
            current_index = self.arp_state[channel_id].current_index,
            current_notes = self.arp_state[channel_id].current_notes,
            direction = self.arp_state[channel_id].direction,
            random_sequence = self.arp_state[channel_id].random_sequence
        }
        
        -- Preview and log each event
        for i, t in ipairs(pulse_times) do
            local note = self:preview_next_note(channel_id, preview_state)
            local note_name = musicutil.note_num_to_name(note)
            local duration = self:calculate_duration(channel_id, t)  -- Pass the event offset
            
            utils.debug_table(string.format(
                "%-6d %-8.3f %-12.3f %d (%s)", 
                i, t, duration, note, note_name
            ), channel_id)
        end
        utils.debug_table("----------------------------------------", channel_id)
    end

    return pulse_times
end

function Channel:generate_burst_timing(channel_id)
    local window_idx = params:get("burst_window_" .. channel_id)
    local window_beats = theory_utils.get_note_length(window_idx)
    local window_value = load("return " .. window_beats)()
    local total_duration = clock.get_beat_sec() * window_value
    local style = params:get("burst_style_" .. channel_id)
    
    utils.debug_print(string.format(
        "Generating burst: window=%.3f beats (%.3fs), style=%s",
        window_value, total_duration, ({"Spray", "Accelerate", "Decelerate", "Crescendo", "Cascade", "Pulse", "Bounce", "Chaos"})[style]
    ), channel_id)

    local event_times = {}
    local min_time = 0.001 -- Minimum time in seconds
    
    -- Reset pattern position for this burst
    if self.duration_state and self.duration_state[channel_id] then
        self.duration_state[channel_id].pattern_position = 1
    end
    
    if style == 1 then -- Spray
        -- Like throwing a handful of pebbles: more chaotic at start, settling at end
        local num_events = math.random(10, 18)
        for i = 1, num_events do
            -- More events clustered in first half
            local t = math.random() * total_duration
            if i <= num_events/2 then
                t = t * 0.6  -- Front-loaded
            end
            table.insert(event_times, t)
        end
        
    elseif style == 2 then -- Accelerate
        -- A gentle roll building into an avalanche: exponential acceleration
        local num_events = 16
        for i = 1, num_events do
            local normalized = (i - 1) / (num_events - 1)
            -- Sharper acceleration curve
            local t = total_duration * math.pow(normalized, 3)
            table.insert(event_times, t)
        end
        
    elseif style == 3 then -- Decelerate
        -- Tumbling down stairs: distinct impacts that slow down
        local num_events = 12
        for i = 1, num_events do
            local normalized = (i - 1) / (num_events - 1)
            -- Add slight randomness to timing to simulate bounces
            local bounce = math.sin(normalized * math.pi * 3) * 0.03
            local t = total_duration * (1 - math.pow(1 - normalized, 2)) + (bounce * total_duration)
            table.insert(event_times, t)
        end
        
    elseif style == 4 then -- Crescendo
        -- Anticipation becoming reality: sparse to dense with increasing variation
        local num_events = 20
        for i = 1, num_events do
            local normalized = (i - 1) / (num_events - 1)
            -- More dramatic build-up curve
            local t = total_duration * (1 - math.pow(1 - normalized, 0.7))
            -- Increasing randomness towards the end
            local jitter = (math.random() - 0.5) * 0.15 * math.pow(normalized, 2)
            t = t + (jitter * total_duration)
            table.insert(event_times, t)
        end
        
    elseif style == 5 then -- Cascade
        -- Three distinct waves, each slightly more intense
        local waves = 3
        local events_per_wave = {6, 8, 10}  -- Increasing density
        for w = 1, waves do
            local num_events = events_per_wave[w]
            local wave_start = (w - 1) / waves
            local wave_duration = 1.2 / waves  -- Slight overlap
            for i = 1, num_events do
                local normalized = (i - 1) / (num_events - 1)
                -- Each wave has a slight curve
                local t = total_duration * (wave_start + (normalized * wave_duration * 0.8))
                -- Add slight randomness within each wave
                t = t + (math.random() - 0.5) * 0.02 * total_duration
                table.insert(event_times, t)
            end
        end
        
    elseif style == 6 then -- Pulse
        -- A steady heart with occasional skips: pairs of events
        local num_pairs = 6
        for i = 1, num_pairs do
            local base_time = total_duration * ((i - 1) / (num_pairs - 1))
            -- First beat of pair
            table.insert(event_times, base_time)
            -- Second beat slightly delayed (occasional extra delay)
            local delay = 0.02
            if math.random() < 0.3 then delay = delay * 2 end
            table.insert(event_times, base_time + (delay * total_duration))
        end
        
    elseif style == 7 then -- Bounce
        -- A rubber ball: exponentially decreasing bounces
        local num_bounces = 8
        local decay = 0.7  -- Energy loss per bounce
        local time = 0
        local velocity = 1.0
        for i = 1, num_bounces do
            table.insert(event_times, time * total_duration)
            -- Time between bounces decreases with velocity
            time = time + velocity
            velocity = velocity * decay
        end
        
    else -- Chaos
        -- Order and disorder playing cat and mouse: alternating patterns and randomness
        local num_events = math.random(16, 24)
        local is_ordered = true
        local current_time = 0
        while current_time < 1 and #event_times < num_events do
            if is_ordered then
                -- Brief ordered sequence
                for i = 1, 3 do
                    local t = current_time + (i - 1) * 0.04
                    if t < 1 then
                        table.insert(event_times, t * total_duration)
                    end
                end
                current_time = current_time + 0.15
            else
                -- Random cluster
                local cluster_size = math.random(2, 4)
                for i = 1, cluster_size do
                    local t = current_time + math.random() * 0.1
                    if t < 1 then
                        table.insert(event_times, t * total_duration)
                    end
                end
                current_time = current_time + 0.2
            end
            is_ordered = not is_ordered
        end
    end
    
    -- Sort and ensure minimum spacing
    table.sort(event_times)
    for i = 2, #event_times do
        if event_times[i] - event_times[i-1] < min_time then
            event_times[i] = event_times[i-1] + min_time
        end
    end
    
    -- Ensure all events are within window
    for i = 1, #event_times do
        event_times[i] = math.max(min_time, math.min(event_times[i], total_duration))
    end

    -- After generating all event times, log them in a table format
    if SEEKER_DEBUG then
        utils.debug_table("Event sequence:", channel_id)
        utils.debug_table(string.format(
            "%-6s %-8s %-12s %s", 
            "Event", "Time", "Duration", "Note"
        ), channel_id)
        utils.debug_table(string.format(
            "%-6s %-8s %-12s %s", 
            "-----", "----", "--------", "----"
        ), channel_id)
        
        -- Make a copy of arp state for preview
        local preview_state = {
            current_index = self.arp_state[channel_id].current_index,
            current_notes = self.arp_state[channel_id].current_notes,
            direction = self.arp_state[channel_id].direction,
            random_sequence = self.arp_state[channel_id].random_sequence
        }
        
        -- Preview and log each event
        for i, t in ipairs(event_times) do
            local note = self:preview_next_note(channel_id, preview_state)
            local note_name = musicutil.note_num_to_name(note)
            -- Calculate duration with normalized position based on event index
            local duration = self:calculate_duration(channel_id, t)
            
            utils.debug_table(string.format(
                "%-6d %-8.3f %-12.3f %d (%s)", 
                i, t, duration, note, note_name
            ), channel_id)
        end
        utils.debug_table("----------------------------------------", channel_id)
        utils.debug_table("", channel_id)  -- Empty line
    end

    return event_times
end

function Channel:get_next_note(channel_id)
    -- Initialize or update the chord notes if needed
    if not self.arp_state or not self.arp_state[channel_id] then
        self:generate_chord_notes(channel_id)
    end
    
    local state = self.arp_state[channel_id]
    local notes = state.current_notes
    local style = params:get("arp_style_" .. channel_id)
    local step_size = params:get("arp_step_" .. channel_id)
    local style_names = {"Up", "Down", "Up-Down", "Random", "Random-Lock"}
    
    if SEEKER_VERBOSE then
        utils.debug_print(string.format(
            "Arp State: style=%s, position=%d/%d, step=%d, direction=%s",
            style_names[style], state.current_index, #notes, step_size,
            state.direction == 1 and "up" or "down"
        ), channel_id)
    end
    
    -- Get the current note based on the arpeggiator style
    local note
    local next_index
    if style == 1 then  -- Up
        note = notes[state.current_index]
        -- Calculate next position with wrapping for any step size
        next_index = state.current_index + math.abs(step_size)
        while next_index > #notes do
            next_index = next_index - #notes
        end
        if SEEKER_VERBOSE and next_index < state.current_index then 
            utils.debug_print("Up pattern wrapping to start", channel_id) 
        end
    elseif style == 2 then  -- Down
        note = notes[state.current_index]
        -- Calculate next position with wrapping for any step size
        next_index = state.current_index - math.abs(step_size)
        while next_index < 1 do
            next_index = next_index + #notes
        end
        if SEEKER_VERBOSE and next_index > state.current_index then 
            utils.debug_print("Down pattern wrapping to end", channel_id) 
        end
    elseif style == 3 then  -- Up-Down
        note = notes[state.current_index]
        -- Use step size direction for up-down movement
        next_index = state.current_index + (math.abs(step_size) * state.direction)
        if next_index > #notes then
            state.direction = -1
            -- Calculate wrap position for upward overflow
            next_index = #notes - (next_index - #notes - 1)
            if SEEKER_VERBOSE then utils.debug_print("Up-Down pattern reversing direction (going down)", channel_id) end
        elseif next_index < 1 then
            state.direction = 1
            -- Calculate wrap position for downward overflow
            next_index = 1 + math.abs(next_index)
            if SEEKER_VERBOSE then utils.debug_print("Up-Down pattern reversing direction (going up)", channel_id) end
        end
    elseif style == 4 then  -- Random
        next_index = math.random(#notes)
        note = notes[next_index]
        if SEEKER_VERBOSE then utils.debug_print("Random pattern jumping to position " .. next_index, channel_id) end
    else  -- Random-Lock
        -- Initialize random sequence if needed
        if not state.random_sequence or #state.random_sequence == 0 then
            if SEEKER_VERBOSE then
                utils.debug_print("No Random-Lock sequence exists, generating new one", channel_id)
            end
            self:generate_random_sequence(channel_id)
        end
        
        -- Ensure current_index is within bounds
        if state.current_index > #state.random_sequence then
            if SEEKER_VERBOSE then
                utils.debug_print("Random-Lock position reset to start", channel_id)
            end
            state.current_index = 1
        end
        
        -- Get note from random sequence
        local seq_idx = state.random_sequence[state.current_index]
        note = notes[seq_idx]
        
        if SEEKER_VERBOSE then
            local sequence_preview = {}
            for i, idx in ipairs(state.random_sequence) do
                local note_name = musicutil.note_num_to_name(notes[idx])
                if i == state.current_index then
                    note_name = "*" .. note_name .. "*"  -- Mark current position
                end
                table.insert(sequence_preview, note_name)
            end
            utils.debug_print(string.format(
                "Random-Lock playback: [%s] (step: %d)",
                table.concat(sequence_preview, ","),
                step_size
            ), channel_id)
        end
        
        -- Advance with wrapping
        next_index = state.current_index + math.abs(step_size)
        while next_index > #notes do
            next_index = next_index - #notes
        end
        if SEEKER_VERBOSE and next_index < state.current_index then 
            utils.debug_print("Random-Lock pattern restarting sequence", channel_id) 
        end
    end
    
    -- Log the note movement
    if SEEKER_VERBOSE then
        utils.debug_print(string.format(
            "Moving from note %d (%s) to position %d",
            note, musicutil.note_num_to_name(note), next_index
        ), channel_id)
    end
    
    -- Update position
    state.current_index = next_index
    
    return note
end

local function sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

function Channel:calculate_velocity(channel_id)
    local preset = params:get("velocity_preset_" .. channel_id)
    local period = params:get("velocity_period_" .. channel_id)
    local min_vel = params:get("velocity_min_" .. channel_id) / 127
    local max_vel = params:get("velocity_max_" .. channel_id) / 127
    
    -- Initialize expression state for this channel if needed
    self.expression_state = self.expression_state or {}
    self.expression_state[channel_id] = self.expression_state[channel_id] or {}
    local state = self.expression_state[channel_id]
    
    -- Get current beat
    local current_beat = clock.get_beats()
    
    -- Calculate phase (0 to 1) within the period
    local phase = (current_beat % period) / period
    
    -- Start with normalized velocity (0-1)
    local norm_velocity = 1.0  -- Default to max for static
    
    if preset == 1 then  -- Static
        norm_velocity = 1.0  -- Always use max velocity
        
    elseif preset == 2 then  -- Rise
        norm_velocity = phase
        
    elseif preset == 3 then  -- Fall
        norm_velocity = 1 - phase
        
    elseif preset == 4 then  -- Steps
        -- Generate new random steps at start of period
        if not state.steps or phase < (state.last_phase or 0) then
            state.steps = {}
            for i = 1, 8 do  -- 8 steps per period
                state.steps[i] = math.random()  -- Full range for steps
            end
        end
        state.last_phase = phase
        
        -- Find current step
        local step_index = math.floor(phase * 8) + 1
        norm_velocity = state.steps[step_index]
    end
    
    -- Scale normalized velocity to min/max range
    local velocity = util.linlin(0, 1, min_vel, max_vel, norm_velocity)
    
    -- Debug velocity calculation if enabled
    if SEEKER_VERBOSE then
        utils.debug_table("----------------------------------------", channel_id)
        utils.debug_table("Velocity Calculation:", channel_id)
        utils.debug_table(string.format(
            "Beat: %.2f, Period: %.2f, Phase: %.2f", 
            current_beat, period, phase
        ), channel_id)
        utils.debug_table(string.format(
            "Preset: %s, Range: %d-%d",
            ({"Static", "Rise", "Fall", "Steps"})[preset],
            min_vel * 127,
            max_vel * 127
        ), channel_id)
        utils.debug_table(string.format(
            "Normalized: %.2f, Final: %.2f",
            norm_velocity,
            velocity
        ), channel_id)
        if preset == 4 and state.steps then
            utils.debug_table(string.format(
                "Steps: %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f",
                table.unpack(state.steps)
            ), channel_id)
        end
        utils.debug_table("----------------------------------------", channel_id)
    end
    
    return velocity
end

function Channel:trigger_note(channel_id, note, event_offset)
    local player = params:lookup_param("channel_voice_" .. channel_id):get_player()
    if player then
        local velocity = self:calculate_velocity(channel_id)
        local duration = self:calculate_duration(channel_id, event_offset)
        
        -- Trigger note callbacks (start)
        for _, callback in ipairs(self.note_callbacks) do
            callback(channel_id, note, true)
        end
        
        -- Schedule note-off callback
        clock.run(function()
            clock.sleep(duration * clock.get_beat_sec())
            for _, callback in ipairs(self.note_callbacks) do
                callback(channel_id, note, false)
            end
        end)
        
        player:play_note(note, velocity, duration)
        if SEEKER_VERBOSE then
            utils.debug_print(string.format(
                "Triggered note %d with velocity %.2f and duration %.3f beats",
                note, velocity, duration
            ), channel_id)
        end
    end
end

function Channel:pulse_channel(channel_id)
    -- Trigger pulse callbacks
    for _, callback in ipairs(self.pulse_callbacks) do
        callback(channel_id)
    end

    local behavior = params:get("clock_pulse_behavior_" .. channel_id)
    local current_beat = clock.get_beats()
    local current_time = os.time()
    
    -- Show basic settings at pulse time
    if SEEKER_DEBUG then
        local behavior_names = {"Pulse", "Strum", "Burst"}
        local clock_div = clock_utils.get_division(params:get("clock_mod_" .. channel_id))
        local mode = params:get("duration_mode_" .. channel_id)
        
        utils.debug_table("", channel_id)  -- Empty line
        utils.debug_table("----------------------------------------", channel_id)
        utils.debug_table(string.format(
            "Channel Settings: Mode=%s, Clock=1/%s", 
            behavior_names[behavior],
            clock_div
        ), channel_id)

        if mode == 1 then  -- Fixed mode
            local variance = params:get("duration_variance_" .. channel_id)
            utils.debug_table(string.format(
                "Duration: Mode=Fixed, Variance=%d%%",
                variance
            ), channel_id)
        else  -- Pattern mode
            local pattern_length = params:get("duration_pattern_length_" .. channel_id)
            local pattern_shape = params:get("duration_pattern_shape_" .. channel_id)
            local min_idx = params:get("duration_min_" .. channel_id)
            local max_idx = params:get("duration_max_" .. channel_id)
            local min_beats = theory_utils.get_note_length(min_idx)
            local max_beats = theory_utils.get_note_length(max_idx)
            
            utils.debug_table(string.format(
                "Duration: Mode=Pattern, Shape=%s, Length=%d",
                ({"Pendulum", "Mountain", "Valley", "Steps", "Gather", "Scatter"})[pattern_shape],
                pattern_length
            ), channel_id)
            utils.debug_table(string.format(
                "Range: %s to %s",
                min_beats,
                max_beats
            ), channel_id)
        end
        utils.debug_table("----------------------------------------", channel_id)
    end
    
    if behavior == 1 then  -- Pulse
        local note = self:get_next_note(channel_id)
        local duration = self:calculate_duration(channel_id)
        local note_name = musicutil.note_num_to_name(note)
        
        -- Show event table for all pulses
        if SEEKER_DEBUG then
            utils.debug_table("Event sequence:", channel_id)
            utils.debug_table(string.format(
                "%-6s %-8s %-12s %s", 
                "Event", "Time", "Duration", "Note"
            ), channel_id)
            utils.debug_table(string.format(
                "%-6s %-8s %-12s %s", 
                "-----", "----", "--------", "----"
            ), channel_id)
            
            utils.debug_table(string.format(
                "%-6d %-8.3f %-12.3f %d (%s)", 
                1, 0.0, duration, note, note_name
            ), channel_id)
            utils.debug_table("----------------------------------------", channel_id)
        end
        
        self:trigger_note(channel_id, note)
    elseif behavior == 2 then  -- Strum
        self:initiate_strum(channel_id, current_time, current_beat)
    elseif behavior == 3 then  -- Burst
        self:initiate_burst(channel_id, current_time, current_beat)
    end
end

-- Chord and arpeggiator state
function Channel:init_arp_state(channel_id)
    if not self.arp_state then
        self.arp_state = {}
    end
    self.arp_state[channel_id] = {
        current_notes = {},  -- The current chord notes
        current_index = 1,   -- Current position in the arpeggio
        direction = 1,       -- 1 for up, -1 for down
        random_sequence = {} -- For Random-Lock mode
    }
end

function Channel:get_chord_intervals(quality, extension)
    local base_intervals = {
        Major = {0, 4, 7},
        Minor = {0, 3, 7},
        Diminished = {0, 3, 6},
        Augmented = {0, 4, 8}
    }
    
    local extension_intervals = {
        ["7"] = {10},
        ["9"] = {10, 14},
        ["11"] = {10, 14, 17},
        ["13"] = {10, 14, 17, 21}
    }
    
    local intervals = utils.deep_copy(base_intervals[quality])
    if extension ~= "None" then
        for _, interval in ipairs(extension_intervals[extension]) do
            table.insert(intervals, interval)
        end
    end
    
    return intervals
end

function Channel:apply_inversion(intervals, inversion)
    if inversion == 1 then return intervals end
    
    local result = utils.deep_copy(intervals)
    for i = 1, inversion - 1 do
        local first = table.remove(result, 1)
        table.insert(result, first + 12)
    end
    
    return result
end

function Channel:validate_note(note, context, channel_id)
    if note < 0 or note > 127 then
        utils.debug_print(string.format(
            "WARNING: Note %d (%s) out of MIDI range in %s",
            note, musicutil.note_num_to_name(note), context
        ), channel_id)
        -- Wrap the note to the nearest octave in range
        while note < 0 do note = note + 12 end
        while note > 127 do note = note - 12 end
        utils.debug_print(string.format(
            "Wrapped to %d (%s)",
            note, musicutil.note_num_to_name(note)
        ), channel_id)
    end
    return note
end

function Channel:get_scale_chord_notes(root_note, scale_notes, degree)
    -- Get the next two thirds up from the root note in the scale
    local third_idx = degree + 2
    if third_idx > #scale_notes then third_idx = third_idx - #scale_notes end
    local fifth_idx = degree + 4
    if fifth_idx > #scale_notes then fifth_idx = fifth_idx - #scale_notes end
    
    local third = scale_notes[third_idx] - root_note
    local fifth = scale_notes[fifth_idx] - root_note
    
    return {0, third, fifth}
end

function Channel:generate_chord_notes(channel_id)
    -- Get all the chord parameters
    local degree = params:get("chord_degree_" .. channel_id)
    local user_quality = ({"Major", "Minor", "Diminished", "Augmented"})[params:get("chord_quality_" .. channel_id)]
    local extension = ({"None", "7", "9", "11", "13"})[params:get("chord_extension_" .. channel_id)]
    local inversion = params:get("chord_inversion_" .. channel_id)
    local note_count = params:get("chord_range_" .. channel_id)
    local start_octave = params:get("chord_octave_" .. channel_id)
    
    -- Get the global key and scale
    local root_note = params:get("global_key") - 1  -- Adjust for 0-based MIDI notes
    local scale_num = params:get("global_scale")
    local transpose = params:get("global_transpose")
    local global_octave = params:get("global_octave")
    
    -- Debug the initial parameters
    utils.debug_print(string.format(
        "Initial params: root=%d, scale=%d, degree=%d, quality=%s, octave=%d",
        root_note, scale_num, degree, user_quality, start_octave
    ), channel_id)
    
    -- Get the scale degrees from musicutil
    local scale = musicutil.SCALES[scale_num]
    local scale_notes = musicutil.generate_scale(root_note, scale.name, 1)
    
    -- Debug the scale
    utils.debug_print("Generated scale notes:", channel_id)
    for i, note in ipairs(scale_notes) do
        utils.debug_print(string.format("  Scale degree %d: MIDI %d (%s)", 
            i-1, note, musicutil.note_num_to_name(note)), channel_id)
    end
    
    -- Get the root note for our chord based on the degree
    local chord_root = scale_notes[degree]
    utils.debug_print(string.format(
        "Selected chord root: degree %d = MIDI %d (%s)",
        degree-1, chord_root, musicutil.note_num_to_name(chord_root)
    ), channel_id)
    
    -- Get the natural chord intervals from the scale
    local scale_intervals = self:get_scale_chord_notes(chord_root, scale_notes, degree)
    utils.debug_print("Scale-based intervals: " .. table.concat(scale_intervals, ", "), channel_id)
    
    -- Only apply user quality if it's different from the natural scale quality
    local intervals
    if user_quality ~= "Major" then  -- If user wants something other than default
        intervals = self:get_chord_intervals(user_quality, extension)
        utils.debug_print("User-modified intervals: " .. table.concat(intervals, ", "), channel_id)
    else
        intervals = scale_intervals
        if extension ~= "None" then
            local ext_intervals = self:get_chord_intervals(user_quality, extension)
            -- Add only the extension intervals
            for i = 4, #ext_intervals do
                table.insert(intervals, ext_intervals[i])
            end
        end
    end
    
    -- Apply inversion to intervals
    if inversion > 1 then
        intervals = self:apply_inversion(intervals, inversion)
        utils.debug_print("After inversion " .. inversion .. ": " .. table.concat(intervals, ", "), channel_id)
    end
    
    -- Apply octave shift to root
    chord_root = chord_root + (start_octave * 12)
    chord_root = self:validate_note(chord_root, "chord root octave shift", channel_id)
    utils.debug_print(string.format(
        "After octave shift: MIDI %d (%s)",
        chord_root, musicutil.note_num_to_name(chord_root)
    ), channel_id)
    
    -- Generate the full set of notes
    local notes = {}
    local current_octave = 0
    while #notes < note_count do
        for _, interval in ipairs(intervals) do
            local note = chord_root + interval + (current_octave * 12) + (global_octave * 12) + transpose
            note = self:validate_note(note, "chord note generation", channel_id)
            table.insert(notes, note)
            if #notes >= note_count then break end
        end
        current_octave = current_octave + 1
    end
    
    -- Store the notes in our arp state
    self:init_arp_state(channel_id)
    self.arp_state[channel_id].current_notes = notes
    
    -- If we're in Random-Lock mode, generate a new random sequence
    local style = params:get("arp_style_" .. channel_id)
    if style == 5 then  -- Random-Lock
        self:generate_random_sequence(channel_id)
    end
    
    -- Debug final notes
    utils.debug_print("\nFinal chord notes:", channel_id)
    for i, note in ipairs(notes) do
        utils.debug_print(string.format("  Note %d: MIDI %d (%s)", 
            i, note, musicutil.note_num_to_name(note)), channel_id)
    end
    
    return notes
end

function Channel:generate_random_sequence(channel_id)
    local notes = self.arp_state[channel_id].current_notes
    local sequence = {}
    for i = 1, #notes do
        table.insert(sequence, i)
    end
    
    -- Fisher-Yates shuffle
    for i = #sequence, 2, -1 do
        local j = math.random(i)
        sequence[i], sequence[j] = sequence[j], sequence[i]
    end
    
    self.arp_state[channel_id].random_sequence = sequence
end

function Channel:preview_next_note(channel_id, preview_state)
    local notes = preview_state.current_notes
    local style = params:get("arp_style_" .. channel_id)
    local step_size = params:get("arp_step_" .. channel_id)
    local note
    
    if style == 4 then  -- Random
        local random_idx = math.random(#notes)
        note = notes[random_idx]
        preview_state.current_index = random_idx
    elseif style == 5 then  -- Random-Lock
        if not preview_state.random_sequence or #preview_state.random_sequence == 0 then
            self:generate_random_sequence(channel_id)
            preview_state.random_sequence = self.arp_state[channel_id].random_sequence
        end
        
        if preview_state.current_index > #preview_state.random_sequence then
            preview_state.current_index = 1
        end
        
        local seq_idx = preview_state.random_sequence[preview_state.current_index]
        note = notes[seq_idx]
        preview_state.current_index = preview_state.current_index + math.abs(step_size)
        while preview_state.current_index > #notes do
            preview_state.current_index = preview_state.current_index - #notes
        end
    else  -- Up, Down, or Up-Down
        note = notes[preview_state.current_index]
        
        if style == 1 then  -- Up
            preview_state.current_index = preview_state.current_index + math.abs(step_size)
            while preview_state.current_index > #notes do
                preview_state.current_index = preview_state.current_index - #notes
            end
        elseif style == 2 then  -- Down
            preview_state.current_index = preview_state.current_index - math.abs(step_size)
            while preview_state.current_index < 1 do
                preview_state.current_index = preview_state.current_index + #notes
            end
        elseif style == 3 then  -- Up-Down
            local next_index = preview_state.current_index + (math.abs(step_size) * preview_state.direction)
            if next_index > #notes then
                preview_state.direction = -1
                preview_state.current_index = #notes - (next_index - #notes - 1)
            elseif next_index < 1 then
                preview_state.direction = 1
                preview_state.current_index = 1 + math.abs(next_index)
            else
                preview_state.current_index = next_index
            end
        end
    end
    
    return note
end

-- Initialize duration state
function Channel:init_duration_state(channel_id)
    if not self.duration_state then
        self.duration_state = {}
    end
    self.duration_state[channel_id] = {
        pattern_position = 1,  -- Always start at position 1
        last_duration = nil,
        drift_value = 0,
        breathe_phase = 0
    }
    
    -- Reset pattern position when initializing state
    if params:get("duration_mode_" .. channel_id) == 2 then  -- Pattern mode
        self.duration_state[channel_id].pattern_position = 1
    end
end

function Channel:generate_locked_duration_sequence(channel_id)
    if not self.duration_state or not self.duration_state[channel_id] then
        self:init_duration_state(channel_id)
    end
    local state = self.duration_state[channel_id]
    
    -- Get sequence length from pattern length parameter
    local sequence_length = params:get("duration_pattern_length_" .. channel_id)
    
    -- Get min/max indices for note lengths
    local min_idx = params:get("duration_min_" .. channel_id)
    local max_idx = params:get("duration_max_" .. channel_id)
    
    -- Ensure min_idx is not greater than max_idx
    if min_idx > max_idx then
        min_idx, max_idx = max_idx, min_idx
    end
    
    -- Create array of available note lengths between min and max
    local available_lengths = {}
    for i = min_idx, max_idx do
        local beats = theory_utils.get_note_length(i)
        table.insert(available_lengths, {idx = i, beats = beats})
    end
    
    -- Generate new sequence of note length indices
    state.locked_sequence = {}
    
    for i = 1, sequence_length do
        -- Pick a random note length from available options
        local choice = math.random(#available_lengths)
        table.insert(state.locked_sequence, available_lengths[choice].idx)
    end
    
    if SEEKER_DEBUG then
        utils.debug_table("Generated new locked random sequence:", channel_id)
        local sequence_preview = {}
        for i, idx in ipairs(state.locked_sequence) do
            table.insert(sequence_preview, theory_utils.get_note_length(idx))
        end
        utils.debug_table(table.concat(sequence_preview, ", "), channel_id)
        
        -- Also show the available lengths we chose from
        local available_preview = {}
        for _, length in ipairs(available_lengths) do
            table.insert(available_preview, theory_utils.get_note_length(length.idx))
        end
        utils.debug_table("Available lengths: " .. table.concat(available_preview, ", "), channel_id)
    end
end

function Channel:calculate_duration(channel_id, event_offset)
    local mode = params:get("duration_mode_" .. channel_id)
    local base_idx = params:get("duration_base_" .. channel_id)
    local base_beats = theory_utils.get_note_length(base_idx)
    local base_value = load("return " .. base_beats)()
    
    -- Initialize duration state if needed
    if not self.duration_state or not self.duration_state[channel_id] then
        self:init_duration_state(channel_id)
    end
    local state = self.duration_state[channel_id]
    
    -- Start with base duration
    local duration = base_value
    
    if mode == 1 then  -- Fixed mode
        duration = base_value
    else  -- Pattern mode
        local min_idx = params:get("duration_min_" .. channel_id)
        local max_idx = params:get("duration_max_" .. channel_id)
        local min_beats = load("return " .. theory_utils.get_note_length(min_idx))()
        local max_beats = load("return " .. theory_utils.get_note_length(max_idx))()
        local pattern_length = params:get("duration_pattern_length_" .. channel_id)
        local pattern_shape = params:get("duration_pattern_shape_" .. channel_id)
        
        -- Normalize position to 0-1 range
        local normalized_pos = (state.pattern_position - 1) / pattern_length
        
        -- Calculate duration based on pattern shape
        if pattern_shape == 1 then  -- Pendulum
            -- True alternating pattern
            local is_long = (state.pattern_position % 2) == 1
            duration = is_long and max_beats or min_beats
            
        elseif pattern_shape == 2 then  -- Mountain
            -- Peak in the middle
            local peak_pos = math.abs(normalized_pos - 0.5) * 2  -- 0->1->0
            duration = util.linlin(0, 1, max_beats, min_beats, peak_pos)
            
        elseif pattern_shape == 3 then  -- Valley
            -- Dip in the middle
            local valley_pos = math.abs(normalized_pos - 0.5) * 2  -- 0->1->0
            duration = util.linlin(0, 1, min_beats, max_beats, valley_pos)
            
        elseif pattern_shape == 4 then  -- Steps
            -- Use or generate locked sequence
            if not state.locked_sequence then
                self:generate_locked_duration_sequence(channel_id)
            end
            -- Get note length from sequence
            local length_idx = state.locked_sequence[state.pattern_position]
            local beats = theory_utils.get_note_length(length_idx)
            duration = load("return " .. beats)()
            
            -- Validate against min/max range
            duration = math.max(min_beats, math.min(max_beats, duration))
            
        elseif pattern_shape == 5 then  -- Gather
            -- Progressive gathering: short to long durations
            duration = util.linlin(0, 1, min_beats, max_beats, normalized_pos)
            
        elseif pattern_shape == 6 then  -- Scatter
            -- Progressive scattering: long to short durations
            duration = util.linlin(0, 1, max_beats, min_beats, normalized_pos)
        end
        
        -- Advance pattern position
        state.pattern_position = state.pattern_position + 1
        if state.pattern_position > pattern_length then
            state.pattern_position = 1
        end
    end
    
    -- Apply variance (now used in both modes)
    local variance = params:get("duration_variance_" .. channel_id)
    if variance > 0 then
        local variance_amount = duration * (variance / 100)
        duration = duration + (math.random() * 2 - 1) * variance_amount
    end
    
    -- Ensure duration is positive and reasonable
    duration = math.max(0.01, duration)
    return duration
end

function Channel:initiate_strum(channel_id, current_time, current_beat)
    local strum_timing = self:generate_strum_timing(channel_id)
    local start_time = current_time
    local last_event_time = nil
    local note_count = #self.arp_state[channel_id].current_notes
    local strum_events = #strum_timing

    -- Log initial state
    utils.debug_table("========== STRUM DEBUG ==========", channel_id)
    utils.debug_table(string.format(
        "Initial State: index=%d/%d, direction=%d",
        self.arp_state[channel_id].current_index,
        note_count,
        self.arp_state[channel_id].direction
    ), channel_id)
    utils.debug_table("Available notes:", channel_id)
    for i, note in ipairs(self.arp_state[channel_id].current_notes) do
        utils.debug_table(string.format(
            "  [%d] MIDI %d (%s)",
            i, note, musicutil.note_num_to_name(note)
        ), channel_id)
    end
    utils.debug_table("--------------------------------", channel_id)

    if SEEKER_DEBUG then
        local duration_idx = params:get("strum_duration_" .. channel_id)
        local duration_beats = theory_utils.get_note_length(duration_idx)
        local clustering = params:get("strum_clustering_" .. channel_id)
        local variation = params:get("strum_variation_" .. channel_id)
        utils.debug_table(string.format(
            "Strum Settings: Events=%d, Window=%s, Shape=%d%%, Feel=%d%%",
            strum_events, duration_beats, clustering, variation
        ), channel_id)
        utils.debug_table("----------------------------------------", channel_id)
    end
    
    -- Store current arp state
    local original_index = self.arp_state[channel_id].current_index
    local original_direction = self.arp_state[channel_id].direction
    
    -- Get all notes before scheduling to maintain sequence
    local notes_to_play = {}
    for i = 1, #strum_timing do
        local note = self:get_next_note(channel_id)
        table.insert(notes_to_play, note)
    end
    
    -- Reset state for next strum
    self.arp_state[channel_id].current_index = original_index
    self.arp_state[channel_id].direction = original_direction

    -- Schedule all events in a single clock function
    clock.run(function()
        -- Initial sync to next beat
        clock.sync(1)
        
        -- Play each note at its scheduled time
        for i, t in ipairs(strum_timing) do
            if i > 1 then  -- Don't sleep before the first event
                clock.sleep(t - strum_timing[i-1])
            end
            
            utils.debug_table(string.format(
                "Event %d/%d - Playing note %d (%s) at offset %.3fs",
                i, strum_events,
                notes_to_play[i],
                musicutil.note_num_to_name(notes_to_play[i]),
                t
            ), channel_id)
            
            self:trigger_note(channel_id, notes_to_play[i], t)
        end
    end)
    
    utils.debug_table("========== END STRUM DEBUG ==========", channel_id)
end

function Channel:initiate_burst(channel_id, current_time, current_beat)
    local burst_timing = self:generate_burst_timing(channel_id)
    local start_time = current_time
    local last_event_time = nil
    local note_count = #self.arp_state[channel_id].current_notes
    local burst_events = #burst_timing

    -- Log initial state
    utils.debug_table("========== BURST DEBUG ==========", channel_id)
    utils.debug_table(string.format(
        "Initial State: index=%d/%d, direction=%d",
        self.arp_state[channel_id].current_index,
        note_count,
        self.arp_state[channel_id].direction
    ), channel_id)
    utils.debug_table("Available notes:", channel_id)
    for i, note in ipairs(self.arp_state[channel_id].current_notes) do
        utils.debug_table(string.format(
            "  [%d] MIDI %d (%s)",
            i, note, musicutil.note_num_to_name(note)
        ), channel_id)
    end
    utils.debug_table("--------------------------------", channel_id)

    if SEEKER_DEBUG then
        local window_idx = params:get("burst_window_" .. channel_id)
        local window_beats = theory_utils.get_note_length(window_idx)
        local style = params:get("burst_style_" .. channel_id)
        local style_names = {"Spray", "Accelerate", "Decelerate", "Crescendo", "Cascade", "Pulse", "Bounce", "Chaos"}
        utils.debug_table(string.format(
            "Burst Settings: Events=%d, Window=%s, Style=%s",
            burst_events, window_beats, style_names[style]
        ), channel_id)
        utils.debug_table("----------------------------------------", channel_id)
    end
    
    -- Store current arp state
    local original_index = self.arp_state[channel_id].current_index
    local original_direction = self.arp_state[channel_id].direction
    
    -- Get all notes before scheduling to maintain sequence
    local notes_to_play = {}
    for i = 1, #burst_timing do
        local note = self:get_next_note(channel_id)
        table.insert(notes_to_play, note)
    end
    
    -- Reset state for next burst
    self.arp_state[channel_id].current_index = original_index
    self.arp_state[channel_id].direction = original_direction

    -- Schedule all events in a single clock function
    clock.run(function()
        -- Initial sync to next beat
        clock.sync(1)
        
        -- Play each note at its scheduled time
        for i, t in ipairs(burst_timing) do
            if i > 1 then  -- Don't sleep before the first event
                clock.sleep(t - burst_timing[i-1])
            end
            
            utils.debug_table(string.format(
                "Event %d/%d - Playing note %d (%s) at offset %.3fs",
                i, burst_events,
                notes_to_play[i],
                musicutil.note_num_to_name(notes_to_play[i]),
                t
            ), channel_id)
            
            -- Trigger pulse callback for visual feedback
            self:trigger_pulse_callbacks()
            
            self:trigger_note(channel_id, notes_to_play[i], t)
        end
    end)
    
    utils.debug_table("========== END BURST DEBUG ==========", channel_id)
end

function Channel:add_pulse_callback(callback)
    table.insert(self.pulse_callbacks, callback)
end

function Channel:remove_pulse_callback(callback)
    for i, cb in ipairs(self.pulse_callbacks) do
        if cb == callback then
            table.remove(self.pulse_callbacks, i)
            break
        end
    end
end

function Channel:trigger_pulse_callbacks()
    for _, callback in ipairs(self.pulse_callbacks) do
        callback(self.id)
    end
end

return Channel