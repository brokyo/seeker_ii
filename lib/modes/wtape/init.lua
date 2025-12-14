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
    reverse = include("lib/modes/wtape/wtape_reverse"),
    loop_active = include("lib/modes/wtape/wtape_loop_active"),
    frippertronics = include("lib/modes/wtape/wtape_frippertronics"),
    decay = include("lib/modes/wtape/wtape_decay"),
}

-- Map module names to section IDs
local SECTION_IDS = {
    config = "WTAPE",
    playback = "WTAPE_PLAYBACK",
    record = "WTAPE_RECORD",
    ff = "WTAPE_FF",
    rewind = "WTAPE_REWIND",
    reverse = "WTAPE_REVERSE",
    loop_active = "WTAPE_LOOP_ACTIVE",
    frippertronics = "WTAPE_FRIPPERTRONICS",
    decay = "WTAPE_DECAY",
}

-- Ordered init: config must come first so direction state is available
local INIT_ORDER = {"config", "playback", "record", "ff", "rewind", "reverse", "loop_active", "frippertronics", "decay"}

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
