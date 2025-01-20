-- grid.lua
-- Handles grid hardware interaction and visual feedback
-- Core responsibilities:
-- 1. Handle grid button presses
-- 2. Manage visual feedback
-- 3. Route user actions to appropriate components
--------------------------------------------------

local GridUI = {}
local g = grid.connect()
local theory = include('lib/theory_utils')
local MotifRecorder = include('lib/motif_recorder')
local params_manager = include('lib/params_manager')
local lane_utils = include('lib/lane_utils')
local grid_animations = include('lib/grid_animations')

--------------------------------------------------
-- Constants & Configuration
-- Good: Clear separation of configuration from logic
--------------------------------------------------

local GRID = {
  width = 16,
  height = 8,
  lane_count = 4,
  brightness = {
    high = 15,
    medium = 8,
    low = 2,
    off = 0
  },
  recording_column = 4,
  playback_column = 5,
  clear_column = 13,
  pattern_start = 7,
  pattern_end = 10,
  keyboard_row_start = 6,
  fps = 144
}

-- WARN: Global state within a module
local motif_recorder = MotifRecorder.new({})

local redraw_metro = nil

--------------------------------------------------
-- Initialization
-- Simple and clear - just sets up grid callback
--------------------------------------------------

function GridUI.init()
  if g.device then    
    g.key = function(x, y, z)
      GridUI.key(x, y, z)
    end
    
    -- Initialize animations
    grid_animations.init(g)
    
    -- Set up continuous redraw
    redraw_metro = metro.init()
    redraw_metro.time = 1/GRID.fps
    redraw_metro.event = function()
      GridUI.redraw()
    end
    redraw_metro:start()
  else
    print("⬖ Grid Connect failed")
  end

  return GridUI
end

function GridUI.cleanup()
  if redraw_metro then
    redraw_metro:stop()
  end
  grid_animations.cleanup()
end

--------------------------------------------------
-- Voice Control Event Handlers
-- Each handler is focused on one type of control
--------------------------------------------------

-- Record button handler
function GridUI.handle_record_toggle(x, y, z)
  if x == GRID.recording_column and z == 1 then
    local lane_num = y
    
    if not motif_recorder.is_recording then
      motif_recorder:start_recording()
      print(string.format("● Recording Started | Lane %d ●", lane_num))
    else
      local recorded_data = motif_recorder:stop_recording()
      _seeker.conductor:create_motif(lane_num, recorded_data)
      print(string.format("▣ Recording Stopped | Lane %d ▣", lane_num))
    end
  end
end

-- Play button handler
-- Clean: Simple toggle between play/stop
function GridUI.handle_playback_toggle(x, y, z)
  if x == GRID.playback_column and z == 1 then
    local lane_num = y
    local lane = _seeker.conductor.lanes[lane_num]
    
    if lane.is_playing then
      _seeker.conductor:stop_lane(lane_num)
    else
      _seeker.conductor:play_lane(lane_num)
    end
    
    GridUI.redraw()
  end
end

-- Handle clear pattern
-- TODO: I need to decide what to do with clearing. Is that a matter for the motif or a matter for the conductor?
function GridUI.handle_clear_pattern(x, y, z)
  if x == GRID.clear_column and z == 1 then
    local lane_num = y
    
    -- If recording on this lane, stop and discard
    if _seeker.conductor.lanes[lane_num].is_recording then
      motif_recorder:stop_recording()
      _seeker.conductor:clear_pattern(lane_num)
      print("▣ Recording Cleared ▣")
    end
  end
end

--------------------------------------------------
-- Keyboard Event Handlers
-- Handles note input and recording
--------------------------------------------------

-- Direct note playback for live performance
-- Keeps this separate from conductor's pattern playback responsibilities
function GridUI.play_live_note(lane_num, note, z)
  if not lane_num then return end
  
  -- Get lane's instrument name
  local instrument_name = lane_utils.get_lane_instrument(lane_num)
  
  if z == 1 then
    print(string.format("♫ NOTE ON: %s | %d", theory.note_to_name(note), note))
    _seeker.skeys:on({
      name = instrument_name,
      midi = note,
      velocity = 127
    })
  else
    _seeker.skeys:off({
      name = instrument_name,
      midi = note
    })
  end
end

-- Note recording handler
-- Only handles recording of notes, playback is handled at key level
function GridUI.handle_note_record(x, y, z, pitch, velocity)
  if z == 1 then
    if motif_recorder.is_recording then
      motif_recorder:on_note_on(pitch, velocity, {x=x, y=y})
    end
  else
    if motif_recorder.is_recording then
      motif_recorder:on_note_off(pitch)
    end
  end
end

-- Main input router
function GridUI.key(x, y, z)
  if y >= GRID.keyboard_row_start then
    -- Handle note input for keyboard area
    if x >= 4 and x <= 12 and y >= 6 and y <= 8 then
      local pitch = theory.grid_to_note(x, y)
      if pitch then
        -- Use standard MIDI velocity range
        local velocity = z == 1 and 127 or 0
        
        -- Always handle live playback at key level
        GridUI.play_live_note(_seeker.focused_lane, pitch, z)
        
        -- Handle recording separately
        GridUI.handle_note_record(x, y, z, pitch, velocity)
      end
    end
    
    GridUI.redraw()  -- SMELL: Why redraw after every note?
    return
  end

  if y <= GRID.lane_count then
    GridUI.handle_record_toggle(x, y, z)
    GridUI.handle_playback_toggle(x, y, z)
    GridUI.handle_clear_pattern(x, y, z)
  end

  GridUI.redraw()
end

--------------------------------------------------
-- Grid Display & Rendering
-- Handles all visual feedback
--------------------------------------------------

-- Draw the musical interval keyboard on the grid
-- WARN: We should split the interval keyboard logic and the general keyboard brightness. May want to get more dynamic.
function GridUI.draw_keyboard()
  local current_scale = params:get("scale_type")
  
  -- Draw keyboard in original position (x=4-12, y=6-8)
  for x = 4, 12 do
    for y = 6, 8 do
      -- How dynamic can we make this? Today it matches scale... can it eventually suggest notes?
      local interval = x - 8  -- Center on x=8 (-4 to +4 range)
      local importance = theory.get_interval_importance(interval, current_scale)
      local brightness = theory.importance_to_brightness(importance, GRID.brightness)
      g:led(x, y, brightness)
    end
  end
end

-- Control lane display
-- WARN: Deep coupling to conductor's internal state
function GridUI.draw_pattern_lanes()   
  -- This cannot matter
  if not _seeker.conductor or not _seeker.conductor.lanes then
    print("Warning: Conductor or lanes not initialized yet")
    return
  end
  
  -- TODO It's possible we ultimately only have one lane on screen at a time and it's more of a control bar
  for lane_num = 1,GRID.lane_count do
    -- lane is a control set with instrument settings and motif data
    local lane = _seeker.conductor.lanes[lane_num]
    local is_focused = (lane_num == _seeker.focused_lane)

    -- Adjust brightness based on focus
    local brightness_multiplier = is_focused and 1 or 0.4
    
    -- Draw record button
    local rec_brightness = motif_recorder.is_recording 
      and GRID.brightness.high or GRID.brightness.medium
    g:led(GRID.recording_column, lane_num, 
      math.floor(rec_brightness * brightness_multiplier))
    
    -- Draw play button
    local play_brightness = lane.is_playing 
      and GRID.brightness.high or GRID.brightness.medium
    g:led(GRID.playback_column, lane_num, 
      math.floor(play_brightness * brightness_multiplier))
    
    -- Draw pattern slots with dim lighting
    for x = GRID.pattern_start, GRID.pattern_end do
      g:led(x, lane_num, 
        math.floor(GRID.brightness.low * brightness_multiplier))
    end
    
    -- Draw clear button
    g:led(GRID.clear_column, lane_num, 
      math.floor(GRID.brightness.medium * brightness_multiplier))
  end
end

-- Main display refresh
function GridUI.redraw()  
  g:all(0)
  
  -- Draw animations first as base layer
  grid_animations.update()
  
  -- Always draw UI elements
  GridUI.draw_keyboard()
  GridUI.draw_pattern_lanes()
  g:refresh()
end

--------------------------------------------------
-- Voice Management
-- SMELL: This might belong in conductor
--------------------------------------------------

-- Select a lane as the current focus
function GridUI.select_lane(lane_num)
  _seeker.focused_lane = lane_num
  -- Redraw grid to show new focus
  GridUI.redraw()
end

-- Do we need to return this object?
return GridUI
