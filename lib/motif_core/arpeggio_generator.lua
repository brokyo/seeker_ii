-- arpeggio_generator.lua
-- Shared arpeggio generation logic used by both recorder (genesis) and stages
-- Extracts velocity curve and strum position calculations to prevent drift

local ArpeggioGenerator = {}

-- Calculate velocity based on curve type and position in sequence
function ArpeggioGenerator.calculate_velocity(index, total_steps, curve_type, min_vel, max_vel)
  if curve_type == "Flat" then
    return (min_vel + max_vel) / 2
  end

  local progress = (index - 1) / math.max(total_steps - 1, 1)  -- 0 to 1
  local range = max_vel - min_vel

  if curve_type == "Crescendo" then
    return min_vel + (progress * range)
  elseif curve_type == "Decrescendo" then
    return max_vel - (progress * range)
  elseif curve_type == "Wave" then
    return min_vel + (math.sin(progress * math.pi) * range)
  elseif curve_type == "Accent First" then
    return (index == 1) and max_vel or min_vel
  elseif curve_type == "Accent Last" then
    return (index == total_steps) and max_vel or min_vel
  elseif curve_type == "Random" then
    return min_vel + (math.random() * range)
  end

  return (min_vel + max_vel) / 2
end

-- Calculate absolute time position within strum window
-- amount_percent is 0-100 (window size as percentage of sequence_duration)
-- Returns absolute time position where note should play
function ArpeggioGenerator.calculate_strum_position(index, total_steps, curve_type, amount_percent, direction, sequence_duration)
  if curve_type == "None" or amount_percent == 0 then
    -- No strum: return evenly spaced positions across full sequence
    return (index - 1) * (sequence_duration / total_steps)
  end

  -- Window size as percentage of total sequence duration
  local window_duration = sequence_duration * (amount_percent / 100)
  local progress = (index - 1) / math.max(total_steps - 1, 1)  -- 0 to 1
  local position_in_window = 0

  -- Apply curve shape to distribute notes within window
  if curve_type == "Gentle" then
    -- Linear distribution (like seeker_1.5's sweep)
    position_in_window = progress * window_duration
  elseif curve_type == "Picking" then
    -- Quadratic acceleration (like seeker_1.5's rush)
    position_in_window = (progress * progress) * window_duration
  elseif curve_type == "Sweep" then
    -- Sine curve acceleration (like seeker_1.5's gliss)
    position_in_window = math.sin(progress * math.pi / 2) * window_duration
  elseif curve_type == "Natural" then
    -- Cubic with jitter (like seeker_1.5's burst)
    local curved = math.pow(progress, 3)
    local chaos = (1 - progress) * 0.1
    local jitter = (math.random() * 2 - 1) * chaos
    position_in_window = (curved + jitter) * window_duration
  end

  -- Apply direction
  if direction == "Forward" then
    return position_in_window
  elseif direction == "Reverse" then
    return window_duration - position_in_window
  elseif direction == "Center Out" then
    local center = (total_steps + 1) / 2
    local distance = math.abs(index - center)
    local max_distance = math.max(center - 1, total_steps - center)
    return (distance / max_distance) * window_duration
  elseif direction == "Edges In" then
    local center = (total_steps + 1) / 2
    local distance = math.abs(index - center)
    local max_distance = math.max(center - 1, total_steps - center)
    return window_duration - ((distance / max_distance) * window_duration)
  elseif direction == "Thumb First" then
    if index == 1 then
      return 0
    else
      local remaining_progress = (index - 2) / math.max(total_steps - 2, 1)
      return remaining_progress * window_duration
    end
  elseif direction == "Random" then
    return math.random() * window_duration
  end

  return position_in_window
end

return ArpeggioGenerator
