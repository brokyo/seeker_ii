-- Eurorack mode initialization
-- Provides unified initialization for all eurorack components

local Eurorack = {}

-- Include all eurorack modules
local modules = {
    config = include("lib/modes/eurorack/eurorack_config"),
    cv_monitor = include("lib/modes/eurorack/cv_monitor"),
    crow_output = include("lib/modes/eurorack/crow_output"),
    txo_tr_output = include("lib/modes/eurorack/txo_tr_output"),
    txo_cv_output = include("lib/modes/eurorack/txo_cv_output"),
}

-- Map module names to section IDs.
-- cv_monitor owns the EURORACK_CONFIG screen.
-- eurorack_config creates params and sync only (no screen).
local SECTION_IDS = {
    cv_monitor = "EURORACK_CONFIG",
    crow_output = "CROW_OUTPUT",
    txo_tr_output = "TXO_TR_OUTPUT",
    txo_cv_output = "TXO_CV_OUTPUT",
}

function Eurorack.init()
    local instance = {
        sections = {},
        grids = {}
    }

    -- Initialize each module and collect screens/grids
    for name, module in pairs(modules) do
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

    -- Expose sync method from config
    instance.sync_all_clocks = instance.config.sync_all_clocks

    -- Exposed on the eurorack instance so screen_saver.lua can dispatch via MODE_SEEKER_KEYS
    instance.draw_screensaver = modules.cv_monitor.draw_screensaver

    return instance
end

return Eurorack
