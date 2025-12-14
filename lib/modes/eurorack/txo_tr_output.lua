-- txo_tr_output.lua
-- Component for individual TXO TR output configuration (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")
local Descriptions = include("lib/ui/component_descriptions")

local TxoTrOutput = {}
TxoTrOutput.__index = TxoTrOutput

-- Type descriptions for dynamic help
local TYPE_DESCRIPTIONS = {
  Clock = "Clocked gate output.",
  Pattern = "Random rhythmic pattern.\n\nREROLL generates a new random distribution.",
  Euclidean = "Euclidean rhythmic pattern.",
  Burst = "Rapid burst of triggers.\n\nTIME sets burst duration as percentage of clock period.\n\nSHAPE controls timing between triggers."
}

-- Store active clock IDs globally
local active_clocks = {}

-- Store pattern states globally for rhythmic patterns
local pattern_states = {}


-- Get clock timing parameters
local function get_clock_timing(interval, modifier, offset)
    if interval == "Off" then return nil end

    local interval_beats = tonumber(interval)
    local modifier_value = EurorackUtils.modifier_to_value(modifier)
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

-- Calculate burst timing intervals based on shape
local function get_burst_intervals(count, total_time, shape)
    local intervals = {}

    if shape == "Linear" then
        local interval = total_time / count
        for i = 1, count do
            intervals[i] = interval
        end
    elseif shape == "Accelerating" then
        -- Bursts get faster: longer gaps at start, shorter at end
        local sum = 0
        for i = 1, count do sum = sum + i end
        for i = 1, count do
            intervals[i] = total_time * (count - i + 1) / sum
        end
    elseif shape == "Decelerating" then
        -- Bursts get slower: shorter gaps at start, longer at end
        local sum = 0
        for i = 1, count do sum = sum + i end
        for i = 1, count do
            intervals[i] = total_time * i / sum
        end
    elseif shape == "Random" then
        -- Random distribution
        local remaining = total_time
        for i = 1, count - 1 do
            local max_for_this = remaining - (count - i) * 0.01
            intervals[i] = math.random() * max_for_this * 0.5 + 0.01
            remaining = remaining - intervals[i]
        end
        intervals[count] = remaining
    end

    return intervals
end

-- Pattern generation and management

-- Generate random pattern with hits distributed randomly across length
function TxoTrOutput.generate_random_pattern(output_num)
    local pattern_length = params:get("txo_tr_" .. output_num .. "_pattern_length")
    local pattern_hits = params:get("txo_tr_" .. output_num .. "_pattern_hits")

    if not pattern_states["txo_" .. output_num] then
        pattern_states["txo_" .. output_num] = {
            pattern = {},
            current_step = 1
        }
    end

    -- Ensure hits doesn't exceed pattern length
    pattern_hits = math.min(pattern_hits, pattern_length)

    local pattern = {}
    local hits_placed = 0

    while hits_placed < pattern_hits do
        local position = math.random(1, pattern_length)
        if not pattern[position] then
            pattern[position] = true
            hits_placed = hits_placed + 1
        end
    end

    for i = 1, pattern_length do
        if not pattern[i] then
            pattern[i] = false
        end
    end

    pattern_states["txo_" .. output_num].pattern = pattern
    pattern_states["txo_" .. output_num].current_step = 1

    return pattern
end

-- Generate euclidean pattern using Bjorklund algorithm
function TxoTrOutput.generate_euclidean_pattern(output_num)
    local pattern_length = params:get("txo_tr_" .. output_num .. "_euclidean_length")
    local pattern_hits = params:get("txo_tr_" .. output_num .. "_euclidean_hits")
    local rotation = params:get("txo_tr_" .. output_num .. "_euclidean_rotation")

    if not pattern_states["txo_" .. output_num] then
        pattern_states["txo_" .. output_num] = {
            pattern = {},
            current_step = 1
        }
    end

    -- Clamp hits to length
    pattern_hits = math.min(pattern_hits, pattern_length)

    -- Bjorklund algorithm
    local pattern = {}
    if pattern_hits == 0 then
        for i = 1, pattern_length do
            pattern[i] = false
        end
    elseif pattern_hits == pattern_length then
        for i = 1, pattern_length do
            pattern[i] = true
        end
    else
        local groups = {}
        for i = 1, pattern_hits do
            groups[i] = {true}
        end
        for i = 1, pattern_length - pattern_hits do
            groups[pattern_hits + i] = {false}
        end

        while #groups > pattern_hits do
            local new_groups = {}
            local num_to_merge = math.min(pattern_hits, #groups - pattern_hits)
            for i = 1, num_to_merge do
                local merged = {}
                for _, v in ipairs(groups[i]) do table.insert(merged, v) end
                for _, v in ipairs(groups[#groups - num_to_merge + i]) do table.insert(merged, v) end
                new_groups[i] = merged
            end
            for i = num_to_merge + 1, #groups - num_to_merge do
                new_groups[i] = groups[i]
            end
            groups = new_groups
            if #groups <= pattern_hits then break end
        end

        local idx = 1
        for _, group in ipairs(groups) do
            for _, v in ipairs(group) do
                pattern[idx] = v
                idx = idx + 1
            end
        end
    end

    -- Apply rotation
    if rotation > 0 then
        local rotated = {}
        for i = 1, pattern_length do
            local src_idx = ((i - 1 + rotation) % pattern_length) + 1
            rotated[i] = pattern[src_idx]
        end
        pattern = rotated
    end

    pattern_states["txo_" .. output_num].pattern = pattern
    pattern_states["txo_" .. output_num].current_step = 1

    return pattern
end

function TxoTrOutput.reroll_txo_pattern(output_num)
    local type = params:string("txo_tr_" .. output_num .. "_type")
    if type == "Pattern" then
        TxoTrOutput.generate_random_pattern(output_num)
    elseif type == "Euclidean" then
        TxoTrOutput.generate_euclidean_pattern(output_num)
    end
    TxoTrOutput.update_txo_tr(output_num)
    _seeker.screen_ui.set_needs_redraw()
end

-- Main TXO TR update function

function TxoTrOutput.update_txo_tr(output_num)
    if active_clocks["txo_tr_" .. output_num] then
        clock.cancel(active_clocks["txo_tr_" .. output_num])
        active_clocks["txo_tr_" .. output_num] = nil
    end

    local type = params:string("txo_tr_" .. output_num .. "_type")
    if type ~= "Clock" and type ~= "Pattern" and type ~= "Euclidean" and type ~= "Burst" then return end

    local clock_interval = params:string("txo_tr_" .. output_num .. "_clock_interval")
    local clock_modifier = params:string("txo_tr_" .. output_num .. "_clock_modifier")
    local clock_offset = params:string("txo_tr_" .. output_num .. "_clock_offset")
    local interval_beats = EurorackUtils.interval_to_beats(clock_interval)
    local modifier_value = EurorackUtils.modifier_to_value(clock_modifier)
    local beats = interval_beats * modifier_value

    if beats == 0 then
        crow.ii.txo.tr(output_num, 0)
        return
    end

    local function clock_function()
        while true do
            if type == "Burst" then
                local burst_count = params:get("txo_tr_" .. output_num .. "_burst_count")
                local burst_time = params:get("txo_tr_" .. output_num .. "_burst_time") / 100
                local burst_shape = params:string("txo_tr_" .. output_num .. "_burst_shape")

                local intervals = get_burst_intervals(burst_count, burst_time, burst_shape)

                for i = 1, burst_count do
                    crow.ii.txo.tr(output_num, 1)
                    clock.sleep(intervals[i] / 2)
                    crow.ii.txo.tr(output_num, 0)
                    clock.sleep(intervals[i] / 2)
                end
            elseif type == "Pattern" or type == "Euclidean" then
                if not pattern_states["txo_" .. output_num] or not pattern_states["txo_" .. output_num].pattern then
                    if type == "Pattern" then
                        TxoTrOutput.generate_random_pattern(output_num)
                    else
                        TxoTrOutput.generate_euclidean_pattern(output_num)
                    end
                end

                local gate_length = params:get("txo_tr_" .. output_num .. "_gate_length") / 100
                local beat_sec = clock.get_beat_sec()
                local gate_time = beat_sec * beats * gate_length
                local pattern = pattern_states["txo_" .. output_num].pattern
                local current_step = pattern_states["txo_" .. output_num].current_step

                if pattern[current_step] then
                    crow.ii.txo.tr(output_num, 1)
                    clock.sleep(gate_time)
                    crow.ii.txo.tr(output_num, 0)
                end

                current_step = current_step + 1
                if current_step > #pattern then
                    current_step = 1
                end
                pattern_states["txo_" .. output_num].current_step = current_step
            else
                -- Clock type (simple clocked gate)
                local gate_length = params:get("txo_tr_" .. output_num .. "_clock_length") / 100
                local beat_sec = clock.get_beat_sec()
                local gate_time = beat_sec * beats * gate_length

                crow.ii.txo.tr(output_num, 1)
                clock.sleep(gate_time)
                crow.ii.txo.tr(output_num, 0)
            end

            clock.sync(beats, tonumber(clock_offset) or 0)
        end
    end

    active_clocks["txo_tr_" .. output_num] = clock.run(clock_function)
end

-- Screen UI

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "TXO_TR_OUTPUT",
        name = "TXO TR Output",
        description = Descriptions.TXO_TR_OUTPUT,
        params = {}
    })

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()  -- Rebuild params BEFORE entering (so arc.new_section gets valid params)
        original_enter(self)
    end

    norns_ui.rebuild_params = function(self)
        local selected_number = params:get("eurorack_selected_number")

        self.name = string.format("TXO TR %d", selected_number)

        local param_table = {}
        local output_num = selected_number
        local type = params:string("txo_tr_" .. output_num .. "_type")

        -- Update description based on selected type
        self.description = TYPE_DESCRIPTIONS[type] or Descriptions.TXO_TR_OUTPUT

        table.insert(param_table, { separator = true, title = "Mode" })
        table.insert(param_table, { id = "txo_tr_" .. output_num .. "_type" })

        table.insert(param_table, { separator = true, title = "Clock" })
        table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_interval" })
        table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_modifier" })
        table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_offset" })

        if type == "Clock" then
            table.insert(param_table, { separator = true, title = "Output" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_length", arc_multi_float = {10, 5, 1} })
        elseif type == "Pattern" then
            table.insert(param_table, { separator = true, title = "Pattern" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_gate_length", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_pattern_length" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_pattern_hits" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_pattern_reroll", is_action = true })
        elseif type == "Euclidean" then
            table.insert(param_table, { separator = true, title = "Euclidean" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_gate_length", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_euclidean_length" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_euclidean_hits" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_euclidean_rotation" })
        elseif type == "Burst" then
            table.insert(param_table, { separator = true, title = "Burst" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_burst_count" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_burst_time", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_burst_shape" })
        end

        self.params = param_table
    end

    return norns_ui
end

-- Grid UI

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TXO_TR_OUTPUT",
    layout = {
      x = 13,
      y = 6,
      width = 4,
      height = 1
    }
  })

  -- Override draw to show selected output with dynamic brightness
  grid_ui.draw = function(self, layers)
    local is_txo_section = (_seeker.ui_state.get_current_section() == "TXO_TR_OUTPUT")
    local selected_type = params:get("eurorack_selected_type")
    local selected_number = params:get("eurorack_selected_number")

    for i = 0, 3 do
      local x = self.layout.x + i
      local output_num = i + 1
      local is_selected = (selected_type == 2 and output_num == selected_number)
      local is_enabled = params:string("txo_tr_" .. output_num .. "_clock_interval") ~= "Off"
      local brightness

      if is_selected then
        if is_txo_section then
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

  -- Override handle_key to select output and switch to TXO_TR_OUTPUT section
  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local output_num = (x - self.layout.x) + 1
      params:set("eurorack_selected_type", 2) -- 2 = TXO TR
      params:set("eurorack_selected_number", output_num)

      -- Switch to TXO TR output section
      _seeker.ui_state.set_current_section("TXO_TR_OUTPUT")

      -- Trigger UI updates
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

-- Parameter creation

local function create_params()
    params:add_group("txo_tr_output", "TXO TR OUTPUT", 60)

    for i = 1, 4 do
        params:add_option("txo_tr_" .. i .. "_clock_interval", "Interval", EurorackUtils.interval_options, 1)
        params:add_option("txo_tr_" .. i .. "_clock_modifier", "Modifier", EurorackUtils.modifier_options, 26)
        params:add_option("txo_tr_" .. i .. "_clock_offset", "Offset", EurorackUtils.offset_options, 1)
        params:set_action("txo_tr_" .. i .. "_clock_interval", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:set_action("txo_tr_" .. i .. "_clock_modifier", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:set_action("txo_tr_" .. i .. "_clock_offset", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)

        params:add_option("txo_tr_" .. i .. "_type", "Type", {"Clock", "Pattern", "Euclidean", "Burst"}, 1)
        params:set_action("txo_tr_" .. i .. "_type", function(value)
            -- Reset pattern state when type changes
            pattern_states["txo_" .. i] = nil
            TxoTrOutput.update_txo_tr(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.txo_tr_output then
                _seeker.eurorack.txo_tr_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        -- Clock parameters (simple clocked gate)
        params:add_number("txo_tr_" .. i .. "_clock_length", "Gate Length", 1, 100, 50, function(param) return param.value .. "%" end)
        params:set_action("txo_tr_" .. i .. "_clock_length", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)

        -- Shared gate length for Pattern/Euclidean
        params:add_number("txo_tr_" .. i .. "_gate_length", "Gate Length", 1, 100, 50, function(param) return param.value .. "%" end)
        params:set_action("txo_tr_" .. i .. "_gate_length", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)

        -- Pattern parameters (random distribution)
        params:add_number("txo_tr_" .. i .. "_pattern_length", "Length", 1, 32, 8)
        params:set_action("txo_tr_" .. i .. "_pattern_length", function(value)
            TxoTrOutput.generate_random_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_number("txo_tr_" .. i .. "_pattern_hits", "Hits", 1, 32, 4)
        params:set_action("txo_tr_" .. i .. "_pattern_hits", function(value)
            TxoTrOutput.generate_random_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_binary("txo_tr_" .. i .. "_pattern_reroll", "Reroll", "trigger", 0)
        params:set_action("txo_tr_" .. i .. "_pattern_reroll", function(value)
            TxoTrOutput.reroll_txo_pattern(i)
        end)

        -- Euclidean parameters (Bjorklund algorithm)
        params:add_number("txo_tr_" .. i .. "_euclidean_length", "Length", 1, 32, 8)
        params:set_action("txo_tr_" .. i .. "_euclidean_length", function(value)
            TxoTrOutput.generate_euclidean_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_number("txo_tr_" .. i .. "_euclidean_hits", "Hits", 1, 32, 4)
        params:set_action("txo_tr_" .. i .. "_euclidean_hits", function(value)
            TxoTrOutput.generate_euclidean_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_number("txo_tr_" .. i .. "_euclidean_rotation", "Rotation", 0, 31, 0)
        params:set_action("txo_tr_" .. i .. "_euclidean_rotation", function(value)
            TxoTrOutput.generate_euclidean_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)

        -- Burst parameters
        params:add_number("txo_tr_" .. i .. "_burst_count", "Burst Count", 1, 16, 1)
        params:set_action("txo_tr_" .. i .. "_burst_count", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_number("txo_tr_" .. i .. "_burst_time", "Burst Time", 1, 100, 25, function(param) return param.value .. "%" end)
        params:set_action("txo_tr_" .. i .. "_burst_time", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_option("txo_tr_" .. i .. "_burst_shape", "Burst Shape", {"Linear", "Accelerating", "Decelerating", "Random"}, 1)
        params:set_action("txo_tr_" .. i .. "_burst_shape", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)
    end
end

-- Sync all TXO TR outputs by restarting their clocks
function TxoTrOutput.sync()
    for i = 1, 4 do
        TxoTrOutput.update_txo_tr(i)
    end
end

function TxoTrOutput.init()
    create_params()

    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync = TxoTrOutput.sync
    }

    return component
end

return TxoTrOutput
