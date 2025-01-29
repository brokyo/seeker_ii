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
local forms = include('lib/forms')

local lane_archetype = {}

-- Current debug configuration (can be modified at runtime)
lane_archetype.debug_config = {
    motif = "progression",  -- Use progression from forms.motifs
    arrangement = "octaves",        -- Use layers from forms.arrangements
    volume = 0.8,
    speed = 1.0
}

-- Create a debug lane using internal configuration
function lane_archetype.create_debug_lane()
    local lane = Lane.new({ id = 99 })
    lane:set_motif(forms.motifs[lane_archetype.debug_config.motif])
    lane:apply_arrangement(lane_archetype.debug_config.arrangement)
    lane.volume = lane_archetype.debug_config.volume
    lane.speed = lane_archetype.debug_config.speed
    print(string.format('⌸ LANE_%s TEST FORM | M: %s A: %s 型', 
        lane.id, 
        lane_archetype.debug_config.motif,
        lane_archetype.debug_config.arrangement))
    return lane
end

return lane_archetype
