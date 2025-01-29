local ScreenUI = {}
local UIState = include("lib/ui_state")

ScreenUI.state = {
    current_section = "Musical",
    needs_redraw = true,
    fps = 30,
    selected_index = 0,     -- 0 is header, 1+ are params
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
            {name = "Lane", value = UIState.get_focused_lane(), is_selector = true}
        }
        -- Add params for selected lane
        local i = UIState.get_focused_lane()
        table.insert(section_params, {
            name = "Instrument",
            value = params:string("lane_" .. i .. "_instrument")
        })
        table.insert(section_params, {
            name = "Volume",
            value = string.format("%.2f", params:get("lane_" .. i .. "_volume"))
        })
    end

    for i, param in ipairs(section_params) do
        local y = start_y + (i * 10)
        draw_param(param, y, ScreenUI.state.selected_index == i)
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
        num_params = 3  -- selector + 2 params
    end
    
    local new_index = ScreenUI.state.selected_index + delta
    ScreenUI.state.selected_index = util.clamp(new_index, 0, num_params)
    ScreenUI.set_needs_redraw()
end

function ScreenUI.modify_selected(delta)
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
                -- Modify lane selector through UIState
                UIState.set_focused_lane(util.clamp(UIState.get_focused_lane() + delta, 1, 4))
            elseif ScreenUI.state.selected_index == 2 then
                -- Modify instrument for selected lane
                params:delta("lane_" .. UIState.get_focused_lane() .. "_instrument", delta)
            elseif ScreenUI.state.selected_index == 3 then
                -- Modify volume for selected lane
                params:delta("lane_" .. UIState.get_focused_lane() .. "_volume", delta)
            end
        end
    end
    ScreenUI.set_needs_redraw()
end

return ScreenUI