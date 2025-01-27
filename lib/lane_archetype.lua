-- lane_archetype.lua
--
-- Reference patterns and configurations for testing core functionality.
-- Provides "golden record" data to verify:
--   1. Motif event storage and playback (via motif_ii)
--   2. Lane configuration and scheduling (via lane)
--   3. Stage transitions and transforms
--
-- Usage: Create debug lane with known good data
--   _seeker.debug_lane = lane_archetype.create_debug_lane()
--------------------------------------------------

local Motif = include('lib/motif_ii')
local Lane = include('lib/lane')

local lane_archetype = {}

-- Collection of preset motifs (our "golden record" patterns)
lane_archetype.motifs = {
    -- Basic triad (C major)
    triad = {
        events = {
            {time = 0.0, type = "note_on",  note = 60, velocity = 100},
            {time = 0.2, type = "note_off", note = 60},
            {time = 0.25, type = "note_on", note = 64, velocity = 100},
            {time = 0.45, type = "note_off", note = 64},
            {time = 0.5, type = "note_on",  note = 67, velocity = 100},
            {time = 0.7, type = "note_off", note = 67}
        },
        duration = 1.0
    },

    -- Arpeggiated chord (C major up and down)
    arpeggio = {
        events = {
            -- Up
            {time = 0.0,  type = "note_on",  note = 60, velocity = 100},
            {time = 0.1,  type = "note_off", note = 60},
            {time = 0.25, type = "note_on",  note = 64, velocity = 100},
            {time = 0.35, type = "note_off", note = 64},
            {time = 0.5,  type = "note_on",  note = 67, velocity = 100},
            {time = 0.6,  type = "note_off", note = 67},
            -- Down
            {time = 0.75, type = "note_on",  note = 67, velocity = 90},
            {time = 0.85, type = "note_off", note = 67},
            {time = 1.0,  type = "note_on",  note = 64, velocity = 90},
            {time = 1.1,  type = "note_off", note = 64},
            {time = 1.25, type = "note_on",  note = 60, velocity = 90},
            {time = 1.35, type = "note_off", note = 60}
        },
        duration = 1.5
    },

    -- Overlapping notes to test polyphony
    polyphonic = {
        events = {
            -- First chord
            {time = 0.0,  type = "note_on",  note = 60, velocity = 100},
            {time = 0.0,  type = "note_on",  note = 64, velocity = 100},
            {time = 0.0,  type = "note_on",  note = 67, velocity = 100},
            {time = 0.45, type = "note_off", note = 60},
            {time = 0.45, type = "note_off", note = 64},
            {time = 0.45, type = "note_off", note = 67},
            -- Second chord
            {time = 0.5,  type = "note_on",  note = 65, velocity = 100},
            {time = 0.5,  type = "note_on",  note = 69, velocity = 100},
            {time = 0.5,  type = "note_on",  note = 72, velocity = 100},
            {time = 0.95, type = "note_off", note = 65},
            {time = 0.95, type = "note_off", note = 69},
            {time = 0.95, type = "note_off", note = 72}
        },
        duration = 1.0
    },

    -- Single note to test basic timing
    single = {
        events = {
            {time = 0.0, type = "note_on",  note = 60, velocity = 100},
            {time = 0.5, type = "note_off", note = 60}
        },
        duration = 0.5
    }
}

-- Collection of preset stage configurations
lane_archetype.stages = {
    -- Basic playback
    basic = {
        {
            id = 1,
            mute = false,
            reset_motif = false,
            loops = 1,
            transform_name = "noop",
            transform_config = {}
        }
    },

    -- Test harmonization
    harmonize = {
        {
            id = 1,
            mute = false,
            reset_motif = false,
            loops = 2,
            transform_name = "harmonize",
            transform_config = { interval = 12, probability = 0.7 }
        }
    },

    -- Test reverse
    reverse = {
        {
            id = 1,
            mute = false,
            reset_motif = false,
            loops = 1,
            transform_name = "reverse",
            transform_config = {}
        }
    },

    -- Test multiple transforms
    multi = {
        {
            id = 1,
            mute = false,
            reset_motif = false,
            loops = 2,
            transform_name = "harmonize",
            transform_config = { interval = 12, probability = 0.7 }
        },
        {
            id = 2,
            mute = false,
            reset_motif = true,
            loops = 2,
            transform_name = "reverse",
            transform_config = {}
        },
        {
            id = 3,
            mute = false,
            reset_motif = false,
            loops = 2,
            transform_name = "harmonize",
            transform_config = { interval = 4, probability = 0.25}
        },
        {
            id = 4,
            mute = true,
            reset_motif = true,
            loops = 2,
            transform_name = "noop",
            transform_config = {}
        }
    }
}

-- Current debug configuration (can be modified at runtime)
lane_archetype.debug_config = {
    motif = "arpeggio",
    stage = "multi",
    volume = 0.8,
    speed = 2.0
}

-- Create a debug lane using internal configuration
function lane_archetype.create_debug_lane()
    local lane = Lane.new({ id = 99 })
    lane:set_motif(lane_archetype.motifs[lane_archetype.debug_config.motif])
    lane.stages = lane_archetype.stages[lane_archetype.debug_config.stage]
    lane.volume = lane_archetype.debug_config.volume
    lane.speed = lane_archetype.debug_config.speed
    print(string.format('⌸ LANE_%s | Test Form 型', lane.id))
    return lane
end

return lane_archetype
