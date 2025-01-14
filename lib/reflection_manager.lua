-- reflection_manager.lua
-- Manages pattern recording, playback, and synchronization using Reflection
-- Reflection API docs https://monome.org/docs/norns/reference/lib/reflection
-- Reflection Source Code https://github.com/monome/norns/blob/main/lua/lib/reflection.lua


local reflection = require("reflection")
local logger = include('lib/logger')

local ReflectionManager = {
  patterns = {},  -- Will hold our pattern instances
  skeys = nil    -- Will hold MXSamples instance
}

function ReflectionManager.init(skeys_instance)
  ReflectionManager.skeys = skeys_instance
  
  -- Initialize a single pattern to start
  ReflectionManager.patterns.main = reflection.new()
  
  -- Set quantization for tight arpeggios (1/16 = sixteenth notes)
  ReflectionManager.patterns.main:set_quantization(1/16)
  
  -- Set up the process function that will execute on playback
  ReflectionManager.patterns.main.process = function(event)
    if event.z == 1 then  -- Note on
      ReflectionManager.skeys:on({
        name = params:string("instrument"),  -- Get instrument from params
        midi = event.id,
        velocity = event.velocity or 100
      })
      
      -- Log the played note with beat timestamp
      logger.music("note", {
        message = "pattern playback",
        context = {
          string.format("beat: %.3f  note: %d  vel: %d  x: %d  y: %d",
            clock.get_beats(),
            event.id,
            event.velocity or 100,
            event.x,
            event.y)
        }
      })
    else  -- Note off
      ReflectionManager.skeys:off({
        name = params:string("instrument"),  -- Get instrument from params
        midi = event.id
      })
    end
  end
  
  -- Set up callbacks
  ReflectionManager.patterns.main.start_callback = function()
    logger.music("pattern", {
      message = "main",
      context = { 
        string.format("playback started (quantize: %.3f)", ReflectionManager.patterns.main.quantize)
      }
    })
  end
  
  ReflectionManager.patterns.main.end_callback = function()
    logger.music("pattern", {
      message = "main",
      context = { "playback stopped" }
    })
  end
end

-- Basic recording controls
function ReflectionManager.start_recording()
  -- Start recording immediately
  ReflectionManager.patterns.main:set_rec(1)
  logger.music("pattern", {
    message = "main",
    context = { string.format("recording started (quantize: %.3f)", 
      ReflectionManager.patterns.main.quantize) }
  })
end

function ReflectionManager.stop_recording()
  ReflectionManager.patterns.main:set_rec(0)
  logger.music("pattern", {
    message = "main",
    context = { "recording stopped" }
  })
end

function ReflectionManager.is_recording()
  return ReflectionManager.patterns.main.rec == 1
end

-- Basic playback controls
function ReflectionManager.start_playback()
  ReflectionManager.patterns.main:set_loop(1)  -- Enable looping
  -- Start immediately
  ReflectionManager.patterns.main:start()
end

function ReflectionManager.stop_playback()
  ReflectionManager.patterns.main:stop()
end

-- Record a note event
function ReflectionManager.record_note(note_num, velocity, x, y)
  -- Only record if we're in recording mode
  if ReflectionManager.patterns.main.rec == 1 then
    local event = {
      id = note_num,
      velocity = velocity,
      x = x or 0,
      y = y or 0,
      z = velocity > 0 and 1 or 0  -- z=1 for note on, z=0 for note off
    }
    
    -- Log recording with beat timestamp
    if event.z == 1 then
      logger.music("note", {
        message = "recording",
        context = {
          string.format("beat: %.3f  note: %d  vel: %d  x: %d  y: %d",
            clock.get_beats(),
            event.id,
            event.velocity,
            event.x,
            event.y)
        }
      })
    end
    
    ReflectionManager.patterns.main:watch(event)
  end
end

-- Basic pattern management
function ReflectionManager.clear_pattern()
  ReflectionManager.patterns.main:clear()
  logger.music("pattern", {
    message = "main",
    context = { "pattern cleared" }
  })
end

return ReflectionManager