-- test_helpers.lua
-- Utility functions for testing via REPL
--
-- USAGE:
-- 1. In maiden REPL:
--    > test = include("lib/test_helpers")
-- 2. List available tests:
--    > test.list_tests()
-- 3. Run specific test:
--    > test.run_test(1)
-- 4. Run all tests:
--    > test.run_all_tests()

local TestHelpers = {}
local Log = include('lib/log')
local MotifRecorder = include('lib/motif_recorder')

--- Record a test sequence into a lane
-- @param lane_num The lane number to record into
-- @param notes Array of note events in format:
--   { {pitch=60, start=0, duration=1}, {pitch=64, start=1, duration=0.5}, ... }
-- @param opts Optional settings:
--   * grid_mode: true/false - whether to use grid mode for arpeggios (default true)
--   * grid: "1/16", "1/8", etc - grid division for arpeggio mode (default "1/16")
--   * loops: number of times to loop (default 2)
function TestHelpers.record_test_sequence(lane_num, notes, opts)
  opts = opts or {}
  opts.grid_mode = opts.grid_mode ~= false  -- default true
  opts.grid = opts.grid or "1/16"
  opts.loops = opts.loops or 2
  
  -- Check for conductor
  if not _seeker or not _seeker.conductor then
    print("Error: _seeker.conductor not found - make sure script is initialized")
    return
  end
  
  -- Set timing mode (2 = grid/arpeggio, 1 = free)
  params:set("lane_" .. lane_num .. "_timing_mode", opts.grid_mode and 2 or 1)
  params:set("lane_" .. lane_num .. "_recording_mode", opts.grid_mode and 2 or 1)
  
  -- Set grid division if in grid mode
  if opts.grid_mode then
    local grid_values = {["1/64"]=1, ["1/32"]=2, ["1/16"]=3, ["1/8"]=4, ["1/4"]=5}
    local grid_value = grid_values[opts.grid]
    if grid_value then
      params:set("lane_" .. lane_num .. "_quantize_value", grid_value)
    end
  end
  
  -- Configure stage(s)
  if opts.stage_setup then
    opts.stage_setup(lane_num)
  else
    -- Default single stage setup
    params:set("lane_" .. lane_num .. "_stage_1_active", 2)  -- Enable stage 1
    params:set("lane_" .. lane_num .. "_stage_1_loop_count", opts.loops)
    params:set("lane_" .. lane_num .. "_stage_1_loop_rest", 0)
    params:set("lane_" .. lane_num .. "_stage_1_stage_rest", 0)
  end
  
  -- Create recorder
  local recorder = MotifRecorder.new()
  recorder:start_recording(lane_num)
  local start_time = clock.get_beats()
  
  -- Find total sequence duration for proper loop timing
  local total_duration = 0
  for _, note in ipairs(notes) do
    local note_end = note.start + note.duration
    if note_end > total_duration then total_duration = note_end end
  end
  
  -- Add 1 beat padding for test sequences in free mode only
  if not opts.grid_mode then
    total_duration = total_duration + 1
    Log.log("MOTIF_REC", "TIMING", string.format("%s Adding 1 beat test padding to free sequence (%.3f → %.3f)", Log.ICONS.CLOCK, total_duration - 1, total_duration))
  end
  
  -- Schedule all notes
  for _, note in ipairs(notes) do
    -- Note ON
    clock.run(function()
      clock.sync(start_time + note.start)
      recorder:on_note_on(note.pitch, note.velocity or 100, note.pos or {x=1, y=1})
      
      -- Note OFF
      clock.sync(start_time + note.start + note.duration)
      recorder:on_note_off(note.pitch, note.pos or {x=1, y=1})
    end)
  end
  
  -- Stop recording after sequence completes
  clock.run(function()
    -- Wait for all notes to complete
    clock.sync(start_time + total_duration + 0.1) -- Small buffer after last note
    local events = recorder:stop_recording()
    
    -- Log recorded sequence details
    print(string.format("\nRecorded %d events in lane %d", #events, lane_num))
    print("Recorded sequence details:")
    for i, evt in ipairs(events) do
      print(string.format("  Note %d: pitch=%d start=%.3f duration=%.3f", 
        i, evt.pitch, evt.time, evt.duration))
    end
    
    -- Create motif and start playback
    _seeker.conductor:create_motif(lane_num, events)
    _seeker.conductor:play_lane(lane_num)
  end)
  
  -- Return expected completion time for test sequencing
  return total_duration * opts.loops + 0.5  -- Add small buffer for cleanup
end

-- Test definitions
TestHelpers.tests = {
  {
    name = "Grid mode - basic arpeggio",
    notes = {
      {pitch=60, start=0, duration=0.25},    -- C4 quarter note
      {pitch=64, start=0.25, duration=0.25}, -- E4 quarter note
      {pitch=67, start=0.5, duration=0.25},  -- G4 quarter note
      {pitch=72, start=0.75, duration=0.25}, -- C5 quarter note
    },
    opts = {
      grid_mode = true,
      grid = "1/16"
    }
  },
  {
    name = "Grid mode - varied durations",
    notes = {
      {pitch=60, start=0, duration=0.5},     -- C4 half note
      {pitch=64, start=0.5, duration=0.25},  -- E4 quarter note
      {pitch=67, start=0.75, duration=0.25}, -- G4 quarter note
    },
    opts = {
      grid_mode = true,
      grid = "1/16"
    }
  },
  {
    name = "Free mode - basic melody",
    notes = {
      {pitch=60, start=0.1, duration=0.3},   -- Slightly off-grid timing
      {pitch=64, start=0.5, duration=0.2},
      {pitch=67, start=0.8, duration=0.4},
      {pitch=72, start=1.3, duration=0.3}
    },
    opts = {
      grid_mode = false
    }
  },
  {
    name = "Free mode - expressive timing",
    notes = {
      {pitch=60, start=0, duration=0.7},     -- Longer first note
      {pitch=64, start=0.8, duration=0.2},   -- Quick second note
      {pitch=67, start=1.2, duration=0.5},   -- Medium final note
    },
    opts = {
      grid_mode = false
    }
  },
  {
    name = "Grid mode - stage transition",
    notes = {
      {pitch=60, start=0, duration=0.25},
      {pitch=64, start=0.25, duration=0.25},
      {pitch=67, start=0.5, duration=0.25},
      {pitch=72, start=0.75, duration=0.25}
    },
    opts = {
      grid_mode = true,
      grid = "1/16",
      loops = 2,
      stage_setup = function(lane_num)
        for stage = 1,2 do
          params:set("lane_" .. lane_num .. "_stage_" .. stage .. "_active", 2)
          params:set("lane_" .. lane_num .. "_stage_" .. stage .. "_loop_count", 2)
          params:set("lane_" .. lane_num .. "_stage_" .. stage .. "_loop_rest", 0)
          params:set("lane_" .. lane_num .. "_stage_" .. stage .. "_stage_rest", 0)
        end
      end
    }
  },
  {
    name = "Free mode - stage transition",
    notes = {
      {pitch=60, start=0.1, duration=0.3},
      {pitch=64, start=0.5, duration=0.2},
      {pitch=67, start=0.8, duration=0.4},
      {pitch=72, start=1.3, duration=0.3}
    },
    opts = {
      grid_mode = false,
      loops = 2,
      stage_setup = function(lane_num)
        for stage = 1,2 do
          params:set("lane_" .. lane_num .. "_stage_" .. stage .. "_active", 2)
          params:set("lane_" .. lane_num .. "_stage_" .. stage .. "_loop_count", 2)
          params:set("lane_" .. lane_num .. "_stage_" .. stage .. "_loop_rest", 0)
          params:set("lane_" .. lane_num .. "_stage_" .. stage .. "_stage_rest", 0)
        end
      end
    }
  }
}

--- Run a specific test by number
-- @param test_num The test number to run
function TestHelpers.run_test(test_num)
  if not test_num or test_num < 1 or test_num > #TestHelpers.tests then
    print("Invalid test number. Available tests:")
    TestHelpers.list_tests()
    return
  end
  
  local test = TestHelpers.tests[test_num]
  print(string.format("\n=== TEST %d: %s ===", test_num, test.name))
  
  -- Run everything in a coroutine
  clock.run(function()
    -- Stop any existing playback and cleanup
    if _seeker and _seeker.conductor then 
      _seeker.conductor:stop_all() 
      clock.sleep(0.1)  -- Give time for cleanup
    end
    
    print("Recording sequence...")
    
    -- Ensure clean state
    params:set("clock_tempo", 120)  -- Reset to standard tempo
    
    local duration = TestHelpers.record_test_sequence(1, test.notes, test.opts)
    -- Add buffer for stage transitions
    local buffer = test.opts and test.opts.stage_setup and 2 or 1
    clock.sleep(duration + buffer)
    _seeker.conductor:stop_lane(1)
    print(string.format("\n=== TEST %d COMPLETE ===\n", test_num))
  end)
end

--- List available tests
function TestHelpers.list_tests()
  print("\nAvailable tests:")
  for i, test in ipairs(TestHelpers.tests) do
    print(string.format("%d: %s", i, test.name))
  end
end

--- Run all tests with clear boundaries
function TestHelpers.run_all_tests()
  -- Run everything in a coroutine
  clock.run(function()
    -- Stop any existing playback and cleanup
    if _seeker and _seeker.conductor then 
      _seeker.conductor:stop_all() 
      clock.sleep(0.1)  -- Give time for cleanup
    end
    
    -- Ensure clean state
    params:set("clock_tempo", 120)  -- Reset to standard tempo
    
    for i, test in ipairs(TestHelpers.tests) do
      print(string.format("\n=== TEST %d: %s ===", i, test.name))
      print("Recording sequence...")
      
      local duration = TestHelpers.record_test_sequence(1, test.notes, test.opts)
      -- Add buffer for stage transitions
      local buffer = test.opts and test.opts.stage_setup and 2 or 1
      clock.sleep(duration + buffer)
      _seeker.conductor:stop_lane(1)
      
      print(string.format("\n=== TEST %d COMPLETE ===\n", i))
      clock.sleep(2)  -- Longer pause between tests
    end
    print("\n=== ALL TESTS COMPLETE ===")
  end)
end

return TestHelpers 