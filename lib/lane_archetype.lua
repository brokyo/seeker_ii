-- lane_archetype.lua
-- Defines the fundamental forms (型 kata) for lanes and their components
local Motif = include('lib/motif_ii')

local lane_archetype = {
    id = 1,               -- Int used to reference lane
    playing = false,      -- bool that sets playback
    voice = '',          -- skeys instrument
    volume = 1.0,        -- 0 > 1 Modifies velocity
    midi = {},           -- midi out table
    speed = 1.0,         -- speed control -4x > 4x. Changes event timing
    stages = {},         -- stage sequence configuration
    motif = {},          -- event sequence for MIDI and UI
    motif_duration = 1.0 -- Duration of one complete cycle
}

-- Stage - defines the form of a transformation stage
local stage_archetype = {
    id = 1,                -- stage id
    mute = false,          -- bool. determines if notes play
    reset_motif = false,   -- bool. determines if motif should reset to original state
    loops = 1,             -- number of times to play motif before advancing
    transform_name = "",   -- name of transform from transformations.lua
    transform_config = {}  -- parameters for the transform function
}

-- motif, the table of notes to play
local motif_archetype = {
    {time = 0.0, type = 'note_on', note = 60, velocity = 127},
    {time = 0.5, type = 'note_off', note = 60},
    {time = 1.0, type = 'note_on', note = 64, velocity = 127},
    {time = 1.5, type = 'note_off', note = 64},
    {time = 2.0, type = 'motif_end'} -- Marks the loop point
}

-- Create an empty lane ready for recording
function lane_archetype.create_empty(id)
    local empty_motif = Motif.from_example("empty")
    print(string.format('⌸ Lane %d, empty form 型 ', id))
    return {
        id = id,
        playing = false,
        voice = 'piano',  -- Default instrument
        volume = 1.0,
        midi = {          -- Default MIDI settings
            channel = 1,
            device = nil  -- No MIDI device by default
        },
        speed = 1.0,
        motif_duration = empty_motif.duration,
        stages = {        -- Single empty stage
            {
                id = 1,
                mute = false,
                reset_motif = false,
                transform_name = "noop",
                transform_config = {}
            }
        },
        motif = empty_motif.events
    }
end

-- Create an example lane demonstrating core concepts
function lane_archetype.create_example(id)
    -- Get a test motif
    local test_motif = Motif.from_example("polyphonic")
    print(string.format('⌸ lane %d, test form 型', id))
    
    return {
        id = id,
        playing = true,
        voice = 'piano',
        volume = 0.8,
        midi = {
            channel = 1,
            device = 1
        },
        speed = 4,
        motif_duration = test_motif.duration,
        stages = {
            {
                id = 1,
                mute = false,
                reset_motif = false,
                loops = 2,              -- Play original twice
                transform_name = "noop",
                transform_config = {}
            },
            {
                id = 2,
                mute = false,
                reset_motif = false,
                loops = 2,              -- Harmonize and repeat 4 times
                transform_name = "harmonize",
                transform_config = { probability = 0.1, interval = 12 }
            },
            {
                id = 3,
                mute = false,
                reset_motif = true,
                loops = 1,              -- Play reversed once
                transform_name = "reverse",
                transform_config = {}
            }
        },
        motif = test_motif.events
    }
end

--[[ Event Flow Through Stages with Different Sources
Original Events → Stage 1 (2x No-op) → Stage 2 (4x Harmonize) → Stage 3 (1x Reset + Reverse)

Time  | Event Type | Original          | Stage 1 (2 loops) | Stage 2 (4 loops)    | Stage 3 (1 loop)  |
------+------------+------------------+------------------+--------------------+------------------|
0.0   | note_on    | n:60, v:100      | n:60, v:100      | n:60,64, v:100,70   | n:72, v:110      |
0.2   | note_off   | n:60             | n:60             | n:60,64             | n:72             |
0.25  | note_on    | n:64, v:90       | n:64, v:90       | n:64,68, v:90,63    | n:67, v:80       |
0.45  | note_off   | n:64             | n:64             | n:64,68             | n:67             |
0.5   | note_on    | n:67, v:80       | n:67, v:80       | n:67,71, v:80,56    | n:64, v:90       |
0.7   | note_off   | n:67             | n:67             | n:67,71             | n:64             |
0.75  | note_on    | n:72, v:110      | n:72, v:110      | n:72,76, v:110,77   | n:60, v:100      |
0.95  | note_off   | n:72             | n:72             | n:72,76             | n:60             |
1.0   | loop_end   | -                | Loop 1 ends      | Loop 1 ends         | Stage ends       |
1.0   | note_on    | -                | n:60, v:100      | n:60,64, v:100,70   | -                |
...   | ...        | -                | (repeats)        | (repeats 3x more)   | -                |
2.0   | stage_end  | -                | Stage ends       | -                   | -                |

Stage Transition Rules:
- Stage 1: No-op passes through the original motif unchanged, plays twice
- Stage 2: Transforms once with harmonize, then repeats that result 4 times
- Stage 3: Has reset_motif=true, transforms once with reverse, plays once
- Each stage that resets starts fresh from original_motif
- Stages without reset build upon the previous stage's working_motif
- Transform is applied once at stage start (or on reset), then loops play that result

Technical Details:
- Velocity is capped at 127 in all cases
- note_off events maintain the transformed note value but don't carry velocity
- Stages wrap around. Playing is continual
- Loop timing accounts for motif duration and speed
]]

return lane_archetype
