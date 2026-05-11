-- txo_cv_output.lua
-- Component for individual TXO CV output configuration (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")
local Descriptions = include("lib/ui/component_descriptions")
local PageState = include("lib/ui/components/page_state")
local ArcPages = include("lib/modes/eurorack/arc_pages")

-- Use global Modal singleton
local function get_modal()
  return _seeker and _seeker.modal
end

local TxoCvOutput = {}
TxoCvOutput.__index = TxoCvOutput

-- Short codes for CV monitor display
local TYPE_SHORT_CODES = { LFO = "LFO", Random = "RND", Envelope = "ENV" }

-- Type descriptions for dynamic help
local TYPE_DESCRIPTIONS = {
  LFO = "Clock-synced LFO.\n\nMORPH blends between adjacent waveforms.\n\nRECT clips or folds the output voltage.",
  Random = "Wandering voltage.\n\nCENTER and DEPTH define the range.\n\nJUMP picks a new random position each step.\nACCUMULATE drifts from current value by STEP SIZE.",
  Envelope = "Clock-synced envelope.\n\nAttack, decay, release in beats. Scales proportionally if total exceeds clock cycle."
}

-- Store active clock IDs globally
local active_clocks = {}

-- Per-output random state: current_value, initialized flag, and voltage history for monitor
local random_states = {}
for i = 1, 4 do
    random_states["txo_cv_" .. i] = {
        current_value = 0,
        initialized = false,
        history = {},
        history_max = 32
    }
end

-- Track cycle start times for voltage estimation in CV monitor
local cv_cycle_starts = {0, 0, 0, 0}

-- Compute envelope stage times in seconds from beat params.
-- Attack, decay, and release are independent of cycle length; if their total exceeds one
-- cycle, the envelope is retriggered mid-flight at the next clock boundary.
-- Returns {mode, a, d, s, r, wait, cycle} for ADSR, or {mode, a, r, wait, cycle} for AR.
local function compute_envelope_times(output_num, cycle_sec)
    local env_mode = params:string("txo_cv_" .. output_num .. "_envelope_mode")
    local beat_sec = clock.get_beat_sec()
    local a_beats = params:get("txo_cv_" .. output_num .. "_envelope_attack")
    local r_beats = params:get("txo_cv_" .. output_num .. "_envelope_release")

    if env_mode == "ADSR" then
        local d_beats = params:get("txo_cv_" .. output_num .. "_envelope_decay")
        local a_sec = a_beats * beat_sec
        local d_sec = d_beats * beat_sec
        local r_sec = r_beats * beat_sec
        local s_sec = math.max(0, cycle_sec - a_sec - d_sec - r_sec)
        return { mode = "ADSR", a = a_sec, d = d_sec, s = s_sec, r = r_sec, wait = 0, cycle = cycle_sec }
    else
        local a_sec = a_beats * beat_sec
        local r_sec = r_beats * beat_sec
        local wait = math.max(0, cycle_sec - a_sec - r_sec)
        return { mode = "AR", a = a_sec, r = r_sec, wait = wait, cycle = cycle_sec }
    end
end


local get_clock_timing = EurorackUtils.get_clock_timing

-- Setup clock helper
local function setup_clock(output_id, clock_fn)
    if active_clocks[output_id] then
        clock.cancel(active_clocks[output_id])
        active_clocks[output_id] = nil
    end

    if clock_fn then
        active_clocks[output_id] = clock.run(clock_fn)
    end
end

-- Main TXO CV update function

function TxoCvOutput.update_txo_cv(output_num)
    if active_clocks["txo_cv_" .. output_num] then
        clock.cancel(active_clocks["txo_cv_" .. output_num])
        active_clocks["txo_cv_" .. output_num] = nil
    end

    random_states["txo_cv_" .. output_num].initialized = false

    local type = params:string("txo_cv_" .. output_num .. "_type")
    local clock_interval = params:string("txo_cv_" .. output_num .. "_clock_interval")
    local clock_modifier = params:string("txo_cv_" .. output_num .. "_clock_modifier")
    local clock_offset = params:string("txo_cv_" .. output_num .. "_clock_offset")

    if clock_interval == "Off" then
        -- TXO amplitude 0 stops the oscillator
        crow.ii.txo.cv(output_num, 0)
        return
    end

    -- Handle Random type (center/depth range, Jump or Accumulate)
    if type == "Random" then
        local mode = params:string("txo_cv_" .. output_num .. "_random_mode")
        local slew = params:get("txo_cv_" .. output_num .. "_random_slew") / 100
        local center = params:get("txo_cv_" .. output_num .. "_random_center")
        local depth = params:get("txo_cv_" .. output_num .. "_random_depth")
        local min_value = util.clamp(center - depth, -10, 10)
        local max_value = util.clamp(center + depth, -10, 10)

        crow.ii.txo.cv_init(output_num)

        -- Initialize state if needed
        local state_key = "txo_cv_" .. output_num
        if not random_states[state_key].initialized then
            if mode == "Accumulate" then
                random_states[state_key].current_value = center
            else
                random_states[state_key].current_value = min_value + math.random() * (max_value - min_value)
            end
            random_states[state_key].initialized = true
            crow.ii.txo.cv_set(output_num, random_states[state_key].current_value)
        end

        local function random_function()
            while true do
                -- Re-read params each tick so arc changes take effect
                local center = params:get("txo_cv_" .. output_num .. "_random_center")
                local depth = params:get("txo_cv_" .. output_num .. "_random_depth")
                local lo = util.clamp(center - depth, -10, 10)
                local hi = util.clamp(center + depth, -10, 10)
                local current_mode = params:string("txo_cv_" .. output_num .. "_random_mode")
                local new_value

                if current_mode == "Jump" then
                    new_value = lo + math.random() * (hi - lo)
                else
                    local step_size = params:get("txo_cv_" .. output_num .. "_random_step_size")
                    local step = (math.random() - 0.5) * 2 * step_size
                    new_value = random_states[state_key].current_value + step

                    -- Reflect at boundaries
                    if new_value > hi then new_value = 2 * hi - new_value
                    elseif new_value < lo then new_value = 2 * lo - new_value end
                    new_value = util.clamp(new_value, lo, hi)
                end

                random_states[state_key].current_value = new_value
                local hist = random_states[state_key].history
                table.insert(hist, new_value)
                if #hist > random_states[state_key].history_max then table.remove(hist, 1) end

                -- Calculate slew time in milliseconds
                local interval_beats = EurorackUtils.interval_to_beats(clock_interval)
                local modifier_value = EurorackUtils.modifier_to_value(clock_modifier)
                local beats = interval_beats * modifier_value
                local beat_sec = clock.get_beat_sec()
                local total_sec = beats * beat_sec
                local slew_pct = params:get("txo_cv_" .. output_num .. "_random_slew") / 100
                local slew_ms = total_sec * slew_pct * 1000

                if slew_ms > 0 then
                    crow.ii.txo.cv_slew(output_num, slew_ms)
                    crow.ii.txo.cv(output_num, new_value)
                else
                    crow.ii.txo.cv_set(output_num, new_value)
                end

                local offset_value = tonumber(clock_offset) or 0
                clock.sync(beats, offset_value)
            end
        end

        active_clocks["txo_cv_" .. output_num] = clock.run(random_function)
        return
    end

    -- Handle Envelope type via software-driven slew (TXO has no native ASL)
    if type == "Envelope" then
        local timing = get_clock_timing(clock_interval, clock_modifier, clock_offset)
        if not timing then
            crow.ii.txo.cv_set(output_num, 0)
            crow.ii.txo.env_act(output_num, 0)
            return
        end

        local peak = params:get("txo_cv_" .. output_num .. "_envelope_peak")
        local sustain_v = params:get("txo_cv_" .. output_num .. "_envelope_sustain")

        crow.ii.txo.cv_init(output_num)

        local clock_fn = function()
            while true do
                -- Re-read params each cycle so arc changes take effect
                local cycle_sec = timing.beats * clock.get_beat_sec()
                local t = compute_envelope_times(output_num, cycle_sec)
                local pk = params:get("txo_cv_" .. output_num .. "_envelope_peak")
                local sv = params:get("txo_cv_" .. output_num .. "_envelope_sustain")

                cv_cycle_starts[output_num] = util.time()

                if t.mode == "ADSR" then
                    -- Attack: 0 -> peak
                    crow.ii.txo.cv_slew(output_num, t.a * 1000)
                    crow.ii.txo.cv(output_num, pk)
                    clock.sleep(t.a)

                    -- Decay: peak -> sustain
                    crow.ii.txo.cv_slew(output_num, t.d * 1000)
                    crow.ii.txo.cv(output_num, sv)
                    clock.sleep(t.d)

                    -- Sustain: hold at sustain voltage
                    clock.sleep(t.s)

                    -- Release: sustain -> 0
                    crow.ii.txo.cv_slew(output_num, t.r * 1000)
                    crow.ii.txo.cv(output_num, 0)
                    clock.sleep(t.r)
                else
                    -- Attack: 0 -> peak
                    crow.ii.txo.cv_slew(output_num, t.a * 1000)
                    crow.ii.txo.cv(output_num, pk)
                    clock.sleep(t.a)

                    -- Release: peak -> 0
                    crow.ii.txo.cv_slew(output_num, t.r * 1000)
                    crow.ii.txo.cv(output_num, 0)
                    clock.sleep(t.r)

                    -- Wait for remaining cycle
                    if t.wait > 0 then
                        clock.sleep(t.wait)
                    end
                end

                clock.sync(timing.beats, timing.offset)
            end
        end

        setup_clock("txo_cv_" .. output_num, clock_fn)
        return
    end

    -- Handle LFO type (default)

    -- Get LFO parameters
    local shape = params:string("txo_cv_" .. output_num .. "_shape")
    local morph = params:get("txo_cv_" .. output_num .. "_morph")
    local depth = params:get("txo_cv_" .. output_num .. "_depth")
    local offset = params:get("txo_cv_" .. output_num .. "_offset")
    local phase = params:get("txo_cv_" .. output_num .. "_phase")
    local rect = params:string("txo_cv_" .. output_num .. "_rect")

    -- Convert rect name to TXO rect value
    local rect_value = 0
    if rect == "Negative Half" then rect_value = -2
    elseif rect == "Negative Clipped" then rect_value = -1
    elseif rect == "Positive Clipped" then rect_value = 1
    elseif rect == "Positive Half" then rect_value = 2
    end

    -- Convert shape to TXO wave type and apply morphing
    local base_wave_type = 0
    if shape == "Triangle" then base_wave_type = 100
    elseif shape == "Saw" then base_wave_type = 200
    elseif shape == "Pulse" then base_wave_type = 300
    elseif shape == "Noise" then base_wave_type = 400
    end

    -- Calculate morphing wave types in both directions
    local prev_wave_type = base_wave_type
    local next_wave_type = base_wave_type

    if shape == "Sine" then
        prev_wave_type = 400
        next_wave_type = 100
    elseif shape == "Triangle" then
        prev_wave_type = 0
        next_wave_type = 200
    elseif shape == "Saw" then
        prev_wave_type = 100
        next_wave_type = 300
    elseif shape == "Pulse" then
        prev_wave_type = 200
        next_wave_type = 400
    elseif shape == "Noise" then
        prev_wave_type = 300
        next_wave_type = 0
    end

    -- Interpolate between wave types based on morph value
    local wave_type
    if morph < 0 then
        wave_type = base_wave_type + ((prev_wave_type - base_wave_type) * (math.abs(morph) / 50))
    else
        wave_type = base_wave_type + ((next_wave_type - base_wave_type) * (morph / 50))
    end

    -- Initialize the CV output
    crow.ii.txo.cv_init(output_num)

    -- Set up the oscillator parameters
    crow.ii.txo.osc_wave(output_num, wave_type)

    -- Set up sync clock
    local interval_beats = EurorackUtils.interval_to_beats(clock_interval)
    local modifier_value = EurorackUtils.modifier_to_value(clock_modifier)
    local beats = interval_beats * modifier_value
    local beat_sec = clock.get_beat_sec()
    local cycle_time = beat_sec * beats * 1000

    -- Clock function maintains phase alignment while avoiding discontinuities
    local function sync_lfo()
        -- Initialize the LFO parameters once
        crow.ii.txo.osc_wave(output_num, wave_type)
        crow.ii.txo.cv(output_num, depth)
        crow.ii.txo.osc_ctr(output_num, math.floor((offset/10) * 16384))
        crow.ii.txo.osc_rect(output_num, rect_value)

        -- Calculate initial cycle time
        local current_beat_sec = clock.get_beat_sec()
        local current_cycle_time = current_beat_sec * beats * 1000
        crow.ii.txo.osc_cyc(output_num, current_cycle_time)

        crow.ii.txo.osc_phase(output_num, math.floor((phase / 360) * 16384))
        cv_cycle_starts[output_num] = util.time()

        while true do
            -- Wait for a complete cycle with offset
            clock.sync(beats, tonumber(clock_offset) or 0)

            -- Update cycle time only if tempo has changed
            local new_beat_sec = clock.get_beat_sec()
            if new_beat_sec ~= current_beat_sec then
                current_beat_sec = new_beat_sec
                current_cycle_time = current_beat_sec * beats * 1000
                crow.ii.txo.osc_cyc(output_num, current_cycle_time)
            end

            -- Only update other parameters if they've changed
            local new_depth = params:get("txo_cv_" .. output_num .. "_depth")
            local new_offset = params:get("txo_cv_" .. output_num .. "_offset")

            if new_depth ~= depth then
                depth = new_depth
                crow.ii.txo.cv(output_num, depth)
            end

            if new_offset ~= offset then
                offset = new_offset
                crow.ii.txo.osc_ctr(output_num, math.floor((offset/10) * 16384))
            end
        end
    end

    -- Start the sync clock
    active_clocks["txo_cv_" .. output_num] = clock.run(sync_lfo)
end

---------------------------------------------------------------
-- Live view: single-output console with PageState frame
---------------------------------------------------------------
local cv_page_state = nil

local function cv_get_selected()
  return { source = "txo_cv", num = params:get("eurorack_selected_number") }
end

local function cv_rebuild_page_state()
  local pages = ArcPages.build_pages_for_output(cv_get_selected())
  if cv_page_state then
    cv_page_state:set_pages(pages)
  else
    cv_page_state = PageState.new({ pages = pages })
  end
end

local function draw_cv_live()
  local selected = cv_get_selected()
  local states = TxoCvOutput.get_cv_states()
  local state = states[selected.num]

  cv_page_state:draw_frame({
    draw_fallback = function()
      screen.level(8); screen.rect(0, 52, 128, 12); screen.fill()
      screen.level(0); screen.move(2, 60); screen.text("TXO CV " .. selected.num)
    end,
    draw_header = function()
      local type_label = state and state.type or "---"
      local active = state and state.active
      screen.level(active and 12 or 4)
      screen.move(2, 7)
      screen.text("CV " .. selected.num .. " — " .. type_label)
    end,
    draw_content = function(top, height)
      if state then ArcPages.draw_output_viz(state, top, height) end
    end,
  })
end

-- Screen UI

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "TXO_CV_OUTPUT",
        name = "TXO CV Output",
        description = Descriptions.TXO_CV_OUTPUT,
        params = {},
    })

    norns_ui.needs_playback_refresh = true
    norns_ui.live_view_enabled = true

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        cv_rebuild_page_state()
        original_enter(self)

        -- Check for conflicts with lane TXO Osc and show warning
        local selected_number = params:get("eurorack_selected_number")
        local conflicts = EurorackUtils.find_txo_cv_conflicts(selected_number)
        if #conflicts.lanes > 0 then
            local Modal = get_modal()
            if Modal then
                Modal.show_warning({ body = "IN USE: Lane " .. table.concat(conflicts.lanes, ",") })
                _seeker.screen_ui.set_needs_redraw()
            end
        end
    end

    norns_ui.draw_live = function(self) draw_cv_live() end

    -- Initialize page state and wire arc/enc/key routing
    cv_rebuild_page_state()
    cv_page_state:wire(norns_ui, {
      after_delta = function(n)
        local page_def = cv_page_state.pages[cv_page_state.page]
        if not page_def then return end
        local slot = page_def.slots[n]
        if not slot or not slot.param_id then return end
        local selected = cv_get_selected()
        if slot.param_id == "txo_cv_" .. selected.num .. "_type" then
          cv_rebuild_page_state()
        end
      end,
    })

    norns_ui.rebuild_params = function(self)
        local selected_number = params:get("eurorack_selected_number")

        self.name = string.format("TXO CV %d", selected_number)

        local param_table = {}
        local output_num = selected_number
        local type = params:string("txo_cv_" .. output_num .. "_type")

        -- Update description based on selected type
        self.description = TYPE_DESCRIPTIONS[type] or Descriptions.TXO_CV_OUTPUT

        table.insert(param_table, { separator = true, title = "Mode" })
        table.insert(param_table, { id = "txo_cv_" .. output_num .. "_type" })

        table.insert(param_table, { separator = true, title = "Clock" })
        table.insert(param_table, { id = "txo_cv_" .. output_num .. "_clock_interval" })
        table.insert(param_table, { id = "txo_cv_" .. output_num .. "_clock_modifier" })
        table.insert(param_table, { id = "txo_cv_" .. output_num .. "_clock_offset" })

        if type == "LFO" then
            table.insert(param_table, { separator = true, title = "LFO" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_shape" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_morph", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_depth", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_offset", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_phase", arc_multi_float = {30, 10, 1} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_rect" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_restart" })
        elseif type == "Random" then
            table.insert(param_table, { separator = true, title = "Random" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_mode" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_center", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_depth", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_slew", arc_multi_float = {10, 5, 1} })

            local mode = params:string("txo_cv_" .. output_num .. "_random_mode")
            if mode == "Accumulate" then
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_step_size", arc_multi_float = {0.5, 0.1, 0.01} })
            end

            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_restart" })
        elseif type == "Envelope" then
            table.insert(param_table, { separator = true, title = "Envelope" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_envelope_mode" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_envelope_peak", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_envelope_attack", arc_multi_float = {0.5, 0.1, 0.01} })

            local mode = params:string("txo_cv_" .. output_num .. "_envelope_mode")
            if mode == "ADSR" then
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_envelope_decay", arc_multi_float = {0.5, 0.1, 0.01} })
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_envelope_sustain", arc_multi_float = {1.0, 0.1, 0.01} })
            end

            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_envelope_release", arc_multi_float = {0.5, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_restart" })
        end

        self.params = param_table
    end

    return norns_ui
end

-- Grid UI

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TXO_CV_OUTPUT",
    layout = {
      x = 13,
      y = 7,
      width = 4,
      height = 1
    }
  })

  -- Override draw to show selected output with dynamic brightness
  grid_ui.draw = function(self, layers)
    local is_txo_cv_section = (_seeker.ui_state.get_current_section() == "TXO_CV_OUTPUT")
    local selected_type = params:get("eurorack_selected_type")
    local selected_number = params:get("eurorack_selected_number")

    for i = 0, 3 do
      local x = self.layout.x + i
      local output_num = i + 1
      local is_selected = (selected_type == 3 and output_num == selected_number)
      local is_enabled = params:string("txo_cv_" .. output_num .. "_clock_interval") ~= "Off"
      local brightness

      if is_selected then
        if is_txo_cv_section then
          brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
        else
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        end
      elseif is_enabled then
        brightness = GridConstants.BRIGHTNESS.UI.UNFOCUSED
      else
        brightness = GridConstants.BRIGHTNESS.UI.NORMAL
      end

      layers.ui[x][self.layout.y] = brightness
    end
  end

  -- Override handle_key to select output and switch to TXO_CV_OUTPUT section
  -- First click selects output (preserves current page), second click cycles page
  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local output_num = (x - self.layout.x) + 1
      local current = _seeker.ui_state.get_current_section()
      local already_selected = current == "TXO_CV_OUTPUT" and
        params:get("eurorack_selected_type") == 3 and
        params:get("eurorack_selected_number") == output_num

      if already_selected then
        cv_page_state:next_page()
      else
        params:set("eurorack_selected_type", 3) -- 3 = TXO CV
        params:set("eurorack_selected_number", output_num)
        cv_rebuild_page_state()
        _seeker.ui_state.set_current_section("TXO_CV_OUTPUT")

        local conflicts = EurorackUtils.find_txo_cv_conflicts(output_num)
        if #conflicts.lanes > 0 then
          local Modal = get_modal()
          if Modal then
            Modal.show_warning({ body = "IN USE: Lane " .. table.concat(conflicts.lanes, ",") })
          end
        end
      end
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

-- Parameter creation

local function create_params()
    params:add_group("txo_cv_output", "TXO CV OUTPUT", 88)

    for i = 1, 4 do
        params:add_option("txo_cv_" .. i .. "_clock_interval", "Interval", EurorackUtils.interval_options, 1)
        params:add_option("txo_cv_" .. i .. "_clock_modifier", "Modifier", EurorackUtils.modifier_options, 26)
        params:add_option("txo_cv_" .. i .. "_clock_offset", "Offset", EurorackUtils.offset_options, 1)
        params:set_action("txo_cv_" .. i .. "_clock_interval", function(value)
            TxoCvOutput.update_txo_cv(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.txo_cv_output then
                _seeker.eurorack.txo_cv_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)
        params:set_action("txo_cv_" .. i .. "_clock_modifier", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)
        params:set_action("txo_cv_" .. i .. "_clock_offset", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_option("txo_cv_" .. i .. "_type", "Type", {"LFO", "Random", "Envelope"}, 1)
        params:set_action("txo_cv_" .. i .. "_type", function(value)
            TxoCvOutput.update_txo_cv(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.txo_cv_output then
                _seeker.eurorack.txo_cv_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_option("txo_cv_" .. i .. "_shape", "Shape", {"Sine", "Triangle", "Saw", "Pulse", "Noise"}, 1)
        params:set_action("txo_cv_" .. i .. "_shape", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_number("txo_cv_" .. i .. "_morph", "Morph", -50, 50, 0)
        params:set_action("txo_cv_" .. i .. "_morph", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_depth", "Depth", controlspec.new(0, 10, 'lin', 0.01, 2.5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("txo_cv_" .. i .. "_depth", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_offset", "Offset", controlspec.new(-5, 5, 'lin', 0.01, 0), function(param) return params:get(param.id) .. "v" end)
        params:set_action("txo_cv_" .. i .. "_offset", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_number("txo_cv_" .. i .. "_phase", "Phase", 0, 360, 0)
        params:set_action("txo_cv_" .. i .. "_phase", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_option("txo_cv_" .. i .. "_rect", "Rect", {"Negative Half", "Negative Clipped", "Full Range", "Positive Clipped", "Positive Half"}, 3)
        params:set_action("txo_cv_" .. i .. "_rect", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        -- Random parameters (center/depth range)
        params:add_option("txo_cv_" .. i .. "_random_mode", "Mode", {"Jump", "Accumulate"}, 2)
        params:set_action("txo_cv_" .. i .. "_random_mode", function(value)
            TxoCvOutput.update_txo_cv(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.txo_cv_output then
                _seeker.eurorack.txo_cv_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_control("txo_cv_" .. i .. "_random_center", "Center", controlspec.new(-10, 10, 'lin', 0.01, 0), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("txo_cv_" .. i .. "_random_center", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_random_depth", "Depth", controlspec.new(0, 10, 'lin', 0.01, 5), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("txo_cv_" .. i .. "_random_depth", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_random_slew", "Slew", controlspec.new(0, 100, 'lin', 1, 50), function(param) return params:get(param.id) .. "%" end)
        params:set_action("txo_cv_" .. i .. "_random_slew", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_random_step_size", "Step Size", controlspec.new(0.01, 5, 'lin', 0.01, 0.5), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("txo_cv_" .. i .. "_random_step_size", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        -- Envelope parameters
        params:add_option("txo_cv_" .. i .. "_envelope_mode", "Envelope Mode", {"ADSR", "AR"}, 1)
        params:set_action("txo_cv_" .. i .. "_envelope_mode", function(value)
            TxoCvOutput.update_txo_cv(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.txo_cv_output then
                _seeker.eurorack.txo_cv_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_control("txo_cv_" .. i .. "_envelope_peak", "Peak", controlspec.new(0, 10, 'lin', 0.01, 5), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("txo_cv_" .. i .. "_envelope_peak", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_envelope_attack", "Attack", controlspec.new(0.01, 16, 'exp', 0.01, 0.25), function(param) return string.format("%.2f", params:get(param.id)) end)
        params:set_action("txo_cv_" .. i .. "_envelope_attack", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_envelope_decay", "Decay", controlspec.new(0.01, 16, 'exp', 0.01, 0.25), function(param) return string.format("%.2f", params:get(param.id)) end)
        params:set_action("txo_cv_" .. i .. "_envelope_decay", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_envelope_sustain", "Sustain", controlspec.new(0, 10, 'lin', 0.01, 3), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("txo_cv_" .. i .. "_envelope_sustain", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_envelope_release", "Release", controlspec.new(0.01, 16, 'exp', 0.01, 0.5), function(param) return string.format("%.2f", params:get(param.id)) end)
        params:set_action("txo_cv_" .. i .. "_envelope_release", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_binary("txo_cv_" .. i .. "_restart", "Restart", "trigger", 0)
        params:set_action("txo_cv_" .. i .. "_restart", function(value)
            for j = 1, 4 do
                TxoCvOutput.update_txo_cv(j)
            end
        end)
    end
end

-- Normalized waveform value (-1 to 1) for a given phase (0 to 1)
local function waveform_value(phase, shape)
    if shape == "Triangle" then
        if phase < 0.25 then return phase * 4
        elseif phase < 0.75 then return 2 - phase * 4
        else return phase * 4 - 4 end
    elseif shape == "Saw" then
        return phase < 0.5 and phase * 2 or phase * 2 - 2
    elseif shape == "Pulse" then
        return phase < 0.5 and 1 or -1
    elseif shape == "Noise" then
        return 0
    end
    -- Sine (default)
    return math.sin(2 * math.pi * phase)
end

-- Estimate current TXO LFO voltage from elapsed time since cycle start
local function estimate_lfo_voltage(output_num)
    local depth = params:get("txo_cv_" .. output_num .. "_depth")
    local offset = params:get("txo_cv_" .. output_num .. "_offset")
    local shape = params:string("txo_cv_" .. output_num .. "_shape")
    local clock_interval = params:string("txo_cv_" .. output_num .. "_clock_interval")
    local clock_modifier = params:string("txo_cv_" .. output_num .. "_clock_modifier")

    local interval_beats = EurorackUtils.interval_to_beats(clock_interval)
    local modifier_value = EurorackUtils.modifier_to_value(clock_modifier)
    local beats = interval_beats * modifier_value
    local period = beats * clock.get_beat_sec()
    if period <= 0 then return offset end

    local elapsed = util.time() - cv_cycle_starts[output_num]
    local phase = (elapsed % period) / period
    return offset + depth * waveform_value(phase, shape)
end

-- Estimate current TXO envelope voltage from elapsed time since cycle start.
-- TXO envelopes are linear (no shape easing).
local function estimate_envelope_voltage(output_num)
    local timing = get_clock_timing(
        params:string("txo_cv_" .. output_num .. "_clock_interval"),
        params:string("txo_cv_" .. output_num .. "_clock_modifier"),
        params:string("txo_cv_" .. output_num .. "_clock_offset")
    )
    if not timing or timing.total_sec <= 0 then return 0 end

    local peak = params:get("txo_cv_" .. output_num .. "_envelope_peak")
    local sustain_v = params:get("txo_cv_" .. output_num .. "_envelope_sustain")

    local cycle_sec = timing.total_sec
    local t = compute_envelope_times(output_num, cycle_sec)
    local elapsed = (util.time() - cv_cycle_starts[output_num]) % cycle_sec

    if t.mode == "ADSR" then
        if elapsed < t.a then
            return peak * (elapsed / t.a)
        elseif elapsed < t.a + t.d then
            local p = (elapsed - t.a) / t.d
            return peak - (peak - sustain_v) * p
        elseif elapsed < t.a + t.d + t.s then
            return sustain_v
        elseif elapsed < t.a + t.d + t.s + t.r then
            local p = (elapsed - t.a - t.d - t.s) / t.r
            return sustain_v * (1 - p)
        else
            return 0
        end
    else
        if elapsed < t.a then
            return peak * (elapsed / t.a)
        elseif elapsed < t.a + t.r then
            local p = (elapsed - t.a) / t.r
            return peak * (1 - p)
        else
            return 0
        end
    end
end

-- Returns state table for each TXO CV output (1-4).
-- Base fields: { active, type, current, min, max }
-- Type-specific: LFO adds phase/lfo_shape, Envelope adds env_times/peak/sustain/elapsed_frac,
--                Random adds voltage_history
function TxoCvOutput.get_cv_states()
    local states = {}
    for i = 1, 4 do
        local cv_type = params:string("txo_cv_" .. i .. "_type")
        local short = TYPE_SHORT_CODES[cv_type] or cv_type
        local clock_interval = params:string("txo_cv_" .. i .. "_clock_interval")
        local is_active = clock_interval ~= "Off"

        if cv_type == "Random" then
            local state_key = "txo_cv_" .. i
            local center = params:get("txo_cv_" .. i .. "_random_center")
            local depth_v = params:get("txo_cv_" .. i .. "_random_depth")
            states[i] = {
                active = is_active,
                type = short,
                current = is_active and random_states[state_key].current_value or 0,
                min = util.clamp(center - depth_v, -10, 10),
                max = util.clamp(center + depth_v, -10, 10),
                voltage_history = random_states[state_key].history
            }
        elseif cv_type == "LFO" then
            local depth = params:get("txo_cv_" .. i .. "_depth")
            local offset = params:get("txo_cv_" .. i .. "_offset")
            local shape = params:string("txo_cv_" .. i .. "_shape")
            local timing = get_clock_timing(
                clock_interval,
                params:string("txo_cv_" .. i .. "_clock_modifier"),
                params:string("txo_cv_" .. i .. "_clock_offset")
            )
            local phase = 0
            if timing and timing.total_sec > 0 then
                local elapsed = util.time() - cv_cycle_starts[i]
                phase = (elapsed % timing.total_sec) / timing.total_sec
            end
            states[i] = {
                active = is_active,
                type = short,
                current = is_active and estimate_lfo_voltage(i) or 0,
                min = offset - depth,
                max = offset + depth,
                phase = phase, lfo_shape = shape
            }
        elseif cv_type == "Envelope" then
            local peak = params:get("txo_cv_" .. i .. "_envelope_peak")
            local sustain_v = params:get("txo_cv_" .. i .. "_envelope_sustain")
            local timing = get_clock_timing(
                clock_interval,
                params:string("txo_cv_" .. i .. "_clock_modifier"),
                params:string("txo_cv_" .. i .. "_clock_offset")
            )
            local env_times, elapsed_frac = nil, 0
            if timing and timing.total_sec > 0 then
                env_times = compute_envelope_times(i, timing.total_sec)
                elapsed_frac = ((util.time() - cv_cycle_starts[i]) % timing.total_sec) / timing.total_sec
            end
            states[i] = {
                active = is_active,
                type = short,
                current = is_active and estimate_envelope_voltage(i) or 0,
                min = 0,
                max = peak,
                env_times = env_times, peak = peak, sustain = sustain_v, elapsed_frac = elapsed_frac
            }
        end
        if states[i] then
            states[i]._source = "txo_cv"
            states[i]._num = i
        end
    end
    return states
end

-- Sync all TXO CV outputs by restarting their clocks
function TxoCvOutput.sync()
    for i = 1, 4 do
        TxoCvOutput.update_txo_cv(i)
    end
end

function TxoCvOutput.init()
    create_params()

    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync = TxoCvOutput.sync,
        get_cv_states = TxoCvOutput.get_cv_states
    }

    return component
end

return TxoCvOutput
