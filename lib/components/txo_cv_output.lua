-- txo_cv_output.lua
-- Component for individual TXO CV output configuration (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid_constants")

local TxoCvOutput = {}
TxoCvOutput.__index = TxoCvOutput

-- Configuration constants
local interval_options = {"Off", "1", "2", "3", "4", "5", "6", "7", "8", "12", "13", "14", "15", "16", "24", "32", "48", "64"}
local modifier_options = {"1/64", "1/32", "1/24", "1/23", "1/22", "1/21", "1/20", "1/19", "1/18", "1/17", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "48", "64"}
local offset_options = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"}

-- Store active clock IDs globally
local active_clocks = {}

-- Store random walk states globally for TXO CV outputs
local random_walk_states = {}

-- Initialize random walk states for all 4 TXO CV outputs
for i = 1, 4 do
    random_walk_states["txo_cv_" .. i] = {
        current_value = 0,
        initialized = false
    }
end

-- Shared utility functions

-- Convert division string to beats
function TxoCvOutput.division_to_beats(div)
    if div == "Off" then
        return 0
    end

    if tonumber(div) then
        return tonumber(div)
    end

    local num, den = div:match("(%d+)/(%d+)")
    if num and den then
        return tonumber(num)/tonumber(den)
    end

    return 1
end

-- Convert modifier string to numeric value
function TxoCvOutput.modifier_to_value(modifier)
    if tonumber(modifier) then
        return tonumber(modifier)
    end

    local num, den = modifier:match("(%d+)/(%d+)")
    if num and den then
        return tonumber(num)/tonumber(den)
    end

    return 1
end

-- Convert interval string to beats
function TxoCvOutput.interval_to_beats(interval)
    if interval == "Off" then
        return 0
    end

    return tonumber(interval) or 1
end

-- Get clock timing parameters
local function get_clock_timing(interval, modifier, offset)
    if interval == "Off" then return nil end

    local interval_beats = tonumber(interval)
    local modifier_value = TxoCvOutput.modifier_to_value(modifier)
    local offset_value = tonumber(offset)

    local beats = interval_beats * modifier_value
    if beats <= 0 then return nil end

    local beat_sec = clock.get_beat_sec()
    return {
        beats = beats,
        beat_sec = beat_sec,
        total_sec = beats * beat_sec,
        offset = offset_value
    }
end

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
    -- Stop existing clock if any
    if active_clocks["txo_cv_" .. output_num] then
        clock.cancel(active_clocks["txo_cv_" .. output_num])
        active_clocks["txo_cv_" .. output_num] = nil
    end

    -- Reset random walk state when changing types
    random_walk_states["txo_cv_" .. output_num].initialized = false

    -- Get the output type
    local type = params:string("txo_cv_" .. output_num .. "_type")
    local clock_interval = params:string("txo_cv_" .. output_num .. "_clock_interval")
    local clock_modifier = params:string("txo_cv_" .. output_num .. "_clock_modifier")
    local clock_offset = params:string("txo_cv_" .. output_num .. "_clock_offset")

    -- If sync is Off, disable the output and return early
    if clock_interval == "Off" then
        -- Stop the oscillator by setting amplitude to 0
        crow.ii.txo.cv(output_num, 0)
        return
    end

    -- Handle Random Walk type
    if type == "Random Walk" then
        local mode = params:string("txo_cv_" .. output_num .. "_random_walk_mode")
        local slew = params:get("txo_cv_" .. output_num .. "_random_walk_slew") / 100
        local min_value = params:get("txo_cv_" .. output_num .. "_random_walk_min")
        local max_value = params:get("txo_cv_" .. output_num .. "_random_walk_max")

        -- Initialize the CV output
        crow.ii.txo.cv_init(output_num)

        -- Initialize state if needed
        local state_key = "txo_cv_" .. output_num
        if not random_walk_states[state_key].initialized then
            if mode == "Accumulate" then
                local offset = params:get("txo_cv_" .. output_num .. "_random_walk_offset")
                random_walk_states[state_key].current_value = offset
            else
                -- Start at a random position for Jump mode
                random_walk_states[state_key].current_value = min_value + math.random() * (max_value - min_value)
            end
            random_walk_states[state_key].initialized = true
            crow.ii.txo.cv_set(output_num, random_walk_states[state_key].current_value)
        end

        -- Setup clock for random walk
        local function random_walk_function()
            while true do
                local new_value

                if mode == "Jump" then
                    -- Jump to random value within range
                    new_value = min_value + math.random() * (max_value - min_value)
                else
                    -- Accumulate mode
                    local step_size = params:get("txo_cv_" .. output_num .. "_random_walk_step_size")
                    local step = (math.random() - 0.5) * 2 * step_size
                    new_value = random_walk_states[state_key].current_value + step

                    -- Reflect at boundaries
                    if new_value > max_value then
                        new_value = 2 * max_value - new_value
                    elseif new_value < min_value then
                        new_value = 2 * min_value - new_value
                    end

                    -- Extra safety clamp
                    new_value = util.clamp(new_value, min_value, max_value)
                end

                -- Update state
                random_walk_states[state_key].current_value = new_value

                -- Calculate slew time in milliseconds
                local interval_beats = TxoCvOutput.interval_to_beats(clock_interval)
                local modifier_value = TxoCvOutput.modifier_to_value(clock_modifier)
                local beats = interval_beats * modifier_value
                local beat_sec = clock.get_beat_sec()
                local total_sec = beats * beat_sec
                local slew_ms = total_sec * slew * 1000

                -- Set slew time and target voltage
                if slew_ms > 0 then
                    crow.ii.txo.cv_slew(output_num, slew_ms)
                    crow.ii.txo.cv(output_num, new_value)
                else
                    crow.ii.txo.cv_set(output_num, new_value)
                end

                -- Wait for next step with offset
                local offset_value = tonumber(clock_offset) or 0
                clock.sync(beats, offset_value)
            end
        end

        -- Start the clock
        active_clocks["txo_cv_" .. output_num] = clock.run(random_walk_function)
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
    local interval_beats = TxoCvOutput.interval_to_beats(clock_interval)
    local modifier_value = TxoCvOutput.modifier_to_value(clock_modifier)
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

        -- Start at phase 0
        crow.ii.txo.osc_phase(output_num, 0)

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

-- Screen UI

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "TXO_CV_OUTPUT",
        name = "TXO CV Output",
        description = "Configure individual TXO CV output. Use grid to select output.",
        params = {}
    })

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()  -- Rebuild params BEFORE entering (so arc.new_section gets valid params)
        original_enter(self)
    end

    norns_ui.rebuild_params = function(self)
        local selected_number = params:get("eurorack_selected_number")

        self.name = string.format("TXO CV %d", selected_number)

        local param_table = {}
        local output_num = selected_number
        local type = params:string("txo_cv_" .. output_num .. "_type")

        table.insert(param_table, { id = "txo_cv_" .. output_num .. "_type" })

        table.insert(param_table, { separator = true, title = "Clock" })
        table.insert(param_table, { id = "txo_cv_" .. output_num .. "_clock_interval" })
        table.insert(param_table, { id = "txo_cv_" .. output_num .. "_clock_modifier" })
        table.insert(param_table, { id = "txo_cv_" .. output_num .. "_clock_offset" })

        if type == "LFO" then
            table.insert(param_table, { separator = true, title = "LFO" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_shape" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_morph" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_depth", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_offset", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_phase" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_rect" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_restart" })
        elseif type == "Random Walk" then
            table.insert(param_table, { separator = true, title = "Random Walk" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_walk_mode" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_walk_slew" })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_walk_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_walk_max", arc_multi_float = {1.0, 0.1, 0.01} })

            local mode = params:string("txo_cv_" .. output_num .. "_random_walk_mode")
            if mode == "Accumulate" then
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_walk_step_size", arc_multi_float = {0.5, 0.1, 0.01} })
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_walk_offset", arc_multi_float = {1.0, 0.1, 0.01} })
            end

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
      local brightness

      if is_selected then
        if is_txo_cv_section then
          brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
        else
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        end
      else
        brightness = GridConstants.BRIGHTNESS.UI.NORMAL
      end

      layers.ui[x][self.layout.y] = brightness
    end
  end

  -- Override handle_key to select output and switch to TXO_CV_OUTPUT section
  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local output_num = (x - self.layout.x) + 1
      params:set("eurorack_selected_type", 3) -- 3 = TXO CV
      params:set("eurorack_selected_number", output_num)

      -- Switch to TXO CV output section
      _seeker.ui_state.set_current_section("TXO_CV_OUTPUT")

      -- Trigger UI updates
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

-- Parameter creation

local function create_params()
    for i = 1, 4 do
        params:add_option("txo_cv_" .. i .. "_clock_interval", "Interval", interval_options, 1)
        params:add_option("txo_cv_" .. i .. "_clock_modifier", "Modifier", modifier_options, 26)
        params:add_option("txo_cv_" .. i .. "_clock_offset", "Offset", offset_options, 1)
        params:set_action("txo_cv_" .. i .. "_clock_interval", function(value)
            TxoCvOutput.update_txo_cv(i)
            if _seeker and _seeker.txo_cv_output then
                _seeker.txo_cv_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)
        params:set_action("txo_cv_" .. i .. "_clock_modifier", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)
        params:set_action("txo_cv_" .. i .. "_clock_offset", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_option("txo_cv_" .. i .. "_type", "Type", {"LFO", "Random Walk"}, 1)
        params:set_action("txo_cv_" .. i .. "_type", function(value)
            TxoCvOutput.update_txo_cv(i)
            if _seeker and _seeker.txo_cv_output then
                _seeker.txo_cv_output.screen:rebuild_params()
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

        -- Random Walk parameters
        params:add_option("txo_cv_" .. i .. "_random_walk_mode", "Mode", {"Jump", "Accumulate"}, 2)
        params:set_action("txo_cv_" .. i .. "_random_walk_mode", function(value)
            TxoCvOutput.update_txo_cv(i)
            if _seeker and _seeker.txo_cv_output then
                _seeker.txo_cv_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_control("txo_cv_" .. i .. "_random_walk_slew", "Slew", controlspec.new(0, 100, 'lin', 1, 50), function(param) return params:get(param.id) .. "%" end)
        params:set_action("txo_cv_" .. i .. "_random_walk_slew", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_random_walk_min", "Min", controlspec.new(-10, 10, 'lin', 0.01, -5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("txo_cv_" .. i .. "_random_walk_min", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_random_walk_max", "Max", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("txo_cv_" .. i .. "_random_walk_max", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_random_walk_step_size", "Step Size", controlspec.new(0.01, 5, 'lin', 0.01, 0.5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("txo_cv_" .. i .. "_random_walk_step_size", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_control("txo_cv_" .. i .. "_random_walk_offset", "Offset", controlspec.new(-10, 10, 'lin', 0.01, 0), function(param) return params:get(param.id) .. "v" end)
        params:set_action("txo_cv_" .. i .. "_random_walk_offset", function(value)
            TxoCvOutput.update_txo_cv(i)
        end)

        params:add_binary("txo_cv_" .. i .. "_restart", "Restart", "trigger", 0)
        params:set_action("txo_cv_" .. i .. "_restart", function(value)
            -- Restart all TXO CV LFOs
            for j = 1, 4 do
                TxoCvOutput.update_txo_cv(j)
            end
            print("Restarted all LFOs")
        end)
    end
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
        sync = TxoCvOutput.sync
    }

    return component
end

return TxoCvOutput
