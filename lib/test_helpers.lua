-- test_helpers.lua
-- Utility functions for testing via REPL

local TestHelpers = {}
local Log = include('lib/log')
local MotifRecorder = include('lib/motif_recorder')

--- Record a test sequence into a lane
-- @param lane_num The lane number to record into
-- @param notes Array of note events in format:
--   { {pitch=60, start=0, duration=1}, {pitch=64, start=1, duration=0.5}, ... }
-- @param opts Optional settings:
--   * quantize: true/false - whether to use quantized mode (default true)
--   * grid: "1/16", "1/8", etc - quantization grid (default "1/16")
--   * loops: number of times to loop (default 2)
function TestHelpers.record_test_sequence(lane_num, notes, opts)
  opts = opts or {}
  opts.quantize = opts.quantize ~= false  -- default true
  opts.grid = opts.grid or "1/16"
  opts.loops = opts.loops or 2
  
  -- Check for conductor
  if not _seeker or not _seeker.conductor then
    print("Error: _seeker.conductor not found - make sure script is initialized")
    return
  end
  
  -- Set recording mode
  params:set("lane_" .. lane_num .. "_recording_mode", opts.quantize and 2 or 1)
  
  -- Set quantize grid if needed
  if opts.quantize then
    local grid_values = {["1/64"]=1, ["1/32"]=2, ["1/16"]=3, ["1/8"]=4, ["1/4"]=5}
    local grid_value = grid_values[opts.grid]
    if grid_value then
      params:set("lane_" .. lane_num .. "_quantize_value", grid_value)
    end
  end
  
  -- Configure stage
  params:set("lane_" .. lane_num .. "_stage_1_active", 2)  -- Enable stage 1
  params:set("lane_" .. lane_num .. "_stage_1_loop_count", opts.loops)
  params:set("lane_" .. lane_num .. "_stage_1_loop_rest", 0)
  params:set("lane_" .. lane_num .. "_stage_1_stage_rest", 0)
  
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
    name = "Basic sequence (quantized 1/16)",
    notes = {
      {pitch=60, start=0, duration=0.5},    -- C4 at start
      {pitch=64, start=1, duration=0.25},   -- E4 at beat 1
      {pitch=67, start=1.5, duration=0.5},  -- G4 at beat 1.5
      {pitch=72, start=2, duration=1},      -- C5 at beat 2
    }
  },
  {
    name = "Overlapping notes",
    notes = {
      {pitch=60, start=0, duration=2},      -- C4 long note
      {pitch=64, start=0.5, duration=1},    -- E4 overlaps with C4
      {pitch=67, start=1, duration=0.5},    -- G4 overlaps with both
    }
  },
  {
    name = "Same pitch overlapping",
    notes = {
      {pitch=60, start=0, duration=1},      -- C4
      {pitch=60, start=0.5, duration=1},    -- C4 again, overlapping
      {pitch=60, start=1, duration=0.5},    -- C4 third time
    }
  },
  {
    name = "Unquantized with loop crossing",
    notes = {
      {pitch=60, start=0.1, duration=2.3},    -- Long note crossing loop
      {pitch=64, start=0.7, duration=0.4},    -- Normal note
      {pitch=67, start=1.3, duration=1.6},    -- Another crossing note
    },
    opts = {quantize=false, loops=3}
  },
  {
    name = "Long notes with multiple loop crossings",
    notes = {
      {pitch=60, start=0, duration=4},      -- C4 spanning multiple loops
      {pitch=64, start=1, duration=0.5},    -- E4 normal note
      {pitch=67, start=2, duration=3},      -- G4 spanning loop boundary
    },
    opts = {loops=3}
  },
  {
    name = "Rapid note repetition",
    notes = {
      {pitch=60, start=0, duration=0.1},    -- Quick C4
      {pitch=60, start=0.1, duration=0.1},  -- Immediate repeat
      {pitch=60, start=0.2, duration=0.1},  -- Another repeat
      {pitch=60, start=0.3, duration=1},    -- Longer final note
    },
    opts = {quantize=false}
  },
  {
    name = "Simultaneous notes (chord)",
    notes = {
      {pitch=60, start=0, duration=1},    -- C4 chord
      {pitch=64, start=0, duration=1},    -- E4 chord
      {pitch=67, start=0, duration=1},    -- G4 chord
      {pitch=72, start=1, duration=1},    -- C5 after
    }
  },
  {
    name = "Quantization edge cases",
    notes = {
      {pitch=60, start=0.99, duration=0.5},   -- Just before beat
      {pitch=64, start=1.01, duration=0.5},   -- Just after beat
      {pitch=67, start=1.49, duration=0.5},   -- Just before half beat
      {pitch=72, start=1.51, duration=0.5},   -- Just after half beat
    }
  }
}

--- Run a specific test by number
-- @param test_num The test number to run (1-8)
function TestHelpers.run_test(test_num)
  if not test_num or test_num < 1 or test_num > #TestHelpers.tests then
    print("Invalid test number. Available tests:")
    for i, test in ipairs(TestHelpers.tests) do
      print(string.format("%d: %s", i, test.name))
    end
    return
  end
  
  -- Stop any existing playback
  if _seeker and _seeker.conductor then 
    _seeker.conductor:stop_all() 
  end
  
  local test = TestHelpers.tests[test_num]
  print(string.format("\n=== TEST %d: %s ===", test_num, test.name))
  print("Recording sequence...")
  
  clock.run(function()
    local duration = TestHelpers.record_test_sequence(1, test.notes, test.opts)
    clock.sleep(duration + 1)
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
  -- Stop any existing playback
  if _seeker and _seeker.conductor then 
    _seeker.conductor:stop_all() 
  end
  
  clock.run(function()
    for i, test in ipairs(TestHelpers.tests) do
      print(string.format("\n=== TEST %d: %s ===", i, test.name))
      print("Recording sequence...")
      
      local duration = TestHelpers.record_test_sequence(1, test.notes, test.opts)
      clock.sleep(duration + 1)
      _seeker.conductor:stop_lane(1)
      
      print(string.format("\n=== TEST %d COMPLETE ===\n", i))
      clock.sleep(2)  -- Longer pause between tests
    end
    print("\n=== ALL TESTS COMPLETE ===")
  end)
end

return TestHelpers 