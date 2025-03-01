-- midi_visualizer.lua
-- Handles visualization of MIDI input on the grid

local theory = include('lib/theory_utils')
local GridConstants = include('lib/grid_constants')
local GridLayers = include('lib/grid_layers')

local MidiVisualizer = {}

-- Store active notes and their visual states
local active_notes = {}

-- Constants for animation
local ANIMATION = {
  ATTACK_TIME = 0.15,    -- Time to reach full brightness
  DECAY_TIME = 0.1,      -- Time to settle to sustained brightness
  RELEASE_TIME = 0.2,    -- Time to fade out
  
  PEAK_BRIGHTNESS = GridConstants.BRIGHTNESS.FULL,
  SUSTAIN_BRIGHTNESS = GridConstants.BRIGHTNESS.HIGH
}

-- Handle incoming MIDI note
function MidiVisualizer.note_on(note, velocity)
  -- Find all positions for this note
  local positions = theory.find_all_note_positions(note)
  
  -- Store note state
  active_notes[note] = {
    positions = positions,
    start_time = util.time(),
    velocity = velocity,
    state = "attack"  -- States: attack, sustain, release
  }
end

-- Handle MIDI note release
function MidiVisualizer.note_off(note)
  if active_notes[note] then
    active_notes[note].state = "release"
    active_notes[note].release_start = util.time()
  end
end

-- Update visualization (call this in the grid redraw loop)
function MidiVisualizer.update(response_layer)
  local current_time = util.time()
  
  for note, note_state in pairs(active_notes) do
    local brightness = 0
    local elapsed = current_time - note_state.start_time
    
    -- Calculate brightness based on state
    if note_state.state == "attack" then
      if elapsed < ANIMATION.ATTACK_TIME then
        -- Fade in
        local progress = elapsed / ANIMATION.ATTACK_TIME
        brightness = util.linlin(0, 1, 0, ANIMATION.PEAK_BRIGHTNESS, progress)
      elseif elapsed < ANIMATION.ATTACK_TIME + ANIMATION.DECAY_TIME then
        -- Decay to sustain
        local decay_progress = (elapsed - ANIMATION.ATTACK_TIME) / ANIMATION.DECAY_TIME
        brightness = util.linlin(0, 1, ANIMATION.PEAK_BRIGHTNESS, ANIMATION.SUSTAIN_BRIGHTNESS, decay_progress)
      else
        -- Move to sustain state
        note_state.state = "sustain"
        brightness = ANIMATION.SUSTAIN_BRIGHTNESS
      end
      
    elseif note_state.state == "sustain" then
      brightness = ANIMATION.SUSTAIN_BRIGHTNESS
      
    elseif note_state.state == "release" then
      local release_elapsed = current_time - note_state.release_start
      if release_elapsed >= ANIMATION.RELEASE_TIME then
        -- Note is done, mark for cleanup
        active_notes[note] = nil
      else
        -- Fade out
        local progress = release_elapsed / ANIMATION.RELEASE_TIME
        brightness = util.linlin(0, 1, ANIMATION.SUSTAIN_BRIGHTNESS, 0, progress)
      end
    end
    
    -- Apply brightness to all positions for this note
    if note_state and note_state.positions then
      for _, pos in ipairs(note_state.positions) do
        GridLayers.set(response_layer, pos.x, pos.y, math.floor(brightness))
      end
    end
  end
end

return MidiVisualizer 