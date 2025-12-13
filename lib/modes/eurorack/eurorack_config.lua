-- eurorack_config.lua
-- Global Eurorack configuration component
-- Contains sync button and type/number selection

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local Descriptions = include("lib/ui/component_descriptions")

local EurorackConfig = {}
EurorackConfig.__index = EurorackConfig

local function create_params()
    params:add_group("eurorack_config", "EURORACK CONFIG", 7)

    -- Selection params used by all eurorack output components
    params:add_option("eurorack_selected_type", "Type", {"Crow", "TXO TR", "TXO CV"}, 1)
    params:set_action("eurorack_selected_type", function(value)
        -- Rebuild params for whichever component is currently active
        local current_section = _seeker.ui_state.get_current_section()
        if current_section == "CROW_OUTPUT" and _seeker.eurorack.crow_output then
            _seeker.eurorack.crow_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        elseif current_section == "TXO_TR_OUTPUT" and _seeker.eurorack.txo_tr_output then
            _seeker.eurorack.txo_tr_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        elseif current_section == "TXO_CV_OUTPUT" and _seeker.eurorack.txo_cv_output then
            _seeker.eurorack.txo_cv_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    params:add_option("eurorack_selected_number", "Number", {"1", "2", "3", "4"}, 1)
    params:set_action("eurorack_selected_number", function(value)
        -- Rebuild params for whichever component is currently active
        local current_section = _seeker.ui_state.get_current_section()
        if current_section == "CROW_OUTPUT" and _seeker.eurorack.crow_output then
            _seeker.eurorack.crow_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        elseif current_section == "TXO_TR_OUTPUT" and _seeker.eurorack.txo_tr_output then
            _seeker.eurorack.txo_tr_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        elseif current_section == "TXO_CV_OUTPUT" and _seeker.eurorack.txo_cv_output then
            _seeker.eurorack.txo_cv_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- Crow output category params (Gate vs CV)
    for i = 1, 4 do
        params:add_option("crow_" .. i .. "_category", "Category", {"Gate", "CV"}, 1)
        params:set_action("crow_" .. i .. "_category", function(value)
            -- Reset mode and pattern state when category changes
            if _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)
    end

    -- Add sync trigger param
    params:add_binary("sync_all_eurorack_clocks", "Synchronize All", "trigger", 0)
    params:set_action("sync_all_eurorack_clocks", function(value)
        if value == 1 then
            EurorackConfig.sync_all_clocks()
            _seeker.ui_state.trigger_activated("sync_all_eurorack_clocks")
        end
    end)
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "EURORACK_CONFIG",
        name = "Eurorack Config",
        description = Descriptions.EURORACK_CONFIG,
        params = {
            { separator = true, title = "Actions" },
            { id = "sync_all_eurorack_clocks", is_action = true }
        }
    })

    return norns_ui
end

local function create_grid_ui()
    -- No grid button - mode switching handled by grid_mode_registry at (15, 2)
    return nil
end

-- Sync all eurorack outputs and lanes
function EurorackConfig.sync_all_clocks()
    if _seeker and _seeker.conductor then
        _seeker.conductor.sync_all()
    end
end

function EurorackConfig.init()
    -- Create params first (before components that use them)
    create_params()

    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync_all_clocks = EurorackConfig.sync_all_clocks
    }

    return component
end

return EurorackConfig
