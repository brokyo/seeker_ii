-- create_motif.lua
-- Self-contained component for the Create Motif functionality.
-- Handles parameter, screen, grid, and arc initialization and management

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local CreateMotif = {}
CreateMotif.__index = CreateMotif

local function create_params()
    params:add_group("create_motif", "CREATE MOTIF", 4)
    params:add_option("create_motif_type", "Motif Type", {"Tape", "Arpeggio"}, 1)
    params:set_action("create_motif_type", function(value)
        if _seeker and _seeker.create_motif then
            _seeker.create_motif.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end
    end)
    
    -- Arpeggio mode parameters
    params:add_option("arpeggio_interval", "Arpeggio Interval",
        {"1/32", "1/24", "1/16", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "16", "24", "32"}, 12)
    params:add_binary("arpeggio_add_rest", "Add Rest", "trigger", 0)
    params:set_action("arpeggio_add_rest", function(value)
        if value == 1 then
            _seeker.motif_recorder:add_arpeggio_rest()
            _seeker.ui_state.trigger_activated("arpeggio_add_rest")
        end
    end)
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "CREATE_MOTIF",
        name = "Create Motif",
        description = "Motif creation methods. Change type to play live, create arpeggios, or generate automatically",
        params = {
            { separator = true, title = "Create Motif" },
            { id = "create_motif_type" },
            { id = "arpeggio_interval" },
            { id = "arpeggio_add_rest" }
        }
    })
    
    -- Dynamic parameter rebuilding based on motif type
    norns_ui.rebuild_params = function(self)
        local param_table = {
            { separator = true, title = "Create Motif" },
            { id = "create_motif_type" }
        }
        
        -- Only show arpeggio params when in arpeggio mode
        if params:get("create_motif_type") == 2 then
            table.insert(param_table, { id = "arpeggio_interval" })
            table.insert(param_table, { id = "arpeggio_add_rest", is_action = true })
        end
        
        -- Update the UI with the new parameter table
        self.params = param_table
    end
    
    -- Override enter method to build initial params
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        original_enter(self)
        self:rebuild_params()
    end
    
    -- Override screen draw method
    norns_ui.draw_default = function(self)
        screen.clear() -- Clear once at the beginning

        -- Call the new internal method from NornsUI to draw base content
        self:_draw_standard_ui()

        -- Original create_motif drawing logic starts here
        -- Show tooltip
        local tooltip
        if _seeker.motif_recorder and _seeker.motif_recorder.is_recording then
            tooltip = "⏹: tap"
        else
            local focused_lane_tooltip = _seeker.ui_state.get_focused_lane()
            local lane_tooltip = _seeker.lanes[focused_lane_tooltip]
            if lane_tooltip and lane_tooltip.motif and #lane_tooltip.motif.events > 0 and lane_tooltip.playing then
                tooltip = "⏺: hold [overdub]"
            else
                tooltip = "⏺: hold [record]"
            end
        end
        
        -- Draw tooltip if we have one
        if tooltip then
            local width_tooltip = screen.text_extents(tooltip)
            
            if _seeker.ui_state.is_long_press_active() then
                screen.level(15)
            else
                screen.level(2)
            end
            
            screen.move(64 - width_tooltip/2, 46)
            screen.text(tooltip)
        end
        
        -- Draw loop visualization whenever there's a motif (only in tape mode)
        if params:get("create_motif_type") == 1 then
            local focused_lane_vis = _seeker.ui_state.get_focused_lane()
            local lane_vis = _seeker.lanes[focused_lane_vis]
            local motif_vis = lane_vis.motif

            if motif_vis and #motif_vis.events > 0 then
             -- Constants for visualization
            local VIS_Y = 32    
            local VIS_HEIGHT = 6
            local VIS_X = 8
            local VIS_WIDTH = 112
                
            -- Get the effective duration (handles custom duration)
            local loop_duration = motif_vis:get_duration()
                
            -- Draw loop outline
            screen.level(4)
            screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
            screen.stroke()
                
            -- Visualization highlights generation via brightness
            local max_gen = 1
            
            -- Find the latest generation
            for _, event in ipairs(motif_vis.events) do
                if event.generation and event.generation > max_gen then
                    max_gen = event.generation
                end
            end

            -- Draw existing event markers with generation-based brightness
            for _, event in ipairs(motif_vis.events) do
                if event.type == "note_on" then
                    -- Calculate brightness based on generation (older=dimmer, newer=brighter)
                    local gen = event.generation or 1
                    local brightness = 2 + math.floor((gen / max_gen) * 10)
                    screen.level(brightness)
                    
                    -- Calculate x position based on event time relative to loop duration
                    local x_event = VIS_X + (event.time / loop_duration * VIS_WIDTH)
                  
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
                        local x_overdub = VIS_X + (event.time / loop_duration * VIS_WIDTH)
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

            if lane_vis.playing then
                -- Use more precise position based on stage timing when playing
                local current_stage = lane_vis.stages[lane_vis.current_stage_index]
                if current_stage and current_stage.last_start_time then
                    local elapsed_time = current_beat - current_stage.last_start_time
                    position = (elapsed_time * lane_vis.speed) % loop_duration
                end
            end

            -- Draw playhead
            local x_playhead = VIS_X + (position / loop_duration * VIS_WIDTH)
            screen.level(15)
            screen.move(x_playhead, VIS_Y - 1)
            screen.line(x_playhead, VIS_Y + VIS_HEIGHT + 1)
            screen.stroke()
            end
        end
        
        screen.update() -- Single update at the very end
    end
    
    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "CREATE_MOTIF",
        layout = {
            x = 2,
            y = 7,
            width = 1,
            height = 1
        }
    })
    
    -- Helper function for common key press logic
    local function handle_key_press(self)
        _seeker.ui_state.set_current_section("CREATE_MOTIF")
        _seeker.ui_state.set_long_press_state(true, "CREATE_MOTIF")
        _seeker.screen_ui.set_needs_redraw()
    end
    
    -- Helper function for common key release cleanup
    local function handle_key_release_cleanup(self, key_id)
        _seeker.ui_state.set_long_press_state(false, nil)
        _seeker.screen_ui.set_needs_redraw()
        self:key_release(key_id)
    end
    
    -- Helper function for tape mode recording logic
    local function handle_tape_recording_stop(self)
        local focused_lane_idx = _seeker.ui_state.get_focused_lane()
        local current_lane = _seeker.lanes[focused_lane_idx]
        
        -- Determine if it was an overdub by checking if an original_motif was set in the recorder.
        local was_overdubbing = (_seeker.motif_recorder.original_motif ~= nil)
        
        local overdubbed_motif = _seeker.motif_recorder:stop_recording()
        current_lane:set_motif(overdubbed_motif)
        
        if not was_overdubbing then
            -- New recording finished. Start playing it.
            current_lane:play()
        end
        
        _seeker.screen_ui.set_needs_redraw()
    end
    
    -- Helper function for tape mode recording start
    local function handle_tape_recording_start(self)
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
    
    -- Helper function for arpeggio mode recording logic
    local function handle_arpeggio_recording_stop(self)
        local focused_lane_idx = _seeker.ui_state.get_focused_lane()
        local current_lane = _seeker.lanes[focused_lane_idx]
        
        local arpeggio_motif = _seeker.motif_recorder:stop_arpeggio_recording()
        
        current_lane:set_motif(arpeggio_motif)
        current_lane:play() -- Start playing immediately after recording
        
        _seeker.screen_ui.set_needs_redraw()
    end
    
    -- Helper function for arpeggio mode recording start
    local function handle_arpeggio_recording_start(self)
        local focused_lane_idx = _seeker.ui_state.get_focused_lane()
        local current_lane = _seeker.lanes[focused_lane_idx]
        
        -- Clear the current motif and start new arpeggio recording
        current_lane:clear()
        _seeker.motif_recorder:start_arpeggio_recording()
        
        _seeker.screen_ui.set_needs_redraw()
    end
    
    -- Override draw to add keyboard outline during long press
    grid_ui.draw = function(self, layers)
        local x = self.layout.x
        local y = self.layout.y
        local brightness = (_seeker.ui_state.get_current_section() == self.id) and 
            GridConstants.BRIGHTNESS.UI.FOCUSED or 
            GridConstants.BRIGHTNESS.UI.NORMAL
        
        -- Handle different modes
        if params:get("create_motif_type") == 1 then -- Tape mode
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
                for x_count = count_display.x_start, count_display.x_end do
                    layers.ui[x_count][count_display.y] = GridConstants.BRIGHTNESS.LOW / 2
                end
                
                -- Determine which position should be highlighted (moves every beat)
                local highlight_x = count_display.x_start + current_quarter
                
                -- Calculate brightness based on sine wave but keep at 1 beat cycle
                local pulse_brightness = math.floor(math.sin(clock.get_beats() * 4) * 2 + GridConstants.BRIGHTNESS.LOW + 2)
                layers.ui[highlight_x][count_display.y] = pulse_brightness
                
                -- Make the Create Motif button pulsate while recording
                -- One complete pulse cycle takes 2 beats
                brightness = self:calculate_pulse_brightness(GridConstants.BRIGHTNESS.FULL, 2)
            end
        elseif params:get("create_motif_type") == 2 then -- Arpeggio mode
            -- Make the Create Motif button pulsate while recording
            if _seeker.motif_recorder.is_recording then
                brightness = self:calculate_pulse_brightness(GridConstants.BRIGHTNESS.FULL, 1)
            end
        end
        
        layers.ui[x][y] = brightness
    end

    -- Override handle_key to implement recording functionality
    grid_ui.handle_key = function(self, x, y, z)
        local motif_type = params:get("create_motif_type")
        local key_id = string.format("%d,%d", x, y)
        
        if z == 1 then -- Key pressed
            self:key_down(key_id)
            handle_key_press(self)
        else -- Key released
            -- Handle recording stop logic based on mode
            if _seeker.motif_recorder.is_recording then
                if motif_type == 1 then -- Tape mode
                    handle_tape_recording_stop(self)
                elseif motif_type == 2 and _seeker.motif_recorder.recording_mode == 3 then -- Arpeggio mode
                    handle_arpeggio_recording_stop(self)
                end
            -- Handle recording start logic for long press
            elseif self:is_long_press(key_id) then
                if motif_type == 1 then -- Tape mode
                    handle_tape_recording_start(self)
                elseif motif_type == 2 then -- Arpeggio mode
                    handle_arpeggio_recording_start(self)
                end
            end
            
            -- Always perform cleanup
            handle_key_release_cleanup(self, key_id)
        end
    end
    
    return grid_ui
end

function CreateMotif.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    
    return component
end

return CreateMotif