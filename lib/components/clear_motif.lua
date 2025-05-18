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
        screen = {
            instance = NornsUI.new({
                id = "CLEAR_MOTIF",
                name = "Clear Motif",
                description = "Hold to clear the current lane's motif",
                params = {
                    { separator = true, name = "Clear Motif" }
                }
            }),
            
            -- This build function is needed by screen_iii.lua
            build = function()
                return instance.screen.instance
            end
        },

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
    instance.screen.instance.draw_default = function(self)
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
    
    -- Override draw to add visual feedback during long press
    instance.grid.draw = function(self, layers)
        -- Call original draw method
        original_grid_draw(self, layers)
        
        -- Draw visual indicator during long press
        if self:is_holding_long_press() then
            -- Use the shared keyboard outline highlight method
            self:draw_keyboard_outline_highlight(layers)
            
            -- Additionally draw an X pattern inside the keyboard area to indicate clearing
            local keyboard = {
                upper_left_x = 6,
                upper_left_y = 2,
                width = 6,
                height = 6
            }
            
            -- Diagonal from top-left to bottom-right
            for i = 0, keyboard.width - 1 do
                layers.response[keyboard.upper_left_x + i][keyboard.upper_left_y + i] = GridConstants.BRIGHTNESS.HIGH
            end
            
            -- Diagonal from top-right to bottom-left
            for i = 0, keyboard.width - 1 do
                layers.response[keyboard.upper_left_x + keyboard.width - 1 - i][keyboard.upper_left_y + i] = GridConstants.BRIGHTNESS.HIGH
            end
        end
    end
    
    -- Override handle_key to implement clearing functionality
    instance.grid.handle_key = function(self, x, y, z)
        local key_id = string.format("%d,%d", x, y)
        
        if z == 1 then -- Key pressed
            self:key_down(key_id)
            _seeker.ui_state.set_current_section("CLEAR_MOTIF")
            _seeker.ui_state.set_long_press_state(true, "CLEAR_MOTIF")
            _seeker.screen_ui.set_needs_redraw()
        else -- Key released
            -- If it was a long press, clear the motif
            if self:is_long_press(key_id) then
                local focused_lane = _seeker.ui_state.get_focused_lane()
                local lane = _seeker.lanes[focused_lane]
                
                if lane and lane.motif and #lane.motif.events > 0 then
                    lane:clear()
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