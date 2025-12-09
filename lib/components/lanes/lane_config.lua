-- lane_config.lua
-- Self-contained component for Lane configuration following the component pattern

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

-- Voice parameter modules
local voice_mx_samples = include("lib/components/lanes/voices/mx_samples")
local voice_midi = include("lib/components/lanes/voices/midi")
local voice_crow_txo = include("lib/components/lanes/voices/crow_txo")
local voice_just_friends = include("lib/components/lanes/voices/just_friends")
local voice_wsyn = include("lib/components/lanes/voices/wsyn")
local voice_osc = include("lib/components/lanes/voices/osc")
local voice_disting = include("lib/components/lanes/voices/disting")

-- Motif type constants
local MOTIF_TYPE_TAPE = 1
local MOTIF_TYPE_COMPOSER = 2
local MOTIF_TYPE_SAMPLER = 3

local LaneConfig = {}
LaneConfig.__index = LaneConfig

local function create_params()
    -- Global sampler voice count (shared across all lanes)
    params:add_number("sampler_voice_count", "Sampler Voices", 1, 6, 6)
    params:set_action("sampler_voice_count", function(value)
        if _seeker and _seeker.sampler then
            _seeker.sampler.num_voices = value
        end
    end)

    -- Create parameters for all lanes
    for i = 1, 8 do
        params:add_group("lane_" .. i, "LANE " .. i .. " VOICES", 81)

        -- Config Voice selector
        params:add_option("lane_" .. i .. "_visible_voice", "Config Voice",
            {"MX Samples", "MIDI", "Crow/TXO", "Just Friends", "w/syn", "OSC", "Disting"})
        params:set_action("lane_" .. i .. "_visible_voice", function(value)
            _seeker.lane_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Create all voice-specific parameters
        voice_mx_samples.create_params(i)
        voice_midi.create_params(i)
        voice_crow_txo.create_params(i)
        voice_just_friends.create_params(i)
        voice_wsyn.create_params(i)
        voice_osc.create_params(i)
        voice_disting.create_params(i)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "LANE_CONFIG",
        name = "Lane 1",
        icon = "⌸",
        description = "Voice configuration. Multiple voices can run simultaneously",
        params = {}
    })
    
    -- Override enter method to build initial params
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end
    
    -- Dynamic parameter rebuilding based on current focused lane
    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local motif_type = params:get("lane_" .. lane_idx .. "_motif_type")
        local visible_voice = params:get("lane_" .. lane_idx .. "_visible_voice")

        -- Update section name with current lane
        self.name = string.format("Lane %d", lane_idx)

        -- Start with volume and motif type (always visible)
        local param_table = {
            { separator = true, title = string.format("Lane %d Config", lane_idx) },
            { id = "lane_" .. lane_idx .. "_volume", arc_multi_float = {0.1, 0.05, 0.01} },
            { id = "lane_" .. lane_idx .. "_motif_type" }
        }

        -- Sampler mode loads audio files directly (no voice routing needed)
        if motif_type == MOTIF_TYPE_SAMPLER then
            table.insert(param_table, { separator = true, title = "Sampler Settings" })
            table.insert(param_table, { id = "sampler_voice_count" })
            table.insert(param_table, { separator = true, title = "Sample Source" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sample_file", is_action = true })

            -- Show recording state in param name and icon
            if _seeker.sampler and _seeker.sampler.is_recording then
                table.insert(param_table, {
                    id = "lane_" .. lane_idx .. "_record_sample",
                    is_action = true,
                    custom_name = "Recording Sample",
                    custom_value = "●"
                })
            else
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_record_sample", is_action = true })
            end
        else -- Tape/Composer modes require voice routing to play notes
            table.insert(param_table, { separator = true, title = "Voice Routing" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_visible_voice" })

            -- Add params based on visible voice selection
            if visible_voice == 1 then -- MX Samples
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_mx_samples_active" })

            -- Only show additional MX Samples params if active
            if params:get("lane_" .. lane_idx .. "_mx_samples_active") == 1 then
                table.insert(param_table, { separator = true, title = "Voice Settings" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_mx_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_instrument" })
                table.insert(param_table, { separator = true, title = "Individual Event" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_pan", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_attack", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_decay", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sustain", arc_multi_float = {0.5, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_release", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { separator = true, title = "Lane Effects" })
                table.insert(param_table, {
                    id = "lane_" .. lane_idx .. "_lpf",
                    arc_multi_float = {1000, 100, 10}
                })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_resonance", arc_multi_float = {0.5, 0.1, 0.05} })
                table.insert(param_table, {
                    id = "lane_" .. lane_idx .. "_hpf",
                    arc_multi_float = {1000, 100, 10}
                })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_delay_send", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_reverb_send", arc_multi_float = {0.1, 0.05, 0.01} })
            end
        elseif visible_voice == 2 then -- MIDI
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_midi_active" })

            -- Only show additional MIDI params if active
            if params:get("lane_" .. lane_idx .. "_midi_active") == 1 then
                table.insert(param_table, { separator = true, title = "Voice Settings" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_midi_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_midi_device" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_midi_channel" })
            end
        elseif visible_voice == 3 then -- CV/Gate via i2c
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_eurorack_active" })

            -- Only show additional Crow/TXO params if active
            if params:get("lane_" .. lane_idx .. "_eurorack_active") == 1 then
                table.insert(param_table, { separator = true, title = "Voice Settings" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_euro_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_gate_out" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_cv_out" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_loop_start_trigger" })
            end
        elseif visible_voice == 4 then -- Just Friends
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_just_friends_active" })

            -- Only show additional Just Friends params if active
            if params:get("lane_" .. lane_idx .. "_just_friends_active") == 1 then
                table.insert(param_table, { separator = true, title = "Voice Settings" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_just_friends_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_just_friends_voice_select" })
            end
        elseif visible_voice == 5 then -- w/syn
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_active" })

            -- Only show additional w/syn params if active
            if params:get("lane_" .. lane_idx .. "_wsyn_active") == 1 then
                table.insert(param_table, { separator = true, title = "Voice Settings" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_voice_select" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_ar_mode" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_curve", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_ramp", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_fm_index", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_fm_env", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_fm_ratio_num", arc_multi_float = {0.1, 0.01, 0.001} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_fm_ratio_denom", arc_multi_float = {0.1, 0.01, 0.001} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_lpg_time", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_lpg_symmetry", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { separator = true, title = "CV Patching" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_patch_this" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_patch_that" })
            end
        elseif visible_voice == 6 then -- OSC
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_osc_active" })
        elseif visible_voice == 7 then -- Disting
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_active" })

            -- Only show additional Disting params if active
            if params:get("lane_" .. lane_idx .. "_disting_active") == 1 then
                table.insert(param_table, { separator = true, title = "Voice Settings" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_algorithm" })

                -- Multisample Params
                if params:get("lane_" .. lane_idx .. "_disting_algorithm") == 1 then
                    table.insert(param_table, { separator = true, title = "Multisample Params" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_sample_folder" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_attack", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_decay", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_sustain", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_release", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_gain", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_delay_mode" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_delay_level", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_delay_time", arc_multi_float = {100, 50, 10} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_tone_bass", arc_multi_float = {50, 10, 5} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_tone_treble", arc_multi_float = {50, 10, 5} })
                end
                -- Rings Params
                if params:get("lane_" .. lane_idx .. "_disting_algorithm") == 2 then
                    table.insert(param_table, { separator = true, title = "Rings Params" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_mode" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_effect" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_polyphony" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_structure", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_brightness", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_damping", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_position", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_output_gain", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_dry_gain", arc_multi_float = {10, 5, 1} })
                end

                -- Plaits Params
                if params:get("lane_" .. lane_idx .. "_disting_algorithm") == 3 then
                    table.insert(param_table, { separator = true, title = "Plaits Params" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_voice_select" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_output" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_model" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_harmonics", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_timbre", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_morph", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_fm", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_timbre_mod", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_morph_mod", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_low_pass_gate", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_time", arc_multi_float = {10, 5, 1} })
                end
                -- DX 7 Params
                if params:get("lane_" .. lane_idx .. "_disting_algorithm") == 4 then
                    table.insert(param_table, { separator = true, title = "DX 7 Params" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_bank" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_gain", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_pan", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_brightness", arc_multi_float = {10, 5, 1} })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_morph", arc_multi_float = {10, 5, 1} })
                end
            end
        end
        end -- Close else block for tape/composer voice params

        -- Update the UI with the new parameter table
        self.params = param_table
        self:filter_active_params()
    end

    -- Override draw to show recording/fileselect overlays
    norns_ui.draw = function(self)
        -- Draw standard UI
        self:draw_default()

        -- Check if recording and draw overlay
        if _seeker.sampler and _seeker.sampler.recording_state then
            local message = _seeker.sampler.recording_state == "recording" and "RECORDING" or "SAVING"

            -- Dark background
            screen.level(1)
            screen.rect(0, 0, 128, 64)
            screen.fill()

            -- Border box
            screen.level(15)
            screen.rect(10, 20, 108, 24)
            screen.stroke()

            -- Main message (large, centered)
            screen.level(15)
            screen.move(64, 32)
            screen.font_face(1)
            screen.font_size(16)
            screen.text_center(message)

            -- Instruction (smaller, centered below)
            if _seeker.sampler.recording_state == "recording" then
                screen.font_size(8)
                screen.move(64, 42)
                screen.text_center("k3 to stop")
            end

            -- Reset font size
            screen.font_size(8)

            -- Push overlay to display
            screen.update()

        -- Check if fileselect is active and draw overlay
        elseif _seeker.sampler and _seeker.sampler.file_select_active then
            -- Dark background
            screen.level(1)
            screen.rect(0, 0, 128, 64)
            screen.fill()

            -- Border box
            screen.level(15)
            screen.rect(10, 16, 108, 32)
            screen.stroke()

            -- Main message (large, centered)
            screen.level(15)
            screen.move(64, 30)
            screen.font_face(1)
            screen.font_size(12)
            screen.text_center("FILE SELECT")

            -- Instruction (smaller, centered below)
            screen.font_size(8)
            screen.move(64, 42)
            screen.text_center("use norns e2/e3/k3")

            -- Reset font size
            screen.font_size(8)

            -- Push overlay to display
            screen.update()
        end
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "LANE_CONFIG",
        layout = {
            x = 13,
            y = 6,
            width = 4,
            height = 2
        }
    })
    
    -- Flash state for visual feedback
    grid_ui.flash_state = {
        flash_until = nil
    }
    
    -- Override draw method to handle lane display and flash feedback
    function grid_ui:draw(layers)
        local is_lane_section = _seeker.ui_state.get_current_section() == "LANE_CONFIG"
        
        -- Draw keyboard outline during lane switch flash
        if self.flash_state.flash_until and util.time() < self.flash_state.flash_until then
            -- Top and bottom rows
            for x = 0, 5 do
                layers.response[6 + x][2] = GridConstants.BRIGHTNESS.HIGH
                layers.response[6 + x][7] = GridConstants.BRIGHTNESS.HIGH
            end
            -- Left and right columns
            for y = 0, 5 do
                layers.response[6][2 + y] = GridConstants.BRIGHTNESS.HIGH
                layers.response[11][2 + y] = GridConstants.BRIGHTNESS.HIGH
            end
        end
        
        -- Draw lane buttons
        for row = 0, self.layout.height - 1 do
            for i = 0, self.layout.width - 1 do
                local lane_idx = (row * self.layout.width) + i + 1
                local is_focused = lane_idx == _seeker.ui_state.get_focused_lane()
                local lane = _seeker.lanes[lane_idx]
                
                local brightness
                if is_lane_section and is_focused then
                    brightness = GridConstants.BRIGHTNESS.FULL
                elseif lane.playing then
                    -- Pulsing bright when playing, unless focused
                    brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
                elseif is_lane_section then
                    brightness = GridConstants.BRIGHTNESS.MEDIUM
                else
                    brightness = GridConstants.BRIGHTNESS.LOW
                end
                
                layers.ui[self.layout.x + i][self.layout.y + row] = brightness
            end
        end
    end
    
    -- Override handle_key to manage lane selection
    function grid_ui:handle_key(x, y, z)
        if not self:contains(x, y) then
            return false
        end
        
        local row = y - self.layout.y
        local new_lane_idx = (row * self.layout.width) + (x - self.layout.x) + 1
        local key_id = string.format("%d,%d", x, y)
        
        if z == 1 then -- Key pressed
            -- Use GridUI base class key tracking for long press detection
            self:key_down(key_id)
            
            -- Always focus the lane on press
            _seeker.ui_state.set_focused_lane(new_lane_idx)
            _seeker.ui_state.set_current_section("LANE_CONFIG")
            
            -- Update screen UI to reflect new lane
            _seeker.lane_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
            
            -- Start flash effect (0.15 seconds)
            self.flash_state.flash_until = util.time() + 0.15
            
        else -- Key released
            -- Only toggle playback on long press
            if self:is_long_press(key_id) then
                local lane = _seeker.lanes[new_lane_idx]
                if lane.playing then
                    lane:stop()
                else
                    lane:play()
                end
            end
            
            -- Clean up key tracking
            self:key_release(key_id)
        end
        
        return true
    end
    
    return grid_ui
end

function LaneConfig.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    
    return component
end

return LaneConfig