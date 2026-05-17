-- lane_config.lua
-- Lane configuration: motif type selection (Tape/Composer/Sampler) and voice routing
-- Each lane can output to multiple voices simultaneously (MX Samples, MIDI, Crow, Just Friends, etc.)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")
local LaneMap = include("lib/lanes/lane_map")

-- Use global Modal singleton
local function get_modal()
  return _seeker and _seeker.modal
end

-- Voice parameter modules (order: mx.samples first, then alphabetical)
local VOICES = {
    include("lib/modes/motif/infrastructure/voices/mx_samples"),      -- 1. mx. samples
    include("lib/modes/motif/infrastructure/voices/disting"),         -- 2. Disting Ex
    include("lib/modes/motif/infrastructure/voices/disting_nt"),      -- 3. Disting NT
    include("lib/modes/motif/infrastructure/voices/eurorack_cv"),     -- 4. Eurorack
    include("lib/modes/motif/infrastructure/voices/just_friends"),    -- 5. Just Friends
    include("lib/modes/motif/infrastructure/voices/midi"),            -- 6. MIDI
    include("lib/modes/motif/infrastructure/voices/osc"),             -- 7. OSC
    include("lib/modes/motif/infrastructure/voices/txo_osc"),         -- 8. TXO Osc
    include("lib/modes/motif/infrastructure/voices/wsyn"),            -- 9. w/syn
}

-- Build voice names from registry
local VOICE_NAMES = {}
for _, voice in ipairs(VOICES) do
    table.insert(VOICE_NAMES, voice.name)
end

-- Motif type constants
local MOTIF_TYPE_TAPE = 1
local MOTIF_TYPE_DRUMS = 2
local MOTIF_TYPE_SAMPLER = 3
local MOTIF_TYPE_COMPOSER = 4

local LaneConfig = {}
LaneConfig.__index = LaneConfig

local function create_params()
    -- Global sampler settings (shared across all lanes)
    params:add_group("sampler_global", "SAMPLER GLOBAL", 1)
    params:add_number("sampler_voice_count", "Sampler Voices", 1, 6, 6)
    params:set_action("sampler_voice_count", function(value)
        if _seeker and _seeker.sampler then
            _seeker.sampler.num_voices = value
        end
    end)

    -- Create parameters for all lanes
    for i = 1, LaneMap.ACTIVE_LANES do
        local sub_mode = LaneMap.from_flat(i)
        local local_index = i - LaneMap.OFFSETS[sub_mode]
        local label = sub_mode:sub(1,1):upper() .. sub_mode:sub(2) .. " " .. local_index
        params:add_group("lane_" .. i, label .. " VOICES", 294)

        -- Voice selector (uses registry-built names)
        params:add_option("lane_" .. i .. "_visible_voice", "Voice", VOICE_NAMES)
        params:set_action("lane_" .. i .. "_visible_voice", function(value)
            _seeker.lane_config.screen:rebuild_params()
            -- Rebuild Form voice section if it exists (shows voice-specific params)
            if _seeker.screen_ui and _seeker.screen_ui.sections.COMPOSER_VOICE and _seeker.screen_ui.sections.COMPOSER_VOICE.rebuild_params then
              _seeker.screen_ui.sections.COMPOSER_VOICE:rebuild_params()
            end
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Create all voice-specific parameters via registry
        for _, voice in ipairs(VOICES) do
            voice.create_params(i)
        end

        -- Clear generation selector (0=all, 1+=specific generation)
        params:add_number("lane_" .. i .. "_clear_generation", "Clear Generation", 0, 10, 0,
            function(param)
                local val = param:get()
                if val == 0 then return "all" end
                return tostring(val)
            end)

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
        params:add_binary("lane_" .. i .. "_adsr_visual_edit", "Visual Edit", "trigger", 0)
        params:set_action("lane_" .. i .. "_adsr_visual_edit", function()
            local Modal = get_modal()
            if not Modal then return end

            local idx = lane_idx

            -- Sustain normalized from 0-2 range to 0-1 for modal visualization
            local function get_adsr_data()
                return {
                    a = params:get("lane_" .. idx .. "_attack"),
                    d = params:get("lane_" .. idx .. "_decay"),
                    s = params:get("lane_" .. idx .. "_sustain") / 2,
                    r = params:get("lane_" .. idx .. "_release")
                }
            end

            Modal.show_adsr({
                get_data = get_adsr_data,
                param_ids = {
                    "lane_" .. idx .. "_attack",
                    "lane_" .. idx .. "_decay",
                    "lane_" .. idx .. "_sustain",
                    "lane_" .. idx .. "_release"
                }
            })
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Disting Multisample ADSR visual editor trigger
        params:add_binary("lane_" .. i .. "_disting_multisample_visual_edit", "Visual Edit", "trigger", 0)
        params:set_action("lane_" .. i .. "_disting_multisample_visual_edit", function()
            local Modal = get_modal()
            if not Modal then return end

            -- Values normalized to 0-1 for modal visualization
            local function get_adsr_data()
                return {
                    a = params:get("lane_" .. lane_idx .. "_disting_multisample_attack") / 100,
                    d = params:get("lane_" .. lane_idx .. "_disting_multisample_decay") / 100,
                    s = params:get("lane_" .. lane_idx .. "_disting_multisample_sustain") / 100,
                    r = params:get("lane_" .. lane_idx .. "_disting_multisample_release") / 100
                }
            end

            Modal.show_adsr({
                get_data = get_adsr_data,
                param_ids = {
                    "lane_" .. lane_idx .. "_disting_multisample_attack",
                    "lane_" .. lane_idx .. "_disting_multisample_decay",
                    "lane_" .. lane_idx .. "_disting_multisample_sustain",
                    "lane_" .. lane_idx .. "_disting_multisample_release"
                }
            })
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Disting NT Poly Multisample ADSR visual editor trigger
        params:add_binary("lane_" .. i .. "_dnt_pm_visual_edit", "Visual Edit", "trigger", 0)
        params:set_action("lane_" .. i .. "_dnt_pm_visual_edit", function()
            local Modal = get_modal()
            if not Modal then return end

            -- Values normalized to 0-1 for modal visualization
            -- A/D/R are 0-127, S is 0-100
            local function get_adsr_data()
                return {
                    a = params:get("lane_" .. lane_idx .. "_dnt_pm_attack") / 127,
                    d = params:get("lane_" .. lane_idx .. "_dnt_pm_decay") / 127,
                    s = params:get("lane_" .. lane_idx .. "_dnt_pm_sustain") / 100,
                    r = params:get("lane_" .. lane_idx .. "_dnt_pm_release") / 127
                }
            end

            Modal.show_adsr({
                get_data = get_adsr_data,
                param_ids = {
                    "lane_" .. lane_idx .. "_dnt_pm_attack",
                    "lane_" .. lane_idx .. "_dnt_pm_decay",
                    "lane_" .. lane_idx .. "_dnt_pm_sustain",
                    "lane_" .. lane_idx .. "_dnt_pm_release"
                }
            })
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Disting NT Poly Wavetable Envelope 1 visual editor trigger
        params:add_binary("lane_" .. i .. "_dnt_pwt_env1_visual_edit", "Visual Edit", "trigger", 0)
        params:set_action("lane_" .. i .. "_dnt_pwt_env1_visual_edit", function()
            local Modal = get_modal()
            if not Modal then return end

            -- Values normalized to 0-1 for modal visualization (0-127 range)
            local function get_adsr_data()
                return {
                    a = params:get("lane_" .. lane_idx .. "_dnt_pwt_env1_attack") / 127,
                    d = params:get("lane_" .. lane_idx .. "_dnt_pwt_env1_decay") / 127,
                    s = params:get("lane_" .. lane_idx .. "_dnt_pwt_env1_sustain") / 127,
                    r = params:get("lane_" .. lane_idx .. "_dnt_pwt_env1_release") / 127
                }
            end

            Modal.show_adsr({
                get_data = get_adsr_data,
                param_ids = {
                    "lane_" .. lane_idx .. "_dnt_pwt_env1_attack",
                    "lane_" .. lane_idx .. "_dnt_pwt_env1_decay",
                    "lane_" .. lane_idx .. "_dnt_pwt_env1_sustain",
                    "lane_" .. lane_idx .. "_dnt_pwt_env1_release"
                }
            })
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Disting NT Poly Wavetable Envelope 2 visual editor trigger
        params:add_binary("lane_" .. i .. "_dnt_pwt_env2_visual_edit", "Visual Edit", "trigger", 0)
        params:set_action("lane_" .. i .. "_dnt_pwt_env2_visual_edit", function()
            local Modal = get_modal()
            if not Modal then return end

            -- Values normalized to 0-1 for modal visualization (0-127 range, env2 sustain is -127 to 127)
            local function get_adsr_data()
                return {
                    a = params:get("lane_" .. lane_idx .. "_dnt_pwt_env2_attack") / 127,
                    d = params:get("lane_" .. lane_idx .. "_dnt_pwt_env2_decay") / 127,
                    s = (params:get("lane_" .. lane_idx .. "_dnt_pwt_env2_sustain") + 127) / 254,
                    r = params:get("lane_" .. lane_idx .. "_dnt_pwt_env2_release") / 127
                }
            end

            Modal.show_adsr({
                get_data = get_adsr_data,
                param_ids = {
                    "lane_" .. lane_idx .. "_dnt_pwt_env2_attack",
                    "lane_" .. lane_idx .. "_dnt_pwt_env2_decay",
                    "lane_" .. lane_idx .. "_dnt_pwt_env2_sustain",
                    "lane_" .. lane_idx .. "_dnt_pwt_env2_release"
                }
            })
            _seeker.screen_ui.set_needs_redraw()
        end)
    end

    -- Initialize TXO oscillators (VOICES[8] = txo_osc)
    if VOICES[8].init then VOICES[8].init() end
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

        -- Update section name with sub-mode-aware label
        local sub_mode = LaneMap.from_flat(lane_idx)
        local local_index = lane_idx - LaneMap.OFFSETS[sub_mode]
        self.name = sub_mode:sub(1,1):upper() .. sub_mode:sub(2) .. " " .. local_index

        -- Update description based on motif type
        local base = Descriptions.LANE_CONFIG
        if motif_type == MOTIF_TYPE_TAPE then
            self.description = base .. "\n\nTape: Record and loop live performances with overdub layering."
        elseif motif_type == MOTIF_TYPE_COMPOSER then
            self.description = base .. "\n\nComposer: Generate chord progressions with algorithmic patterns."
        elseif motif_type == MOTIF_TYPE_DRUMS then
            self.description = base .. "\n\nDrums: Trigger step sequencer with configurable pattern length."
        elseif motif_type == MOTIF_TYPE_SAMPLER then
            self.description = base .. "\n\nSampler: Chop and sequence audio samples across 16 pads."
        else
            self.description = base
        end

        local param_table = {
            { separator = true, title = "Config" },
            { id = "lane_" .. lane_idx .. "_volume", arc_multi_float = {0.1, 0.05, 0.01} },
        }

        -- Sampler parameters: audio source, recording, filter
        if motif_type == MOTIF_TYPE_SAMPLER then
            -- Sample source first (most important)
            table.insert(param_table, { separator = true, title = "Sample Source" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_load_sample", is_action = true })

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
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_hpf", arc_multi_float = {1000, 100, 10} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_resonance", arc_multi_float = {0.5, 0.1, 0.05} })
            end

            -- Global envelope
            table.insert(param_table, { separator = true, title = "Global Envelope" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_attack", arc_multi_float = {0.5, 0.1, 0.01} })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_release", arc_multi_float = {0.5, 0.1, 0.01} })
        else -- Tape/Composer/Drums: voice routing configuration
            table.insert(param_table, { separator = true, title = "Voice Routing" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_visible_voice" })

            local voice_module = VOICES[visible_voice]
            if voice_module and voice_module.get_ui_params then
                local voice_params = voice_module.get_ui_params(lane_idx)
                for _, entry in ipairs(voice_params) do
                    table.insert(param_table, entry)
                end
            end
        end

        -- Update the UI with the new parameter table
        self.params = param_table
        self:filter_active_params()

        -- Also rebuild Form voice section if it exists (voice toggles trigger this)
        if _seeker.screen_ui and _seeker.screen_ui.sections.COMPOSER_VOICE then
          _seeker.screen_ui.sections.COMPOSER_VOICE:rebuild_params()
        end
    end


    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "LANE_CONFIG",
        layout = {
            x = 13,
            y = 7,
            width = 4,
            height = 1
        }
    })

    grid_ui.flash_state = {
        flash_until = nil
    }

    function grid_ui:draw(layers)
        local is_lane_section = _seeker.ui_state.get_current_section() == "LANE_CONFIG"
        local sub_mode = _seeker.current_sub_mode or "tape"
        local lane_ids = LaneMap.lanes_for_mode(sub_mode)

        -- Play area outline: flash on lane switch, hold during long press
        local show_outline = false
        if self.flash_state.flash_until and util.time() < self.flash_state.flash_until then
            show_outline = true
        end
        if self:is_holding_long_press() then
            show_outline = true
        end
        if show_outline then
            local motif_type = params:get("lane_" .. lane_ids[1] .. "_motif_type")
            local ox, oy, ow, oh
            if motif_type == 4 then
                ox, oy, ow, oh = 1, 2, 8, 6
            elseif motif_type == 3 then
                ox, oy, ow, oh = 7, 3, 4, 4
            else
                ox, oy, ow, oh = 6, 2, 6, 6
            end
            for x = 0, ow - 1 do
                layers.response[ox + x][oy] = GridConstants.BRIGHTNESS.HIGH
                layers.response[ox + x][oy + oh - 1] = GridConstants.BRIGHTNESS.HIGH
            end
            for y = 0, oh - 1 do
                layers.response[ox][oy + y] = GridConstants.BRIGHTNESS.HIGH
                layers.response[ox + ow - 1][oy + y] = GridConstants.BRIGHTNESS.HIGH
            end
        end

        -- Draw lane buttons for the active sub-mode
        local active_count = LaneMap.active_lanes_for_mode(sub_mode)
        for i = 1, active_count do
            local lane_idx = lane_ids[i]
            local is_focused = lane_idx == _seeker.ui_state.get_focused_lane()
            local lane = _seeker.lanes[lane_idx]

            local brightness
            if is_focused then
                brightness = GridConstants.BRIGHTNESS.FULL
            elseif lane.playing then
                brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
            elseif is_lane_section then
                brightness = GridConstants.BRIGHTNESS.MEDIUM
            else
                brightness = GridConstants.BRIGHTNESS.LOW
            end

            layers.ui[self.layout.x + (i - 1)][self.layout.y] = brightness
        end
    end

    function grid_ui:handle_key(x, y, z)
        if not self:contains(x, y) then
            return false
        end

        local sub_mode = _seeker.current_sub_mode or "tape"
        local local_index = (x - self.layout.x) + 1
        local active_count = LaneMap.active_lanes_for_mode(sub_mode)
        if local_index > active_count then return true end
        local new_lane_idx = LaneMap.to_flat(sub_mode, local_index)
        local key_id = string.format("%d,%d", x, y)

        if z == 1 then
            self:key_down(key_id)
            local was_focused = new_lane_idx == _seeker.ui_state.get_focused_lane()
            _seeker.ui_state.set_focused_lane(new_lane_idx)
            local motif_type = params:get("lane_" .. new_lane_idx .. "_motif_type")
            if motif_type == 4 then
              if was_focused then
                local COMPOSER_LANE_SECTIONS = {"COMPOSER_VOICE", "COMPOSER_PLAYBACK", "COMPOSER_PARAMS", "COMPOSER_RANDOMIZE"}
                local current = _seeker.ui_state.get_current_section()
                local next_section = COMPOSER_LANE_SECTIONS[1]
                for i, s in ipairs(COMPOSER_LANE_SECTIONS) do
                  if current == s then
                    next_section = COMPOSER_LANE_SECTIONS[(i % #COMPOSER_LANE_SECTIONS) + 1]
                    break
                  end
                end
                _seeker.ui_state.set_current_section(next_section)
              else
                _seeker.ui_state.set_current_section("COMPOSER_VOICE")
              end
            elseif motif_type == 2 then
              local DRUMS_LANE_SECTIONS = {"DRUMS_TIMING", "DRUMS_MUTATION", "LANE_CONFIG"}
              if was_focused then
                local current = _seeker.ui_state.get_current_section()
                local next_section = DRUMS_LANE_SECTIONS[1]
                for i, s in ipairs(DRUMS_LANE_SECTIONS) do
                  if current == s then
                    next_section = DRUMS_LANE_SECTIONS[(i % #DRUMS_LANE_SECTIONS) + 1]
                    break
                  end
                end
                _seeker.ui_state.set_current_section(next_section)
              else
                local current = _seeker.ui_state.get_current_section()
                if current == "DRUMS_HOME" then
                  _seeker.ui_state.set_current_section("DRUMS_TIMING")
                else
                  local is_drums_section = false
                  for _, s in ipairs(DRUMS_LANE_SECTIONS) do
                    if current == s then is_drums_section = true; break end
                  end
                  if not is_drums_section then
                    _seeker.ui_state.set_current_section("DRUMS_TIMING")
                  end
                end
              end
              local section = _seeker.ui_state.get_current_section()
              local drums_sections = _seeker.drums_type and _seeker.drums_type.sections
              if drums_sections and drums_sections[section] and drums_sections[section].rebuild_params then
                drums_sections[section]:rebuild_params()
                drums_sections[section]:filter_active_params()
              end
            else
              _seeker.ui_state.set_current_section("LANE_CONFIG")
            end
            _seeker.lane_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
            self.flash_state.flash_until = util.time() + 0.15
        else
            if self:is_long_press(key_id) then
                local lane = _seeker.lanes[new_lane_idx]
                if lane.playing then
                    lane:stop()
                else
                    local motif_type = params:get("lane_" .. new_lane_idx .. "_motif_type")
                    if motif_type == 4 and _seeker.composer_mode then
                        _seeker.composer_mode.composer.rebuild(new_lane_idx)
                    end
                    lane:play({ quantize = true })
                end
            end
            self:key_release(key_id)
            _seeker.screen_ui.set_needs_redraw()
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

    -- Initialize Disting NT (clears preset, resets channel allocation)
    VOICES[3].init()

    return component
end

return LaneConfig