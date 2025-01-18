-- grid.lua
-- Handles grid hardware interaction and visual feedback
-- Core responsibilities:
-- 1. Handle grid button presses
-- 2. Manage visual feedback
-- 3. Route user actions to appropriate components
--------------------------------------------------

local GridUI = {}
local g = grid.connect()
local theory = include('/lib/theory_utils')
local MotifRecorder = include('/lib/motif_recorder')
local params_manager = include('/lib/params_manager')

--------------------------------------------------
-- Constants & Configuration
-- Good: Clear separation of configuration from logic
--------------------------------------------------

local BRIGHTNESS = {
  high = 12,
  medium = 8,
  low = 5,
  inactive = 0
}

local GRID = {
  recording_column = 4,
  playback_column = 5,
  clear_column = 13,
  pattern_start = 7,
  pattern_end = 10,
  keyboard_row_start = 6,
  voice_count = 4
}

-- SMELL: Global state within a module
local motif_recorder = MotifRecorder.new({})

--------------------------------------------------
-- Initialization
-- Simple and clear - just sets up grid callback
--------------------------------------------------

function GridUI.init()
  if g.device then    
    g.key = function(x, y, z)
      GridUI.key(x, y, z)
    end
    GridUI.redraw()
  else
    print("⬖ Grid Connect failed")
  end

  return GridUI
end

--------------------------------------------------
-- Voice Control Event Handlers
-- Each handler is focused on one type of control
--------------------------------------------------

-- Record button handler
function GridUI.handle_record_toggle(x, y, z)
  if x == GRID.recording_column and z == 1 then
    local voice_num = y
    
    if not motif_recorder.is_recording then
      motif_recorder:start_recording()
      print(string.format("● Recording Started | Lane %d ●", voice_num))
    else
      local recorded_data = motif_recorder:stop_recording()
      _seeker.conductor:create_motif(voice_num, recorded_data)
      print(string.format("▣ Recording Stopped | Lane %d ▣", voice_num))
    end
  end
end

-- Play button handler
-- Clean: Simple toggle between play/stop
function GridUI.handle_playback_toggle(x, y, z)
  if x == GRID.playback_column and z == 1 then
    local voice_num = y
    local voice = _seeker.conductor.voices[voice_num]
    
    if voice.is_playing then
      _seeker.conductor:stop_voice(voice_num)
    else
      _seeker.conductor:play_voice(voice_num)
    end
    
    GridUI.redraw()
  end
end

-- Handle clear pattern
-- TODO: I need to decide what to do with clearing. Is that a matter for the motif or a matter for the conductor?
function GridUI.handle_clear_pattern(x, y, z)
  if x == GRID.clear_column and z == 1 then
    local voice_num = y
    
    -- If recording on this voice, stop and discard
    if _seeker.conductor.voices[voice_num].is_recording then
      motif_recorder:stop_recording()
      _seeker.conductor:clear_pattern(voice_num)
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
function GridUI.play_live_note(voice_num, note, z)
  if not voice_num then return end
  
  -- Get voice-specific instrument name
  local instrument_id = params:get("voice_" .. voice_num .. "_instrument")
  local instruments = params_manager.get_instrument_list()
  local instrument_name = instruments[instrument_id]
  
  -- Play through mx.samples using explicit note on/off
  -- NB: Hardcoded velocity of 127
  if z == 1 then
    print(string.format("♫ NOTE ON: %s | %d", theory.note_to_name(note), note))
    _seeker.skeys:on({
      name=instrument_name,
      midi=note,
      velocity=127
    })
  elseif z == 0 then
    -- print(string.format("♫ NOTE OFF: %s (MIDI: %d)", theory.note_to_name(note), note))
    _seeker.skeys:off({
      name=instrument_name,
      midi=note
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
        GridUI.play_live_note(_seeker.focused_voice, pitch, z)
        
        -- Handle recording separately
        GridUI.handle_note_record(x, y, z, pitch, velocity)
      end
    end
    
    GridUI.redraw()  -- SMELL: Why redraw after every note?
    return
  end

  if y <= GRID.voice_count then
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
      local brightness = theory.importance_to_brightness(importance, BRIGHTNESS)
      g:led(x, y, brightness)
    end
  end
end

-- Control lane display
-- WARN: Deep coupling to conductor's internal state
function GridUI.draw_pattern_lanes()   
  -- This cannot matter
  if not _seeker.conductor or not _seeker.conductor.voices then
    print("Warning: Conductor or voices not initialized yet")
    return
  end
  
  -- It's possible we only have one voice on screen at a time and it's more of a control bar
  for voice_num = 1,GRID.voice_count do
    -- voice is probably a bad term for what this is. It's a control set.
    local voice = _seeker.conductor.voices[voice_num]
    local is_focused = (voice_num == _seeker.focused_voice)

    -- Adjust brightness based on focus
    local brightness_multiplier = is_focused and 1 or 0.4
    
    -- Draw record button
    local rec_brightness = voice.is_recording 
      and BRIGHTNESS.high or BRIGHTNESS.medium
    g:led(GRID.recording_column, voice_num, 
      math.floor(rec_brightness * brightness_multiplier))
    
    -- Draw play button
    local play_brightness = voice.is_playing 
      and BRIGHTNESS.high or BRIGHTNESS.medium
    g:led(GRID.playback_column, voice_num, 
      math.floor(play_brightness * brightness_multiplier))
    
    -- Draw pattern slots with dim lighting
    for x = GRID.pattern_start, GRID.pattern_end do
      g:led(x, voice_num, 
        math.floor(BRIGHTNESS.low * brightness_multiplier))
    end
    
    -- Draw clear button
    g:led(GRID.clear_column, voice_num, 
      math.floor(BRIGHTNESS.medium * brightness_multiplier))
  end
end

-- Main display refresh
-- Clean: Clear three-step process
function GridUI.redraw()  
  g:all(0)
  GridUI.draw_keyboard()
  GridUI.draw_pattern_lanes()
  g:refresh()
end

--------------------------------------------------
-- Voice Management
-- SMELL: This might belong in conductor
--------------------------------------------------

-- Is there any reason for this?
function GridUI.select_voice(voice_num)
  _seeker.focused_voice = voice_num
  -- Redraw grid to show new focus
  GridUI.redraw()
end

-- Do we need to return this object?
return GridUI
