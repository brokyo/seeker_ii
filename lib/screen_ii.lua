local transforms = include("lib/transforms")

local ScreenUI = {}

ScreenUI.state = {
    current_section = 1,
    needs_redraw = true,
    fps = 30,
    selected_index = 0,     -- 0 is header, 1+ are params
    scroll_offset = 0,      -- Track scrolling position
}

local sections_config = {
    {
        name = "Musical",
        params = {
            { id = "root_note", name = "Root Note" },
            { id = "scale_type", name = "Scale" },
            { id = "octave", name = "Octave" },
        },
    },
    {
        name = "Recording",
        params = {
            { id = "quantize_division", name = "Quantize" },
        },
    },
    {
        name = "Lanes",
        params = {
            { id = "lane_selector", name = "Lane", is_selector = true },
            { id = "midi_device", name = "MIDI Device" },
            { id = "midi_channel", name = "MIDI Channel" },
            { id = "instrument", name = "Instrument" },
            { id = "volume", name = "Volume" },
            { id = "speed", name = "Speed" },
        },
    },
    {
        name = "Stages",
        params = {
            { id = "stage_selector", name = "Stage", is_selector = true },
            { id = "mute", name = "Mute" },
            { id = "reset_motif", name = "Reset Motif" },
            { id = "loops", name = "Loops" },
            { id = "transform", name = "Transform" },
            -- Transform parameters will be added dynamically
        },
    },
}

-- 
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

function get_current_section()
    return sections_config[ScreenUI.state.current_section]
end

function get_stage()
    local lane_idx = _seeker.ui_state.focused_lane
    local stage_idx = _seeker.ui_state.focused_stage
    local lane = _seeker.lanes[lane_idx]
    local stage = lane.stages[stage_idx]
    return stage
end 

function draw_header(y_pos, selected)
    if selected then
        screen.level(15)
        screen.move(2, y_pos)
        screen.text("►")
    end
    
    screen.level(selected and 15 or 4)
    screen.move(64, y_pos)
    screen.text_center(get_current_section().name)
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
    local section = get_current_section()
    local section_params = {}

    for _, param_info in ipairs(section.params) do
        local value = get_param_value(param_info)
        table.insert(section_params, {
            name = param_info.name,
            value = value,
            is_selector = param_info.is_selector,
            is_transform_param = param_info.is_transform_param,
        })
    end

    -- If in "Stages" section, add transform parameters
    if ScreenUI.state.current_section == 4 then
        local transform_params = get_transform_params()
        for _, param_info in ipairs(transform_params) do
            local value = get_transform_param_value(param_info)
            table.insert(section_params, {
                name = "  " .. param_info.name, -- Indent to show hierarchy
                value = value,
                is_transform_param = true,
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
    local stage = get_stage()
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
    local num_params = get_section_params_count(current_section)

    local new_index = ScreenUI.state.selected_index + delta
    ScreenUI.state.selected_index = util.clamp(new_index, 0, num_params)
    ScreenUI.set_needs_redraw()
end

function get_section_params_count(section_name)
    local base_count = #sections_config[section_name].params
    if ScreenUI.state.current_section == 4 then
        local transform_params = get_transform_params()
        return base_count + #transform_params
    else
        return base_count
    end
end

function ScreenUI.modify_selected(delta)
    if ScreenUI.state.selected_index == 0 then
        -- Change section
        local current_idx = ScreenUI.state.current_section
        local new_idx = util.clamp(current_idx + delta, 1, #sections_config)
        ScreenUI.state.current_section = new_idx
    else
        local param_info = get_selected_param_info(ScreenUI.state.current_section, ScreenUI.state.selected_index)
        modify_param(param_info, delta)
    end
    ScreenUI.set_needs_redraw()
end

function get_selected_param_info(section_name, selected_index)
    local section = sections_config[section_name]
    local params = section.params

    -- If in "Stages" section, include transform params
    if ScreenUI.state.current_section == 4 then
        local transform_params = get_transform_params()
        params = { table.unpack(params) }
        for _, param in ipairs(transform_params) do
            table.insert(params, param)
        end
    end

    return params[selected_index]
end

function get_param_value(param_info)
    local lane_idx = _seeker.ui_state.focused_lane
    local stage_idx = _seeker.ui_state.focused_stage

    if param_info.id == "lane_selector" then
        return lane_idx
    elseif param_info.id == "stage_selector" then
        return stage_idx
    elseif param_info.id == "midi_device" then
        return params:string("lane_" .. lane_idx .. "_midi_device")
    elseif param_info.id == "midi_channel" then
        return params:get("lane_" .. lane_idx .. "_midi_channel")
    elseif param_info.id == "instrument" then
        return params:string("lane_" .. lane_idx .. "_instrument")
    elseif param_info.id == "volume" then
        return string.format("%.2f", params:get("lane_" .. lane_idx .. "_volume"))
    elseif param_info.id == "speed" then
        return string.format("%.2f", params:get("lane_" .. lane_idx .. "_speed"))
    elseif param_info.id == "mute" then
        return params:string("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_mute")
    elseif param_info.id == "reset_motif" then
        return params:string("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif")
    elseif param_info.id == "loops" then
        return params:string("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops")
    elseif param_info.id == "transform" then
        return params:string("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transform")
    else
        return params:string(param_info.id) or ""
    end
end

function get_transform_param_value(param_info)
    local stage = get_stage()
    local value = stage.transform_config[param_info.id]
    return string.format("%.2f", value)
end

function get_transform_params()
    local params_list = {}
    local stage = get_stage()
    local transform = transforms.available[stage.transform_name]

    if transform and transform.params then
        local param_names = {}
        for name, _ in pairs(transform.params) do
            table.insert(param_names, name)
        end
        table.sort(param_names)

        for _, param_name in ipairs(param_names) do
            table.insert(params_list, {
                id = param_name,
                name = param_name,
                is_transform_param = true,
            })
        end
    end

    return params_list
end

function modify_param(param_info, delta)
    local lane_idx = _seeker.ui_state.focused_lane
    local stage_idx = _seeker.ui_state.focused_stage

    if param_info.is_transform_param then
        modify_transform_param(param_info, delta)
    elseif param_info.id == "lane_selector" then
        _seeker.ui_state.focused_lane = util.clamp(lane_idx + delta, 1, 4)
    elseif param_info.id == "stage_selector" then
        _seeker.ui_state.focused_stage = util.clamp(stage_idx + delta, 1, 4)
    elseif param_info.id == "midi_device" then
        params:delta("lane_" .. lane_idx .. "_midi_device", delta)
    elseif param_info.id == "midi_channel" then
        params:delta("lane_" .. lane_idx .. "_midi_channel", delta)
    elseif param_info.id == "instrument" then
        params:delta("lane_" .. lane_idx .. "_instrument", delta)
    elseif param_info.id == "volume" then
        params:delta("lane_" .. lane_idx .. "_volume", delta)
    elseif param_info.id == "speed" then
        params:delta("lane_" .. lane_idx .. "_speed", delta)
    elseif param_info.id == "mute" then
        params:delta("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_mute", delta)
    elseif param_info.id == "reset_motif" then
        params:delta("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif", delta)
    elseif param_info.id == "loops" then
        params:delta("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops", delta)
    elseif param_info.id == "transform" then
        params:delta("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transform", delta)
    else
        params:delta(param_info.id, delta)
    end
end

function modify_transform_param(param_info, delta)
    local lane_idx = _seeker.ui_state.focused_lane
    local stage_idx = _seeker.ui_state.focused_stage
    local lane = _seeker.lanes[lane_idx]
    local stage = lane.stages[stage_idx]
    local transform = transforms.available[stage.transform_name]

    local param_name = param_info.id
    local param_spec = transform.params[param_name]
    local current_value = stage.transform_config[param_name]
    
    -- Use the parameter's specified step size or type
    local step = param_spec.step or (
        param_spec.type == "integer" and 1 or 
        (param_spec.max - param_spec.min) / 20
    )

    stage.transform_config[param_name] = util.clamp(
        current_value + (delta * step),
        param_spec.min,
        param_spec.max
    )

    -- Round to integers if needed
    if param_spec.type == "integer" then
        stage.transform_config[param_name] = math.floor(stage.transform_config[param_name] + 0.5)
    end
end

function get_section_index(name)
    for i, section in ipairs(sections_config) do
        if section.name == name then
            return i
        end
    end
    return 1  -- default to first section if not found
end

return ScreenUI