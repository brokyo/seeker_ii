-- lane_config.lua
-- Lane configuration: motif type selection (Tape/Composer/Sampler) and voice routing
-- Each lane can output to multiple voices simultaneously (MX Samples, MIDI, Crow, Just Friends, etc.)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

-- Use global Modal singleton
local function get_modal()
  return _seeker and _seeker.modal
end

-- Voice parameter modules
local voice_mx_samples = include("lib/modes/motif/infrastructure/voices/mx_samples")
local voice_midi = include("lib/modes/motif/infrastructure/voices/midi")
local voice_crow_txo = include("lib/modes/motif/infrastructure/voices/crow_txo")
local voice_just_friends = include("lib/modes/motif/infrastructure/voices/just_friends")
local voice_wsyn = include("lib/modes/motif/infrastructure/voices/wsyn")
local voice_osc = include("lib/modes/motif/infrastructure/voices/osc")
local voice_disting = include("lib/modes/motif/infrastructure/voices/disting")

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
        params:add_group("lane_" .. i, "LANE " .. i .. " VOICES", 89)

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

        -- Global sampler filter (applies to all chops in lane)
        local lane_idx = i  -- Capture for closures
        params:add_option("lane_" .. i .. "_sampler_filter_type", "Filter Type",
            {"Off", "Lowpass", "Highpass", "Bandpass", "Notch"}, 1)
        params:set_action("lane_" .. i .. "_sampler_filter_type", function()
            if _seeker.sampler then _seeker.sampler.apply_global_filter(lane_idx) end
            _seeker.lane_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)

        params:add_taper("lane_" .. i .. "_sampler_lpf", "LPF Cutoff", 20, 20000, 20000, 3, "Hz")
        params:set_action("lane_" .. i .. "_sampler_lpf", function()
            if _seeker.sampler then _seeker.sampler.apply_global_filter(lane_idx) end
        end)

        params:add_taper("lane_" .. i .. "_sampler_hpf", "HPF Cutoff", 20, 20000, 20, 3, "Hz")
        params:set_action("lane_" .. i .. "_sampler_hpf", function()
            if _seeker.sampler then _seeker.sampler.apply_global_filter(lane_idx) end
        end)

        params:add_control("lane_" .. i .. "_sampler_resonance", "Resonance",
            controlspec.new(0, 4, 'lin', 0.01, 0, ""))
        params:set_action("lane_" .. i .. "_sampler_resonance", function()
            if _seeker.sampler then _seeker.sampler.apply_global_filter(lane_idx) end
        end)

        -- Global sampler envelope (applies to all chops in lane)
        params:add_control("lane_" .. i .. "_sampler_attack", "Attack",
            controlspec.new(0, 2, 'lin', 0.01, 0.01, "s"))
        params:set_action("lane_" .. i .. "_sampler_attack", function()
            if _seeker.sampler then _seeker.sampler.apply_global_envelope(lane_idx) end
        end)

        params:add_control("lane_" .. i .. "_sampler_release", "Release",
            controlspec.new(0, 2, 'lin', 0.01, 0.01, "s"))
        params:set_action("lane_" .. i .. "_sampler_release", function()
            if _seeker.sampler then _seeker.sampler.apply_global_envelope(lane_idx) end
        end)

        -- ADSR visual editor trigger (for MX Samples voice)
        params:add_trigger("lane_" .. i .. "_adsr_visual_edit", "Visual Edit")
        params:set_action("lane_" .. i .. "_adsr_visual_edit", function()
            local Modal = get_modal()
            if not Modal then return end

            local idx = lane_idx

            -- Get current ADSR values for visualization
            -- Sustain is normalized from 0-2 range to 0-1 for modal visualization
            local function get_adsr_data()
                return {
                    a = params:get("lane_" .. idx .. "_attack"),
                    d = params:get("lane_" .. idx .. "_decay"),
                    s = params:get("lane_" .. idx .. "_sustain") / 2,
                    r = params:get("lane_" .. idx .. "_release")
                }
            end

            -- ADSR param IDs mapped to stages (1=A, 2=D, 3=S, 4=R)
            local adsr_params = {
                "lane_" .. idx .. "_attack",
                "lane_" .. idx .. "_decay",
                "lane_" .. idx .. "_sustain",
                "lane_" .. idx .. "_release"
            }

            -- Step sizes for each ADSR stage: {coarse, medium, fine} for encoders 2/3/4
            local adsr_step_sizes = {
                {0.5, 0.1, 0.01},   -- Attack (0-10s)
                {0.5, 0.1, 0.01},   -- Decay (0-10s)
                {0.2, 0.05, 0.01},  -- Sustain (0-2)
                {1.0, 0.5, 0.1}     -- Release (0-10s)
            }

            -- Adjust the selected ADSR parameter using encoder-specific step sizes
            local function adjust_adsr(encoder, delta)
                local stage = Modal.get_adsr_selected()
                local param_id = adsr_params[stage]
                local steps = adsr_step_sizes[stage]
                -- Encoder 2=coarse, 3=medium, 4=fine
                local step = steps[encoder - 1]
                if step then
                    local current = params:get(param_id)
                    local new_val = current + (delta * step)
                    params:set(param_id, new_val)
                end
                if _seeker.arc and _seeker.arc.update_adsr_display then
                    _seeker.arc.update_adsr_display()
                end
            end

            -- Key handler: K3 saves and dismisses, K2 cancels
            local function on_key(n, z)
                if z == 1 then
                    if n == 2 or n == 3 then
                        Modal.dismiss()
                        _seeker.screen_ui.set_needs_redraw()
                        return true
                    end
                end
                return false
            end

            -- Accumulate Arc encoder 1 movements to prevent accidental selection changes
            local selector_accumulator = 0
            local SELECTOR_THRESHOLD = 12

            -- Encoder handler: Arc ring 1 selects stage, rings 2-4 adjust; Norns E2 selects, E3 adjusts
            local function on_enc(n, d, source)
                if source == "arc" then
                    if n == 1 then
                        -- Select stage after enough rotation
                        selector_accumulator = selector_accumulator + d
                        if math.abs(selector_accumulator) >= SELECTOR_THRESHOLD then
                            local direction = selector_accumulator > 0 and 1 or -1
                            selector_accumulator = 0
                            local current = Modal.get_adsr_selected()
                            local new_sel = util.clamp(current + direction, 1, 4)
                            Modal.set_adsr_selected(new_sel)
                            if _seeker.arc and _seeker.arc.update_adsr_display then
                                _seeker.arc.update_adsr_display()
                            end
                            _seeker.screen_ui.set_needs_redraw()
                        end
                        return true
                    elseif n >= 2 and n <= 4 then
                        -- Adjust selected stage with coarse/medium/fine steps
                        adjust_adsr(n, d)
                        _seeker.screen_ui.set_needs_redraw()
                        return true
                    end
                else
                    -- Norns E2: select stage, E3: adjust selected value (medium step)
                    if n == 2 then
                        local current = Modal.get_adsr_selected()
                        local new_sel = util.clamp(current + util.round(d), 1, 4)
                        Modal.set_adsr_selected(new_sel)
                        if _seeker.arc and _seeker.arc.update_adsr_display then
                            _seeker.arc.update_adsr_display()
                        end
                        _seeker.screen_ui.set_needs_redraw()
                        return true
                    elseif n == 3 then
                        -- Use medium step for Norns encoder
                        adjust_adsr(3, d)
                        _seeker.screen_ui.set_needs_redraw()
                        return true
                    end
                end
                return false
            end

            Modal.show_adsr({
                get_data = get_adsr_data,
                param_ids = adsr_params,
                on_key = on_key,
                on_enc = on_enc,
                hint = "e2 select e3 change k3 set"
            })
            -- Stop pulse animation and update Arc display for ADSR modal
            if _seeker.arc then
                if _seeker.arc.stop_action_pulse then
                    _seeker.arc.stop_action_pulse()
                end
                if _seeker.arc.update_adsr_display then
                    _seeker.arc.update_adsr_display()
                end
            end
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Disting Multisample ADSR visual editor trigger
        params:add_trigger("lane_" .. i .. "_disting_multisample_visual_edit", "Visual Edit")
        params:set_action("lane_" .. i .. "_disting_multisample_visual_edit", function()
            local Modal = get_modal()
            if not Modal then return end

            local function get_adsr_data()
                return {
                    a = params:get("lane_" .. lane_idx .. "_disting_multisample_attack") / 100,
                    d = params:get("lane_" .. lane_idx .. "_disting_multisample_decay") / 100,
                    s = params:get("lane_" .. lane_idx .. "_disting_multisample_sustain") / 100,
                    r = params:get("lane_" .. lane_idx .. "_disting_multisample_release") / 100
                }
            end

            local adsr_params = {
                "lane_" .. lane_idx .. "_disting_multisample_attack",
                "lane_" .. lane_idx .. "_disting_multisample_decay",
                "lane_" .. lane_idx .. "_disting_multisample_sustain",
                "lane_" .. lane_idx .. "_disting_multisample_release"
            }

            -- Step sizes for Disting 0-100 range: {coarse, medium, fine}
            local adsr_step_sizes = {
                {10, 5, 1},  -- Attack
                {10, 5, 1},  -- Decay
                {10, 5, 1},  -- Sustain
                {10, 5, 1}   -- Release
            }

            local function adjust_adsr(encoder, delta)
                local stage = Modal.get_adsr_selected()
                local param_id = adsr_params[stage]
                local steps = adsr_step_sizes[stage]
                local step = steps[encoder - 1]
                if step then
                    local current = params:get(param_id)
                    local new_val = current + (delta * step)
                    params:set(param_id, new_val)
                end
                if _seeker.arc and _seeker.arc.update_adsr_display then
                    _seeker.arc.update_adsr_display()
                end
            end

            local function on_key(n, z)
                if z == 1 and (n == 2 or n == 3) then
                    Modal.dismiss()
                    _seeker.screen_ui.set_needs_redraw()
                    return true
                end
                return false
            end

            -- Accumulate Arc encoder 1 movements to prevent accidental selection changes
            local selector_accumulator = 0
            local SELECTOR_THRESHOLD = 12

            local function on_enc(n, d, source)
                if source == "arc" then
                    if n == 1 then
                        selector_accumulator = selector_accumulator + d
                        if math.abs(selector_accumulator) >= SELECTOR_THRESHOLD then
                            local direction = selector_accumulator > 0 and 1 or -1
                            selector_accumulator = 0
                            local current = Modal.get_adsr_selected()
                            local new_sel = util.clamp(current + direction, 1, 4)
                            Modal.set_adsr_selected(new_sel)
                            if _seeker.arc and _seeker.arc.update_adsr_display then
                                _seeker.arc.update_adsr_display()
                            end
                            _seeker.screen_ui.set_needs_redraw()
                        end
                        return true
                    elseif n >= 2 and n <= 4 then
                        adjust_adsr(n, d)
                        _seeker.screen_ui.set_needs_redraw()
                        return true
                    end
                else
                    if n == 2 then
                        local current = Modal.get_adsr_selected()
                        local new_sel = util.clamp(current + util.round(d), 1, 4)
                        Modal.set_adsr_selected(new_sel)
                        if _seeker.arc and _seeker.arc.update_adsr_display then
                            _seeker.arc.update_adsr_display()
                        end
                        _seeker.screen_ui.set_needs_redraw()
                        return true
                    elseif n == 3 then
                        adjust_adsr(3, d)
                        _seeker.screen_ui.set_needs_redraw()
                        return true
                    end
                end
                return false
            end

            Modal.show_adsr({
                get_data = get_adsr_data,
                param_ids = adsr_params,
                on_key = on_key,
                on_enc = on_enc,
                hint = "e2 select e3 change k3 set"
            })
            if _seeker.arc then
                if _seeker.arc.stop_action_pulse then
                    _seeker.arc.stop_action_pulse()
                end
                if _seeker.arc.update_adsr_display then
                    _seeker.arc.update_adsr_display()
                end
            end
            _seeker.screen_ui.set_needs_redraw()
        end)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "LANE_CONFIG",
        name = "Lane 1",
        icon = "⌸",
        description = Descriptions.LANE_CONFIG,
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

        -- Update description based on motif type
        local base = Descriptions.LANE_CONFIG
        if motif_type == MOTIF_TYPE_TAPE then
            self.description = base .. "\n\nTape: Record and loop live performances with overdub layering."
        elseif motif_type == MOTIF_TYPE_COMPOSER then
            self.description = base .. "\n\nComposer: Generate chord progressions with algorithmic patterns."
        elseif motif_type == MOTIF_TYPE_SAMPLER then
            self.description = base .. "\n\nSampler: Chop and sequence audio samples across 16 pads."
        else
            self.description = base
        end

        -- Start with volume and motif type (always visible)
        local param_table = {
            { separator = true, title = "Config" },
            { id = "lane_" .. lane_idx .. "_volume", arc_multi_float = {0.1, 0.05, 0.01} },
            { id = "lane_" .. lane_idx .. "_motif_type" }
        }

        -- Sampler parameters: audio source, recording, filter
        if motif_type == MOTIF_TYPE_SAMPLER then
            -- Sample source first (most important)
            table.insert(param_table, { separator = true, title = "Sample Source" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sample_file", is_action = true })

            -- Show recording state in param name and icon
            if _seeker.sampler and _seeker.sampler.is_recording then
                table.insert(param_table, {
                    id = "lane_" .. lane_idx .. "_record_sample",
                    is_action = true,
                    custom_name = "Recording Sample",
                    custom_value = "◆"
                })
            else
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_record_sample", is_action = true })
            end

            -- Global settings
            table.insert(param_table, { separator = true, title = "Global Settings" })
            table.insert(param_table, { id = "sampler_voice_count" })

            -- Global filter (defaults for all chops, overridden per-chop)
            table.insert(param_table, { separator = true, title = "Global Filter" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_filter_type" })

            local filter_type = params:get("lane_" .. lane_idx .. "_sampler_filter_type")
            if filter_type == 2 then -- Lowpass
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_lpf", arc_multi_float = {1000, 100, 10} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_resonance", arc_multi_float = {0.5, 0.1, 0.05} })
            elseif filter_type == 3 then -- Highpass
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_hpf", arc_multi_float = {1000, 100, 10} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_resonance", arc_multi_float = {0.5, 0.1, 0.05} })
            elseif filter_type == 4 or filter_type == 5 then -- Bandpass or Notch
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_lpf", arc_multi_float = {1000, 100, 10} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_resonance", arc_multi_float = {0.5, 0.1, 0.05} })
            end

            -- Global envelope
            table.insert(param_table, { separator = true, title = "Global Envelope" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_attack", arc_multi_float = {0.5, 0.1, 0.01} })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_release", arc_multi_float = {0.5, 0.1, 0.01} })
        else -- Tape/Composer parameters: voice routing configuration
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
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_pan", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { separator = true, title = "Envelope" })
                table.insert(param_table, {
                    id = "lane_" .. lane_idx .. "_adsr_visual_edit",
                    is_action = true,
                    custom_name = "Visual Edit",
                    custom_value = "..."
                })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_attack", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_decay", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sustain", arc_multi_float = {0.1, 0.05, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_release", arc_multi_float = {1.0, 0.5, 0.1} })
                table.insert(param_table, { separator = true, title = "Filter" })
                table.insert(param_table, {
                    id = "lane_" .. lane_idx .. "_lpf",
                    arc_multi_float = {1000, 100, 10}
                })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_resonance", arc_multi_float = {0.5, 0.1, 0.05} })
                table.insert(param_table, {
                    id = "lane_" .. lane_idx .. "_hpf",
                    arc_multi_float = {1000, 100, 10}
                })
                table.insert(param_table, { separator = true, title = "Effects" })
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
                    table.insert(param_table, {
                        id = "lane_" .. lane_idx .. "_disting_multisample_visual_edit",
                        is_action = true,
                        custom_name = "Visual Edit",
                        custom_value = "..."
                    })
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

        local Modal = get_modal()
        if not Modal then return end

        -- Check if recording and draw overlay
        if _seeker.sampler and _seeker.sampler.recording_state then
            local message = _seeker.sampler.recording_state == "recording" and "RECORDING" or "SAVING"
            local hint = _seeker.sampler.recording_state == "recording" and "k3 to stop" or nil
            Modal.draw_status_immediate({ body = message, hint = hint })
            screen.update()

        -- Check if fileselect is active and draw overlay
        elseif _seeker.sampler and _seeker.sampler.file_select_active then
            Modal.draw_status_immediate({ body = "FILE SELECT", hint = "use norns e2/e3/k3" })
            screen.update()

        -- Check if loading sample and draw overlay
        elseif _seeker.sampler and _seeker.sampler.loading_state then
            Modal.draw_status_immediate({ body = "LOADING" })
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