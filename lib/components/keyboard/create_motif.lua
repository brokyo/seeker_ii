-- create_motif.lua
-- Self-contained component for the Create Motif functionality.
-- Handles parameter, screen, grid, and arc initialization and management
--
-- ARCHITECTURAL NOTE: This component handles two distinct modes (Tape and Arpeggio)
-- via conditional branching on motif_type. This creates coupling but keeps the UI
-- simple (one screen, one button). If arpeggio mode grows significantly complex
-- (step visualization, pattern presets, unique features), consider splitting into:
--   - create_motif_region.lua (routing layer, owns grid button)
--   - tape_motif.lua (tape recording component)
--   - arpeggio_motif.lua (arpeggio generation component)
-- See keyboard_region.lua for precedent on this pattern.

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local arpeggio_sequence = include('lib/components/lanes/stage_types/arpeggio_sequence')

local CreateMotif = {}
CreateMotif.__index = CreateMotif

-- Track playback state per mode for each lane (persists until restart)
local lane_playback_state = {}
-- Track the current mode to detect changes
local current_mode = 1

local function create_params()
    params:add_group("create_motif_group", "CREATE MOTIF", 1)
    -- Duration parameter for tape mode
    params:add_control("create_motif_duration", "Duration", controlspec.new(0.25, 128, 'lin', 0.25, 4, "beats", 0.25 / 128))
    params:set_action("create_motif_duration", function(value)
        local focused_lane = _seeker.ui_state.get_focused_lane()
        if _seeker.lanes[focused_lane] and _seeker.lanes[focused_lane].motif then
            if value == 0 then
                _seeker.lanes[focused_lane].motif.custom_duration = nil
            else
                _seeker.lanes[focused_lane].motif.custom_duration = value
            end
            -- Trigger screen redraw to update visualization
            if _seeker.screen_ui then
                _seeker.screen_ui.set_needs_redraw()
            end
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
            { id = "create_motif_duration" }
        }
    })
    
    -- Dynamic parameter rebuilding based on motif type
    norns_ui.rebuild_params = function(self)
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local motif_type = params:get("lane_" .. focused_lane .. "_motif_type")

        local param_table = {
            { separator = true, title = "Create Motif" },
            { id = "lane_" .. focused_lane .. "_motif_type" }
        }

        -- Only show duration param when in tape mode AND there's an active motif
        if motif_type == 1 then
            local focused_lane = _seeker.ui_state.get_focused_lane()
            local lane = _seeker.lanes[focused_lane]
            if lane and lane.motif and #lane.motif.events > 0 then
                table.insert(param_table, { id = "create_motif_duration" })
            end
        end
        
        
        -- Only show arpeggio sequence structure when in arpeggio mode
        -- Musical params (chord, velocity, strum) are now configured in Stage Config
        if motif_type == 2 then
            table.insert(param_table, { separator = true, title = "Sequence Structure" })
            table.insert(param_table, { id = "lane_" .. focused_lane .. "_arpeggio_num_steps" })
            table.insert(param_table, { id = "lane_" .. focused_lane .. "_arpeggio_step_length" })
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
    
    -- Override get_param_value to handle duration parameter
    local original_get_param_value = norns_ui.get_param_value
    norns_ui.get_param_value = function(self, param)
        if param.id == "create_motif_duration" then
            local focused_lane = _seeker.ui_state.get_focused_lane()
            local lane = _seeker.lanes[focused_lane]
            if lane and lane.motif then
                -- Show custom duration if set, otherwise show genesis duration
                local duration = lane.motif.custom_duration or lane.motif.genesis.duration
                return string.format("%.2f", duration)
            end
            return "4.00" -- Default value
        end
        return original_get_param_value(self, param)
    end
    
    -- Override modify_param to handle duration parameter
    local original_modify_param = norns_ui.modify_param
    norns_ui.modify_param = function(self, param, delta)
        if param.id == "create_motif_duration" then
            local focused_lane = _seeker.ui_state.get_focused_lane()
            local lane = _seeker.lanes[focused_lane]
            if lane and lane.motif then
                -- Get current value (either custom or genesis)
                local current = lane.motif.custom_duration or lane.motif.genesis.duration
                
                -- If this is the first adjustment (no custom duration set), snap to nearest 0.25
                if not lane.motif.custom_duration then
                    current = math.floor(current * 4 + 0.5) / 4
                end
                
                local new_value = util.clamp(current + (delta * 0.25), 0.25, 128)
                
                -- Store in custom_duration to preserve genesis
                lane.motif.custom_duration = new_value
                
                -- Update the parameter value
                params:set("create_motif_duration", new_value)
                
                -- Trigger screen redraw to update visualization
                if _seeker.screen_ui then
                    _seeker.screen_ui.set_needs_redraw()
                end
            end
        else
            original_modify_param(self, param, delta)
        end
    end
    
    -- Override handle_key to add K3 reset functionality for duration
    local original_handle_key = norns_ui.handle_key
    norns_ui.handle_key = function(self, n, z)
        if n == 3 and z == 1 and self.state.selected_index > 0 then
            local param = self.params[self.state.selected_index]
            if param.id == "create_motif_duration" then
                local focused_lane = _seeker.ui_state.get_focused_lane()
                local lane = _seeker.lanes[focused_lane]
                if lane and lane.motif then
                    -- Clear custom duration to revert to genesis
                    lane.motif.custom_duration = nil
                    -- Update the parameter value to show genesis duration
                    local genesis_duration = lane.motif.genesis.duration
                    params:set("create_motif_duration", genesis_duration)
                    -- Trigger screen redraw to update visualization
                    if _seeker.screen_ui then
                        _seeker.screen_ui.set_needs_redraw()
                    end
                end
            else
                original_handle_key(self, n, z)
            end
        else
            original_handle_key(self, n, z)
        end
    end
    
    -- Override screen draw method
    norns_ui.draw_default = function(self)
        screen.clear() -- Clear once at the beginning

        -- Call the new internal method from NornsUI to draw base content
        self:_draw_standard_ui()

        -- Original create_motif drawing logic starts here
        -- Determine tooltip text
        local tooltip
        if _seeker.motif_recorder and _seeker.motif_recorder.is_recording then
            tooltip = "⏹: tap"
        else
            local focused_lane_tooltip = _seeker.ui_state.get_focused_lane()
            local motif_type = params:get("lane_" .. focused_lane_tooltip .. "_motif_type")
            local lane_tooltip = _seeker.lanes[focused_lane_tooltip]

            if motif_type == 2 then -- Arpeggio mode
                if lane_tooltip and lane_tooltip.motif and #lane_tooltip.motif.events > 0 and lane_tooltip.playing then
                    tooltip = "stage cfg: edit"
                else
                    tooltip = "⏺: hold [create]"
                end
            elseif lane_tooltip and lane_tooltip.motif and #lane_tooltip.motif.events > 0 and lane_tooltip.playing then
                tooltip = "⏺: hold [overdub]"
            else
                tooltip = "⏺: hold [record]"
            end
        end

        -- Draw piano roll visualization when motif exists or recording in progress (tape mode only)
        local focused_lane_vis = _seeker.ui_state.get_focused_lane()
        local motif_type_vis = params:get("lane_" .. focused_lane_vis .. "_motif_type")
        local show_piano_roll = false
        if motif_type_vis == 1 then
            local lane_vis = _seeker.lanes[focused_lane_vis]
            local motif_vis = lane_vis.motif

            -- Show visualization if we have a motif OR if we're currently recording
            local has_existing_motif = motif_vis and #motif_vis.events > 0
            local is_recording_new = _seeker.motif_recorder.is_recording and not _seeker.motif_recorder.original_motif

            if has_existing_motif or is_recording_new then
                show_piano_roll = true
                -- Constants for visualization
                local VIS_Y = 35
                local VIS_HEIGHT = 14
                local VIS_X = 8
                local VIS_WIDTH = 107

                -- Get the effective duration
                -- During initial recording, use elapsed time as duration
                local loop_duration
                if is_recording_new then
                    loop_duration = math.max(clock.get_beats() - _seeker.motif_recorder.start_time, 0.25)
                else
                    loop_duration = motif_vis:get_duration()
                end

                -- Draw grey background
                screen.level(2)
                screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
                screen.fill()

                -- Draw loop outline
                screen.level(3)
                screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
                screen.stroke()

                -- Draw tooltip over piano roll background, before notes
                -- Tooltip drawn here OR at end depending on piano roll visibility
                -- This ensures notes appear on top while keeping tooltip visible in all contexts
                if tooltip then
                    local width_tooltip = screen.text_extents(tooltip)

                    -- Pulse brightness when recording, otherwise static
                    if _seeker.motif_recorder.is_recording then
                        -- Pulse using sine wave synced to beats
                        local base = 10
                        local range = 5
                        local speed = 4  -- cycles per beat
                        local pulse = math.floor(math.sin(clock.get_beats() * speed) * range + base)
                        screen.level(pulse)
                    else
                        screen.level(1)
                    end

                    screen.move(64 - width_tooltip/2, 46)
                    screen.text(tooltip)
                end

                -- Find max generation and note range from existing motif
                local max_gen = 1
                local min_note = 127
                local max_note = 0

                if has_existing_motif then
                    for _, event in ipairs(motif_vis.events) do
                        if event.generation and event.generation > max_gen then
                            max_gen = event.generation
                        end
                        if event.type == "note_on" then
                            if event.note < min_note then min_note = event.note end
                            if event.note > max_note then max_note = event.note end
                        end
                    end
                end

                -- Match note_on with note_off events to show duration
                local note_pairs = {}
                if has_existing_motif then
                    for _, event in ipairs(motif_vis.events) do
                    if event.type == "note_on" then
                        -- Find matching note_off
                        local note_off_time = nil
                        for _, off_event in ipairs(motif_vis.events) do
                            if off_event.type == "note_off" and
                               off_event.note == event.note and
                               off_event.time > event.time then
                                note_off_time = off_event.time
                                break
                            end
                        end

                        table.insert(note_pairs, {
                            note = event.note,
                            start_time = event.time,
                            end_time = note_off_time or event.time,
                            generation = event.generation or 1
                        })
                    end
                    end
                end

                -- Draw note events as horizontal bars
                for _, note_pair in ipairs(note_pairs) do
                    local gen = note_pair.generation
                    local brightness = 2 + math.floor((gen / max_gen) * 10)
                    screen.level(brightness)

                    local x_start = VIS_X + (note_pair.start_time / loop_duration * VIS_WIDTH)
                    local x_end = VIS_X + (note_pair.end_time / loop_duration * VIS_WIDTH)

                    -- Map note pitch to Y position within visualization
                    if max_note > min_note then
                        local note_range = max_note - min_note
                        local note_y_offset = ((note_pair.note - min_note) / note_range) * (VIS_HEIGHT - 2)
                        local note_y = VIS_Y + VIS_HEIGHT - 1 - note_y_offset
                        screen.move(x_start, note_y)
                        screen.line(x_end, note_y)
                        screen.stroke()
                    else
                        -- Single note - draw in center
                        local note_y = VIS_Y + VIS_HEIGHT / 2
                        screen.move(x_start, note_y)
                        screen.line(x_end, note_y)
                        screen.stroke()
                    end
                end

                -- Draw live recording events
                if _seeker.motif_recorder.is_recording then
                    screen.level(15)

                    -- Find note range including recorder events
                    local recorder_min = min_note
                    local recorder_max = max_note
                    for _, event in ipairs(_seeker.motif_recorder.events) do
                        if event.type == "note_on" then
                            if event.note < recorder_min then recorder_min = event.note end
                            if event.note > recorder_max then recorder_max = event.note end
                        end
                    end

                    -- Match note pairs from recorder events
                    local recorder_note_pairs = {}
                    for _, event in ipairs(_seeker.motif_recorder.events) do
                        if event.type == "note_on" then
                            local note_off_time = nil
                            for _, off_event in ipairs(_seeker.motif_recorder.events) do
                                if off_event.type == "note_off" and
                                   off_event.note == event.note and
                                   off_event.time > event.time then
                                    note_off_time = off_event.time
                                    break
                                end
                            end

                            table.insert(recorder_note_pairs, {
                                note = event.note,
                                start_time = event.time,
                                end_time = note_off_time,
                                generation = event.generation or _seeker.motif_recorder.current_generation
                            })
                        end
                    end

                    -- Draw recorder events as bars or marks
                    for _, note_pair in ipairs(recorder_note_pairs) do
                        local x_start = VIS_X + (note_pair.start_time / loop_duration * VIS_WIDTH)

                        -- Map note to Y position using expanded range
                        if recorder_max > recorder_min then
                            local note_range = recorder_max - recorder_min
                            local note_y_offset = ((note_pair.note - recorder_min) / note_range) * (VIS_HEIGHT - 2)
                            local note_y = VIS_Y + VIS_HEIGHT - 1 - note_y_offset

                            if note_pair.end_time then
                                -- Draw horizontal bar for completed notes
                                local x_end = VIS_X + (note_pair.end_time / loop_duration * VIS_WIDTH)
                                screen.move(x_start, note_y)
                                screen.line(x_end, note_y)
                                screen.stroke()
                            else
                                -- Draw vertical mark for notes still held
                                screen.move(x_start, note_y - 1)
                                screen.line(x_start, note_y + 1)
                                screen.stroke()
                            end
                        else
                            -- Single note - draw in center
                            local note_y = VIS_Y + VIS_HEIGHT / 2
                            if note_pair.end_time then
                                local x_end = VIS_X + (note_pair.end_time / loop_duration * VIS_WIDTH)
                                screen.move(x_start, note_y)
                                screen.line(x_end, note_y)
                                screen.stroke()
                            else
                                screen.move(x_start, VIS_Y)
                                screen.line(x_start, VIS_Y + VIS_HEIGHT)
                                screen.stroke()
                            end
                        end
                    end
                end

                -- Draw playhead (only when playing existing motif, not during initial recording)
                if not is_recording_new and lane_vis.playing then
                    local current_beat = clock.get_beats()
                    local position = current_beat % loop_duration

                    local current_stage = lane_vis.stages[lane_vis.current_stage_index]
                    if current_stage and current_stage.last_start_time then
                        local elapsed_time = current_beat - current_stage.last_start_time
                        position = (elapsed_time * lane_vis.speed) % loop_duration
                    end

                    local x_playhead = VIS_X + (position / loop_duration * VIS_WIDTH)
                    screen.level(15)
                    screen.move(x_playhead, VIS_Y)
                    screen.line(x_playhead, VIS_Y + VIS_HEIGHT)
                    screen.stroke()
                end
            end
        end

        -- Draw tooltip below parameters when no piano roll shown (arpeggio mode or tape with no motif)
        if tooltip and not show_piano_roll then
            local width_tooltip = screen.text_extents(tooltip)

            -- Pulse brightness when recording, otherwise static
            if _seeker.motif_recorder.is_recording then
                -- Pulse using sine wave synced to beats
                local base = 10
                local range = 5
                local speed = 4  -- cycles per beat
                local pulse = math.floor(math.sin(clock.get_beats() * speed) * range + base)
                screen.level(pulse)
            else
                screen.level(2)
            end

            screen.move(64 - width_tooltip/2, 46)
            screen.text(tooltip)
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
        
        -- Rebuild parameters to show/hide duration based on new motif state
        if _seeker.create_motif and _seeker.create_motif.screen then
            _seeker.create_motif.screen:rebuild_params()
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
            
            -- Rebuild parameters to hide duration since motif was cleared
            if _seeker.create_motif and _seeker.create_motif.screen then
                _seeker.create_motif.screen:rebuild_params()
            end
            
            -- Start new recording
            _seeker.motif_recorder:set_recording_mode(1) -- Set to regular recording mode
            _seeker.motif_recorder:start_recording(nil)
        end
        
        _seeker.screen_ui.set_needs_redraw()
    end
    
    -- Helper function for arpeggio mode - instant snapshot of current pattern
    -- Note: Arpeggio mode never supports overdubbing - always starts fresh
    local function handle_arpeggio_recording_start(self)
        local focused_lane_idx = _seeker.ui_state.get_focused_lane()
        local current_lane = _seeker.lanes[focused_lane_idx]

        -- Always clear the current motif (no overdubbing in arpeggio mode)
        current_lane:clear()

        -- Rebuild parameters to hide duration since motif was cleared
        if _seeker.create_motif and _seeker.create_motif.screen then
            _seeker.create_motif.screen:rebuild_params()
        end

        -- Generate arpeggio from current step pattern using Stage 1 parameters
        -- ARCHITECTURE NOTE: Arpeggio uses generator pattern (params → motif)
        -- not recorder pattern (real-time input → motif)
        local arpeggio_motif = arpeggio_sequence.generate_motif(focused_lane_idx, 1)

        if arpeggio_motif and arpeggio_motif.events and #arpeggio_motif.events > 0 then
            -- Set the motif and start playback
            current_lane:set_motif(arpeggio_motif)
            current_lane:play()

            print(string.format("✓ Arpeggio motif created: %d events, duration %.2f",
                #arpeggio_motif.events, arpeggio_motif.duration))
        else
            print("⚠ No active steps to create arpeggio motif")
        end

        -- Rebuild parameters to show duration based on new motif state
        if _seeker.create_motif and _seeker.create_motif.screen then
            _seeker.create_motif.screen:rebuild_params()
        end

        _seeker.screen_ui.set_needs_redraw()
    end

    local function handle_arpeggio_recording_stop(self)
        -- Arpeggio mode completes immediately in start function - nothing to do here
    end
    
    -- Helper function to draw count display when recording
    local function draw_count_display(self, layers)
        -- Use quarter-note subdivisions for metronome
        local current_quarter = math.floor(clock.get_beats()) % 4

        -- Count display coordinates
        local count_display = {
            x_start = 7,
            x_end = 10,
            y = 1
        }

        -- Set all count LEDs to low brightness
        for x_count = count_display.x_start, count_display.x_end do
            layers.ui[x_count][count_display.y] = GridConstants.BRIGHTNESS.LOW
        end

        -- Determine which position should be highlighted (moves every beat)
        local highlight_x = count_display.x_start + current_quarter

        -- Sharp attack with quick exponential decay
        local beat_phase = clock.get_beats() % 1
        local brightness
        if beat_phase < 0.25 then
            local decay = math.exp(-beat_phase * 12)
            local range = GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.LOW
            brightness = math.floor(GridConstants.BRIGHTNESS.LOW + range * decay)
        else
            brightness = GridConstants.BRIGHTNESS.LOW
        end
        layers.ui[highlight_x][count_display.y] = brightness
    end
    
    -- Override draw to add keyboard outline during long press
    grid_ui.draw = function(self, layers)
        local x = self.layout.x
        local y = self.layout.y
        local brightness = (_seeker.ui_state.get_current_section() == self.id) and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL

        -- Draw keyboard outline during long press (same for both modes)
        if self:is_holding_long_press() then
            self:draw_keyboard_outline_highlight(layers)
        end

        -- Draw count display when recording (same for both modes)
        if _seeker.motif_recorder.is_recording then
            draw_count_display(self, layers)

            -- Pulse button smoothly while recording
            local base = GridConstants.BRIGHTNESS.UI.NORMAL
            local range = 3
            local speed = 4  -- cycles per beat
            brightness = math.floor(math.sin(clock.get_beats() * speed) * range + base + range)
        end

        layers.ui[x][y] = brightness
    end

    -- Override handle_key to implement recording functionality
    grid_ui.handle_key = function(self, x, y, z)
        local focused_lane_key = _seeker.ui_state.get_focused_lane()
        local motif_type = params:get("lane_" .. focused_lane_key .. "_motif_type")
        local key_id = string.format("%d,%d", x, y)

        if z == 1 then -- Key pressed
            self:key_down(key_id)
            handle_key_press(self)
        else -- Key released
            -- Handle recording stop logic based on mode
            if _seeker.motif_recorder.is_recording then
                if motif_type == 1 then -- Tape mode
                    handle_tape_recording_stop(self)
                elseif motif_type == 2 then -- Arpeggio mode
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