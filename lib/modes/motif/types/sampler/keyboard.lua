-- keyboard.lua
-- Sampler type keyboard: 4x4 pad grid
-- Each pad triggers a sample chop
-- Part of lib/modes/motif/types/sampler/

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local GridLayers = include("lib/grid/layers")

local SamplerKeyboard = {}

-- Note: Performance state is accessed via _seeker.sampler_performance
-- to ensure we use the single initialized instance

-- Playback mode constants for sampler behavior
local MODE_GATE = 1

-- Layout definition - 4x4 grid centered in the keyboard area
local layout = {
  x = 7,
  y = 3,
  width = 4,
  height = 4
}

-- Convert grid position to pad number (1-16)
local function position_to_pad(x, y)
  local rel_x = x - layout.x
  local rel_y = y - layout.y
  return rel_y * layout.width + rel_x + 1
end

-- Convert pad number to grid position
local function pad_to_position(pad)
  if pad < 1 or pad > (layout.width * layout.height) then
    return nil
  end

  local pad_index = pad - 1
  local rel_x = pad_index % layout.width
  local rel_y = math.floor(pad_index / layout.width)

  return {
    x = layout.x + rel_x,
    y = layout.y + rel_y
  }
end

-- Find all grid positions for a given pad
-- Maintains keyboard interface compatibility (treats pad as note)
local function note_to_positions(note)
  local pos = pad_to_position(note)
  return pos and {pos} or nil
end

-- Create a standardized note event for sampler pads
local function create_note_event(x, y, pad, velocity)
  local pos = pad_to_position(pad)

  return {
    note = pad,  -- Use pad number as note (1-16)
    velocity = velocity or 127,
    x = x,
    y = y,
    all_positions = pos and {pos} or nil
  }
end

-- Handle pad press
local function pad_on(x, y)
  local pad = position_to_pad(x, y)
  if not pad then return end

  -- Trigger samples during recording, navigate to pad config otherwise
  local is_recording = _seeker and _seeker.motif_recorder and _seeker.motif_recorder.is_recording

  if not is_recording then
    -- Navigate to pad configuration screen
    if _seeker and _seeker.sampler_pad_config then
      _seeker.sampler_pad_config.select_pad(pad)
    end
  end

  -- Trigger sample playback (unless muted by performance button)
  if _seeker and _seeker.sampler then
    local lane = _seeker.ui_state.get_focused_lane()
    local perf = _seeker.sampler_performance
    if not perf or not perf.is_muted(lane) then
      local velocity = _seeker.sampler_velocity and _seeker.sampler_velocity.get_current_velocity() or 127
      if perf then
        velocity = velocity * perf.get_velocity_multiplier(lane)
      end
      _seeker.sampler.trigger_pad(lane, pad, velocity)
    end
  end

  -- Record pad event if motif recorder is active
  if is_recording then
    local velocity = _seeker.sampler_velocity and _seeker.sampler_velocity.get_current_velocity() or 127
    local event = create_note_event(x, y, pad, velocity)
    _seeker.motif_recorder:on_note_on(event)
  end
end

-- Handle pad release
local function pad_off(x, y)
  local pad = position_to_pad(x, y)
  if not pad then return end

  -- Gate mode: stop playback on release
  if _seeker and _seeker.sampler then
    local lane = _seeker.ui_state.get_focused_lane()
    local chop = _seeker.sampler.get_chop(lane, pad)
    if chop and chop.mode == MODE_GATE then
      _seeker.sampler.stop_pad(lane, pad)
    end
  end

  -- Record pad release if motif recorder is active
  if _seeker and _seeker.motif_recorder and _seeker.motif_recorder.is_recording then
    local event = create_note_event(x, y, pad, 0)
    _seeker.motif_recorder:on_note_off(event)
  end
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "SAMPLER_KEYBOARD",
    layout = layout
  })

  grid_ui.draw = function(self, layers)
    -- Draw all pads
    for y = layout.y, layout.y + layout.height - 1 do
      for x = layout.x, layout.x + layout.width - 1 do
        local brightness = GridConstants.BRIGHTNESS.UI.NORMAL

        -- Highlight selected pad when in config section
        local current_section = _seeker.ui_state.get_current_section()
        if current_section == "SAMPLER_PAD_CONFIG" then
          local pad = position_to_pad(x, y)
          if _seeker and _seeker.sampler_pad_config then
            local selected_pad = _seeker.sampler_pad_config.get_selected_pad()
            if pad == selected_pad then
              brightness = GridConstants.BRIGHTNESS.HIGH
            end
          end
        end

        GridLayers.set(layers.ui, x, y, brightness)
      end
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      pad_on(x, y)
    else
      pad_off(x, y)
    end
  end

  -- Expose helper functions for external use
  grid_ui.position_to_pad = position_to_pad
  grid_ui.pad_to_position = pad_to_position
  grid_ui.note_to_positions = note_to_positions

  return grid_ui
end

function SamplerKeyboard.init()
  local component = {
    grid = create_grid_ui()
  }

  return component
end

return SamplerKeyboard
