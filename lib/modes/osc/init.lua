-- OSC mode initialization
-- Provides unified initialization for all osc components

local Osc = {}

-- Include all osc modules
local modules = {
    config = include("lib/modes/osc/osc_config"),
    float = include("lib/modes/osc/osc_float"),
    lfo = include("lib/modes/osc/osc_lfo"),
    trigger = include("lib/modes/osc/osc_trigger"),
}

-- Map module names to section IDs
local SECTION_IDS = {
    config = "OSC_CONFIG",
    float = "OSC_FLOAT",
    lfo = "OSC_LFO",
    trigger = "OSC_TRIGGER",
}

-- Ordered init: config must come first so send_message is available
local INIT_ORDER = {"config", "float", "lfo", "trigger"}

function Osc.init()
    local instance = {
        sections = {},
        grids = {}
    }

    for _, name in ipairs(INIT_ORDER) do
        local module = modules[name]
        instance[name] = module.init()

        -- Expose send_message immediately after config init
        if name == "config" then
            instance.send_message = instance.config.send_message
            instance.get_dest_ip = instance.config.get_dest_ip
            instance.sync = instance.config.sync
            -- Assign to _seeker so other modules can use it during init
            _seeker.osc = instance
        end

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

return Osc
