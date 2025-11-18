-- clear_motif.lua
-- Self-contained component for the Clear Motif functionality.
-- Allows clearing the current lane's motif with a long press

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local ClearMotif = {}
ClearMotif.__index = ClearMotif

local instance = nil

function ClearMotif.init()
    if instance then return instance end

    instance = {
        -- Params interface used by @params_manager_ii for loading core data
        params = {
            create = function()
                params:add_group("clear_motif", "CLEAR MOTIF", 1)
            end
        },
        
        -- Screen interface used by @screen_iii
        screen = NornsUI.new({
            id = "CLEAR_MOTIF",
            name = "Clear Motif",
            description = "Hold to clear the current lane's motif",
            params = {
                { separator = true, title = "Clear Motif" }
            }
        }),

        -- Grid interface used by @grid_ii
        grid = GridUI.new({
            id = "CLEAR_MOTIF",
            layout = {
                x = 3,
                y = 7,
                width = 1,
                height = 1
            },
            long_press_threshold = 1.0
        })
    }
    
    --------------------------------
    -- Screen Overrides
    --------------------------------
    instance.screen.draw_default = function(self)
        -- Call the original draw method from ScreenUI
        NornsUI.draw_default(self)
        
        -- Show tooltip for clearing motif
        local tooltip
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[focused_lane]
        
        if lane and lane.motif and #lane.motif.events > 0 then
            tooltip = "x: hold [clear]"
        else
            tooltip = "No motif to clear"
        end
        
        local width = screen.text_extents(tooltip)
        
        if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "CLEAR_MOTIF" then
            screen.level(15)
        else
            screen.level(2)
        end
        
        screen.move(64 - width/2, 46)
        screen.text(tooltip)
        
        screen.update()
    end
    
    --------------------------------
    -- Grid Overrides
    --------------------------------
    -- Change long_press_threshold because of risk of accidental clearing
    instance.grid.long_press_threshold = 1.5
    
    -- Store original draw method
    local original_grid_draw = instance.grid.draw
    
    -- Track button state for animation
    local button_pressed = false
    local button_press_time = nil

    -- Override draw to add visual feedback during press
    instance.grid.draw = function(self, layers)
        -- Call original draw method
        original_grid_draw(self, layers)

        -- Draw visual indicator when button is pressed
        if button_pressed and button_press_time then
            local press_duration = util.time() - button_press_time
            local threshold_reached = press_duration >= self.long_press_threshold

            -- Determine keyboard brightness
            local keyboard_brightness
            if threshold_reached then
                -- Calculate time since threshold was reached
                local time_since_threshold = press_duration - self.long_press_threshold
                local pulse_rate = 4
                local pulse_duration = 1 / pulse_rate
                local pulses_completed = time_since_threshold / pulse_duration

                if pulses_completed < 3 then
                    -- Pulse 3 times to indicate ready to execute
                    local phase = (clock.get_beats() * pulse_rate) % 1
                    local pulse = math.sin(phase * math.pi * 2) * 0.5 + 0.5
                    keyboard_brightness = math.floor(GridConstants.BRIGHTNESS.MEDIUM + pulse * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.MEDIUM))
                else
                    -- After 3 pulses, hold at full brightness
                    keyboard_brightness = GridConstants.BRIGHTNESS.FULL
                end
            else
                -- Lower illumination while holding (before threshold)
                keyboard_brightness = GridConstants.BRIGHTNESS.MEDIUM
            end

            -- Illuminate entire keyboard
            local keyboard = {
                upper_left_x = 6,
                upper_left_y = 2,
                width = 6,
                height = 6
            }

            for x = keyboard.upper_left_x, keyboard.upper_left_x + keyboard.width - 1 do
                for y = keyboard.upper_left_y, keyboard.upper_left_y + keyboard.height - 1 do
                    layers.response[x][y] = keyboard_brightness
                end
            end
        end
    end
    
    -- Override handle_key to implement clearing functionality
    instance.grid.handle_key = function(self, x, y, z)
        local key_id = string.format("%d,%d", x, y)

        if z == 1 then -- Key pressed
            self:key_down(key_id)
            button_pressed = true
            button_press_time = util.time()
            _seeker.ui_state.set_current_section("CLEAR_MOTIF")
            _seeker.ui_state.set_long_press_state(true, "CLEAR_MOTIF")
            _seeker.screen_ui.set_needs_redraw()
        else -- Key released
            button_pressed = false
            button_press_time = nil
            -- If it was a long press, clear the motif
            if self:is_long_press(key_id) then
                local focused_lane = _seeker.ui_state.get_focused_lane()
                local lane = _seeker.lanes[focused_lane]
                
                if lane and lane.motif and #lane.motif.events > 0 then
                    lane:clear()
                    
                    -- Rebuild create_motif parameters to hide duration since motif was cleared
                    if _seeker.create_motif and _seeker.create_motif.screen then
                        _seeker.create_motif.screen:rebuild_params()
                    end
                end
                
                _seeker.screen_ui.set_needs_redraw()
            end
            
            -- Clear long press state on release
            _seeker.ui_state.set_long_press_state(false, nil)
            _seeker.screen_ui.set_needs_redraw()
            
            self:key_release(key_id)
        end
    end
    
    return instance
end

return ClearMotif 