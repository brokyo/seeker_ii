-- sequence_manager.lua
-- Coordinates multiple patterns, transformations, and playback scheduling.

local SequenceManager = {}

-- External modules (adjust as needed)
local Pattern         = include("seeker_ii/lib/pattern")
local Transformations = include("seeker_ii/lib/transformations")
local Logger          = include("seeker_ii/lib/logger")      -- optional
local LatticeManager  = include("seeker_ii/lib/lattice_manager")
local musicutil       = require("musicutil")            -- if you want scale/harmony logic
local params          = params                           -- standard Norns params

--------------------------------------------------
-- Internal State
--------------------------------------------------

-- Holds all known patterns (base patterns or derived).
-- e.g. { [1] = PatternObject, [2] = PatternObject, ... }
local patterns = {}

-- Index of the currently active pattern in `patterns`.
local current_pattern_index = 1

-- If you want to store how many loops remain until a transform triggers, or 
-- how many times we've played this pattern, etc.
local loop_count = 0          
local loop_threshold = 4      -- e.g. transform after 4 loops (this might be param-based)

-- A reference to a currently chosen transform function/key,
-- or something more advanced like "role-based" transformations.
local active_transform = nil  

-- If you want to track roles or other meta-data (like your TEXTURE role from the snippet)
local current_role = "TEXTURE"

--------------------------------------------------
-- Initialization
--------------------------------------------------

function SequenceManager.init()
  -- 1. Possibly define Norns parameters for transforms, roles, loop counts, etc.
  --    For example:
  --    params:add_option("transform_key", "Transform", {"transpose", "harmonize", "partial"}, 1)
  --    params:add_number("loop_threshold", "Loop Threshold", 1, 32, 4)
  --
  -- 2. If you want to preload patterns or start with a "genesis" pattern:
  --    patterns[1] = Pattern.new({type="human"})
  --
  -- 3. You may want to register a Lattice callback that:
  --    - Checks if we need to apply a transform
  --    - Steps the pattern playback
  --    - Or simply call "SequenceManager.play_pattern()" from a Lattice pattern
end

--------------------------------------------------
-- Pattern Management
--------------------------------------------------

--- Add a new pattern to the sequence
-- @param p A Pattern object or data table
function SequenceManager.add_pattern(p)
  table.insert(patterns, p)
end

--- Set the currently active pattern by index
-- @param idx integer
function SequenceManager.set_active_pattern(idx)
  if patterns[idx] then
    current_pattern_index = idx
    loop_count = 0
  else
    Logger.log("Invalid pattern index: " .. tostring(idx))
  end
end

--- Get the currently active pattern
function SequenceManager.get_active_pattern()
  return patterns[current_pattern_index]
end

--------------------------------------------------
-- Role & Transformation
--------------------------------------------------

--- Set a "role" (like TEXTURE) which influences available transformations
-- @param role_key string (e.g. "TEXTURE")
function SequenceManager.set_role(role_key)
  -- Could link to your ROLES system (like in your snippet).
  current_role = role_key
end

--- Choose an active transform (e.g. "harmonize")
function SequenceManager.set_transform(transform_key)
  active_transform = transform_key
end

--------------------------------------------------
-- Playback & Looping
--------------------------------------------------

--- Called by the Lattice or clock to play notes from the current pattern
--  and track loop counts.
function SequenceManager.tick()
  local p = SequenceManager.get_active_pattern()
  if not p then
    Logger.log("No active pattern to play.")
    return
  end
  
  -- 1. Play one loop of pattern `p`.
  --    - For instance, you might call a function like p:play_once() or
  --      do your note-on/off scheduling here.
  -- 2. Once the pattern finishes a loop, increment loop_count.
  loop_count = loop_count + 1
  Logger.log("Finished loop #" .. loop_count .. " of pattern ".. current_pattern_index)

  -- 3. Check if we’ve hit the threshold for a transform.
  if loop_count >= params:get("loop_threshold") then
    SequenceManager.apply_transform()
    loop_count = 0
  end
end

--- Apply the currently selected transform to the active pattern
function SequenceManager.apply_transform()
  local p = SequenceManager.get_active_pattern()
  if not p or not active_transform then
    Logger.log("No pattern or transform set.")
    return
  end
  
  -- Example: use the standard transformations from transformations.lua
  if Transformations[active_transform] then
    Logger.log("Applying transform: "..active_transform)
    p = Transformations[active_transform](p, /* pass any needed args */)
    -- If the transform returns an updated pattern, store it back
    patterns[current_pattern_index] = p
  else
    Logger.log("Transform not found: "..active_transform)
  end
end

--- Start the playback sequence
function SequenceManager.start()
  -- 1. Integrate with Lattice or a clock coroutine.
  --    e.g. create a pattern in LatticeManager that calls SequenceManager.tick() every x beats.
  --    or do:
  --      LatticeManager.add_sequence_tick_fn(SequenceManager.tick)
  
  Logger.log("Starting sequence playback...")
end

--- Stop the playback sequence
function SequenceManager.stop()
  -- 1. Cancel Lattice pattern or clock coroutine that calls tick()
  Logger.log("Stopping sequence playback.")
end

--------------------------------------------------
-- Utility / Advanced
--------------------------------------------------

--- If you want a function that does partial chaining:
-- e.g. "Play pattern 1 -> transform -> pattern 2 -> transform -> pattern 1..."
function SequenceManager.chain_patterns(order_list)
  -- placeholder for advanced chaining logic
  -- order_list could be {1,2,3,1} meaning play pattern #1, #2, #3, then #1 again, etc.
end

--- If you have roles defined externally (like your snippet):
function SequenceManager.get_role_transform_list(role_key)
  -- Return a table of possible transforms for the given role
  -- e.g. { "harmonize", "transpose", "random", ... }
  return {}
end

return SequenceManager
