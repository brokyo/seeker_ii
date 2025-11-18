-- txo_tr_output.lua
-- Component for individual TXO TR output configuration (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid_constants")

local TxoTrOutput = {}
TxoTrOutput.__index = TxoTrOutput

-- Configuration constants
local interval_options = {"Off", "1", "2", "3", "4", "5", "6", "7", "8", "12", "13", "14", "15", "16", "24", "32", "48", "64"}
local modifier_options = {"1/64", "1/32", "1/24", "1/23", "1/22", "1/21", "1/20", "1/19", "1/18", "1/17", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "48", "64"}
local offset_options = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"}

-- Store active clock IDs globally
local active_clocks = {}

-- Store pattern states globally for rhythmic patterns
local pattern_states = {}

-- Shared utility functions

-- Convert division string to beats
function TxoTrOutput.division_to_beats(div)
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
function TxoTrOutput.modifier_to_value(modifier)
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
function TxoTrOutput.interval_to_beats(interval)
    if interval == "Off" then
        return 0
    end

    return tonumber(interval) or 1
end

-- Get clock timing parameters
local function get_clock_timing(interval, modifier, offset)
    if interval == "Off" then return nil end

    local interval_beats = tonumber(interval)
    local modifier_value = TxoTrOutput.modifier_to_value(modifier)
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

-- Pattern generation and management

function TxoTrOutput.generate_txo_pattern(output_num)
    local pattern_length = params:get("txo_tr_" .. output_num .. "_gate_pattern_length")
    local pattern_hits = params:get("txo_tr_" .. output_num .. "_gate_pattern_hits")

    if not pattern_states["txo_" .. output_num] then
        pattern_states["txo_" .. output_num] = {
            pattern = {},
            current_step = 1
        }
    end

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

function TxoTrOutput.reroll_txo_pattern(output_num)
    TxoTrOutput.generate_txo_pattern(output_num)
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
    if type ~= "Burst" and type ~= "Gate" then return end

    local clock_interval = params:string("txo_tr_" .. output_num .. "_clock_interval")
    local clock_modifier = params:string("txo_tr_" .. output_num .. "_clock_modifier")
    local clock_offset = params:string("txo_tr_" .. output_num .. "_clock_offset")
    local interval_beats = TxoTrOutput.interval_to_beats(clock_interval)
    local modifier_value = TxoTrOutput.modifier_to_value(clock_modifier)
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

                for i = 1, burst_count do
                    crow.ii.txo.tr(output_num, 1)
                    clock.sleep(burst_time / burst_count)
                    crow.ii.txo.tr(output_num, 0)
                    clock.sleep(burst_time / burst_count)
                end
            else
                local gate_mode = params:string("txo_tr_" .. output_num .. "_gate_mode")

                if gate_mode == "Clock" then
                    local gate_length = params:get("txo_tr_" .. output_num .. "_gate_length") / 100
                    local beat_sec = clock.get_beat_sec()
                    local gate_time = beat_sec * beats * gate_length

                    crow.ii.txo.tr(output_num, 1)
                    clock.sleep(gate_time)
                    crow.ii.txo.tr(output_num, 0)
                else
                    if not pattern_states["txo_" .. output_num] or not pattern_states["txo_" .. output_num].pattern then
                        TxoTrOutput.generate_txo_pattern(output_num)
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
                end
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
        description = "Configure individual TXO TR output. Use grid to select output.",
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

        table.insert(param_table, { id = "txo_tr_" .. output_num .. "_type" })

        table.insert(param_table, { separator = true, title = "Clock" })
        table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_interval" })
        table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_modifier" })
        table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_offset" })

        if type == "Burst" then
            table.insert(param_table, { separator = true, title = "Burst" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_burst_count" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_burst_time" })
        elseif type == "Gate" then
            table.insert(param_table, { separator = true, title = "Gate" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_gate_length" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_gate_mode" })

            local gate_mode = params:string("txo_tr_" .. output_num .. "_gate_mode")
            if gate_mode == "Pattern" then
                table.insert(param_table, { separator = true, title = "Pattern" })
                table.insert(param_table, { id = "txo_tr_" .. output_num .. "_gate_pattern_length" })
                table.insert(param_table, { id = "txo_tr_" .. output_num .. "_gate_pattern_hits" })
                table.insert(param_table, { id = "txo_tr_" .. output_num .. "_gate_pattern_reroll", is_action = true })
            end
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
      local brightness

      if is_selected then
        if is_txo_section then
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
    for i = 1, 4 do
        params:add_option("txo_tr_" .. i .. "_clock_interval", "Interval", interval_options, 1)
        params:add_option("txo_tr_" .. i .. "_clock_modifier", "Modifier", modifier_options, 26)
        params:add_option("txo_tr_" .. i .. "_clock_offset", "Offset", offset_options, 1)
        params:set_action("txo_tr_" .. i .. "_clock_interval", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:set_action("txo_tr_" .. i .. "_clock_modifier", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:set_action("txo_tr_" .. i .. "_clock_offset", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)

        params:add_option("txo_tr_" .. i .. "_type", "Type", {"Gate", "Burst"}, 1)
        params:set_action("txo_tr_" .. i .. "_type", function(value)
            TxoTrOutput.update_txo_tr(i)
            if _seeker and _seeker.txo_tr_output then
                _seeker.txo_tr_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_number("txo_tr_" .. i .. "_burst_count", "Burst Count", 1, 16, 1)
        params:set_action("txo_tr_" .. i .. "_burst_count", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)

        params:add_number("txo_tr_" .. i .. "_burst_time", "Burst Time", 1, 100, 25, function(param) return param.value .. "%" end)
        params:set_action("txo_tr_" .. i .. "_burst_time", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)

        params:add_number("txo_tr_" .. i .. "_gate_length", "Gate Length", 1, 100, 50, function(param) return param.value .. "%" end)
        params:set_action("txo_tr_" .. i .. "_gate_length", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)

        params:add_option("txo_tr_" .. i .. "_gate_mode", "Gate Mode", {"Clock", "Pattern"}, 1)
        params:set_action("txo_tr_" .. i .. "_gate_mode", function(value)
            TxoTrOutput.update_txo_tr(i)
            if _seeker and _seeker.txo_tr_output then
                _seeker.txo_tr_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_number("txo_tr_" .. i .. "_gate_pattern_length", "Pattern Length", 1, 32, 8)
        params:set_action("txo_tr_" .. i .. "_gate_pattern_length", function(value)
            TxoTrOutput.generate_txo_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)

        params:add_number("txo_tr_" .. i .. "_gate_pattern_hits", "Pattern Hits", 1, 32, 4)
        params:set_action("txo_tr_" .. i .. "_gate_pattern_hits", function(value)
            TxoTrOutput.generate_txo_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)

        params:add_binary("txo_tr_" .. i .. "_gate_pattern_reroll", "Reroll Pattern", "trigger", 0)
        params:set_action("txo_tr_" .. i .. "_gate_pattern_reroll", function(value)
            TxoTrOutput.reroll_txo_pattern(i)
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
