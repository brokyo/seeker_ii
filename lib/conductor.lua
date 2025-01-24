-- conductor.lua
-- Conductor is the maestro of the application, responsible for:
-- 1. Managing when motifs play (clock/timing)
-- 2. Orchestrating how motifs evolve through transforms
-- 3. Synchronizing multiple motifs
-- 4. Managing playback state
--
-- The Conductor decides WHEN and HOW patterns should change,
-- while Motif handles the mechanics of those changes.

--
-- Core Responsibilities:
-- 1. Scheduling and timing of motif playback
-- 2. Managing stage transitions and transforms
-- 3. Coordinating multiple parallel lanes
--
-- Implementation Notes:
-- - Uses absolute beat numbers for timing (e.g. 152399.001)
-- - Each stage is a sequence of loops with the same transform
-- - Stage transitions only occur after all loops complete
--
-- Important Quirks:
-- - Stage rest must complete before checking next stage
-- - Transform changes only happen at stage boundaries
-- - Note-offs must be guaranteed even if playback interrupted

local Motif = include('lib/motif')
local params_manager = include('lib/params_manager')
local lane_utils = include('lib/lane_utils')
local transforms = include('lib/transforms')
local Log = include('lib/log')

local MAX_STAGES = 4  -- Configurable number of stages

local Conductor = {}
Conductor.__index = Conductor

--------------------------------------------------
-- Lane Structure
--------------------------------------------------

local Lane = {}
Lane.__index = Lane

function Lane.new(lane_num)
  local l = setmetatable({}, Lane)
  l.lane_num = lane_num
  l.is_playing = false
  l.motif = nil
  l.current_stage = 1
  l.timing_mode = "free"
  l.grid_division = 1/16
  l.playback_speed = 1.0
  l.active_notes = {}
  
  -- Initialize transform state for each stage
  l.stage_transforms = {}
  for i = 1,MAX_STAGES do
    l.stage_transforms[i] = {
      type = "none",  -- Transform type (none, invert, reverse, etc)
      params = {}     -- Transform-specific parameters
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

-- Get/Set transform configuration
function Lane:set_transform(stage_num, transform_type, params)
  if stage_num < 1 or stage_num > MAX_STAGES then return end
  
  -- Validate transform exists
  if transform_type ~= "none" and not transforms.available[transform_type] then
    print(string.format("Transform '%s' not found", transform_type))
    return
  end
  
  -- Store transform config
  self.stage_transforms[stage_num].type = transform_type
  self.stage_transforms[stage_num].params = params or {}
end

function Lane:get_transform(stage_num)
  if stage_num < 1 or stage_num > MAX_STAGES then return nil end
  return self.stage_transforms[stage_num]
end

function Lane:set_stage_active(stage_num, active)
  if stage_num < 1 or stage_num > MAX_STAGES then return end
  -- Set the param value (1 = Off, 2 = On)
  local param_id = string.format("lane_%d_stage_%d_active", self.lane_num, stage_num)
  params:set(param_id, active and 2 or 1)
end

function Lane:is_stage_active(stage_num)
  -- Get the active state from params (2 = On, 1 = Off)
  return self:get_param("active", stage_num) == 2
end

function Lane:find_next_active_stage()
    -- Start looking from the next stage
    local start = self.current_stage
    local checked = 0
    
    -- First look forward from current stage
    while checked < MAX_STAGES do
        local next_stage = (start % MAX_STAGES) + 1
        if self:is_stage_active(next_stage) then
            return next_stage
        end
        start = next_stage
        checked = checked + 1
    end
    
    -- No active stages found after current - look from beginning
    for stage = 1, MAX_STAGES do
        if self:is_stage_active(stage) then
            return stage
        end
    end
    
    return nil
end


function Lane:advance_stage()
  -- Find next active stage
  local next_stage = self:find_next_active_stage()
  if not next_stage then 
    return nil 
  end
  
  -- Update current stage
  self.current_stage = next_stage
  
  -- Reset to genesis state first
  self.motif:reset_to_genesis()
  
  -- Get and apply transform if any
  local transform_config = self:get_transform(self.current_stage)
  if transform_config.type ~= "none" then
    local transform = transforms.available[transform_config.type]
    if transform and transform.fn then
      Log.log("CONDUCTOR", "TRANSFORM", 
        string.format("%s Applying transform %s | Lane %d Stage %d", 
          Log.ICONS.TRANSFORM, transform_config.type, self.lane_num, self.current_stage))
      self.motif:apply_transform(transform.fn, transform_config.params or {}, "genesis")
    end
  end
  
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

function Conductor:play_note_on(lane, note)
  local instrument_name = lane_utils.get_lane_instrument(lane.lane_num)

  -- Track active note for grid feedback
  table.insert(lane.active_notes, note.pitch)
  
  -- Get lane volume and scale velocity
  local volume = lane:get_param("volume")
  local scaled_velocity = math.floor((note.velocity or 100) * volume)

  Log.log("CONDUCTOR", "PLAYBACK", 
  string.format("%s Note ON | Pitch %d | Beat %s | Lane %d", 
    Log.ICONS.NOTE_ON, note.pitch, Log.format.beat(note.time), lane.lane_num))

  _seeker.skeys:on({
    name = instrument_name,
    midi = note.pitch,
    velocity = scaled_velocity
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

  Log.log("CONDUCTOR", "PLAYBACK", 
  string.format("%s Note OFF | Pitch %d | Beat %s | Lane %d", 
    Log.ICONS.NOTE_OFF, note.pitch, note.time, lane.lane_num))

  _seeker.skeys:off({
    name = instrument_name,
    midi = note.pitch
  })
end

function Conductor:stop_all_notes(lane)
  local instrument_name = lane_utils.get_lane_instrument(lane.lane_num)
  
  -- Clear active notes array
  lane.active_notes = {}
  
  Log.log("CONDUCTOR", "PLAYBACK", 
    string.format("%s Stopping all notes | Lane %d", Log.ICONS.NOTE_OFF, lane.lane_num))
  
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
function Conductor:schedule_stage(lane, stage)
  if not lane.motif then return end
  
  -- Calculate rest durations once
  local loop_rest = lane:get_param("loop_rest", lane.current_stage) * 4
  local stage_rest = lane:get_param("stage_rest", lane.current_stage) * 4
  
  -- Calculate total duration for each loop iteration
  local pattern_duration = lane.motif.total_duration
  local total_loop_duration = pattern_duration + loop_rest
  
  -- Get transform info for logging
  local transform_config = lane:get_transform(lane.current_stage)
  local transform_info = transform_config.type ~= "none" and transform_config.type or "none"
  
  Log.log("CONDUCTOR", "BOUNDARY", 
    string.format("%s Stage %d ▸ Transform: %s | Loops: %d | Rest: %.1f,%.1f | Pattern: %.3f | Total: %.3f | Lane %d", 
      Log.ICONS.STAGE, lane.current_stage, transform_info, 
      stage.num_loops, loop_rest, stage_rest, pattern_duration, total_loop_duration, 
      lane.lane_num))
  
  clock.run(function()
    -- First sync to next beat boundary
    clock.sync(1)
    local start_beat = clock.get_beats()
    
    -- Pre-calculate event table timing
    local events = {}
    local last_loop_end = start_beat
    
    for loop = 0, stage.num_loops - 1 do
      -- Loop starts after previous loop's last note
      local loop_start = last_loop_end
      
      -- Add loop start event
      table.insert(events, {
        type = "loop_start",
        time = loop_start,
        loop = loop + 1
      })
      
      -- Track the latest note end time for this loop
      local loop_end = loop_start
      
      -- Add note events
      for i = 1, lane.motif.note_count do
        local note = lane.motif:get_event(i)
        local note_on_time = loop_start + note.time
        local note_off_time = note_on_time + note.duration
        
        -- Track the latest note end
        loop_end = math.max(loop_end, note_off_time)
        
        table.insert(events, {
          type = "note_on",
          time = note_on_time,
          note = note,
          loop = loop + 1
        })
        table.insert(events, {
          type = "note_off",
          time = note_off_time,
          note = note,
          loop = loop + 1
        })
      end
      
      -- Add loop rest
      last_loop_end = loop_end + loop_rest
    end
    
    -- Add stage rest event at the very end
    table.insert(events, {
        type = "stage_end",
        time = last_loop_end + stage_rest,  -- Add stage rest before next stage
        loop = stage.num_loops
    })
    
    -- Sort and process events
    table.sort(events, function(a, b) return a.time < b.time end)
    
    -- Log the scheduled events table
    Log.log("CONDUCTOR", "SCHEDULE", Log.format.conductor_table(events))
    
    -- Process events
    local last_sync_time = nil
    for _, event in ipairs(events) do
      if not lane.is_playing then return end
      
      -- Only sync if this is a new time
      if event.time ~= last_sync_time then
        Log.log("CONDUCTOR", "TIMING", 
            string.format("%s Syncing to beat %s | Event: %s", 
                Log.ICONS.CLOCK, Log.format.beat(event.time), event.type))
        clock.sync(event.time)
        last_sync_time = event.time
      end
      
      Log.log("CONDUCTOR", "TIMING", 
          string.format("%s Executing at beat %s | Event: %s", 
              Log.ICONS.CLOCK, Log.format.beat(clock.get_beats()), event.type))
      
      if event.type == "note_on" then
        self:play_note_on(lane, event.note)
      elseif event.type == "note_off" then
        self:play_note_off(lane, event.note)
      elseif event.type == "loop_start" then
        Log.log("CONDUCTOR", "BOUNDARY", 
            string.format("%s Loop %d/%d ▸ Beat %s | Lane %d", 
                Log.ICONS.PLAY, event.loop, stage.num_loops, 
                Log.format.beat(event.time), lane.lane_num))
      end
    end
    
    -- After all events are processed, handle stage transition
    if lane.is_playing then
        -- Try to advance to next stage
        local next_stage = lane:advance_stage()
        
        if next_stage then
            Log.log("CONDUCTOR", "BOUNDARY", 
                string.format("%s Advancing to stage %d | Lane %d", 
                    Log.ICONS.STAGE, next_stage, lane.lane_num))
            
            -- Schedule the next stage
            self:schedule_stage(lane, {
                num_loops = lane:get_param("loop_count", next_stage),
                transform = nil,
                params = {}
            })
        else
            -- No active stages found - stop playback
            Log.log("CONDUCTOR", "BOUNDARY", 
                string.format("%s No active stages - stopping | Lane %d", 
                    Log.ICONS.STAGE, lane.lane_num))
            self:stop_lane(lane.lane_num)
        end
    end
  end)
end

--------------------------------------------------
-- Playback Control
--------------------------------------------------

-- Start playback for a lane
function Conductor:play_lane(lane_num)
  local lane = self.lanes[lane_num]
  lane.is_playing = true
  
  if not lane.motif then 
    Log.log("CONDUCTOR", "STATUS", 
      string.format("%s No motif to play | Lane %d", Log.ICONS.STOP, lane_num))
    return 
  end
  
  Log.log("CONDUCTOR", "STATUS", 
    string.format("%s Starting | Lane %d", Log.ICONS.PLAY, lane_num))
  
  local stage = {
    num_loops = lane:get_param("loop_count", lane.current_stage),
    transform = nil,
    params = {}
  }
  
  self:schedule_stage(lane, stage)
end

-- Stop playback for a lane
function Conductor:stop_lane(lane_num)
  local lane = self.lanes[lane_num]
  if not lane.is_playing then return end
  
  Log.log("CONDUCTOR", "STATUS", 
    string.format("%s Stopping | Lane %d", Log.ICONS.STOP, lane_num))
  
  self:stop_all_notes(lane)
  lane.is_playing = false
end

function Conductor:stop_all()
  Log.log("CONDUCTOR", "STATUS", string.format("%s Stopping all lanes", Log.ICONS.STOP))
  for i = 1,4 do
    self:stop_lane(i)
  end
end

--------------------------------------------------
-- Motif Management
--------------------------------------------------

-- Create a new motif from recorded data and store it in a lane
function Conductor:create_motif(lane_num, recorded_data)
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
function Conductor:add_transform(lane_num, transform_fn, params)
  local lane = self.lanes[lane_num]
  if not lane then return end
  
  Log.log("CONDUCTOR", "TRANSFORM", 
    string.format("%s Transform added: %s | Lane %d", 
      Log.ICONS.TRANSFORM, transform_fn.name or "unnamed", lane_num))
  
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
  Log.log("CONDUCTOR", "TRANSFORM", 
    string.format("%s Syncing transform %s across lanes [%s]", 
      Log.ICONS.TRANSFORM, transform_fn.name or "unnamed", table.concat(lane_nums, ",")))
  
  for _, lane_num in ipairs(lane_nums) do
    self:add_transform(lane_num, transform_fn, params)
  end
end

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

-- Update lane state and notify UI
function Conductor:update_lane_state(lane_num, updates)
  local lane = self.lanes[lane_num]
  if not lane then return end
  
  -- Update state
  for k, v in pairs(updates) do
    lane[k] = v
  end
  
  -- Notify UI if it exists
  if _seeker and _seeker.ui_manager then
    _seeker.ui_manager:redraw_all()
  end
end

return Conductor
