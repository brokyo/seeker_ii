-- pitch_display.lua
-- Two-column live voicing display at x=10-11, y=1-8.
-- Shows the current chord's notes mapped to pitch space.
-- Updates as stages cycle during playback, or follows edit_stage selection.

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local PitchDisplay = {}

local DISPLAY_X = 10
local DISPLAY_Y = 1
local DISPLAY_W = 2
local DISPLAY_H = 8

-- Fixed pitch range: MIDI 36 (C2) to 84 (C6) = 48 semitones across 8 rows
local PITCH_MIN = 36
local PITCH_MAX = 84
local ROWS = 8
local SEMITONES_PER_ROW = (PITCH_MAX - PITCH_MIN) / ROWS

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
    local notes = {}
    local stage_motif = lane.rc_stage_motifs[display_stage]
    if stage_motif and stage_motif.events then
      local seen = {}
      for _, event in ipairs(stage_motif.events) do
        if event.type == "note_on" and not seen[event.note] then
          seen[event.note] = true
          table.insert(notes, event.note)
        end
      end
    end

    -- Map notes to row indices (row 8 = lowest pitch, row 1 = highest)
    local row_hits = {}
    for _, note in ipairs(notes) do
      local clamped = math.max(PITCH_MIN, math.min(PITCH_MAX - 1, note))
      local row_from_bottom = math.floor((clamped - PITCH_MIN) / SEMITONES_PER_ROW) + 1
      local row = ROWS - row_from_bottom + 1
      row = math.max(1, math.min(ROWS, row))
      row_hits[row] = (row_hits[row] or 0) + 1
    end

    -- Draw both columns
    local has_notes = #notes > 0
    for row = 1, ROWS do
      local gy = DISPLAY_Y + row - 1
      local hit_count = row_hits[row] or 0

      local brightness
      if hit_count > 1 then
        brightness = GridConstants.BRIGHTNESS.FULL
      elseif hit_count == 1 then
        brightness = GridConstants.BRIGHTNESS.HIGH
      elseif has_notes then
        brightness = GridConstants.BRIGHTNESS.DIM
      else
        brightness = GridConstants.BRIGHTNESS.OFF
      end

      layers.ui[DISPLAY_X][gy] = brightness
      layers.ui[DISPLAY_X + 1][gy] = brightness
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
