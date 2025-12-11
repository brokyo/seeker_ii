-- creator.lua
-- Sampler type: motif creation via recording pad triggers
-- Handles the Create Motif button, screen UI, and recording flow
-- Part of lib/modes/motif/types/sampler/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local SamplerCreator = {}
SamplerCreator.__index = SamplerCreator

local function create_params()
    params:add_group("sampler_creator", "SAMPLER CREATOR", 1)

    params:add_control("sampler_creator_duration", "Duration",
        controlspec.new(0.25, 128, 'lin', 0.25, 4, "beats", 0.25 / 128))
    params:set_action("sampler_creator_duration", function(value)
        local focused_lane = _seeker.ui_state.get_focused_lane()
        if _seeker.lanes[focused_lane] and _seeker.lanes[focused_lane].motif then
            if value == 0 then
                _seeker.lanes[focused_lane].motif.custom_duration = nil
            else
                _seeker.lanes[focused_lane].motif.custom_duration = value
            end
            if _seeker.screen_ui then
                _seeker.screen_ui.set_needs_redraw()
            end
        end
    end)
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "SAMPLER_CREATOR",
        name = "Create",
        description = "Record pad triggers as a looping motif. Load samples via Lane Config.",
        params = {
            { separator = true, title = "Sampler" }
        }
    })

    norns_ui.rebuild_params = function(self)
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[focused_lane]

        local param_table = {
            { separator = true, title = "Motif Configuration" }
        }

        -- Show duration param only when there's an active motif
        if lane and lane.motif and #lane.motif.events > 0 then
            table.insert(param_table, { id = "sampler_creator_duration" })
        end

        self.params = param_table
    end

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        original_enter(self)
        self:rebuild_params()
    end

    -- Override get_param_value for duration display
    local original_get_param_value = norns_ui.get_param_value
    norns_ui.get_param_value = function(self, param)
        if param.id == "sampler_creator_duration" then
            local focused_lane = _seeker.ui_state.get_focused_lane()
            local lane = _seeker.lanes[focused_lane]
            if lane and lane.motif then
                local duration = lane.motif.custom_duration or lane.motif.genesis.duration
                return string.format("%.2f", duration)
            end
            return "4.00"
        end
        return original_get_param_value(self, param)
    end

    -- Override modify_param for duration adjustment
    local original_modify_param = norns_ui.modify_param
    norns_ui.modify_param = function(self, param, delta)
        if param.id == "sampler_creator_duration" then
            local focused_lane = _seeker.ui_state.get_focused_lane()
            local lane = _seeker.lanes[focused_lane]
            if lane and lane.motif then
                local current = lane.motif.custom_duration or lane.motif.genesis.duration
                if not lane.motif.custom_duration then
                    current = math.floor(current * 4 + 0.5) / 4
                end
                local new_value = util.clamp(current + (delta * 0.25), 0.25, 128)
                lane.motif.custom_duration = new_value
                params:set("sampler_creator_duration", new_value)
                if _seeker.screen_ui then
                    _seeker.screen_ui.set_needs_redraw()
                end
            end
        else
            original_modify_param(self, param, delta)
        end
    end

    -- Override handle_key for K3 duration reset
    local original_handle_key = norns_ui.handle_key
    norns_ui.handle_key = function(self, n, z)
        if n == 3 and z == 1 and self.state.selected_index > 0 then
            local param = self.params[self.state.selected_index]
            if param.id == "sampler_creator_duration" then
                local focused_lane = _seeker.ui_state.get_focused_lane()
                local lane = _seeker.lanes[focused_lane]
                if lane and lane.motif then
                    lane.motif.custom_duration = nil
                    local genesis_duration = lane.motif.genesis.duration
                    params:set("sampler_creator_duration", genesis_duration)
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

    -- Enable continuous refresh during playback (for visualization)
    norns_ui.needs_playback_refresh = true

    -- Custom draw with sampler visualization
    norns_ui.draw_default = function(self)
        screen.clear()
        self:_draw_standard_ui()

        local focused_lane = _seeker.ui_state.get_focused_lane()
        local lane = _seeker.lanes[focused_lane]

        -- Determine tooltip
        local tooltip
        if _seeker.motif_recorder and _seeker.motif_recorder.is_recording then
            tooltip = "stop: tap"
        elseif _seeker.sampler and _seeker.sampler.has_buffer(focused_lane) then
            local duration = _seeker.sampler.get_sample_duration(focused_lane)
            tooltip = string.format("loaded: %.1fs", duration)
        else
            tooltip = "load file: K3"
        end

        -- Draw visualization when we have a motif or are recording
        local show_visualization = false
        if not self.state.showing_description then
            local motif = lane and lane.motif
            local has_existing_motif = motif and #motif.events > 0
            local is_recording_new = _seeker.motif_recorder.is_recording and not _seeker.motif_recorder.original_motif

            if has_existing_motif or is_recording_new then
                show_visualization = true

                local VIS_Y = 35
                local VIS_HEIGHT = 14
                local VIS_X = 8
                local VIS_WIDTH = 107

                -- Get loop duration
                local loop_duration
                if is_recording_new then
                    loop_duration = math.max(clock.get_beats() - _seeker.motif_recorder.start_time, 0.25)
                else
                    loop_duration = motif:get_duration()
                end

                -- Draw background
                screen.level(2)
                screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
                screen.fill()

                -- Draw outline
                screen.level(3)
                screen.rect(VIS_X, VIS_Y, VIS_WIDTH, VIS_HEIGHT)
                screen.stroke()

                -- Draw tooltip over background
                if tooltip and not self.state.showing_description then
                    local width_tooltip = screen.text_extents(tooltip)
                    if _seeker.motif_recorder.is_recording then
                        local base = 10
                        local range = 5
                        local speed = 4
                        local pulse = math.floor(math.sin(clock.get_beats() * speed) * range + base)
                        screen.level(pulse)
                    else
                        screen.level(1)
                    end
                    screen.move(64 - width_tooltip/2, 46)
                    screen.text(tooltip)
                end

                -- Find max generation from existing motif
                local max_gen = 1
                if has_existing_motif then
                    for _, event in ipairs(motif.events) do
                        if event.generation and event.generation > max_gen then
                            max_gen = event.generation
                        end
                    end
                end

                -- Match note_on with note_off events
                local note_pairs = {}
                if has_existing_motif then
                    for _, event in ipairs(motif.events) do
                        if event.type == "note_on" then
                            local note_off_time = nil
                            for _, off_event in ipairs(motif.events) do
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

                -- Draw existing note events as 4-row grouped blocks
                for _, event_pair in ipairs(note_pairs) do
                    local gen = event_pair.generation
                    local brightness = 2 + math.floor((gen / max_gen) * 10)
                    screen.level(brightness)

                    local x_start = VIS_X + (event_pair.start_time / loop_duration * VIS_WIDTH)
                    local clamped_end = math.min(event_pair.end_time, loop_duration)
                    local x_end = VIS_X + (clamped_end / loop_duration * VIS_WIDTH)

                    -- Sampler: 4 rows grouped by pad number (1-4, 5-8, 9-12, 13-16)
                    local pad = event_pair.note
                    local row = math.floor((pad - 1) / 4)
                    local row_height = VIS_HEIGHT / 4
                    local row_y = VIS_Y + (row * row_height)
                    screen.rect(x_start, row_y, math.max(x_end - x_start, 1), row_height - 1)
                    screen.fill()
                end

                -- Draw live recording events
                if _seeker.motif_recorder.is_recording then
                    screen.level(15)

                    local recorder_note_pairs = {}
                    local current_gen = _seeker.motif_recorder.current_generation
                    for _, event in ipairs(_seeker.motif_recorder.events) do
                        local event_gen = event.generation or current_gen
                        if event.type == "note_on" and event_gen == current_gen then
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
                                generation = event_gen
                            })
                        end
                    end

                    for _, event_pair in ipairs(recorder_note_pairs) do
                        local x_start = VIS_X + (event_pair.start_time / loop_duration * VIS_WIDTH)
                        local pad = event_pair.note
                        local row = math.floor((pad - 1) / 4)
                        local row_height = VIS_HEIGHT / 4
                        local row_y = VIS_Y + (row * row_height)

                        if event_pair.end_time then
                            local clamped_end = math.min(event_pair.end_time, loop_duration)
                            local x_end = VIS_X + (clamped_end / loop_duration * VIS_WIDTH)
                            screen.rect(x_start, row_y, math.max(x_end - x_start, 1), row_height - 1)
                            screen.fill()
                        else
                            screen.move(x_start, row_y)
                            screen.line(x_start, row_y + row_height - 1)
                            screen.stroke()
                        end
                    end
                end

                -- Draw playhead when playing
                if not is_recording_new and lane.playing then
                    local current_beat = clock.get_beats()
                    local position = current_beat % loop_duration

                    local current_stage = lane.stages[lane.current_stage_index]
                    if current_stage and current_stage.last_start_time then
                        local elapsed_time = current_beat - current_stage.last_start_time
                        position = (elapsed_time * lane.speed) % loop_duration
                    end

                    local x_playhead = VIS_X + (position / loop_duration * VIS_WIDTH)
                    screen.level(15)
                    screen.move(x_playhead, VIS_Y)
                    screen.line(x_playhead, VIS_Y + VIS_HEIGHT)
                    screen.stroke()
                end
            end
        end

        -- Draw tooltip below params when no visualization
        if tooltip and not show_visualization and not self.state.showing_description then
            local width_tooltip = screen.text_extents(tooltip)
            if _seeker.motif_recorder.is_recording then
                local base = 10
                local range = 5
                local speed = 4
                local pulse = math.floor(math.sin(clock.get_beats() * speed) * range + base)
                screen.level(pulse)
            else
                screen.level(2)
            end
            screen.move(64 - width_tooltip/2, 46)
            screen.text(tooltip)
        end

        screen.update()
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "SAMPLER_CREATOR",
        layout = {
            x = 2,
            y = 7,
            width = 1,
            height = 1
        }
    })

    -- Recording start helper
    local function handle_recording_start(self)
        local focused_lane_idx = _seeker.ui_state.get_focused_lane()
        local current_lane = _seeker.lanes[focused_lane_idx]
        local existing_motif = current_lane.motif

        if existing_motif and #existing_motif.events > 0 and current_lane.playing then
            -- Overdub existing motif
            _seeker.motif_recorder:set_recording_mode(2)
            _seeker.motif_recorder:start_recording(existing_motif)
        else
            -- Start new recording
            current_lane:clear()

            if _seeker.sampler_creator and _seeker.sampler_creator.screen then
                _seeker.sampler_creator.screen:rebuild_params()
            end

            _seeker.motif_recorder:set_recording_mode(1)
            _seeker.motif_recorder:start_recording(nil)
        end

        _seeker.screen_ui.set_needs_redraw()
    end

    -- Recording stop helper
    local function handle_recording_stop(self)
        local focused_lane_idx = _seeker.ui_state.get_focused_lane()
        local current_lane = _seeker.lanes[focused_lane_idx]

        local was_overdubbing = (_seeker.motif_recorder.original_motif ~= nil)
        local recorded_motif = _seeker.motif_recorder:stop_recording()
        current_lane:set_motif(recorded_motif)

        if not was_overdubbing then
            current_lane:play()
        end

        if _seeker.sampler_creator and _seeker.sampler_creator.screen then
            _seeker.sampler_creator.screen:rebuild_params()
        end

        _seeker.screen_ui.set_needs_redraw()
    end

    -- Count display helper
    local function draw_count_display(self, layers)
        local current_quarter = math.floor(clock.get_beats()) % 4

        local count_display = {
            x_start = 7,
            x_end = 10,
            y = 1
        }

        for x_count = count_display.x_start, count_display.x_end do
            layers.ui[x_count][count_display.y] = GridConstants.BRIGHTNESS.LOW
        end

        local highlight_x = count_display.x_start + current_quarter
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

    grid_ui.draw = function(self, layers)
        local x = self.layout.x
        local y = self.layout.y
        local brightness = (_seeker.ui_state.get_current_section() == self.id) and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL

        if self:is_holding_long_press() then
            self:draw_keyboard_outline_highlight(layers)
        end

        if _seeker.motif_recorder.is_recording then
            draw_count_display(self, layers)

            local base = GridConstants.BRIGHTNESS.UI.NORMAL
            local range = 3
            local speed = 4
            brightness = math.floor(math.sin(clock.get_beats() * speed) * range + base + range)
        end

        layers.ui[x][y] = brightness
    end

    grid_ui.handle_key = function(self, x, y, z)
        local key_id = string.format("%d,%d", x, y)

        if z == 1 then
            self:key_down(key_id)
            _seeker.ui_state.set_current_section("SAMPLER_CREATOR")
            _seeker.ui_state.set_long_press_state(true, "SAMPLER_CREATOR")
            _seeker.screen_ui.set_needs_redraw()
        else
            if _seeker.motif_recorder.is_recording then
                handle_recording_stop(self)
            elseif self:is_long_press(key_id) then
                handle_recording_start(self)
            end

            _seeker.ui_state.set_long_press_state(false, nil)
            _seeker.screen_ui.set_needs_redraw()
            self:key_release(key_id)
        end
    end

    return grid_ui
end

function SamplerCreator.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()

    return component
end

return SamplerCreator
