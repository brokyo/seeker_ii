-- WTape mode initialization
-- Provides unified initialization for all wtape components

local WTape = {}

-- Include all wtape modules
local modules = {
    config = include("lib/modes/wtape/wtape_config"),
    playback = include("lib/modes/wtape/wtape_playback"),
    record = include("lib/modes/wtape/wtape_record"),
    ff = include("lib/modes/wtape/wtape_ff"),
    rewind = include("lib/modes/wtape/wtape_rewind"),
    loop_start = include("lib/modes/wtape/wtape_loop_start"),
    loop_end = include("lib/modes/wtape/wtape_loop_end"),
    reverse = include("lib/modes/wtape/wtape_reverse"),
    loop_active = include("lib/modes/wtape/wtape_loop_active"),
}

-- Map module names to section IDs
local SECTION_IDS = {
    config = "WTAPE",
    playback = "WTAPE_PLAYBACK",
    record = "WTAPE_RECORD",
    ff = "WTAPE_FF",
    rewind = "WTAPE_REWIND",
    loop_start = "WTAPE_LOOP_START",
    loop_end = "WTAPE_LOOP_END",
    reverse = "WTAPE_REVERSE",
    loop_active = "WTAPE_LOOP_ACTIVE",
}

-- Ordered init: config must come first so direction state is available
local INIT_ORDER = {"config", "playback", "record", "ff", "rewind", "loop_start", "loop_end", "reverse", "loop_active"}

function WTape.init()
    local instance = {
        sections = {},
        grids = {}
    }

    for _, name in ipairs(INIT_ORDER) do
        local module = modules[name]

        -- Assign to _seeker before config init so it can set direction
        if name == "config" then
            _seeker.wtape = instance
        end

        instance[name] = module.init()

        -- Register screen section if available
        if instance[name].screen and SECTION_IDS[name] then
            instance.sections[SECTION_IDS[name]] = instance[name].screen
        end

        -- Register grid if available
        if instance[name].grid then
            instance.grids[name] = instance[name].grid
        end
    end

    return instance
end

return WTape
