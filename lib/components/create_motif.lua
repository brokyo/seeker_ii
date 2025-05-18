-- create_motif.lua
-- Self-contained component for the Create Motif functionality.
-- Handles parameter, screen, grid, and arc initialization and management
-- Intended to be the future structure of the project if it works.

local ScreenUI = include("lib/ui/screen_ui")
local GridRegion = include("lib/grid/grid_region")
local GridConstants = include("lib/grid_constants")

local CreateMotif = {}
CreateMotif.__index = CreateMotif

-- Create a single instance that will be reused
local instance = nil

function CreateMotif.init()
    if instance then return instance end

    instance = {
        -- Params interface used by @params_manager_ii for loading core data
        -- Monome Params docs https://monome.org/docs/norns/reference/params
        params = {
            create = function()
                params:add_group("create_motif", "CREATE MOTIF", 1)
                params:add_option("create_motif_type", "Motif Type", {"Tape", "Arpeggio"}, 1)               
            end
        },
        
        -- Screen interface used by @screen_iii 
        screen = {
            instance = ScreenUI.new({
                id = "CREATE_MOTIF",
                name = "Create Motif",
                description = "Motif creation methods. Change type to play live, create arpeggios, or generate automatically",
                params = {
                    { separator = true, name = "Create Motif" },
                    { id = "create_motif_type", name = "Motif Type" }
                }
            }),
            
            -- This build function is needed by screen_iii.lua
            build = function()
                return instance.screen.instance
            end
        },

        -- Grid interface used by @grid_ii
        grid = GridRegion.new({
            id = "CREATE_MOTIF",
            layout = {
                x = 2,
                y = 7,
                width = 1,
                height = 1
            }
        })
    }
    
    -- Override screen draw method
    instance.screen.instance.draw_default = function(self)
        -- Call the original draw method from ScreenUI
        ScreenUI.draw_default(self)
        
        -- Show tooltips for Tape mode
        -- Conditional used based on state & triggers different effects via grid
        if params:get("create_motif_type") == 1 then
            local tooltip
            if _seeker.motif_recorder and _seeker.motif_recorder.is_recording then
                tooltip = "⏹: tap"
            else
                local focused_lane = _seeker.ui_state.get_focused_lane()
                local lane = _seeker.lanes[focused_lane]
                if lane and lane.motif and #lane.motif.events > 0 and lane.playing then
                    tooltip = "⏺: hold [overdub]"
                else
                    tooltip = "⏺: hold [record]"
                end
            end
            
            local width = screen.text_extents(tooltip)
            
            -- TODO: Previously had  "_seeker.ui_state.get_long_press_section() === "CREATE_MOTIF"" an additional check. Don't think it's necessary
            if _seeker.ui_state.is_long_press_active() then
                screen.level(15)
            else
                screen.level(2)
            end
            
            screen.move(64 - width/2, 46)
            screen.text(tooltip)
        end
        
        -- Draw loop visualization whenever there's a motif
        local should_show_visualization = false
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[focused_lane]
        local motif
        
        -- Show visualization when overdubbing
        if _seeker.motif_recorder.is_recording and _seeker.motif_recorder.original_motif then
            should_show_visualization = true
            motif = _seeker.motif_recorder.original_motif
        -- Show visualization when a motif exists, regardless of playback state
        elseif lane and lane.motif and #lane.motif.events > 0 then
            should_show_visualization = true
            motif = lane.motif
        end
        
        if should_show_visualization and motif then
            -- We already verified we have a valid motif with events
            -- in the should_show_visualization check
            -- Constants for visualization
                local VIS_Y = 32        -- Vertical position
                local VIS_HEIGHT = 6    -- Height of visualization
                local VIS_X = 8         -- Left margin
                local VIS_WIDTH = 112   -- Width of visualization
                
                -- Get the effective duration (handles custom duration)
                local loop_duration
                if motif.get_duration then
                    loop_duration = motif:get_duration()
                else
                    -- Default to 4 beats if no duration method available
                    loop_duration = 4
                end
                
                -- Draw loop outline
                screen.level(4)
                screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
                screen.stroke()
                
                -- First find the maximum generation for brightness scaling
                local max_gen = 1
                
                -- Only check for generations if we have a motif with events
                if motif.events then
                    for _, event in ipairs(motif.events) do
                        if event.generation and event.generation > max_gen then
                            max_gen = event.generation
                        end
                    end
        
                    -- Draw existing event markers with generation-based brightness
                    for _, event in ipairs(motif.events) do
                        if event.type == "note_on" then
                            -- Calculate brightness based on generation (older=dimmer, newer=brighter)
                            local gen = event.generation or 1
                            -- Scale brightness from 2-12 based on generation
                            local brightness = 2 + math.floor((gen / max_gen) * 10)
                            screen.level(brightness)
                            
                            -- Calculate x position based on event time relative to loop duration
                            local x = VIS_X + (event.time / loop_duration * VIS_WIDTH)
                            -- Draw small vertical line for event
                            screen.move(x, VIS_Y)
                            screen.line(x, VIS_Y + VIS_HEIGHT)
                            screen.stroke()
                        end
                    end
                end
                
                -- Draw new overdub events if recording (brightest)
                if _seeker.motif_recorder.is_recording and _seeker.motif_recorder.original_motif then
                    screen.level(15)  -- Brightest
                    
                    for _, event in ipairs(_seeker.motif_recorder.events) do
                        -- Only show newly added events from current generation
                        if event.type == "note_on" and event.generation == _seeker.motif_recorder.current_generation then
                            -- Use event time directly from recorder
                            local x = VIS_X + (event.time / loop_duration * VIS_WIDTH)
                            -- Draw slightly taller line for new events
                            screen.move(x, VIS_Y - 1)
                            screen.line(x, VIS_Y + VIS_HEIGHT + 1)
                            screen.stroke()
                        end
                    end
                end
    
                -- Always draw playhead when visualization is shown
                    -- Always use current beat position in the loop
                    local current_beat = clock.get_beats()
                    local position = current_beat % loop_duration
                    
                    -- If playing, use the lane's timing reference for better sync
                    if lane.playing then
                        local current_stage = lane.stages[lane.current_stage_index]
                        if current_stage and current_stage.last_start_time then
                            -- Calculate elapsed time since stage start
                            local elapsed_time = current_beat - current_stage.last_start_time
                            -- Adjust for lane speed (multiply by speed to match how far into motif we are)
                            position = (elapsed_time * lane.speed) % loop_duration
                        end
                    end
                    
                    local x = VIS_X + (position / loop_duration * VIS_WIDTH)
                    screen.level(15)  -- Brightest
                    screen.move(x, VIS_Y - 1)
                    screen.line(x, VIS_Y + VIS_HEIGHT + 1)
                    screen.stroke()
        end
        
        screen.update()
    end
    
    -- Override grid methods
    
    -- Store original draw method
    local original_grid_draw = instance.grid.draw
    
    -- Override draw to add keyboard outline during long press
    instance.grid.draw = function(self, layers)
        -- Call original draw method
        original_grid_draw(self, layers)
        
        -- Only in Tape mode
        if params:get("create_motif_type") == 1 then
            -- Draw keyboard outline during long press
            if self:is_holding_long_press() then
                -- Use the shared keyboard outline highlight method
                self:draw_keyboard_outline_highlight(layers)
            end
            
            -- Draw count display when recording
            if _seeker.motif_recorder.is_recording then
                -- Use quarter-note subdivisions for metronome
                local current_quarter = math.floor(clock.get_beats()) % 4
                
                -- Count display coordinates (same as in RecRegion)
                local count_display = {
                    x_start = 7,
                    x_end = 10,
                    y = 1,
                    pulse_duration = 0.25  -- Extend to 1/4 of a beat for better sync
                }
                
                -- Set all count LEDs to very low brightness initially
                for x = count_display.x_start, count_display.x_end do
                    layers.ui[x][count_display.y] = GridConstants.BRIGHTNESS.LOW / 2
                end
                
                -- Determine which position should be highlighted (moves every beat)
                local highlight_x = count_display.x_start + current_quarter
                
                -- Calculate brightness based on sine wave but keep at 1 beat cycle
                local pulse_brightness = math.floor(math.sin(clock.get_beats() * 4) * 2 + GridConstants.BRIGHTNESS.LOW + 2)
                layers.ui[highlight_x][count_display.y] = pulse_brightness
                
                -- Make the Create Motif button pulsate while recording
                -- Use speed=2 (half speed) to make it cycle every 2 beats
                layers.ui[self.layout.x][self.layout.y] = self:calculate_pulse_brightness(GridConstants.BRIGHTNESS.FULL, 2)
            end
        end
    end
    
    -- Override handle_key to implement recording functionality
    instance.grid.handle_key = function(self, x, y, z)
        -- Only apply recording logic when in Tape mode
        if params:get("create_motif_type") == 1 then -- Tape mode
            local key_id = string.format("%d,%d", x, y)
            
            if z == 1 then -- Key pressed
                self:start_press(key_id)
                _seeker.ui_state.set_current_section("CREATE_MOTIF")
                _seeker.ui_state.set_long_press_state(true, "CREATE_MOTIF")
                _seeker.screen_ui.set_needs_redraw()
            else -- Key released
                -- If already recording, stop on any release (short or long)
                if _seeker.motif_recorder.is_recording then
                    local focused_lane = _seeker.ui_state.get_focused_lane()
                    local motif = _seeker.motif_recorder:stop_recording()
                    local lane = _seeker.lanes[focused_lane]
                    lane:set_motif(motif)
                    lane:play()  -- Start playing immediately after recording
                    _seeker.screen_ui.set_needs_redraw()
                -- If not recording and it was a long press, start recording or overdubbing
                elseif self:is_long_press(key_id) then
                    local focused_lane = _seeker.ui_state.get_focused_lane()
                    local lane = _seeker.lanes[focused_lane]
                    local existing_motif = lane.motif
                    
                    -- Check if lane has a playing motif - if so, overdub instead of recording new
                    if existing_motif and #existing_motif.events > 0 and lane.playing then
                        -- Start overdubbing the existing motif
                        params:set("recording_mode", 2) -- Set to overdub mode
                        _seeker.motif_recorder:start_recording(existing_motif)
                    else
                        -- Clear the current motif and start new recording
                        lane:clear()  -- Clear current motif
                        
                        -- Start new recording
                        params:set("recording_mode", 1) -- Set to regular recording mode
                        _seeker.motif_recorder:start_recording(nil)
                    end
                    
                    _seeker.screen_ui.set_needs_redraw()
                end
                
                -- Always clear long press state on release
                _seeker.ui_state.set_long_press_state(false, nil)
                _seeker.screen_ui.set_needs_redraw()
                
                self:end_press(key_id)
            end
        end
    end
    
    return instance
end

return CreateMotif