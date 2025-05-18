-- grid_region.lua
-- Base prototype for grid regions

local GridConstants = include("lib/grid_constants")

local GridRegion = {}
GridRegion.__index = GridRegion

-- Constants for long press detection
GridRegion.LONG_PRESS_THRESHOLD = 0.5  -- Time in seconds to trigger long press

-- Default (musical) keyboard layout configuration
GridRegion.KEYBOARD_LAYOUT = {
    upper_left_x = 6,
    upper_left_y = 2,
    width = 6,
    height = 6
}

function GridRegion.new(config)
    local region = setmetatable({}, GridRegion)
    
    -- Basic properties
    region.id = config.id
    region.layout = config.layout or {
        x = 1,
        y = 1,
        width = 1,
        height = 1
    }
    
    -- Press state tracking
    region.press_state = {
        start_time = nil,
        pressed_keys = {},
        flash_until = nil  -- For visual feedback
    }
    
    return region
end

-- Core grid methods
function GridRegion:contains(x, y)
    return x >= self.layout.x and 
           x < self.layout.x + self.layout.width and 
           y >= self.layout.y and
           y < self.layout.y + self.layout.height
end

function GridRegion:draw(layers)
    local brightness = (_seeker.ui_state.get_current_section() == self.id) and 
        GridConstants.BRIGHTNESS.UI.FOCUSED or 
        GridConstants.BRIGHTNESS.UI.NORMAL
        
    layers.ui[self.layout.x][self.layout.y] = brightness
end

function GridRegion:handle_key(x, y, z)
    local key_id = string.format("%d,%d", x, y)
    
    if z == 1 then -- Key pressed
        self:start_press(key_id)
        _seeker.ui_state.set_current_section(self.id)
    else -- Key released
        self:end_press(key_id)
    end
end

-- Press state helpers
function GridRegion:start_press(key_id)
    self.press_state.pressed_keys[key_id] = {
        start_time = util.time(),
        long_press_triggered = false
    }
end

function GridRegion:end_press(key_id)
    self.press_state.pressed_keys[key_id] = nil
end

function GridRegion:is_long_press(key_id)
    local press = self.press_state.pressed_keys[key_id]
    if press then
        local elapsed = util.time() - press.start_time
        if elapsed >= self.LONG_PRESS_THRESHOLD and not press.long_press_triggered then
            press.long_press_triggered = true
            return true
        end
    end
    return false
end

function GridRegion:is_holding_long_press()
    for key_id, press in pairs(self.press_state.pressed_keys) do
        local elapsed = util.time() - press.start_time
        if elapsed >= self.LONG_PRESS_THRESHOLD then
            return true
        end
    end
    return false
end

-- Flash state helpers
function GridRegion:start_flash(duration)
    self.press_state.flash_until = util.time() + (duration or 0.15)
end

function GridRegion:is_flashing()
    return self.press_state.flash_until and util.time() < self.press_state.flash_until
end

-- Helper for calculating pulsating brightness
function GridRegion:calculate_pulse_brightness(base_brightness, speed, range)
    speed = speed or 4       -- Pulse speed (cycles per beat)
    range = range or 3       -- Range of brightness variation
    
    -- Use sine wave based on clock.get_beats() to create pulsing effect
    -- The result will oscillate between (base_brightness - range) and base_brightness
    return math.floor(math.sin(clock.get_beats() * speed) * range + base_brightness - range)
end

-- Helper for drawing keyboard outline during long press
function GridRegion:draw_keyboard_outline_highlight(layers, brightness)
    local brightness = brightness or GridConstants.BRIGHTNESS.HIGH
    
    -- Top and bottom rows
    for x = 0, self.KEYBOARD_LAYOUT.width - 1 do
        layers.response[self.KEYBOARD_LAYOUT.upper_left_x + x][self.KEYBOARD_LAYOUT.upper_left_y] = brightness
        layers.response[self.KEYBOARD_LAYOUT.upper_left_x + x][self.KEYBOARD_LAYOUT.upper_left_y + self.KEYBOARD_LAYOUT.height - 1] = brightness
    end
    
    -- Left and right columns
    for y = 0, self.KEYBOARD_LAYOUT.height - 1 do
        layers.response[self.KEYBOARD_LAYOUT.upper_left_x][self.KEYBOARD_LAYOUT.upper_left_y + y] = brightness
        layers.response[self.KEYBOARD_LAYOUT.upper_left_x + self.KEYBOARD_LAYOUT.width - 1][self.KEYBOARD_LAYOUT.upper_left_y + y] = brightness
    end
end

return GridRegion 