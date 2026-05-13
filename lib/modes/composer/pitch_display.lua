-- pitch_display.lua
-- Two-column voicing display at x=10-11, y=1-8.
-- 16 chromatic pitch slots: column 10 (bottom-up) = pitches 1-8,
-- column 11 (bottom-up) = pitches 9-16. Range anchored to chord root.
-- Dim = note exists in chord. Full bright = note currently sounding.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local PitchDisplay = {}

local DISPLAY_X = 10
local DISPLAY_Y = 1
local DISPLAY_W = 2
local DISPLAY_H = 8

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

    -- Extract notes for the display stage from rc_stage_motifs
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

    if #chord_notes == 0 then return end

    -- Anchor range to the lowest note: 16 chromatic slots from there
    local range_start = chord_notes[1]
    local active_notes = lane.active_notes or {}

    -- Map each note to a slot (0-15), then to column + row
    -- Slot 0 = col 10 row 8 (bottom-left), slot 7 = col 10 row 1 (top-left)
    -- Slot 8 = col 11 row 8 (bottom-right), slot 15 = col 11 row 1 (top-right)
    local slot_state = {}
    for _, note in ipairs(chord_notes) do
      local slot = note - range_start
      if slot >= 0 and slot < 16 then
        local is_sounding = active_notes[note] ~= nil
        slot_state[slot] = is_sounding and "playing" or "present"
      end
    end

    -- Draw the 16 cells
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
      else
        brightness = GridConstants.BRIGHTNESS.DIM
      end

      layers.ui[gx][gy] = brightness
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    -- Read-only for now
  end

  return grid_ui
end

function PitchDisplay.init()
  return {
    grid = create_grid_ui(),
  }
end

return PitchDisplay
