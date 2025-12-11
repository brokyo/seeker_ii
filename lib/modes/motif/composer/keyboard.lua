-- keyboard.lua
-- Composer type keyboard: scale position visualization
-- 8 rows x 6 columns (2 blocks of 3 columns each)
-- Shows first 16 scale positions with block illumination and tonnetz-style decay
-- Part of lib/modes/motif/composer/

local GridUI = include("lib/ui/base/grid_ui")
local theory = include("lib/motif_core/theory")
local musicutil = require('musicutil')
local GridConstants = include("lib/grid/constants")
local GridLayers = include("lib/grid/layers")

local ComposerKeyboard = {}

-- Fixed layout: 8 rows x 6 columns at position (6,1)
local layout = {
  x = 6,
  y = 1,
  width = 6,
  height = 8
}

-- Map MIDI note to scale position (1-16)
-- Returns position number or nil if outside range
local function note_to_scale_position(note)
  local root_note = params:get("root_note")
  local scale_type_index = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type_index]

  if not scale or not scale.intervals then
    return nil
  end

  -- Calculate semitone offset from root
  local root_midi = root_note - 1
  local semitone_offset = (note - root_midi) % 12

  -- Find which scale position this matches (allowing octaves)
  local octave = math.floor((note - root_midi) / 12)

  for i, semitones in ipairs(scale.intervals) do
    if semitones == semitone_offset then
      local scale_position = i + (octave * #scale.intervals)

      -- Wrap to 1-16 display range (handles negative octaves)
      scale_position = ((scale_position - 1) % 16) + 1

      return scale_position
    end
  end

  return nil
end

-- Map grid position to scale position (1-16)
-- Returns position number or nil if outside keyboard area
local function grid_to_scale_position(x, y)
  if x < layout.x or x >= layout.x + layout.width or
     y < layout.y or y >= layout.y + layout.height then
    return nil
  end

  -- Calculate row (1-8, bottom to top)
  local row = layout.height - (y - layout.y)

  -- Determine if this is left block (columns 0-2) or right block (columns 3-5)
  local col_offset = x - layout.x
  local is_left_block = col_offset < 3

  -- Calculate position: each row has 2 positions (left=odd, right=even)
  local position = (row - 1) * 2 + (is_left_block and 1 or 2)

  return position
end

-- Map scale position (1-16) to MIDI note
-- Returns MIDI note number or nil if invalid position
local function scale_position_to_note(position)
  if position < 1 or position > 16 then
    return nil
  end

  local root_note = params:get("root_note")
  local scale_type_index = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type_index]

  if not scale or not scale.intervals then
    return nil
  end

  -- Calculate which octave and scale degree within that octave
  local scale_length = #scale.intervals
  local octave = math.floor((position - 1) / scale_length)
  local scale_degree = ((position - 1) % scale_length) + 1

  -- Get the semitone offset for this scale degree
  local semitone_offset = scale.intervals[scale_degree]

  -- Calculate final MIDI note
  local root_midi = root_note - 1
  local note = root_midi + (octave * 12) + semitone_offset

  return note
end

-- Map scale position (1-16) to block columns
-- Returns table of 3 column positions for the block
local function scale_position_to_block_columns(position)
  if position < 1 or position > 16 then
    return nil
  end

  -- Determine which block (left=1-2, right=4-6) and which row
  local is_left_block = (position % 2) == 1  -- Odd positions go left
  local row = math.ceil(position / 2)  -- Two positions per row

  -- Calculate y position (row 1 at bottom = y=8, row 8 at top = y=1)
  local y = layout.y + (layout.height - row)

  -- Calculate x positions for the 3-column block
  local x_start = layout.x + (is_left_block and 0 or 3)

  return {
    {x = x_start, y = y},
    {x = x_start + 1, y = y},
    {x = x_start + 2, y = y}
  }
end

-- Required functions for keyboard interface
local function is_step_active(lane_id, step)
  return true
end

local function get_step_velocity(lane_id, step)
  return params:get("lane_" .. lane_id .. "_composer_normal_velocity")
end

local function step_to_grid(step)
  -- Legacy function for motif recording - return center of layout
  return {
    x = layout.x + 3,
    y = layout.y + 4
  }
end

-- Find all grid positions for a given note
local function note_to_positions(note)
  local position = note_to_scale_position(note)
  if position then
    return scale_position_to_block_columns(position)
  end
  return nil
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "COMPOSER_KEYBOARD",
    layout = layout
  })

  -- Tail state for tonnetz-style decay
  grid_ui.note_tails = {}  -- {[scale_position] = {brightness, timestamp}}

  -- Track held notes for live playback
  grid_ui.held_notes = {}  -- {[x_y] = note}

  -- Track pressed blocks for live playback illumination
  grid_ui.pressed_blocks = {}  -- {[x_y] = {x, y, timestamp}}

  -- Draw the scale interval visualization (base state)
  grid_ui.draw = function(self, layers)
    -- Draw all blocks at LOW brightness as base state
    for row = 1, 8 do
      for block = 1, 2 do  -- 2 blocks (left, right)
        local x_start = layout.x + ((block - 1) * 3)
        local y = layout.y + (8 - row)

        -- Illuminate all 3 columns in the block
        for col_offset = 0, 2 do
          GridLayers.set(layers.ui, x_start + col_offset, y, GridConstants.BRIGHTNESS.LOW)
        end
      end
    end
  end

  -- Draw motif events with tonnetz-style tail decay
  grid_ui.draw_motif_events = function(self, layers)
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local focused_lane = _seeker.lanes[focused_lane_id]

    if not focused_lane then
      return
    end

    -- Draw live playback pressed blocks
    for key, block in pairs(self.pressed_blocks) do
      local position = grid_to_scale_position(block.x, block.y)
      if position then
        local block_cols = scale_position_to_block_columns(position)
        if block_cols then
          for _, col in ipairs(block_cols) do
            GridLayers.set(layers.response, col.x, col.y, GridConstants.BRIGHTNESS.FULL)
          end
        end
      end
    end

    -- Get active positions from lane (algorithmic playback only)
    local active_positions = focused_lane:get_active_positions()

    -- Track which scale positions are currently active
    local active_scale_positions = {}

    -- Process active notes from algorithmic playback
    for _, pos in ipairs(active_positions) do
      if pos.note then
        local scale_pos = note_to_scale_position(pos.note)
        if scale_pos then
          active_scale_positions[scale_pos] = true

          -- Update tail timestamp for active notes
          self.note_tails[scale_pos] = {
            brightness = GridConstants.BRIGHTNESS.FULL,
            timestamp = util.time()
          }

          -- Illuminate block at FULL brightness
          local block_cols = scale_position_to_block_columns(scale_pos)
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

    for scale_pos, tail in pairs(self.note_tails) do
      if not active_scale_positions[scale_pos] then
        local elapsed = current_time - tail.timestamp
        local brightness = GridConstants.BRIGHTNESS.LOW

        if elapsed < decay_duration then
          -- Decay from FULL -> MEDIUM -> LOW
          local progress = elapsed / decay_duration
          if progress < 0.5 then
            brightness = GridConstants.BRIGHTNESS.MEDIUM
          else
            brightness = GridConstants.BRIGHTNESS.LOW
          end

          -- Draw tail
          local block_cols = scale_position_to_block_columns(scale_pos)
          if block_cols then
            for _, col in ipairs(block_cols) do
              GridLayers.set(layers.response, col.x, col.y, brightness)
            end
          end
        else
          -- Remove old tail
          self.note_tails[scale_pos] = nil
        end
      end
    end
  end

  -- Handle grid key press for live playback
  grid_ui.handle_key = function(self, x, y, z)
    -- Handle keyboard note playback
    local position = grid_to_scale_position(x, y)
    if not position then
      return
    end

    local note = scale_position_to_note(position)
    if not note then
      return
    end

    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local focused_lane = _seeker.lanes[focused_lane_id]
    if not focused_lane then
      return
    end

    local key = string.format("%d_%d", x, y)

    if z == 1 then
      -- Key press - trigger note on (+3 octaves for playable range)
      local playback_note = note + 36
      self.held_notes[key] = playback_note
      self.pressed_blocks[key] = {x = x, y = y, timestamp = util.time()}

      local velocity = _seeker.velocity.get_current_velocity()

      focused_lane:on_note_on({
        note = playback_note,
        velocity = velocity,
        x = x,
        y = y,
        is_playback = false
      })
    else
      -- Key release - trigger note off
      local held_note = self.held_notes[key]
      if held_note then
        focused_lane:on_note_off({
          note = held_note,
          velocity = 0,
          x = x,
          y = y,
          is_playback = false
        })
        self.held_notes[key] = nil
        self.pressed_blocks[key] = nil
      end
    end
  end

  -- Expose helper functions for external use (keyboard interface)
  grid_ui.note_to_scale_position = note_to_scale_position
  grid_ui.grid_to_scale_position = grid_to_scale_position
  grid_ui.scale_position_to_note = scale_position_to_note
  grid_ui.scale_position_to_block_columns = scale_position_to_block_columns
  grid_ui.is_step_active = is_step_active
  grid_ui.get_step_velocity = get_step_velocity
  grid_ui.step_to_grid = step_to_grid
  grid_ui.note_to_positions = note_to_positions

  return grid_ui
end

function ComposerKeyboard.init()
  local component = {
    grid = create_grid_ui()
  }

  return component
end

return ComposerKeyboard
