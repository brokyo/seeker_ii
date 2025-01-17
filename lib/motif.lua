-- motif.lua
-- Defines a Motif object for storing notes, velocities, timing, etc.

local musicutil = require("musicutil")
local logger = include('lib/logger')

local Motif = {}
Motif.__index = Motif

--------------------------------------------------
-- Constructor
--------------------------------------------------

function Motif.new(args)
  local m = setmetatable({}, Motif)
  args = args or {}

  -- Initialize motif data
  m.notes = args.notes or {}  -- Accept notes array from constructor
  m.loop_count = 0     -- How many times we've looped this motif
  m.max_loops = args.max_loops or 4
  m.transform = nil    
  m.quantum = args.quantum or 1/64  -- Default to 1/64th note quantum
  
  -- Add playback state
  m.is_playing = false
  m.clock_id = nil   
  m.engine = args.engine

  return m
end

--------------------------------------------------
-- Clock-Based Playback
--------------------------------------------------

function Motif:play()
  if #self.notes == 0 then return end
  
  self.is_playing = true
  self.loop_count = 0

  self.clock_id = clock.run(function()
    while self.is_playing and self.loop_count < self.max_loops do
      local loop_start = clock.get_beats()
      
      logger.playback({
        event = "loop_started",
        loop = self.loop_count + 1,
        start_time = loop_start
      })

      for _, note in ipairs(self.notes) do
        -- Sync to absolute time from loop start
        clock.sync(loop_start + note.time)
        
        if self.engine then
          self.engine:on({
            name = params:string("instrument"),
            midi = note.pitch,
            velocity = note.velocity
          })

          if note.duration > 0 then
            clock.run(function()
              clock.sync(loop_start + note.time + note.duration)
              self.engine:off({
                name = params:string("instrument"),
                midi = note.pitch
              })
            end)
          end
        end

        logger.playback({
          event = "motif_note_played",
          n = note.pitch,
          v = note.velocity,
          t = note.time,
          d = note.duration,
          beat = clock.get_beats()
        })
      end

      -- Wait for next loop
      local total_duration = self.notes[#self.notes].time + self.notes[#self.notes].duration
      clock.sync(loop_start + total_duration)
      
      self.loop_count = self.loop_count + 1
    end

    self.is_playing = false
    self.clock_id = nil
  end)
end

function Motif:stop()
  if not self.is_playing then
    logger.status({
      event = "motif_stop_failed",
      reason = "not_playing"
    })
    return
  end
  
  self.is_playing = false
  if self.clock_id then
    clock.cancel(self.clock_id)
    self.clock_id = nil
  end
  
  logger.status({
    event = "motif_stopped",
    final_loop = self.loop_count
  })
end

--------------------------------------------------
-- Transformation Hook
--------------------------------------------------

function Motif:apply_transform()
  -- 1. If self.transform is set, call it
  -- 2. self.transform(self) or something similar
end

return Motif
