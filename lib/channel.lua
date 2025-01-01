-- channel.lua
-- All logic relates to the channel

local utils = include('lib/utils')
local theory_utils = include('lib/theory_utils')
local clock_utils = include('lib/clock_utils')
local default_channel_params = include("lib/default_channel_params")
local params_manager = include("lib/params_manager")

-- Define the class
local Channel = {}
Channel.__index = Channel

-- Constructor for new instances
function Channel.new(id)
    local self = setmetatable({}, Channel)
    self.id = id
    self.running = false
    self.clock_id = nil

    local defaults = utils.deep_copy(default_channel_params)
    for k, v in pairs(defaults) do
        self[k] = v
    end

    return self
end

function Channel:add_params(channel_id)
    -- Group for rhythm parameters
    params:add_group("Channel " .. channel_id , 13)

    -- Clock Section Header
    params:add_separator("clock_section_header_" .. channel_id, "Clock Config")
  
    -- Clock Source
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
  
    -- Clock Mod
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
  
    -- Clock Pulse Behavior
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
      name = "Strum Duration",
      type = "option",
      options = theory_utils.note_lengths,
      default = 5, -- Default to "1/4"
      action = function(value)
        local length = theory_utils.get_note_length(value)
        utils.debug_print("Channel " .. channel_id .. " strum duration set to " .. length)
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
      default = 5, -- Default to "1/4"
      action = function(value)
        local length = theory_utils.get_note_length(value)
        utils.debug_print("Channel " .. channel_id .. " burst window set to " .. length)
      end
    }

    params:add {
      id = "burst_count_" .. channel_id,
      name = "Burst Events",
      type = "number",
      min = 2,
      max = 12,
      default = 3,
      action = function(value)
        utils.debug_print("Channel " .. channel_id .. " burst events set to " .. value)
      end
    }

    params:add {
      id = "burst_distribution_" .. channel_id,
      name = "Burst Style",
      type = "option",
      options = {"Even", "Front", "Back", "Middle"},
      default = 1,
      action = function(value)
        utils.debug_print("Channel " .. channel_id .. " burst distribution set to " .. ({"Even", "Front", "Back", "Middle"})[value])
      end
    }

    -- Initialize parameter visibility after all params are added
    params_manager.update_behavior_visibility(channel_id, 1)
end

function Channel:start(channel_id)
  if not self.running then
    utils.debug_print("Starting Channel", channel_id)
    self.running = true
    self.last_pulse_time = nil
    self.clock_id = clock.run(function()
      while self.running do
        -- Trigger the channel's pulse action here
        self:pulse_channel(channel_id)
        -- Get the clock time directly from param index
        local clock_mod_value = params:get("clock_mod_" .. channel_id)
        local sync_time = clock_utils.index_to_time(clock_mod_value)
        -- Log the wait time
        utils.debug_print(string.format("Waiting %.3f beats", sync_time), channel_id)
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
    local min_time = 0.001 -- Minimum time in seconds (1ms)
    
    -- Strum always moves in one direction (start to end)
    -- Use exponential curve to simulate physical motion
    for i = 1, num_pulses do
        local normalized_index = (i - 1) / (num_pulses - 1)
        
        -- Apply clustering (physical motion bias)
        local t
        if clustering < 50 then
            -- Fast start, slow finish (like a quick strum that loses energy)
            t = total_duration * (1 - math.exp(-4 * normalized_index * (clustering/50)))
            utils.debug_print(string.format(
                "Pulse %d/%d: Losing energy curve, raw_t=%.3fs",
                i, num_pulses, t
            ), channel_id)
        else
            -- Slow start, fast finish (like a strum that gains momentum)
            t = total_duration * math.exp(-4 * (1-normalized_index) * ((100-clustering)/50))
            utils.debug_print(string.format(
                "Pulse %d/%d: Gaining momentum curve, raw_t=%.3fs",
                i, num_pulses, t
            ), channel_id)
        end
        
        -- Add human-like variation
        if variation > 0 then
            -- More variation in the middle, less at start/end
            local variance_shape = math.sin(normalized_index * math.pi)
            local max_variation = total_duration * (variation/100) / num_pulses
            local variation_amount = (math.random() - 0.5) * max_variation * variance_shape
            t = t + variation_amount
            utils.debug_print(string.format(
                "Applied variation: shape=%.2f, amount=%.3fs, new_t=%.3fs",
                variance_shape, variation_amount, t
            ), channel_id)
        end
        
        t = math.max(min_time, math.min(t, total_duration))
        table.insert(pulse_times, t)
    end
    
    -- Sort to maintain forward motion
    table.sort(pulse_times)
    
    -- Ensure minimum spacing for playability
    for i = 2, #pulse_times do
        if pulse_times[i] - pulse_times[i-1] < min_time then
            pulse_times[i] = pulse_times[i-1] + min_time
            utils.debug_print(string.format(
                "Adjusted spacing: pulse %d moved to %.3fs (min spacing)",
                i, pulse_times[i]
            ), channel_id)
        end
    end

    utils.debug_print("Final pulse times:", channel_id)
    for i, t in ipairs(pulse_times) do
        utils.debug_print(string.format(
            "  Pulse %d: %.3fs (%.3f beats)", 
            i, t, t/clock.get_beat_sec()
        ), channel_id)
    end

    return pulse_times
end

function Channel:generate_burst_timing(channel_id)
    local window_idx = params:get("burst_window_" .. channel_id)
    local window_beats = theory_utils.get_note_length(window_idx)
    local window_value = load("return " .. window_beats)()
    local total_duration = clock.get_beat_sec() * window_value
    local num_events = params:get("burst_count_" .. channel_id)
    local distribution = params:get("burst_distribution_" .. channel_id)

    local event_times = {}
    local min_time = 0.001
    
    -- Simple burst patterns
    if distribution == 1 then  -- Even
        -- Equal time between events
        for i = 1, num_events do
            local t = total_duration * ((i - 1) / (num_events - 1))
            table.insert(event_times, t)
        end
    elseif distribution == 2 then  -- Front
        -- More events at start
        for i = 1, num_events do
            local t = total_duration * (1 - math.exp(-3 * (i-1)/(num_events-1)))
            table.insert(event_times, t)
        end
    elseif distribution == 3 then  -- Back
        -- More events at end
        for i = 1, num_events do
            local t = total_duration * math.exp(-3 * (num_events-i)/(num_events-1))
            table.insert(event_times, t)
        end
    elseif distribution == 4 then  -- Middle
        -- More events in middle
        for i = 1, num_events do
            local normalized = (i - 1) / (num_events - 1)
            local t = total_duration * normalized
            -- Push events towards middle
            if normalized < 0.5 then
                t = t + (total_duration * 0.25 * normalized)
            else
                t = t - (total_duration * 0.25 * (1 - normalized))
            end
            table.insert(event_times, t)
        end
    end
    
    -- Ensure minimum spacing
    for i = 2, #event_times do
        if event_times[i] - event_times[i-1] < min_time then
            event_times[i] = event_times[i-1] + min_time
        end
    end

    return event_times
end

function Channel:pulse_channel(channel_id)
    local behavior = params:get("clock_pulse_behavior_" .. channel_id)
    
    -- Track timing between pulses
    self.last_pulse_time = utils.debug_time_diff("Channel Pulse", self.last_pulse_time, channel_id)
    
    if behavior == 1 then  -- Pulse
        utils.debug_print("Simple Pulse", channel_id)
    elseif behavior == 2 then  -- Strum
        local strum_timing = self:generate_strum_timing(channel_id)
        local start_time = clock.get_beats()
        local last_event_time = nil

        utils.debug_print(string.format("Starting Strum with %d events", #strum_timing), channel_id)
        
        -- Schedule each strum event
        for i, t in ipairs(strum_timing) do
            clock.run(function()
                clock.sync(start_time + t / clock.get_beat_sec())
                last_event_time = utils.debug_time_diff(string.format("Strum Event %d/%d", i, #strum_timing), last_event_time, channel_id)
            end)
        end
    elseif behavior == 3 then  -- Burst
        local burst_timing = self:generate_burst_timing(channel_id)
        local start_time = clock.get_beats()
        local last_event_time = nil

        utils.debug_print(string.format("Starting Burst with %d events", #burst_timing), channel_id)
        
        -- Schedule each burst event
        for i, t in ipairs(burst_timing) do
            clock.run(function()
                clock.sync(start_time + t / clock.get_beat_sec())
                last_event_time = utils.debug_time_diff(string.format("Burst Event %d/%d", i, #burst_timing), last_event_time, channel_id)
            end)
        end
    end
end

return Channel