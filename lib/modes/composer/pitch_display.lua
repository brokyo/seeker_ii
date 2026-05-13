-- pitch_display.lua
-- Two-column voicing display at x=10-11, y=1-8.
-- 16 slots spanning ~2.5 octaves from the key root at the composer's base octave.
-- Each slot = 2 semitones. Shows chord shape: close voicing clusters,
-- wide spread scatters. Notes light up full bright when sounding.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local PitchDisplay = {}

local DISPLAY_X = 10
local DISPLAY_Y = 1
local DISPLAY_W = 2
local DISPLAY_H = 8
local SEMITONES_PER_SLOT = 2

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "COMPOSER_PITCH_DISPLAY",
    layout = {
      x = DISPLAY_X,
      y = DISPLAY_Y,
      width = DISPLAY_W,
      height = DISPLAY_H,
    }
  })

  grid_ui.draw = function(self, layers)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_id]
    local num_stages = params:get("rc_composer_stages")
    local is_playing = lane.playing

    local live_view = _seeker.composer_mode.live_view
    local edit_stage = live_view and live_view.edit_stage and live_view.edit_stage()
    local display_stage = edit_stage or (is_playing and lane.current_stage_index) or 1
    if display_stage > num_stages then display_stage = 1 end

    -- Extract notes for the display stage
    local chord_notes = {}
    local stage_motif = lane.rc_stage_motifs[display_stage]
    if stage_motif and stage_motif.events then
      local seen = {}
      for _, event in ipairs(stage_motif.events) do
        if event.type == "note_on" and not seen[event.note] then
          seen[event.note] = true
          table.insert(chord_notes, event.note)
        end
      end
    end
    table.sort(chord_notes)

    -- Fixed reference: root note at composer's base octave (octave 4 = +48)
    local root_midi = (params:get("root_note") - 1) + 48
    local range_start = root_midi

    -- Build set of currently sounding notes
    local sounding = {}
    local active_notes = lane.active_notes or {}
    for _, note_data in pairs(active_notes) do
      if note_data.note then
        sounding[note_data.note] = true
      end
    end

    -- Map notes to slots: each slot = 2 semitones from range_start
    local slot_state = {}
    for _, note in ipairs(chord_notes) do
      local semitones_above = note - range_start
      local slot = math.floor(semitones_above / SEMITONES_PER_SLOT)
      if slot >= 0 and slot < 16 then
        local is_sounding = sounding[note] == true
        if not slot_state[slot] or is_sounding then
          slot_state[slot] = is_sounding and "playing" or "present"
        end
      end
    end

    -- Draw the 16 cells
    local has_notes = #chord_notes > 0
    for slot = 0, 15 do
      local col = slot < 8 and 0 or 1
      local row_from_bottom = slot % 8
      local gx = DISPLAY_X + col
      local gy = DISPLAY_Y + (DISPLAY_H - 1 - row_from_bottom)

      local state = slot_state[slot]
      local brightness
      if state == "playing" then
        brightness = GridConstants.BRIGHTNESS.FULL
      elseif state == "present" then
        brightness = GridConstants.BRIGHTNESS.MEDIUM
      elseif has_notes then
        brightness = GridConstants.BRIGHTNESS.DIM
      else
        brightness = GridConstants.BRIGHTNESS.OFF
      end

      layers.ui[gx][gy] = brightness
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
  end

  return grid_ui
end

function PitchDisplay.init()
  return {
    grid = create_grid_ui(),
  }
end

return PitchDisplay
