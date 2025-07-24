-- playback_config.lua
-- Self-contained component for Motif Playback Configuration

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local PlaybackConfig = {}
PlaybackConfig.__index = PlaybackConfig

-- Grid layout constants
local GRID_LAYOUT = {
  x = 1,
  y = 7,
  width = 1,
  height = 1
}

-- Shared press state
local press_state = {
  start_time = nil,
  pressed_keys = {}
}

-- Long press threshold
local LONG_PRESS_THRESHOLD = 0.5

local function create_params()
    -- Create parameters for motif playback for all 8 lanes
    for i = 1, 8 do
        params:add_control("lane_" .. i .. "_playback_offset", "Lane " .. i .. " Octave Shift", 
            controlspec.new(-4, 4, 'lin', 1, 0), 
            function(param) 
                local val = params:get(param.id)
                if val > 0 then
                    return "+" .. val
                else
                    return tostring(val)
                end
            end)
        
        params:add_control("lane_" .. i .. "_scale_degree_offset", "Lane " .. i .. " Scale Degree Shift", 
            controlspec.new(-7, 7, 'lin', 1, 0), 
            function(param) 
                local val = params:get(param.id)
                if val > 0 then
                    return "+" .. val
                else
                    return tostring(val)
                end
            end)
        
        params:add_control("lane_" .. i .. "_speed", "Lane " .. i .. " Speed", 
            controlspec.new(0.25, 4.0, 'exp', 0.01, 1.0), 
            function(param) 
                return string.format("%.2fx", params:get(param.id))
            end)
        params:set_action("lane_" .. i .. "_speed", function(value)
            if _seeker.lanes and _seeker.lanes[i] then
                _seeker.lanes[i].speed = value
            end
        end)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "MOTIF",
        name = "Motif Playback [WIP]",
        description = "Configure motifs created in generate or record. Hold grid to start and stop playback.",
        params = {}
    })

    -- Override draw to add help text
    function norns_ui:draw()
        screen.clear()
        
        -- Check if showing description
        if self.state.showing_description then
            -- Use parent class's default drawing for description
            self:draw_default()
            return
        end
        
        -- Draw parameters
        self:draw_params(0)
        
        -- Draw help text
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local help_text = "⏵: hold grid key"  -- Default text
        
        if lane_idx and _seeker.lanes and _seeker.lanes[lane_idx] then
            local lane = _seeker.lanes[lane_idx]
            if lane.playing then
                help_text = "⏹: hold grid key"
            end
        end
        
        local width = screen.text_extents(help_text)
        
        -- Brighten text during long press
        if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "MOTIF" then
            screen.level(15)  -- Full brightness during hold
        else
            screen.level(2)   -- Normal dim state
        end
        
        screen.move(64 - width/2, 46)
        screen.text(help_text)
        
        -- Draw footer
        self:draw_footer()
        
        screen.update()
    end

    function norns_ui:update_focused_motif(lane_idx)
        -- Get the current lane's motif
        local lane = _seeker.lanes[lane_idx]
        
        self.params = {
            {
                id = "motif_info",
                name = "Playback Config",
                separator = true
            },
            { id = "lane_" .. lane_idx .. "_playback_offset", name = "Octave Shift" },
            { id = "lane_" .. lane_idx .. "_scale_degree_offset", name = "Scale Degree Shift" },
            { id = "lane_" .. lane_idx .. "_speed", name = "Speed" }
        }
    end

    -- Override enter method to update when section becomes active
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        if original_enter then
            original_enter(self)
        end
        
        -- Update params after base class initialization
        if _seeker.ui_state then
            local lane_idx = _seeker.ui_state.get_focused_lane()
            if lane_idx then
                self:update_focused_motif(lane_idx)
            end
        end
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "MOTIF",
        layout = GRID_LAYOUT
    })

    -- Grid helper functions
    local function contains(x, y)
        return x == GRID_LAYOUT.x and y == GRID_LAYOUT.y
    end

    local function start_press(key_id)
        press_state.pressed_keys[key_id] = {
            start_time = util.time(),
            long_press_triggered = false
        }
    end

    local function end_press(key_id)
        press_state.pressed_keys[key_id] = nil
    end

    local function is_holding_long_press()
        for key_id, press in pairs(press_state.pressed_keys) do
            local elapsed = util.time() - press.start_time
            if elapsed >= LONG_PRESS_THRESHOLD then
                return true
            end
        end
        return false
    end

    local function is_long_press(key_id)
        local press = press_state.pressed_keys[key_id]
        if press then
            local elapsed = util.time() - press.start_time
            if elapsed >= LONG_PRESS_THRESHOLD and not press.long_press_triggered then
                press.long_press_triggered = true
                return true
            end
        end
        return false
    end

    -- Override draw method
    function grid_ui:draw(layers)
        -- Draw keyboard outline during long press
        if is_holding_long_press() then
            -- Top and bottom rows
            for x = 0, 5 do
                layers.response[6 + x][2] = GridConstants.BRIGHTNESS.HIGH
                layers.response[6 + x][7] = GridConstants.BRIGHTNESS.HIGH
            end
            -- Left and right columns
            for y = 0, 5 do
                layers.response[6][2 + y] = GridConstants.BRIGHTNESS.HIGH
                layers.response[11][2 + y] = GridConstants.BRIGHTNESS.HIGH
            end
        end

        -- Draw region button with brightness logic
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local brightness = GridConstants.BRIGHTNESS.LOW  -- Default brightness
        
        if lane_idx and _seeker.lanes and _seeker.lanes[lane_idx] then
            local lane = _seeker.lanes[lane_idx]
            if lane.playing then
                -- Pulsing bright when playing, regardless of section
                brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
            elseif _seeker.ui_state.get_current_section() == "MOTIF" then
                brightness = GridConstants.BRIGHTNESS.FULL
            elseif _seeker.ui_state.get_current_section() == "GENERATE" or
                   _seeker.ui_state.get_current_section() == "RECORDING" or
                   _seeker.ui_state.get_current_section() == "OVERDUB" then
                brightness = GridConstants.BRIGHTNESS.MEDIUM
            end
        end
        
        layers.ui[GRID_LAYOUT.x][GRID_LAYOUT.y] = brightness
    end

    -- Override handle_key method
    function grid_ui:handle_key(x, y, z)
        if not contains(x, y) then
            return false
        end

        local key_id = string.format("%d,%d", x, y)
        
        if z == 1 then -- Key pressed
            start_press(key_id)
            _seeker.ui_state.set_current_section("MOTIF")
            _seeker.ui_state.set_long_press_state(true, "MOTIF")
            _seeker.screen_ui.set_needs_redraw()
        else -- Key released
            -- If it was a long press, toggle play state
            if is_long_press(key_id) then
                local lane_idx = _seeker.ui_state.get_focused_lane()
                if lane_idx and _seeker.lanes and _seeker.lanes[lane_idx] then
                    local lane = _seeker.lanes[lane_idx]
                    if lane.motif then
                        if lane.playing then
                            lane:stop()
                        else
                            lane:play()
                        end
                        _seeker.screen_ui.set_needs_redraw()
                    end
                end
            end
            
            -- Always clear long press state on release
            _seeker.ui_state.set_long_press_state(false, nil)
            _seeker.screen_ui.set_needs_redraw()
            
            end_press(key_id)
        end

        return true
    end

    return grid_ui
end

function PlaybackConfig.init()
    -- Create parameters first
    create_params()
    
    -- Then create UI components
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    
    return component
end

return PlaybackConfig