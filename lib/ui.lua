-- ui.lua
-- Manages Norns screen drawing, encoder/key handling for page navigation, etc.

local UI = {
  pages = {"VOICE", "PATTERN", "CONFIG"},
  current_page = 1,
  grid_ui = nil,   -- Will store grid_ui reference
  voice_change_callbacks = {}  -- New: callbacks for voice changes
}

--------------------------------------------------
-- Initialization
--------------------------------------------------

function UI.init()
  return UI  -- Return the instance
end

--------------------------------------------------
-- Key & Encoder Input
--------------------------------------------------

function UI.key(n, z)
  -- 1. If we need to handle page switching or advanced UI logic
  if n == 3 and z == 1 then
    UI.current_page = UI.current_page % #UI.pages + 1
  end
end

function UI.enc(n, d)
  if n == 1 then
    local new_voice = util.clamp(_seeker.focused_voice + d, 1, 4)
    UI.select_voice(new_voice)  -- Use new select_voice function
  end
  -- ... other encoder handling
end

--------------------------------------------------
-- Redraw
--------------------------------------------------

function UI.redraw()
  screen.clear()
  screen.level(15)
  
  -- Show current voice prominently
  screen.move(0, 10)
  screen.text("Voice " .. _seeker.focused_voice)
  
  -- Show voice state
  if _seeker.conductor then  -- Check for conductor
    local voice = _seeker.conductor.voices[_seeker.focused_voice]
    if voice then
      screen.move(0, 20)
      screen.text(voice.is_recording and "Recording" or 
                 voice.is_playing and "Playing" or 
                 "Stopped")
    end
  end
  
  screen.update()
end

-- Add callback registration
function UI.on_voice_change(callback)
  table.insert(UI.voice_change_callbacks, callback)
end

-- Update voice selection with callback notifications
function UI.select_voice(new_voice)
  if new_voice ~= _seeker.focused_voice then
    _seeker.focused_voice = new_voice
    -- Notify all callbacks
    for _, callback in ipairs(UI.voice_change_callbacks) do
      callback(new_voice)
    end
    UI.redraw()
  end
end

return UI
