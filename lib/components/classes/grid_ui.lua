-- grid_ui.lua
-- Base class for grid UI functionality. Inherited by individual components.
-- Handles default logic but can be overriden 
-- (see: @create_motif.lua for straightforward example)

local GridConstants = include("lib/grid_constants")

local GridUI = {}
GridUI.__index = GridUI

--------------------------------
-- Constructor
--------------------------------

function GridUI.new(config)
    local grid_ui = setmetatable({}, GridUI)
    
    -- Basic properties
    grid_ui.id = config.id
    grid_ui.layout = config.layout
    grid_ui.long_press_threshold = config.long_press_threshold or 0.5  -- Time in seconds to trigger long press
    
    -- Press state tracking
    grid_ui.press_state = {
        start_time = nil,
        pressed_keys = {},
        flash_until = nil  -- For visual feedback
    }
    
    return grid_ui
end


--------------------------------
-- Grid Interaction
--------------------------------

-- Draws the UI to the grid
-- Sets brightness based on selected status
function GridUI:draw(layers)
    local brightness = (_seeker.ui_state.get_current_section() == self.id) and 
        GridConstants.BRIGHTNESS.UI.FOCUSED or 
        GridConstants.BRIGHTNESS.UI.NORMAL
        
    layers.ui[self.layout.x][self.layout.y] = brightness
end

-- Basic key handling. 
-- Changes sections and tracks long presses for additional behavior
function GridUI:handle_key(x, y, z)
    local key_id = string.format("%d,%d", x, y)
    
    if z == 1 then
        self:key_down(key_id)
        _seeker.ui_state.set_current_section(self.id)
    else
        self:key_release(key_id)
    end
end

-- Checks if key is within range. Used by multi-key regions
function GridUI:contains(x, y)
    return x >= self.layout.x and 
           x < self.layout.x + self.layout.width and 
           y >= self.layout.y and
           y < self.layout.y + self.layout.height
end


--------------------------------
-- Long Press Helpers
--------------------------------

-- Starts keydown timer for long press tracking
function GridUI:key_down(key_id)
    self.press_state.pressed_keys[key_id] = {
        start_time = util.time(),
        long_press_triggered = false
    }
end

-- Clears keydown timer
function GridUI:key_release(key_id)
    self.press_state.pressed_keys[key_id] = nil
end

-- Checks if specific key has just crossed long press threshold (once)
function GridUI:is_long_press(key_id)
    local press = self.press_state.pressed_keys[key_id]
    if press then
        local elapsed = util.time() - press.start_time
        if elapsed >= self.long_press_threshold and not press.long_press_triggered then
            press.long_press_triggered = true
            return true
        end
    end
    return false
end

-- Checks if any key is currently held past threshold (continuous)
function GridUI:is_holding_long_press()
    for key_id, press in pairs(self.press_state.pressed_keys) do
        local elapsed = util.time() - press.start_time
        if elapsed >= self.long_press_threshold then
            return true
        end
    end
    return false
end

--------------------------------
-- Animation Helpers
--------------------------------

-- Helper for calculating pulsating brightness
-- TODO: This isn't as aligned with bpm as it suggests. Review.
function GridUI:calculate_pulse_brightness(base_brightness, speed)
    speed = speed or 4       -- Pulse speed (cycles per beat)
    local range = 3       -- Range of brightness variation
    
    -- Use sine wave based on clock.get_beats() to create pulsing effect
    -- The result will oscillate between (base_brightness - range) and base_brightness
    return math.floor(math.sin(clock.get_beats() * speed) * range + base_brightness - range)
end

-- Helper for drawing keyboard outline during long press
function GridUI:draw_keyboard_outline_highlight(layers, brightness)
    local keyboard_layout = {
        upper_left_x = 6,
        upper_left_y = 2,
        width = 6,
        height = 6
    }
    local brightness = brightness or GridConstants.BRIGHTNESS.HIGH
    
    -- Top and bottom rows
    for x = 0, keyboard_layout.width - 1 do
        layers.response[keyboard_layout.upper_left_x + x][keyboard_layout.upper_left_y] = brightness
        layers.response[keyboard_layout.upper_left_x + x][keyboard_layout.upper_left_y + keyboard_layout.height - 1] = brightness
    end
    
    -- Left and right columns
    for y = 0, keyboard_layout.height - 1 do
        layers.response[keyboard_layout.upper_left_x][keyboard_layout.upper_left_y + y] = brightness
        layers.response[keyboard_layout.upper_left_x + keyboard_layout.width - 1][keyboard_layout.upper_left_y + y] = brightness
    end
end

return GridUI 