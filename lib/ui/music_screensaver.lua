-- music_screensaver.lua
-- Lane timeline visualization for the music mode screensaver.
-- Shows motif note data with playhead position and stage indicators.

local MusicScreensaver = {}

function MusicScreensaver.draw()
  local active_lanes = {}
  for lane_idx = 1, _seeker.num_lanes do
    local lane = _seeker.lanes[lane_idx]
    if lane.motif and #lane.motif.events > 0 then
      table.insert(active_lanes, {idx = lane_idx, lane = lane})
    end
  end

  if #active_lanes == 0 then return end

  local MARGIN_TOP = 8
  local MARGIN_BOTTOM = 8
  local MARGIN_LEFT = 12
  local MARGIN_RIGHT = 12
  local GAP = 4
  local available_height = 64 - MARGIN_TOP - MARGIN_BOTTOM
  local lane_height = math.floor((available_height - (GAP * (#active_lanes - 1))) / #active_lanes)
  local timeline_width = 128 - MARGIN_LEFT - MARGIN_RIGHT
  local use_piano_roll = #active_lanes < 5

  for i, active_lane in ipairs(active_lanes) do
    local lane = active_lane.lane
    local motif = lane.motif
    local y_pos = MARGIN_TOP + ((i - 1) * (lane_height + GAP))
    local loop_duration = motif:get_duration()

    screen.level(2)
    screen.rect(MARGIN_LEFT, y_pos, timeline_width, lane_height)
    screen.fill()
    screen.level(3)
    screen.rect(MARGIN_LEFT, y_pos, timeline_width, lane_height)
    screen.stroke()

    -- Stage position dots along left edge
    local num_stages = #lane.stages
    local dot_x = MARGIN_LEFT + 3
    local dot_spacing = (lane_height - 4) / (num_stages - 1)
    local current_stage = lane.current_stage_index or 1
    for stage = 1, num_stages do
      local dot_y = y_pos + 2 + ((stage - 1) * dot_spacing)
      screen.level((stage == current_stage) and 15 or 3)
      screen.circle(dot_x, dot_y, 1)
      screen.fill()
    end

    -- Collect note ranges and generation bounds for brightness scaling
    local max_gen = 1
    local min_note = 127
    local max_note = 0
    for _, event in ipairs(motif.events) do
      if event.generation and event.generation > max_gen then max_gen = event.generation end
      if event.type == "note_on" then
        if event.note < min_note then min_note = event.note end
        if event.note > max_note then max_note = event.note end
      end
    end

    -- Build note_on/note_off pairs for drawing
    local note_pairs = {}
    for _, event in ipairs(motif.events) do
      if event.type == "note_on" then
        local note_off_time = nil
        for _, off_event in ipairs(motif.events) do
          if off_event.type == "note_off" and off_event.note == event.note and off_event.time > event.time then
            note_off_time = off_event.time
            break
          end
        end
        table.insert(note_pairs, {
          note = event.note, start_time = event.time,
          end_time = note_off_time or event.time,
          generation = event.generation or 1
        })
      end
    end

    -- Draw note bars (piano roll when few lanes, tick marks when many)
    for _, note_pair in ipairs(note_pairs) do
      local brightness = 2 + math.floor((note_pair.generation / max_gen) * 10)
      screen.level(brightness)
      local x_start = MARGIN_LEFT + (note_pair.start_time / loop_duration * timeline_width)
      local x_end = MARGIN_LEFT + (note_pair.end_time / loop_duration * timeline_width)

      if use_piano_roll and max_note > min_note then
        local note_range = max_note - min_note
        local note_y_offset = ((note_pair.note - min_note) / note_range) * (lane_height - 2)
        local note_y = y_pos + lane_height - 1 - note_y_offset
        screen.move(x_start, note_y)
        screen.line(x_end, note_y)
        screen.stroke()
      else
        screen.move(x_start, y_pos)
        screen.line(x_start, y_pos + lane_height)
        screen.stroke()
      end
    end

    -- Playhead
    if lane.playing then
      local current_beat = clock.get_beats()
      local position = current_beat % loop_duration
      local cs = lane.stages[lane.current_stage_index]
      if cs and cs.last_start_time then
        position = ((current_beat - cs.last_start_time) * lane.speed) % loop_duration
      end
      local x_playhead = MARGIN_LEFT + (position / loop_duration * timeline_width)
      screen.level(15)
      screen.move(x_playhead, y_pos)
      screen.line(x_playhead, y_pos + lane_height)
      screen.stroke()
    end
  end
end

return MusicScreensaver
