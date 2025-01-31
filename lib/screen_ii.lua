local transforms = include("lib/transforms")

local ScreenUI = {}

ScreenUI.state = {
    current_section = "Musical",
    needs_redraw = true,
    fps = 30,
    selected_index = 0,     -- 0 is header, 1+ are params
    scroll_offset = 0,      -- Track scrolling position
}

local sections = {
    "Musical",
    "Recording",
    "Lanes",
    "Stages",
}

function ScreenUI.init()    
    clock.run(screen_redraw_clock)
end 

function screen_redraw_clock()
    while true do
        clock.sync(1/ScreenUI.state.fps)
        if ScreenUI.state.needs_redraw then
            ScreenUI.redraw()
            ScreenUI.state.needs_redraw = false
        end
    end
end

function ScreenUI.key(n, z)
    ScreenUI.set_needs_redraw()
end

function ScreenUI.enc(n, d)
    if n == 2 then
        ScreenUI.change_selection(d)
    elseif n == 3 then
        ScreenUI.modify_selected(d)
    end
    ScreenUI.set_needs_redraw()
end

function ScreenUI.set_needs_redraw()
    ScreenUI.state.needs_redraw = true
end 

function draw_header(y_pos, selected)
    if selected then
        screen.level(15)
        screen.move(2, y_pos)
        screen.text("►")
    end
    
    screen.level(selected and 15 or 4)
    screen.move(64, y_pos)
    screen.text_center(ScreenUI.state.current_section)
end

function draw_param(param, y_pos, selected)
    screen.level(selected and 15 or 4)
    if selected then
        screen.move(2, y_pos)
        screen.text("►")
    end
    screen.move(10, y_pos)
    screen.text(param.name)
    screen.move(80, y_pos)
        screen.text(param.value)
end

function draw_params_list(start_y)
    local current_section = ScreenUI.state.current_section
    local lane_idx = _seeker.ui_state.focused_lane
    local stage_idx = _seeker.ui_state.focused_stage

    local section_params = {}
    
    if current_section == "Musical" then
        section_params = {
            {name = "Root Note", value = params:string("root_note")},
            {name = "Scale", value = params:string("scale_type")},
            {name = "Octave", value = params:string("octave")}
        }
    elseif current_section == "Recording" then
        section_params = {
            {name = "Quantize", value = params:string("quantize_division")}
        }
    elseif current_section == "Lanes" then
        -- Add lane selector as first param
        section_params = {
            {name = "Lane", value = lane_idx, is_selector = true},
            {name = "Instrument",value = params:string("lane_" .. lane_idx .. "_instrument")},
            {name = "Volume", value = string.format("%.2f", params:get("lane_" .. lane_idx .. "_volume"))},
            {name = "Speed", value = string.format("%.2f", params:get("lane_" .. lane_idx .. "_speed"))}
        }
    elseif current_section == "Stages" then
        -- Add base stage params
        section_params = {
            {name = "Stage", value = stage_idx},
            {name = "Mute", value = params:string("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_mute")},
            {name = "Reset Motif", value = params:string("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif")},
            {name = "Loops", value = params:string("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops")},
            {name = "Transform", value = params:string("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transform")}
        }

        -- Add transform parameters if any exist
        local lane = _seeker.lanes[lane_idx]
        local stage = lane.stages[stage_idx]
        local transform = transforms.available[stage.transform_name]
        
        local param_names = {}
        for name, _ in pairs(transform.params) do
            table.insert(param_names, name)
        end
        table.sort(param_names)
        
        for _, param_name in ipairs(param_names) do
            table.insert(section_params, {
                name = "  " .. param_name,  -- Indent to show hierarchy
                value = string.format("%.2f", stage.transform_config[param_name])
            })
        end
    end

    -- Calculate visible range based on screen height
    local SCREEN_HEIGHT = 64
    local PARAM_HEIGHT = 10
    local visible_params = math.floor((SCREEN_HEIGHT - start_y) / PARAM_HEIGHT)
    
    -- Ensure selected param is visible by adjusting scroll offset
    if ScreenUI.state.selected_index > 0 then
        if ScreenUI.state.selected_index - ScreenUI.state.scroll_offset > visible_params then
            ScreenUI.state.scroll_offset = ScreenUI.state.selected_index - visible_params
        elseif ScreenUI.state.selected_index <= ScreenUI.state.scroll_offset then
            ScreenUI.state.scroll_offset = ScreenUI.state.selected_index - 1
        end
    end

    -- Draw only visible params
    for i = 1 + ScreenUI.state.scroll_offset, math.min(#section_params, ScreenUI.state.scroll_offset + visible_params) do
        local y = start_y + ((i - ScreenUI.state.scroll_offset) * PARAM_HEIGHT)
        draw_param(section_params[i], y, ScreenUI.state.selected_index == i)
    end

    -- Draw scroll indicators if needed
    if ScreenUI.state.scroll_offset > 0 then
        screen.level(4)
        screen.move(124, start_y + 4)
        screen.text("▲")
    end
    if ScreenUI.state.scroll_offset + visible_params < #section_params then
        screen.level(4)
        screen.move(124, SCREEN_HEIGHT - 4)
        screen.text("▼")
    end
end

function draw_transform_params(start_y)
    local lane_idx = _seeker.ui_state.focused_lane
    local stage_idx = _seeker.ui_state.focused_stage
    local lane = _seeker.lanes[lane_idx]
    local stage = lane.stages[stage_idx]
    local transform = transforms.available[stage.transform_name]

    -- Draw transform name as header
    screen.level(4)
    screen.move(64, start_y)
    screen.text_center(transform.name .. " Parameters")

    for param_name, param_spec in pairs(transform.params) do
        screen.level(4)
        screen.move(10, start_y + ((i - ScreenUI.state.scroll_offset) * PARAM_HEIGHT))
        screen.text(param_name)
    end

    -- Draw each parameter
    local y = start_y + 10
    local param_names = {}
    for name, _ in pairs(transform.params) do
        table.insert(param_names, name)
    end
    table.sort(param_names)
    
    for i, param_name in ipairs(param_names) do
        local param_spec = transform.params[param_name]
        local value = stage.transform_config[param_name]
        local selected = ScreenUI.state.selected_index == (#base_params + i)
        
        screen.level(selected and 15 or 4)
        if selected then
            screen.move(2, y)
            screen.text("►")
        end
        screen.move(10, y)
        screen.text(param_name)
        screen.move(80, y)
        screen.text(string.format("%.2f", value))
        y = y + 10
    end
end

ScreenUI.redraw = function()
    screen.clear()
    draw_header(10, ScreenUI.state.selected_index == 0)
    draw_params_list(20)
    screen.update()
end

function ScreenUI.change_selection(delta)
    local current_section = ScreenUI.state.current_section
    local num_params
    
    if current_section == "Musical" then
        num_params = 3
    elseif current_section == "Recording" then
        num_params = 1
    elseif current_section == "Lanes" then
        num_params = 4
    elseif current_section == "Stages" then
        num_params = 5
    end
    
    local new_index = ScreenUI.state.selected_index + delta
    ScreenUI.state.selected_index = util.clamp(new_index, 0, num_params)
    ScreenUI.set_needs_redraw()
end

function ScreenUI.modify_selected(delta)
    -- Change section
    if ScreenUI.state.selected_index == 0 then
        local current_idx = tab.key(sections, ScreenUI.state.current_section)
        local new_idx = util.clamp(current_idx + delta, 1, #sections)
        ScreenUI.state.current_section = sections[new_idx]
    else
        local current_section = ScreenUI.state.current_section
        if current_section == "Musical" then
            local param_id
            if ScreenUI.state.selected_index == 1 then param_id = "root_note"
            elseif ScreenUI.state.selected_index == 2 then param_id = "scale_type"
            elseif ScreenUI.state.selected_index == 3 then param_id = "octave"
            end
            params:delta(param_id, delta)
        elseif current_section == "Recording" then
            if ScreenUI.state.selected_index == 1 then
                params:delta("quantize_division", delta)
            end
        elseif current_section == "Lanes" then
            if ScreenUI.state.selected_index == 1 then
                -- Modify lane selector through _seeker.ui_state
                _seeker.ui_state.focused_lane = util.clamp(_seeker.ui_state.focused_lane + delta, 1, 4)
            elseif ScreenUI.state.selected_index == 2 then
                -- Modify instrument for selected lane
                params:delta("lane_" .. _seeker.ui_state.focused_lane .. "_instrument", delta)
            elseif ScreenUI.state.selected_index == 3 then
                -- Modify volume for selected lane
                params:delta("lane_" .. _seeker.ui_state.focused_lane .. "_volume", delta)
            elseif ScreenUI.state.selected_index == 4 then
                -- Modify speed for selected lane
                params:delta("lane_" .. _seeker.ui_state.focused_lane .. "_speed", delta)
            end
        elseif current_section == "Stages" then
            local lane = _seeker.lanes[_seeker.ui_state.focused_lane]
            local stage = lane.stages[_seeker.ui_state.focused_stage]
            local transform = transforms.available[stage.transform_name]
            
                
            -- TODO: This is a hack, we need to get the actual number of params
            local base_params = 5  -- Stage, Mute, Reset, Loops, Transform
            local total_params = base_params
            if transform and transform.params then
                total_params = base_params + tab.count(transform.params)
            end

            if ScreenUI.state.selected_index <= base_params then
                if ScreenUI.state.selected_index == 1 then
                    -- Modify stage selector through _seeker.ui_state
                    _seeker.ui_state.focused_stage = util.clamp(_seeker.ui_state.focused_stage + delta, 1, 4)
                elseif ScreenUI.state.selected_index == 2 then
                    -- Modify mute for selected stage
                    params:delta("lane_" .. _seeker.ui_state.focused_lane .. "_stage_" .. _seeker.ui_state.focused_stage .. "_mute", delta)
                elseif ScreenUI.state.selected_index == 3 then
                    -- Modify reset_motif for selected stage
                    params:delta("lane_" .. _seeker.ui_state.focused_lane .. "_stage_" .. _seeker.ui_state.focused_stage .. "_reset_motif", delta)
                elseif ScreenUI.state.selected_index == 4 then
                    -- Modify loops for selected stage
                    params:delta("lane_" .. _seeker.ui_state.focused_lane .. "_stage_" .. _seeker.ui_state.focused_stage .. "_loops", delta)
                elseif ScreenUI.state.selected_index == 5 then
                    -- Modify transform for selected stage
                    params:delta("lane_" .. _seeker.ui_state.focused_lane .. "_stage_" .. _seeker.ui_state.focused_stage .. "_transform", delta)
                end
            else
                print("Handling transform params")
                -- Handle transform params
                local param_idx = ScreenUI.state.selected_index - base_params
                local param_names = {}
                for name, _ in pairs(transform.params) do
                    table.insert(param_names, name)
                end
                table.sort(param_names)
                
                local param_name = param_names[param_idx]
                local param_spec = transform.params[param_name]
                local current = stage.transform_config[param_name]
                local step = (param_spec.max - param_spec.min) / 20
                
                stage.transform_config[param_name] = util.clamp(
                    current + (delta * step),
                    param_spec.min,
                    param_spec.max
                )
            end
        end
    end
    ScreenUI.set_needs_redraw()
end

return ScreenUI