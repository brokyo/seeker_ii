-- conductor.lua

local logger = include("/lib/logger")
local Motif = include('lib/motif')

-- This Conductor manages multiple Motif objects. 
-- Eventually you might add "stage" logic, transforms, or cross-motif interaction. 

local Conductor = {}
Conductor.__index = Conductor

function Conductor.new(args)
  local c = setmetatable({}, Conductor)
  
  -- A table to hold all active motifs
  c.motifs = {}
  
  -- If you want to use Lattice for scheduling:
  --   local lattice = require("lattice")
  --   c.lattice = lattice:new({
  --     ppqn = 96,        -- or your preferred pulses per quarter note
  --     autostart = false -- we'll manually start it 
  --   })

  -- Or if you prefer the simpler "clock" approach, store any references here:
  --   c.clock = args.clock or nil

  logger.status({
    event = "conductor_created",
    args = args
  })

  return c
end

--------------------------------------------------
-- Add / Remove Motifs
--------------------------------------------------

--- Add a Motif to the Conductor
-- @param motif (Motif) the motif to manage
function Conductor:add_motif(args)
  local motif = Motif.new(args)
  table.insert(self.motifs, motif)
  logger.status({
    event = "motif_added",
    total_motifs = #self.motifs
  })
end

--- Remove a Motif by index
function Conductor:remove_motif(index)
  if index < 1 or index > #self.motifs then return end
  table.remove(self.motifs, index)
  logger.status({
    event = "motif_removed",
    index = index,
    total_motifs = #self.motifs
  })
end

--------------------------------------------------
-- Start / Stop All (Global)
--------------------------------------------------

--- Start all motifs playing
function Conductor:start_all()
  logger.status({
    event = "start_all_motifs",
    count = #self.motifs
  })

  for i, motif in ipairs(self.motifs) do
    self:start_motif(i)
  end

  -- If using Lattice, start it here:
  -- if self.lattice then
  --   self.lattice:start()
  -- end
end

--- Stop all motifs
function Conductor:stop_all()
  logger.status({
    event = "stop_all_motifs",
    count = #self.motifs
  })

  for i, motif in ipairs(self.motifs) do
    self:stop_motif(i)
  end

  -- If using Lattice:
  -- if self.lattice then
  --   self.lattice:stop()
  -- end
end

--------------------------------------------------
-- Start / Stop Individual Motifs
--------------------------------------------------

--- Start a single motif by index
function Conductor:start_motif(index)
  local m = self.motifs[index]
  if not m then 
    logger.status({
      event = "motif_start_failed",
      index = index,
      reason = "invalid_index"
    })
    return 
  end

  logger.music({
    event = "motif_started",
    index = index,
    loop_count = m.loop_count
  })

  m.loop_count = 0
  m:play()  -- The timing logic is handled inside the motif's play() method
end

--- Stop a single motif by index
function Conductor:stop_motif(index)
  local m = self.motifs[index]
  if not m then 
    logger.status({
      event = "motif_stop_failed",
      index = index,
      reason = "invalid_index"
    })
    return 
  end
  
  m:stop()  -- Stop the clock-based playback
  
  logger.music({
    event = "motif_stopped",
    index = index,
    final_loop_count = m.loop_count
  })
end

--------------------------------------------------
-- Future Hooks: Cross-Motif Logic, Stage Management
--------------------------------------------------

-- For instance:
function Conductor:on_motif_finished(motif_index)
  logger.flow({
    event = "motif_finished",
    index = motif_index,
    loop_count = self.motifs[motif_index].loop_count
  })
  -- e.g., trigger next motif or transform
end

function Conductor:create_motif(notes, engine)
  return Motif.new({
    notes = notes,
    engine = engine
  })
end

return Conductor
