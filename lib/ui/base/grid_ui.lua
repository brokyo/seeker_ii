-- grid_ui.lua
-- Base class for grid UI functionality. Inherited by individual components.
-- Handles default logic but can be overriden 
-- (see: @create_motif.lua for straightforward example)

local GridConstants = include("lib/grid/constants")

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
        flash_until = nil,  -- For visual feedback
        release_animation_start = nil  -- For shrink animation on release
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

-- Clears keydown timer and starts release animation
function GridUI:key_release(key_id)
    -- Start release animation if key was held long enough to show indicator
    local press = self.press_state.pressed_keys[key_id]
    if press then
        local elapsed = util.time() - press.start_time
        if elapsed >= self.long_press_threshold * 0.2 then  -- Only animate if held a bit
            self.press_state.release_animation_start = util.time()
        end
    end
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

-- Check if any key is currently pressed (not yet released)
function GridUI:is_any_key_held()
    for key_id, _ in pairs(self.press_state.pressed_keys) do
        return true
    end
    return false
end

-- Draw hold indicator as centered diamond that grows 1 > 2 > 3, holds, then shrinks on release
function GridUI:draw_hold_indicator(layers)
    local size = 1
    local brightness = 12

    -- Check if we're in release animation
    local release_start = self.press_state.release_animation_start
    if release_start then
        local release_elapsed = util.time() - release_start
        local release_duration = 0.15  -- Shrink over 150ms

        if release_elapsed < release_duration then
            -- Shrinking: 3 > 2 > 1
            local release_progress = release_elapsed / release_duration
            if release_progress < 0.33 then
                size = 3
            elseif release_progress < 0.66 then
                size = 2
            else
                size = 1
            end
        else
            -- Animation done, clear it
            self.press_state.release_animation_start = nil
            return
        end
    else
        -- Holding: grow to full then stay
        local elapsed = 0
        for key_id, press in pairs(self.press_state.pressed_keys) do
            elapsed = util.time() - press.start_time
            break
        end

        local progress = math.min(elapsed / self.long_press_threshold, 1)

        -- Grow 1 > 2 > 3 in first 60% of threshold, then hold at 3
        if progress < 0.2 then
            size = 1
        elseif progress < 0.4 then
            size = 2
        else
            size = 3
        end
    end

    -- Center point in open grid area
    local cx, cy = 6, 5

    -- Draw diamond based on size
    if size >= 1 then
        layers.ui[cx][cy] = brightness
    end
    if size >= 2 then
        layers.ui[cx-1][cy] = brightness
        layers.ui[cx+1][cy] = brightness
        layers.ui[cx][cy-1] = brightness
        layers.ui[cx][cy+1] = brightness
    end
    if size >= 3 then
        layers.ui[cx-2][cy] = brightness
        layers.ui[cx+2][cy] = brightness
        layers.ui[cx][cy-2] = brightness
        layers.ui[cx][cy+2] = brightness
        layers.ui[cx-1][cy-1] = brightness
        layers.ui[cx+1][cy-1] = brightness
        layers.ui[cx-1][cy+1] = brightness
        layers.ui[cx+1][cy+1] = brightness
    end
end

-- Check if release animation is active
function GridUI:is_release_animating()
    return self.press_state.release_animation_start ~= nil
end

return GridUI 