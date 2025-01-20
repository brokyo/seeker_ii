-- timing_tests.lua
-- Comprehensive timing tests for the conductor system

local Motif = include('lib/motif')
local Conductor = include('lib/conductor')

local function format_beat_number(beat_num)
  return string.format("%.3f", beat_num)
end

local function log_timing_error(expected_time, actual_time, event_type, lane_num)
  local delta = math.abs(actual_time - expected_time)
  if delta > 0.001 then  -- Only log errors above 1ms
    print(string.format("⚠ Timing Error: %s | Lane %d | Expected: %s | Actual: %s | Delta: %.3fms",
      event_type, lane_num, format_beat_number(expected_time),
      format_beat_number(actual_time), delta * 1000))
    return true
  end
  return false
end

local function run_timing_tests()
  if not _seeker or not _seeker.conductor then
    print("Error: Tests must be run after system initialization")
    return
  end

  -- Start a coroutine for the test execution
  clock.run(function()
    print("\n=== Running Timing Tests ===\n")
    
    -- Test 1: Basic Sync - Quarter notes vs Eighth notes
    local test1 = {
      name = "Basic Sync - Quarter notes vs Eighth notes",
      lane1 = {
        notes = {
          {time = 0, duration = 1, pitch = 60, velocity = 100},    -- Quarter notes
          {time = 1, duration = 1, pitch = 62, velocity = 100},
          {time = 2, duration = 1, pitch = 64, velocity = 100},
          {time = 3, duration = 1, pitch = 65, velocity = 100}
        },
        expected_duration = 4  -- One full bar
      },
      lane2 = {
        notes = {
          {time = 0.0, duration = 0.5, pitch = 48, velocity = 100},  -- Eighth notes
          {time = 0.5, duration = 0.5, pitch = 50, velocity = 100},
          {time = 1.0, duration = 0.5, pitch = 52, velocity = 100},
          {time = 1.5, duration = 0.5, pitch = 53, velocity = 100},
          {time = 2.0, duration = 0.5, pitch = 55, velocity = 100},
          {time = 2.5, duration = 0.5, pitch = 57, velocity = 100},
          {time = 3.0, duration = 0.5, pitch = 59, velocity = 100},
          {time = 3.5, duration = 0.5, pitch = 60, velocity = 100}
        },
        expected_duration = 4  -- One full bar
      }
    }

    -- Test 2: Rest Timing - Different rest durations
    local test2 = {
      name = "Rest Timing - Different rest durations",
      lane1 = {
        notes = {
          {time = 0, duration = 1, pitch = 60, velocity = 100},
          {time = 2, duration = 1, pitch = 64, velocity = 100}      -- One beat rest between notes
        },
        expected_duration = 3  -- Three beats total
      },
      lane2 = {
        notes = {
          {time = 0, duration = 0.5, pitch = 48, velocity = 100},
          {time = 1.5, duration = 0.5, pitch = 52, velocity = 100}, -- One beat rest
          {time = 3, duration = 0.5, pitch = 55, velocity = 100}    -- 1.5 beat rest
        },
        expected_duration = 3.5  -- 3.5 beats total
      }
    }

    -- Test 3: Stress Test - Very fast notes
    local test3 = {
      name = "Stress Test - Rapid notes",
      lane1 = {
        notes = {
          {time = 0.0, duration = 0.125, pitch = 60, velocity = 100},   -- 32nd notes
          {time = 0.125, duration = 0.125, pitch = 62, velocity = 100},
          {time = 0.25, duration = 0.125, pitch = 64, velocity = 100},
          {time = 0.375, duration = 0.125, pitch = 65, velocity = 100},
          {time = 0.5, duration = 0.125, pitch = 67, velocity = 100},
          {time = 0.625, duration = 0.125, pitch = 69, velocity = 100},
          {time = 0.75, duration = 0.125, pitch = 71, velocity = 100},
          {time = 0.875, duration = 0.125, pitch = 72, velocity = 100}
        },
        expected_duration = 1  -- One beat of 32nd notes
      },
      lane2 = {
        notes = {
          {time = 0.0, duration = 0.5, pitch = 48, velocity = 100},     -- Overlapping notes
          {time = 0.25, duration = 0.5, pitch = 52, velocity = 100},
          {time = 0.5, duration = 0.5, pitch = 55, velocity = 100}
        },
        expected_duration = 1  -- One beat of overlapping notes
      }
    }

    -- Test 4: Complex Polyphony Test
    local test4 = {
      name = "Complex Polyphony - Multiple overlapping notes",
      lane1 = {
        notes = {
          -- Long note that spans the entire pattern
          {time = 0.0, duration = 4.0, pitch = 48, velocity = 100},
          -- Series of overlapping shorter notes
          {time = 0.5, duration = 1.0, pitch = 52, velocity = 100},
          {time = 1.0, duration = 1.5, pitch = 55, velocity = 100},
          {time = 1.5, duration = 0.5, pitch = 57, velocity = 100},
          -- Cluster of simultaneous notes
          {time = 2.5, duration = 0.25, pitch = 60, velocity = 100},
          {time = 2.5, duration = 0.5, pitch = 64, velocity = 100},
          {time = 2.5, duration = 0.75, pitch = 67, velocity = 100},
          -- Notes that start before others end
          {time = 3.0, duration = 0.5, pitch = 72, velocity = 100},
          {time = 3.25, duration = 0.75, pitch = 69, velocity = 100}
        },
        expected_duration = 4.0  -- One full bar
      },
      lane2 = {
        notes = {
          -- Alternating pattern of long and short notes
          {time = 0.0, duration = 2.0, pitch = 36, velocity = 100},
          {time = 0.5, duration = 0.25, pitch = 40, velocity = 100},
          {time = 1.0, duration = 1.5, pitch = 43, velocity = 100},
          {time = 1.5, duration = 0.25, pitch = 45, velocity = 100},
          {time = 2.0, duration = 2.0, pitch = 38, velocity = 100},
          {time = 2.5, duration = 0.25, pitch = 41, velocity = 100},
          {time = 3.0, duration = 1.0, pitch = 46, velocity = 100},
          {time = 3.5, duration = 0.25, pitch = 48, velocity = 100}
        },
        expected_duration = 4.0  -- One full bar
      }
    }

    local tests = {test1, test2, test3, test4}
    local total_errors = 0
    local total_events = 0

    for _, test in ipairs(tests) do
      print(string.format("\n▶ Running Test: %s", test.name))
      print("----------------------------------------")

      -- Create motifs for each lane
      local motif1 = Motif.new()
      local motif2 = Motif.new()
      
      motif1:store_notes(test.lane1.notes)
      motif2:store_notes(test.lane2.notes)
      
      -- Verify motif durations
      assert(motif1.total_duration == test.lane1.expected_duration,
        string.format("Lane 1 duration mismatch: expected %.2f, got %.2f",
        test.lane1.expected_duration, motif1.total_duration))
      
      assert(motif2.total_duration == test.lane2.expected_duration,
        string.format("Lane 2 duration mismatch: expected %.2f, got %.2f",
        test.lane2.expected_duration, motif2.total_duration))

      -- Set up test lanes
      _seeker.conductor.lanes[1].motif = motif1
      _seeker.conductor.lanes[2].motif = motif2
      
      -- Run test for 2 complete cycles
      local start_time = clock.get_beats()
      local test_duration = math.max(test.lane1.expected_duration, test.lane2.expected_duration) * 2
      
      -- Create and schedule stages
      for lane_num = 1,2 do
        local stage = {
          num_loops = 2,  -- Two complete cycles
          transform = nil,
          params = {}
        }
        _seeker.conductor:schedule_stage(_seeker.conductor.lanes[lane_num], stage)
      end
      
      -- Sleep until test completes
      clock.sleep(test_duration + 0.1)  -- Small buffer for cleanup
      
      print("Test complete - see above for any timing errors")
      print("----------------------------------------\n")
    end
  end)
end

return {
  run_timing_tests = run_timing_tests
} 