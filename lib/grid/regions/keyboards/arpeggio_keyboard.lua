-- arpeggio_keyboard.lua
-- Scale interval visualization for arpeggio sequencer mode
-- 8 rows × 6 columns (2 blocks of 3 columns each)
-- Shows first 16 scale intervals with block illumination and tonnetz-style tail

local theory = include("lib/motif_core/theory")
local musicutil = require('musicutil')
local GridConstants = include("lib/grid_constants")
local GridLayers = include("lib/grid_layers")

local ArpeggioKeyboard = {}

-- Fixed layout: 8 rows × 6 columns at position (6,1)
ArpeggioKeyboard.layout = {
  upper_left_x = 6,
  upper_left_y = 1,
  width = 6,
  height = 8
}

-- Tail state for tonnetz-style decay
ArpeggioKeyboard.note_tails = {}  -- {[interval] = {brightness, timestamp}}

-- Map MIDI note to scale interval (1-16)
-- Returns interval number or nil if outside range
function ArpeggioKeyboard.note_to_interval(note)
  local root_note = params:get("root_note")
  local scale_type_index = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type_index]

  if not scale or not scale.intervals then
    return nil
  end

  -- Calculate semitone offset from root
  local root_midi = root_note - 1
  local semitone_offset = (note - root_midi) % 12

  -- Find which scale interval this matches (allowing octaves)
  local octave = math.floor((note - root_midi) / 12)

  for i, interval in ipairs(scale.intervals) do
    if interval == semitone_offset then
      local scale_interval = i + (octave * #scale.intervals)

      -- Wrap to 1-16 display range (handles negative octaves)
      scale_interval = ((scale_interval - 1) % 16) + 1

      return scale_interval
    end
  end

  return nil
end

-- Map scale interval (1-16) to block columns
-- Returns table of 3 column positions for the block
function ArpeggioKeyboard.interval_to_block_columns(interval)
  if interval < 1 or interval > 16 then
    return nil
  end

  -- Determine which block (left=1-2, right=4-6) and which row
  local is_left_block = (interval % 2) == 1  -- Odd intervals go left
  local row = math.ceil(interval / 2)  -- Two intervals per row

  -- Calculate y position (row 1 at bottom = y=8, row 8 at top = y=1)
  local y = ArpeggioKeyboard.layout.upper_left_y + (ArpeggioKeyboard.layout.height - row)

  -- Calculate x positions for the 3-column block
  local x_start = ArpeggioKeyboard.layout.upper_left_x + (is_left_block and 0 or 3)

  return {
    {x = x_start, y = y},
    {x = x_start + 1, y = y},
    {x = x_start + 2, y = y}
  }
end

-- Required functions for keyboard interface
function ArpeggioKeyboard.is_step_active(lane_id, step)
  return true
end

function ArpeggioKeyboard.get_step_velocity(lane_id, step)
  return params:get("lane_" .. lane_id .. "_arpeggio_normal_velocity")
end

function ArpeggioKeyboard.step_to_grid(step)
  -- Legacy function for motif recording - return center of layout
  return {
    x = ArpeggioKeyboard.layout.upper_left_x + 3,
    y = ArpeggioKeyboard.layout.upper_left_y + 4
  }
end

function ArpeggioKeyboard.contains(x, y)
  return x >= ArpeggioKeyboard.layout.upper_left_x and
         x < ArpeggioKeyboard.layout.upper_left_x + ArpeggioKeyboard.layout.width and
         y >= ArpeggioKeyboard.layout.upper_left_y and
         y < ArpeggioKeyboard.layout.upper_left_y + ArpeggioKeyboard.layout.height
end

function ArpeggioKeyboard.note_to_positions(note)
  local interval = ArpeggioKeyboard.note_to_interval(note)
  if interval then
    return ArpeggioKeyboard.interval_to_block_columns(interval)
  end
  return nil
end

-- Grid is read-only for arpeggio mode - all programming via params
function ArpeggioKeyboard.handle_key(x, y, z)
  -- No interaction - visualization only
end

-- Draw the scale interval visualization (base state)
function ArpeggioKeyboard.draw(layers)
  local layout = ArpeggioKeyboard.layout

  -- Draw all blocks at LOW brightness as base state
  for row = 1, 8 do
    for block = 1, 2 do  -- 2 blocks (left, right)
      local x_start = layout.upper_left_x + ((block - 1) * 3)
      local y = layout.upper_left_y + (8 - row)

      -- Illuminate all 3 columns in the block
      for col_offset = 0, 2 do
        GridLayers.set(layers.ui, x_start + col_offset, y, GridConstants.BRIGHTNESS.LOW)
      end
    end
  end
end

-- Draw motif events with tonnetz-style tail decay
function ArpeggioKeyboard.draw_motif_events(layers)
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local focused_lane = _seeker.lanes[focused_lane_id]

  if not focused_lane then
    return
  end

  -- Get active positions from lane (currently playing notes)
  local active_positions = focused_lane:get_active_positions()

  -- Track which intervals are currently active
  local active_intervals = {}

  -- Process active notes
  for _, pos in ipairs(active_positions) do
    if pos.note then
      local interval = ArpeggioKeyboard.note_to_interval(pos.note)
      if interval then
        active_intervals[interval] = true

        -- Update tail timestamp for active notes
        ArpeggioKeyboard.note_tails[interval] = {
          brightness = GridConstants.BRIGHTNESS.FULL,
          timestamp = util.time()
        }

        -- Illuminate block at FULL brightness
        local block_cols = ArpeggioKeyboard.interval_to_block_columns(interval)
        if block_cols then
          for _, col in ipairs(block_cols) do
            GridLayers.set(layers.response, col.x, col.y, GridConstants.BRIGHTNESS.FULL)
          end
        end
      end
    end
  end

  -- Decay tails for non-active notes
  local current_time = util.time()
  local decay_duration = 0.5  -- Total decay time in seconds

  for interval, tail in pairs(ArpeggioKeyboard.note_tails) do
    if not active_intervals[interval] then
      local elapsed = current_time - tail.timestamp
      local brightness = GridConstants.BRIGHTNESS.LOW

      if elapsed < decay_duration then
        -- Decay from FULL → MEDIUM → LOW
        local progress = elapsed / decay_duration
        if progress < 0.5 then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        else
          brightness = GridConstants.BRIGHTNESS.LOW
        end

        -- Draw tail
        local block_cols = ArpeggioKeyboard.interval_to_block_columns(interval)
        if block_cols then
          for _, col in ipairs(block_cols) do
            GridLayers.set(layers.response, col.x, col.y, brightness)
          end
        end
      else
        -- Remove old tail
        ArpeggioKeyboard.note_tails[interval] = nil
      end
    end
  end
end

return ArpeggioKeyboard