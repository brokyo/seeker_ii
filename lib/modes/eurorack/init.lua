-- Eurorack mode initialization
-- Provides unified initialization for all eurorack components

local Eurorack = {}

-- Include all eurorack modules
local modules = {
    config = include("lib/modes/eurorack/eurorack_config"),
    crow_output = include("lib/modes/eurorack/crow_output"),
    txo_tr_output = include("lib/modes/eurorack/txo_tr_output"),
    txo_cv_output = include("lib/modes/eurorack/txo_cv_output"),
}

-- Map module names to section IDs
local SECTION_IDS = {
    config = "EURORACK_CONFIG",
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

    return instance
end

return Eurorack
