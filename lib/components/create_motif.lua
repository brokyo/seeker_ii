-- create_motif.lua
-- Self-contained component for the Create Motif functionality.
-- Handles parameter, screen, grid, and arc initialization and management
-- Intended to be the future structure of the project if it works.

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
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
                params:add_group("create_motif", "CREATE MOTIF", 2)
                params:add_option("create_motif_type", "Motif Type", {"Tape", "Arpeggio [TODO]"}, 1)
            end
        },
        
        -- Screen interface used by @screen_iii 
        screen = {
            instance = NornsUI.new({
                id = "CREATE_MOTIF",
                name = "Create Motif",
                description = "Motif creation methods. Change type to play live, create arpeggios, or generate automatically",
                params = {
                    { separator = true, title = "Create Motif" },
                    { id = "create_motif_type", name = "Motif Type" }
                },
                active_params = {
                    { separator = true, title = "Create Motif" },
                    { id = "create_motif_type" }
                }
            }),
            
            -- This build function is needed by screen_iii.lua
            build = function()
                return instance.screen.instance
            end
        },

        -- Grid interface used by @grid_ii
        grid = GridUI.new({
            id = "CREATE_MOTIF",
            layout = {
                x = 2,
                y = 7,
                width = 1,
                height = 1
            }
        })
    }
    
    --------------------------------
    -- Screen — Custom logic
    --------------------------------
    
    -- Override screen draw method
    instance.screen.instance.draw_default = function(self)
        screen.clear() -- Clear once at the beginning

        -- Call the new internal method from NornsUI to draw base content
        self:_draw_standard_ui()

        -- Original create_motif drawing logic starts here
        -- Show tooltips for Tape mode
        if params:get("create_motif_type") == 1 then
            local tooltip
            if _seeker.motif_recorder and _seeker.motif_recorder.is_recording then
                tooltip = "⏹: tap"
            else
                local focused_lane_tooltip = _seeker.ui_state.get_focused_lane() -- Renamed to avoid conflict
                local lane_tooltip = _seeker.lanes[focused_lane_tooltip] -- Renamed
                if lane_tooltip and lane_tooltip.motif and #lane_tooltip.motif.events > 0 and lane_tooltip.playing then
                    tooltip = "⏺: hold [overdub]"
                else
                    tooltip = "⏺: hold [record]"
                end
            end
            
            local width_tooltip = screen.text_extents(tooltip) -- Renamed 'width'
            
            if _seeker.ui_state.is_long_press_active() then
                screen.level(15)
            else
                screen.level(2)
            end
            
            screen.move(64 - width_tooltip/2, 46)
            screen.text(tooltip)
        end
        
        -- Draw loop visualization whenever there's a motif
        local focused_lane_vis = _seeker.ui_state.get_focused_lane() -- Renamed 'focused_lane'
        local lane_vis = _seeker.lanes[focused_lane_vis] -- Renamed 'lane'
        local motif_vis = lane_vis.motif -- Renamed 'motif'

        if motif_vis and #motif_vis.events > 0 then -- Use renamed motif_vis and check if motif_vis is not nil
             -- Constants for visualization
            local VIS_Y = 32    
            local VIS_HEIGHT = 6
            local VIS_X = 8
            local VIS_WIDTH = 112
                
            -- Get the effective duration (handles custom duration)
            local loop_duration = motif_vis:get_duration() -- Use renamed motif_vis
                
            -- Draw loop outline
            screen.level(4)
            screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
            screen.stroke()
                
            -- Visualization highlights generation via brightness
            local max_gen = 1
            
            -- Find the latest generation
            for _, event in ipairs(motif_vis.events) do -- Use renamed motif_vis
                if event.generation and event.generation > max_gen then
                    max_gen = event.generation
                end
            end

            -- Draw existing event markers with generation-based brightness
            for _, event in ipairs(motif_vis.events) do -- Use renamed motif_vis
                if event.type == "note_on" then
                    -- Calculate brightness based on generation (older=dimmer, newer=brighter)
                    local gen = event.generation or 1 -- Ensure gen is not nil
                    local brightness = 2 + math.floor((gen / max_gen) * 10)
                    screen.level(brightness)
                    
                    -- Calculate x position based on event time relative to loop duration
                    local x_event = VIS_X + (event.time / loop_duration * VIS_WIDTH) -- Renamed 'x'
                  
                    -- Draw small vertical line for event
                    screen.move(x_event, VIS_Y)
                    screen.line(x_event, VIS_Y + VIS_HEIGHT)
                    screen.stroke()
                end
            end
                
            -- Draw new overdub events if recording
            if _seeker.motif_recorder.is_recording and _seeker.motif_recorder.original_motif then
                screen.level(15)
                
                for _, event in ipairs(_seeker.motif_recorder.events) do
                    -- Only show newly added events from current generation
                    if event.type == "note_on" and event.generation == _seeker.motif_recorder.current_generation then
                        -- Use event time directly from recorder
                        local x_overdub = VIS_X + (event.time / loop_duration * VIS_WIDTH) -- Renamed 'x'
                        -- Draw slightly taller line for new events
                        screen.move(x_overdub, VIS_Y - 1)
                        screen.line(x_overdub, VIS_Y + VIS_HEIGHT + 1)
                        screen.stroke()
                    end
                end
            end

            -- Draw playhead
            local current_beat = clock.get_beats()
            local position = current_beat % loop_duration  -- Default position

            if lane_vis.playing then -- Use renamed lane_vis
                -- Use more precise position based on stage timing when playing
                local current_stage = lane_vis.stages[lane_vis.current_stage_index] -- Use renamed lane_vis
                if current_stage and current_stage.last_start_time then
                    local elapsed_time = current_beat - current_stage.last_start_time
                    position = (elapsed_time * lane_vis.speed) % loop_duration -- Use renamed lane_vis
                end
            end

            -- Draw playhead
            local x_playhead = VIS_X + (position / loop_duration * VIS_WIDTH) -- Renamed 'x'
            screen.level(15)
            screen.move(x_playhead, VIS_Y - 1)
            screen.line(x_playhead, VIS_Y + VIS_HEIGHT + 1)
            screen.stroke()
        end
        
        screen.update() -- Single update at the very end
    end
    
    --------------------------------
    -- Grid — Custom logic
    --------------------------------
    
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
                
                -- Count display coordinates
                local count_display = {
                    x_start = 7,
                    x_end = 10,
                    y = 1,
                    pulse_duration = 0.25  -- 1/4 of a beat
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
                -- One complete pulse cycle takes 2 beats
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
                self:key_down(key_id)
                _seeker.ui_state.set_current_section("CREATE_MOTIF")
                _seeker.ui_state.set_long_press_state(true, "CREATE_MOTIF")
                _seeker.screen_ui.set_needs_redraw()
            else -- Key released
                -- If in recording/overdubbing state, stop on key release
                if _seeker.motif_recorder.is_recording then
                    local focused_lane_idx = _seeker.ui_state.get_focused_lane()
                    local current_lane = _seeker.lanes[focused_lane_idx]
                    
                    -- Determine if it was an overdub by checking if an original_motif was set in the recorder.
                    -- Kind of a hack, but it works.
                    local was_overdubbing = (_seeker.motif_recorder.original_motif ~= nil)
                    
                    local overdubbed_motif = _seeker.motif_recorder:stop_recording()
                    
                    current_lane:set_motif(overdubbed_motif)
                    
                    if was_overdubbing then
                        -- Don't do anything, we're already playing
                    else
                        -- New recording finished. Start playing it.
                        current_lane:play()
                    end
                    
                    _seeker.screen_ui.set_needs_redraw()
                -- If not recording and it was a long press, start recording or overdubbing
                elseif self:is_long_press(key_id) then
                    local focused_lane_idx = _seeker.ui_state.get_focused_lane()
                    local current_lane = _seeker.lanes[focused_lane_idx]
                    local existing_motif = current_lane.motif
                    
                    -- Check if lane has a playing motif - if so, overdub instead of recording new
                    if existing_motif and #existing_motif.events > 0 and current_lane.playing then
                        -- Start overdubbing the existing motif
                        _seeker.motif_recorder:set_recording_mode(2) -- Set to overdub mode
                        _seeker.motif_recorder:start_recording(existing_motif)
                    else
                        -- Clear the current motif and start new recording
                        current_lane:clear()  -- Clear current motif
                        
                        -- Start new recording
                        _seeker.motif_recorder:set_recording_mode(1) -- Set to regular recording mode
                        _seeker.motif_recorder:start_recording(nil)
                    end
                    
                    _seeker.screen_ui.set_needs_redraw()
                end
                
                -- Always clear long press state on release
                _seeker.ui_state.set_long_press_state(false, nil)
                _seeker.screen_ui.set_needs_redraw()
                
                self:key_release(key_id)
            end
        end
    end
    
    return instance
end

return CreateMotif