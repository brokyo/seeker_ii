-- sampler_keyboard.lua
-- 4x4 pad grid for sampler mode
-- Each pad will trigger a sample segment
-- Config button at (4,7) toggles pad configuration mode

local GridConstants = include("lib/grid/constants")
local GridLayers = include("lib/grid/layers")

local SamplerKeyboard = {}

-- Layout definition - 4x4 grid centered in the keyboard area
-- Tape keyboard uses 6x6 starting at (6,2)
-- Center a 4x4 grid within that space
SamplerKeyboard.layout = {
  upper_left_x = 7,
  upper_left_y = 3,
  width = 4,
  height = 4
}

-- Check if coordinates are within sampler keyboard area
function SamplerKeyboard.contains(x, y)
  return x >= SamplerKeyboard.layout.upper_left_x and
         x < SamplerKeyboard.layout.upper_left_x + SamplerKeyboard.layout.width and
         y >= SamplerKeyboard.layout.upper_left_y and
         y < SamplerKeyboard.layout.upper_left_y + SamplerKeyboard.layout.height
end

-- Convert grid position to pad number (1-16)
function SamplerKeyboard.position_to_pad(x, y)
  if not SamplerKeyboard.contains(x, y) then
    return nil
  end

  local rel_x = x - SamplerKeyboard.layout.upper_left_x
  local rel_y = y - SamplerKeyboard.layout.upper_left_y

  return rel_y * SamplerKeyboard.layout.width + rel_x + 1
end

-- Convert pad number to grid position
function SamplerKeyboard.pad_to_position(pad)
  if pad < 1 or pad > (SamplerKeyboard.layout.width * SamplerKeyboard.layout.height) then
    return nil
  end

  local pad_index = pad - 1
  local rel_x = pad_index % SamplerKeyboard.layout.width
  local rel_y = math.floor(pad_index / SamplerKeyboard.layout.width)

  return {
    x = SamplerKeyboard.layout.upper_left_x + rel_x,
    y = SamplerKeyboard.layout.upper_left_y + rel_y
  }
end

-- Find all grid positions for a given pad
-- Maintains keyboard interface compatibility (treats pad as note)
function SamplerKeyboard.note_to_positions(note)
  local pos = SamplerKeyboard.pad_to_position(note)
  return pos and {pos} or nil
end

-- Handle pad press
function SamplerKeyboard.pad_on(x, y)
  local pad = SamplerKeyboard.position_to_pad(x, y)
  if not pad then return end

  -- Always select pad
  if _seeker and _seeker.sampler_pad_config then
    _seeker.sampler_pad_config.select_pad(pad)
  end

  -- Always trigger sample playback
  if _seeker and _seeker.sampler then
    _seeker.sampler.trigger_pad(_seeker.active_lane, pad)
  end

  -- TODO: Record pad events if motif recorder is active
end

-- Handle pad release
function SamplerKeyboard.pad_off(x, y)
  local pad = SamplerKeyboard.position_to_pad(x, y)
  if not pad then return end

  -- For now, pads loop continuously when triggered
  -- Later: add one-shot mode that stops on release
end

-- Handle key presses
function SamplerKeyboard.handle_key(x, y, z)
  if not SamplerKeyboard.contains(x, y) then
    return
  end

  if z == 1 then
    SamplerKeyboard.pad_on(x, y)
  else
    SamplerKeyboard.pad_off(x, y)
  end
end

-- Draw the keyboard
function SamplerKeyboard.draw(layers)
  local layout = SamplerKeyboard.layout

  -- Draw all pads
  for y = layout.upper_left_y, layout.upper_left_y + layout.height - 1 do
    for x = layout.upper_left_x, layout.upper_left_x + layout.width - 1 do
      local brightness = GridConstants.BRIGHTNESS.UI.NORMAL

      -- Highlight selected pad when in config section
      local current_section = _seeker.ui_state.get_current_section()
      if current_section == "SAMPLER_PAD_CONFIG" then
        local pad = SamplerKeyboard.position_to_pad(x, y)
        if _seeker and _seeker.sampler_pad_config then
          local selected_pad = _seeker.sampler_pad_config.get_selected_pad()
          if pad == selected_pad then
            brightness = GridConstants.BRIGHTNESS.UI.BRIGHT
          end
        end
      end

      GridLayers.set(layers.ui, x, y, brightness)
    end
  end
end

-- Draw motif events (pads that are currently playing back)
function SamplerKeyboard.draw_motif_events(layers)
  -- TODO: Highlight pads that are currently playing back
  -- TODO: Show different brightness for recorded vs empty pads
end

return SamplerKeyboard
