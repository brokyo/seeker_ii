-- conductor.lua
-- Conductor is the maestro of the application, responsible for:
-- 1. Managing when motifs play (clock/timing)
-- 2. Orchestrating how motifs evolve through transforms
-- 3. Synchronizing multiple motifs
-- 4. Managing playback state
--
-- The Conductor decides WHEN and HOW patterns should change,
-- while Motif handles the mechanics of those changes.

--------------------------------------------------
-- Architecture Overview
--------------------------------------------------
-- 1. Transform System
--    - Conductor determines the sequence and timing of transforms
--    - Coordinates transforms across multiple lanes
--    - Manages transform state and progression
--    - Uses Motif's transform mechanism to apply changes
--
-- 2. Lane System
--    - Primary organizational unit for playback
--    - Contains: motif data, instrument settings, timing config
--    - Supports multiple parallel lanes with independent settings
--    - Each lane can have up to 4 stages with different transforms
--    - Stages can be activated/deactivated for dynamic performance
--
-- 3. Timing & Scheduling System
--    - Uses absolute beat numbers for precise timing
--    - Global beat counter (e.g. 152399.001) for exact synchronization
--    - Supports quantized playback and "free" event times
--    - Event scheduling hierarchy:
--      * Stage: A complete sequence of loops with same transform
--      * Loop: One complete playthrough of a motif
--      * Event: Individual note on/off at specific beat number
--    - Rest periods:
--      * Loop Rest: Silence between each loop iteration
--      * Stage Rest: Silence between stages
--    - Event Sorting:
--      * All events (note-on/off) sorted chronologically
--      * Ensures proper handling of overlapping notes
--      * Maintains polyphony while preserving timing
--    - Stage Transitions:
--      * Occurs after stage rest period
--      * Checks for next active stage
--      * Lane stops if no active stages found
--    - Example timeline:
--      Beat:    152399.0  152399.5  152400.0  152400.5
--      Events:  note_on   note_off  note_on   note_off



local Motif = include('lib/motif')
local params_manager = include('lib/params_manager')
local lane_utils = include('lib/lane_utils')
local transforms = include('lib/transforms')

local MAX_STAGES = 4  -- Configurable number of stages

local Conductor = {}
Conductor.__index = Conductor

--------------------------------------------------
-- Configuration & Debug Settings
--------------------------------------------------

local DEBUG = {
  PLAYBACK = false,  -- Note events and timing at execution
  STATUS = true,    -- Loop/stage changes and high-level state
  SCHEDULE = false   -- Pre-calculated note sequences and transforms
}

--------------------------------------------------
-- Lane Structure
--------------------------------------------------

local Lane = {}
Lane.__index = Lane

function Lane.new(lane_num)
  local l = setmetatable({}, Lane)
  l.lane_num = lane_num
  l.is_playing = false
  l.motif = nil  -- The lane's motif (contains both genesis and current state)
  l.current_stage = 1
  l.timing_mode = "free"
  l.grid_division = 1/16
  l.playback_speed = 1.0
  l.transform_sequence = {}
  l.current_transform = 1
  l.active_notes = {}  -- Track currently playing notes for grid feedback
  
  -- Initialize transform state for each stage
  l.stage_transforms = {}
  for i = 1,MAX_STAGES do
    l.stage_transforms[i] = {
      type = "none",
      params = {}
    }
  end
  
  return l
end

function Lane:get_param(param_name, stage_num)
  -- Build parameter name
  local param_id
  if stage_num then
    -- Stage-specific parameter
    param_id = string.format("lane_%d_stage_%d_%s", self.lane_num, stage_num, param_name)
  else
    -- Lane-level parameter
    param_id = string.format("lane_%d_%s", self.lane_num, param_name)
  end
  
  -- Check if parameter exists - fail fast if missing
  if not params:lookup_param(param_id) then
    error(string.format("Missing required parameter: %s", param_id))
  end
  
  return params:get(param_id)
end

--------------------------------------------------
-- Transform System
--------------------------------------------------

function Lane:set_stage_transform(stage_num, transform_type, transform_params)
  if not transforms.available[transform_type] and transform_type ~= "none" then
    print(string.format("Transform '%s' not found", transform_type))
    return
  end
  
  -- Initialize with defaults if params not provided
  local params = transform_params or {}
  if transform_type ~= "none" then
    local transform = transforms.available[transform_type]
    if transform.params then
      for param_name, param_spec in pairs(transform.params) do
        if params[param_name] == nil then
          params[param_name] = param_spec.default
        end
      end
    end
  end
  
  self.stage_transforms[stage_num] = {
    type = transform_type,
    params = params
  }
end

function Lane:get_stage_transform(stage_num)
  return self.stage_transforms[stage_num]
end

function Lane:is_stage_active(stage_num)
  -- Validate stage number
  if stage_num < 1 or stage_num > MAX_STAGES then
    error(string.format("Invalid stage number: %d (must be 1-%d)", stage_num, MAX_STAGES))
  end
  
  -- Build parameter name
  local param_name = string.format("lane_%d_stage_%d_active", self.lane_num, stage_num)
  
  -- Check if parameter exists - fail fast if missing
  if not params:lookup_param(param_name) then
    error(string.format("Missing stage active parameter: %s", param_name))
  end
  
  return params:get(param_name) == 1
end

function Lane:find_next_active_stage()
  local start = self.current_stage
  local checked = 0
  
  -- First look forward from current stage
  while checked < MAX_STAGES do
    local next_stage = (start % MAX_STAGES) + 1
    if self:is_stage_active(next_stage) then
      if DEBUG.STATUS then
        print(string.format("Lane %d found next active stage: %d", self.lane_num, next_stage))
      end
      return next_stage
    end
    start = next_stage
    checked = checked + 1
  end
  
  -- No active stages after current - look from beginning
  for stage = 1, MAX_STAGES do
    if self:is_stage_active(stage) then
      if DEBUG.STATUS then
        print(string.format("Lane %d wrapping to stage: %d", self.lane_num, stage))
      end
      return stage
    end
  end
  
  -- No active stages found - stop the lane
  if DEBUG.STATUS then
    print(string.format("Lane %d has no active stages - stopping", self.lane_num))
  end
  
  -- Stop the lane through conductor
  if _seeker.conductor then
    _seeker.conductor:stop_lane(self.lane_num)
  end
  
  print("Find next stage failed.")
  return nil
end

function Lane:advance_stage()
  -- Find next active stage (or stay on current if it's the only active one)
  self.current_stage = self:find_next_active_stage()
  
  -- Get configuration for this stage
  local config = self:get_stage_config(self.current_stage)
  
  -- Stage 1 or no transform: reset to genesis
  local transform = self:get_stage_transform(self.current_stage)
  if self.current_stage == 1 or transform.type == "none" then
    self.motif:reset_to_genesis()
    return self.current_stage
  end
  
  -- Apply transform based on stage number
  -- Stage 2: Transform from genesis
  -- Stage 3/4: Compound on previous transform
  local mode = self.current_stage == 2 and "genesis" or "compound"
  
  -- Get transform function from registry
  local transform_def = transforms.available[transform.type]
  if not transform_def then
    print(string.format("Transform '%s' not found", transform.type))
    self.motif:reset_to_genesis()
    return self.current_stage
  end
  
  -- Apply the transform
  self.motif:apply_transform(transform_def.fn, transform.params, mode)
  
  return self.current_stage
end

--------------------------------------------------
-- Constructor & State Management
--------------------------------------------------

function Conductor.new()
  local c = setmetatable({}, Conductor)
  
  -- Initialize lanes
  c.lanes = {}
  for i = 1,4 do
    c.lanes[i] = Lane.new(i)
  end
  
  return c
end

--------------------------------------------------
-- Note Playback Functions
--------------------------------------------------

-- Format beat number to show only last 4 digits for readability
local function format_beat(beat)
  local beat_str = string.format("%.3f", beat)
  local len = #beat_str
  if len > 8 then
    return "..." .. string.sub(beat_str, len-7)  -- Show last 8 chars (4 digits + "." + 3 decimals)
  end
  return beat_str
end

-- Format timing delta with sign and color indicators
local function format_delta(actual, target)
  local delta = actual - target
  local delta_str = string.format("%+.3f", delta)  -- Use + sign for positive deltas
  if math.abs(delta) < 0.001 then
    return "=0.000"  -- Exact match
  elseif delta > 0 then
    return "+" .. delta_str:sub(2)  -- Remove extra + and add our own
  else
    return delta_str
  end
end

function Conductor:play_note_on(lane, note)
  local instrument_name = lane_utils.get_lane_instrument(lane.lane_num)
  
  -- Track active note for grid feedback
  table.insert(lane.active_notes, note.pitch)
  
  if DEBUG.PLAYBACK then
    print(string.format("♪ ON  | L%d | Beat %s | P%d | V%d", 
      lane.lane_num, format_beat(clock.get_beats()), note.pitch, note.velocity or 100))
  end
  
  _seeker.skeys:on({
    name = instrument_name,
    midi = note.pitch,
    velocity = note.velocity
  })
end

function Conductor:play_note_off(lane, note)
  local instrument_name = lane_utils.get_lane_instrument(lane.lane_num)
  
  -- Remove note from active notes
  for i = #lane.active_notes, 1, -1 do
    if lane.active_notes[i] == note.pitch then
      table.remove(lane.active_notes, i)
      break
    end
  end
  
  if DEBUG.PLAYBACK then
    print(string.format("♪ OFF | L%d | Beat %s | P%d", 
      lane.lane_num, format_beat(clock.get_beats()), note.pitch))
  end
  
  _seeker.skeys:off({
    name = instrument_name,
    midi = note.pitch
  })
end

function Conductor:stop_all_notes(lane)
  local instrument_name = lane_utils.get_lane_instrument(lane.lane_num)
  
  -- Clear active notes array
  lane.active_notes = {}
  
  if DEBUG.PLAYBACK then
    print(string.format("⬛ ALL OFF | L%d", lane.lane_num))
  end
  
  -- Send note offs for all possible MIDI notes
  for note = 0, 127 do
    _seeker.skeys:off({
      name = instrument_name,
      midi = note
    })
  end
end

--------------------------------------------------
-- Core Timing System
--------------------------------------------------

-- Schedule a stage using absolute beat numbers for precise timing
-- Each stage consists of:
-- 1. A sequence of loops with the same motif/transform
-- 2. Optional rest periods between loops
-- 3. Optional rest period after the stage
--
-- Timing is handled by calculating absolute beat numbers for every event
-- and using clock.sync to precisely hit those beat numbers. This ensures:
-- - Perfect synchronization between lanes
-- - No timing drift over long periods
-- - Accurate handling of loop and stage boundaries
function Conductor:schedule_stage(lane, stage)
  if not lane.motif then return end
  
  -- Debug print the motif events
  if DEBUG.SCHEDULE then
    print(string.format("\n◇ Lane %d Stage %d Notes:", lane.lane_num, lane.current_stage))
    for i = 1, lane.motif.note_count do
      local note = lane.motif:get_event(i)
      print(string.format("  Note %d: P%d T%.3f D%.3f", 
        i, note.pitch, note.time, note.duration))
    end
  end
  
  -- Calculate rest durations once
  local loop_rest = lane:get_param("loop_rest", lane.current_stage) * 4
  local stage_rest = lane:get_param("stage_rest", lane.current_stage) * 4
  local total_loop_duration = lane.motif.total_duration + loop_rest
  
  if DEBUG.SCHEDULE then
    print(string.format("  Config: %d loops, %.2f/loop, %.2f rest, %.2f stage-rest", 
      stage.num_loops, lane.motif.total_duration, loop_rest, stage_rest))
  end
  
  clock.run(function()
    -- Phase 1: Initial Synchronization
    clock.sync(1)
    local start_beat = clock.get_beats()
    if DEBUG.STATUS then
      print(string.format("\n▶ Lane %d Stage %d @ %s", 
        lane.lane_num, lane.current_stage, format_beat(start_beat)))
    end
    
    -- Phase 2: Loop Processing
    for loop = 0, stage.num_loops - 1 do
      -- Calculate absolute beat number for loop start
      local loop_start = start_beat + (loop * total_loop_duration)
      if DEBUG.STATUS then
        print(string.format("  Loop %d/%d @ %s", 
          loop + 1, stage.num_loops, format_beat(loop_start)))
      end
      
      -- Phase 3: Event Processing
      -- Create a chronologically sorted list of all events (note-ons and note-offs)
      local events = {}
      for i = 1, lane.motif.note_count do
        local note = lane.motif:get_event(i)
        table.insert(events, {
          type = "note_on",
          time = loop_start + note.time,
          note = note,
          note_index = i
        })
        table.insert(events, {
          type = "note_off",
          time = loop_start + note.time + note.duration,
          note = note,
          note_index = i
        })
      end
      
      -- Sort events by absolute time
      table.sort(events, function(a, b) return a.time < b.time end)
      
      -- Process events in chronological order
      for _, event in ipairs(events) do
        clock.sync(event.time)
        local current_beat = clock.get_beats()
        
        if event.type == "note_on" then
          self:play_note_on(lane, event.note)
          if DEBUG.PLAYBACK then
            print(string.format("  Δ%s", format_delta(current_beat, event.time)))
          end
        else
          self:play_note_off(lane, event.note)
          if DEBUG.PLAYBACK then
            print(string.format("  Δ%s", format_delta(current_beat, event.time)))
          end
        end
      end
      
      -- Phase 4: Loop Rest
      if loop_rest > 0 then
        local rest_end = loop_start + lane.motif.total_duration + loop_rest
        if DEBUG.STATUS then
          print(string.format("    Rest @ %s", format_beat(rest_end)))
        end
        clock.sync(rest_end)
      end
    end

    -- Phase 5: Stage Rest
    if stage_rest > 0 then
      local stage_end = start_beat + (stage.num_loops * total_loop_duration)
      local stage_rest_end = stage_end + stage_rest
      if DEBUG.STATUS then
        print(string.format("  Stage Rest @ %s", format_beat(stage_rest_end)))
      end
      clock.sync(stage_rest_end)
    end

    if DEBUG.STATUS then
      print(string.format("◇ Lane %d Stage %d Complete @ %s", 
        lane.lane_num, lane.current_stage, format_beat(clock.get_beats())))
    end
    
    -- Schedule next stage if still playing and there is a next stage
    if lane.is_playing then
      -- Try to find next active stage
      local next_stage_num = lane:find_next_active_stage()
      
      -- If no active stages found, stop the lane
      if not next_stage_num then
        self:stop_lane(lane.lane_num)
        return
      end
      
      -- Otherwise proceed with next stage
      lane.current_stage = next_stage_num
      if next_stage_num == 1 then
        lane.motif:reset_to_genesis()
      end
      
      -- Schedule next stage
      local next_stage = {
        num_loops = lane:get_param("loop_count", lane.current_stage),
        transform = nil,
        params = {}
      }
      self:schedule_stage(lane, next_stage)
    end
  end)
end

--------------------------------------------------
-- Playback Control
--------------------------------------------------

-- Start playback for a lane
function Conductor:play_lane(lane_num)
  local lane = self.lanes[lane_num]
  
  -- Initialize playback state first
  lane.is_playing = true
  
  if not lane.motif then 
    if DEBUG.STATUS then
      print(string.format("\n▶ Lane %d: No motif to play", lane_num))
    end
    return 
  end
  
  if DEBUG.STATUS then
    print(string.format("\n▶ Starting Lane %d", lane_num))
  end
  
  -- Create a stage with current loop parameters
  local stage = {
    num_loops = lane:get_param("loop_count", lane.current_stage),
    transform = nil,  -- No transform yet
    params = {}
  }
  
  -- Schedule the stage
  self:schedule_stage(lane, stage)
end

-- Stop playback for a lane
function Conductor:stop_lane(lane_num)
  local lane = self.lanes[lane_num]
  if not lane.is_playing then return end
  
  if DEBUG.STATUS then
    print(string.format("\n■ Stopping Lane %d", lane_num))
  end
  
  -- Stop any currently playing notes
  self:stop_all_notes(lane)
  
  -- Clear playback state
  lane.is_playing = false
end

function Conductor:stop_all()
  if DEBUG.STATUS then
    print("\n■ Stopping All Lanes")
  end
  
  for i = 1,4 do
    self:stop_lane(i)
  end
end

--------------------------------------------------
-- Motif Management
--------------------------------------------------

-- Create a new motif from recorded data and store it in a lane
function Conductor:create_motif(lane_num, recorded_data)
  -- Debug print the recorded data
  if DEBUG.SCHEDULE then
    print("\n◇ Creating Motif for Lane " .. lane_num)
    for i, note in ipairs(recorded_data) do
      local note_info = string.format("  Note %d: P%d T%.2f D%.2f", 
        i, note.pitch, note.time, note.duration)
      if note.pos then
        note_info = note_info .. string.format(" pos=(%d,%d)", note.pos.x, note.pos.y)
      end
      print(note_info)
    end
  end
  
  -- Create and store the motif
  local motif = Motif.new({
    notes = recorded_data,
    lane = lane_num
  })
  
  -- Store in lane and reset state
  local lane = self.lanes[lane_num]
  lane.motif = motif
  lane.active_notes = {}  -- Reset active notes when creating new motif
  
  return motif
end

--------------------------------------------------
-- Transform System
--------------------------------------------------

-- Add a transform to a lane's sequence
-- The Conductor orchestrates WHEN transforms happen and coordinates
-- them across lanes, while the actual transform application is 
-- delegated to the Motif class
function Conductor:add_transform(lane_num, transform_fn, params)
  local lane = self.lanes[lane_num]
  if not lane then return end
  
  if DEBUG.STATUS then
    print(string.format("◇ Transform Lane %d: %s", lane_num, transform_fn.name or "unnamed"))
  end
  
  table.insert(lane.transform_sequence, {
    transform = transform_fn,
    params = params,
    num_loops = params.num_loops or 1
  })
end

-- Schedule synchronized transforms across multiple lanes
-- This is a key responsibility of the Conductor - coordinating
-- how multiple lanes evolve together
function Conductor:sync_transform(lane_nums, transform_fn, params)
  if DEBUG.STATUS then
    print(string.format("◇ Sync Transform Lanes [%s]: %s", 
      table.concat(lane_nums, ","), transform_fn.name or "unnamed"))
  end
  
  -- Add the same transform to multiple lanes
  -- They will all transform together after their current stages complete
  for _, lane_num in ipairs(lane_nums) do
    self:add_transform(lane_num, transform_fn, params)
  end
end

--------------------------------------------------
-- Debug Helpers
--------------------------------------------------

-- Print a timeline of all scheduled note events for a lane
function Conductor:print_note_timeline(lane_num, num_loops)
  local lane = self.lanes[lane_num]
  if not lane.motif then return end
  
  num_loops = num_loops or 1
  local now = clock.get_beats()
  
  print(string.format("\n◈ Timeline for Lane %d ◈", lane_num))
  print("Loop | Note | Time    | +Beats  | Pitch | Dur")
  print("-----|------|---------|---------|--------|-----")
  
  for loop = 0, num_loops - 1 do
    local loop_start = now + (loop * lane.motif.total_duration)
    
    for i = 1, lane.motif.note_count do
      local note = lane.motif:get_event(i)
      local abs_time = loop_start + note.time
      local rel_time = note.time
      
      print(string.format("%4d | %4d | %7.2f | %7.2f | %6d | %.2f",
        loop, i, abs_time, rel_time, note.pitch, note.duration))
    end
    
    if loop < num_loops - 1 then
      print("-----|------|---------|---------|--------|-----")
    end
  end
  print(string.format("\nTotal Duration per Loop: %.2f beats", lane.motif.total_duration))
end

--------------------------------------------------
-- Important Implementation Notes
--------------------------------------------------

--[[ Timing System Design:
1. Boundaries & Transitions
   - Loop rests must align to global beat grid
   - Stage transitions need smooth timing
   - Multiple stages must chain correctly

2. Transformations
   - Only occur at stage boundaries (never mid-loop)
   - Speed changes are most critical:
     * Must recalculate all absolute beats for new stage
     * New tempo must align with global beat grid
     * Example: If stage 1 ends at beat 152400.0 and applies
       a 2x speed transform, stage 2's events must map to
       152400.0, 152400.25, 152400.5, etc.
   - Other transforms (pitch, inversion) don't affect timing
   - Each stage maintains its own consistent timing grid

3. Edge Cases
   - Notes crossing loop boundaries
   - Zero duration notes
   - Empty loops or rests
   - Global beat counter limits

4. Performance
   - Consider pre-calculating loop timings
   - Potential for event batching
   - Minimize coroutines

5. Cleanup & Safety
   - Proper cleanup on stop
   - Handle interrupted playback
   - Ensure all notes get note-offs
]]--

--------------------------------------------------
-- Stage Management
--------------------------------------------------

-- Get the transform configuration for a stage
-- Each stage can have:
-- 1. A transform type (e.g. "invert", "speed")
-- 2. Transform-specific parameters
-- 3. Loop and timing settings
function Lane:get_stage_config(stage_num)
  return {
    num_loops = self:get_param("loop_count", stage_num),
    loop_rest = self:get_param("loop_rest", stage_num),
    stage_rest = self:get_param("stage_rest", stage_num)
  }
end

-- Add clear_lane if it doesn't exist
function Conductor:clear_lane(lane_num)
  local lane = self.lanes[lane_num]
  
  -- Stop playback if active
  if lane.is_playing then
    self:stop_lane(lane_num)
  end
  
  -- Clear state
  lane.motif = nil
  lane.active_notes = {}
  lane.current_stage = 1
end

return Conductor
