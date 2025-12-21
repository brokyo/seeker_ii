-- keyboard.lua
-- Sampler type keyboard: 4x4 pad grid
-- Each pad triggers a sample chop
-- Part of lib/modes/motif/types/sampler/

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local GridLayers = include("lib/grid/layers")

local SamplerKeyboard = {}

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

-- Converts pad number to grid position array
-- Returns array for consistency with tape keyboard's note_to_positions API
local function note_to_positions(note)
  local pos = pad_to_position(note)
  return pos and {pos} or nil
end

-- Creates note event from pad press
-- Captures current chop config so recorded motifs reproduce exact sound
local function create_note_event(x, y, pad, velocity)
  local pos = pad_to_position(pad)
  local event = {
    note = pad,  -- Use pad number as note (1-16)
    velocity = velocity or 127,
    x = x,
    y = y,
    positions = pos and {pos} or {{x = x, y = y}}
  }

  -- Capture chop's filter/envelope values at record time
  if _seeker and _seeker.sampler then
    local lane = _seeker.ui_state.get_focused_lane()
    local chop = _seeker.sampler.get_chop(lane, pad)
    if chop then
      event.attack = chop.attack
      event.release = chop.release
      event.fade_time = chop.fade_time
      event.rate = chop.rate
      event.pitch_offset = chop.pitch_offset
      event.max_volume = chop.max_volume
      event.pan = chop.pan
      event.mode = chop.mode
      event.filter_type = chop.filter_type
      event.lpf = chop.lpf
      event.hpf = chop.hpf
      event.resonance = chop.resonance
      event.start_pos = chop.start_pos
      event.stop_pos = chop.stop_pos
    end
  end

  return event
end

-- Handle pad press
local function pad_on(x, y)
  local pad = position_to_pad(x, y)
  if not pad then return end

  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local is_recording = _seeker.motif_recorder and _seeker.motif_recorder.is_recording

  -- Switch to chop config screen for editing the pressed pad
  if not is_recording then
    if _seeker.sampler_type and _seeker.sampler_type.chop_config then
      _seeker.sampler_type.chop_config.select_pad(pad)
    end
  end

  -- Route through lane (applies perform settings, lane volume, triggers sampler)
  local velocity = _seeker.sampler_type and _seeker.sampler_type.velocity and _seeker.sampler_type.velocity.get_current_velocity() or 127
  local event = create_note_event(x, y, pad, velocity)

  if is_recording then
    _seeker.motif_recorder:on_note_on(event)
  end

  focused_lane:on_note_on(event)
end

-- Handle pad release
local function pad_off(x, y)
  local pad = position_to_pad(x, y)
  if not pad then return end

  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local event = create_note_event(x, y, pad, 0)

  if _seeker.motif_recorder and _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_off(event)
  end

  focused_lane:on_note_off(event)
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "SAMPLER_KEYBOARD",
    layout = layout
  })

  grid_ui.draw = function(self, layers)
    local focused_lane = _seeker.ui_state.get_focused_lane()

    -- Draw all pads
    for y = layout.y, layout.y + layout.height - 1 do
      for x = layout.x, layout.x + layout.width - 1 do
        local pad = position_to_pad(x, y)
        local brightness = GridConstants.BRIGHTNESS.UI.NORMAL

        -- Highlight pads with active looping voices
        if _seeker.sampler and _seeker.sampler.get_pad_voice(focused_lane, pad) then
          brightness = GridConstants.BRIGHTNESS.HIGH
        end

        -- Highlight selected pad when in config section
        local current_section = _seeker.ui_state.get_current_section()
        if current_section == "SAMPLER_CHOP_CONFIG" then
          if _seeker and _seeker.sampler_type and _seeker.sampler_type.chop_config then
            local selected_pad = _seeker.sampler_type.chop_config.get_selected_pad()
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
