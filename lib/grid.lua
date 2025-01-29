-- grid.lua
--
-- Core grid interface for Seeker II
-- Handles all monome grid interaction and visual feedback
--
-- Key features:
-- 1. Musical keyboard (6x6 tonnetz layout)
-- 2. Four-lane pattern recording and playback
-- 3. Four-stage pattern sequencing per lane
-- 4. Real-time visual feedback
--------------------------------------------------

-- CONSIDER: motif_recorder.is_recording state could get out of sync with conductor
-- if recording is stopped by other means (like key press or clock stop)
local GridUI = {}
local g = grid.connect()
local theory = include('lib/theory_utils')
local MotifRecorder = include('lib/motif_recorder')
-- local grid_animations = include('lib/grid_animations')

-- Core configuration
local STAGES_PER_LANE = 4  -- Number of stages per lane (may increase in future)
local TRANSPORT_BUTTONS = 3  -- Number of transport buttons [Play, Rec, Clear]

-- Initialize recorder
local motif_recorder = MotifRecorder.new({})
-- local redraw_metro = nil

--------------------------------------------------
-- Grid Layout
--------------------------------------------------

local Layout = {
  width = 16,
  height = 8,
  
  -- Brightness levels
  BRIGHT = 15,     -- Maximum brightness (for active playing notes)
  ACTIVE = 12,     -- For active states (playing/recording)
  FOCUSED = 8,     -- For focused UI elements
  MED = 4,         -- Default state
  DIM = 2,         -- Background elements
  OFF = 0,
  
  -- Keyboard (center 6x6)
  keyboard = {
    x = 6,
    y = 2,
    size = 6
  },
  
  -- Corner positions (easily adjustable if needed)
  corners = {
    -- [lane_number] = {stage_x, stage_y, transport_x, transport_y}
    [1] = {1, 2, 1, 3},    -- Top Left:     Stage at (1,2), Transport at (1,3)
    [2] = {13, 2, 14, 3},  -- Top Right:    Stage at (13,2), Transport at (13,3)
    [3] = {1, 7, 1, 6},    -- Bottom Left:  Stage at (1,7), Transport at (1,8)
    [4] = {13, 7, 14, 6},  -- Bottom Right: Stage at (13,7), Transport at (13,8)
  },

  -- Animation rate
  fps = 30
}

--------------------------------------------------
-- Input Handling
--------------------------------------------------

function GridUI.key(x, y, z)  
  -- Check keyboard region
  -- TODO: Make this a method that checks the region
  if x >= Layout.keyboard.x and x < Layout.keyboard.x + Layout.keyboard.size and
  y >= Layout.keyboard.y and y < Layout.keyboard.y + Layout.keyboard.size then
    -- Get current lane's keyboard offsets
    local lane = _seeker.conductor.lanes[_seeker.ui_state.focused_lane]
    
    -- TODO: Reconsider offset system
    -- Get keyboard offsets from params to ensure sync
    -- local offset_x = params:get("lane_" .. _seeker.focused_lane .. "_keyboard_x") or 0
    -- local offset_y = params:get("lane_" .. _seeker.focused_lane .. "_keyboard_y") or 0
    
    -- Apply offsets to grid position
    -- local adj_x = x - Layout.keyboard.x + 1 + offset_x
    -- local adj_y = y - Layout.keyboard.y + 1 + offset_y
    
    -- TODO: Need to update this for z = 1 and z = 0 for live notes and have it call specific note_on note_off methods
    -- TODO: Same as above but for note_record. It should probably also call motif_recorder directly.
    local note = theory.grid_to_note(adj_x, adj_y)
    if note then
      GridUI.play_live_note(_seeker.lanes[focused_lane], note, z)
      GridUI.handle_note_record(x, y, z, note, 127)
    end
    return
  end

  -- TODO: Reevaluate this whole block. It may be broadly correct but I need to study it.
  -- Check corners
  for lane, pos in pairs(Layout.corners) do
    local stage_x, stage_y, transport_x, transport_y = table.unpack(pos)
    
    -- Stage buttons (independent position)
    if y == stage_y and x >= stage_x and x < stage_x + STAGES_PER_LANE then
      GridUI.handle_stage_select(lane, x - stage_x + 1)
      return
    end
    
    -- Transport buttons (independent position)
    if y == transport_y and x >= transport_x and x < transport_x + TRANSPORT_BUTTONS then
      local button = x - transport_x -- 0=play, 1=rec, 2=clear
      if button == 0 then GridUI.handle_playback_toggle(lane)
      elseif button == 1 then GridUI.handle_record_toggle(lane)
      elseif button == 2 then GridUI.handle_clear(lane)
      end
      return
    end
  end
end

--------------------------------------------------
-- Drawing
--------------------------------------------------

function GridUI.redraw()
  g:all(0)
  -- grid_animations.update() -- Background first
  
  -- Draw keyboard
  for x = 0, Layout.keyboard.size - 1 do
    for y = 0, Layout.keyboard.size - 1 do
      local grid_x = Layout.keyboard.x + x
      local grid_y = Layout.keyboard.y + y
      
      -- TODO: Reconsider offsetsystem
      -- -- Get keyboard offsets from params to ensure sync
      -- local offset_x = params:get("lane_" .. _seeker.focused_lane .. "_keyboard_x") or 0
      -- local offset_y = params:get("lane_" .. _seeker.focused_lane .. "_keyboard_y") or 0
      
      -- -- Apply offsets to the musical position calculation
      -- local adj_x = x + 1 + offset_x  -- +1 because theory expects 1-based indices
      -- local adj_y = y + 1 + offset_y
      
      -- Get interval importance for this position in musical space
      local importance = theory.get_interval_importance(adj_x, adj_y)
      
      -- Draw the LED at the grid position with brightness based on musical importance
      -- local brightness = importance == 'primary' and Layout.BRIGHT or Layout.MED
      local brightness = Layout.MED
      g:led(grid_x, grid_y, brightness)
    end
  end
  
  -- Draw corner controls
  for lane, pos in pairs(Layout.corners) do
    local stage_x, stage_y, transport_x, transport_y = table.unpack(pos)
    local lane_data = _seeker.conductor.lanes[lane]
    local is_focused = lane == _seeker.focused_lane
    
    -- Stages (STAGES_PER_LANE total, independent position)
    for i = 0, STAGES_PER_LANE - 1 do
      local brightness = Layout.MED
      if lane_data.current_stage == (i + 1) then 
        -- If this stage is currently playing and has active notes
        if lane_data.is_playing and lane_data.active_notes and #lane_data.active_notes > 0 then
          brightness = Layout.ACTIVE
        else
          brightness = is_focused and Layout.FOCUSED or Layout.MED
        end
      end
      g:led(stage_x + i, stage_y, brightness)
    end
    
    -- Transport (TRANSPORT_BUTTONS total: Play, Rec, Clear)
    -- Play button - MED by default, BRIGHT when playing, FOCUSED when focused
    local play_brightness = Layout.MED
    if lane_data.is_playing then
      play_brightness = Layout.BRIGHT
    elseif is_focused then
      play_brightness = Layout.FOCUSED
    end
    g:led(transport_x, transport_y, play_brightness)
    
    -- Record button - MED by default, BRIGHT when recording on focused lane, FOCUSED when just focused
    local rec_brightness = Layout.MED
    if motif_recorder.is_recording and lane == _seeker.focused_lane then
      rec_brightness = Layout.BRIGHT
    elseif is_focused then
      rec_brightness = Layout.FOCUSED
    end
    g:led(transport_x + 1, transport_y, rec_brightness)
    
    -- Clear button - always MED unless focused
    g:led(transport_x + 2, transport_y, is_focused and Layout.FOCUSED or Layout.MED)
  end
  
  g:refresh()
end

--------------------------------------------------
-- Lifecycle Management
-- Handles grid connection, initialization,
-- continuous redraw, and cleanup
--------------------------------------------------

function GridUI.init()
  -- CONSIDER: Grid could disconnect during performance
  -- Currently no auto-reconnect which could leave player stuck
  if g.device then    
    g.key = function(x, y, z)
      GridUI.key(x, y, z)
    end
    
    -- Initialize animations
    -- grid_animations.init(g)
    
    
    -- TODO: I think I'm redrawing the grid multiple places. There's another commented out instance of this in seeker.
    -- -- Set up continuous redraw
    -- redraw_metro = metro.init()
    -- redraw_metro.time = 1/Layout.fps
    -- redraw_metro.event = function()
    --   GridUI.redraw()
    -- end
    -- redraw_metro:start()
    
    -- Handle disconnection
    g.remove = function()
      print("⬖ Grid Disconnected")
    end
  else
    print("⬖ Grid Connect failed")
  end

  return GridUI
end

-- CONSIDER: Stuck notes possible if cleanup happens during active recording
function GridUI.cleanup()
  -- TODO: Figure out where the grid metro belongs then stop it there
  -- if redraw_metro then
  --   redraw_metro:stop()
  -- end
  -- grid_animations.cleanup()  
end

--------------------------------------------------
-- Recording Controls
-- Handles starting/stopping recording and
-- creating new motifs from recorded data
--------------------------------------------------

function GridUI.handle_record_toggle(lane_num)
  if not motif_recorder.is_recording then
    _seeker.conductor:clear_lane(lane_num)
    motif_recorder:start_recording(lane_num)
    _seeker.ui_manager:focus_lane(lane_num) 
    print(string.format("⏺ Recording Started | Lane %d", lane_num))
  else
    local recorded_data = motif_recorder:stop_recording()
    _seeker.conductor:create_motif(lane_num, recorded_data)
    print(string.format("⏹ Recording Stopped | Lane %d", lane_num))
  end
end

--------------------------------------------------
-- Playback Controls
-- Manages lane playback state and visual feedback
--------------------------------------------------

function GridUI.handle_playback_toggle(lane_num)
  local lane = _seeker.conductor.lanes[lane_num]
  if lane.is_playing then
    _seeker.conductor:stop_lane(lane_num)
    print(string.format("⏹ Stopped | Lane %d", lane_num))
  else
    _seeker.conductor:play_lane(lane_num)
    print(string.format("▶ Playing | Lane %d", lane_num))
  end
end

--------------------------------------------------
-- Musical Input Handling
-- Processes live note input and recording
--------------------------------------------------

-- Direct note playback for live performance
-- Maps grid positions to musical notes and
-- routes them to the appropriate instrument
function GridUI.play_live_note(lane_num, note, z)
  if not lane_num then return end
  local instrument_name = lane_utils.get_lane_instrument(lane_num)
  local note_name = theory.note_to_name(note)
  local lane_data = _seeker.conductor.lanes[lane_num]
  
  -- Initialize active_notes if needed
  if not lane_data.active_notes then
    lane_data.active_notes = {}
  end
  
  if z == 1 then
    -- Add note to active notes
    table.insert(lane_data.active_notes, note)
    
    _seeker.skeys:on({
      name = instrument_name,
      midi = note,
      velocity = 127
    })
    print(string.format("♪ Note ON  | %s", note_name))
  else
    -- Remove note from active notes
    for i = #lane_data.active_notes, 1, -1 do
      if lane_data.active_notes[i] == note then
        table.remove(lane_data.active_notes, i)
        break
      end
    end
    
    _seeker.skeys:off({
      name = instrument_name,
      midi = note
    })
    print(string.format("♪ Note OFF | %s", note_name))
  end
end

-- Note recording handler
-- Captures notes and grid positions during recording
function GridUI.handle_note_record(x, y, z, pitch, velocity)
  if z == 1 then
    if motif_recorder.is_recording then
      motif_recorder:on_note_on(x, y, velocity)
      print(string.format("⏺ Record ON  | V%d pos=(%d,%d)", velocity, x, y))
    end
  else
    if motif_recorder.is_recording then
      motif_recorder:on_note_off(x, y)
      print(string.format("⏺ Record OFF | pos=(%d,%d)", x, y))
    end
  end
end

--------------------------------------------------
-- Control Handlers
--------------------------------------------------

function GridUI.handle_clear(lane_num)
  -- TODO: Set lane as focused lane
  -- _seeker.ui_manager:focus_lane(lane_num)  -- Focus lane when clearing it
  -- Then clear it
  _seeker.lanes[ui_state.focused_lane]:clear()
  print(string.format("⌀ Cleared | Lane %d", lane_num))
end

function GridUI.handle_stage_select(lane_num, stage)
    _seeker.ui_state.focused_stage = 1
    print(string.format("◉ Stage %d Selected | Lane %d", stage, lane_num))
end

return GridUI
