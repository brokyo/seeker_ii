-- txo_tr_output.lua
-- Component for individual TXO TR output configuration (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")
local Descriptions = include("lib/ui/component_descriptions")
local PageState = include("lib/ui/components/page_state")
local ArcPages = include("lib/modes/eurorack/arc_pages")

local TxoTrOutput = {}
TxoTrOutput.__index = TxoTrOutput

-- Type descriptions for dynamic help
local TYPE_DESCRIPTIONS = {
  Rhythm = "Clock-synced rhythmic gate.\n\nWhen HITS = LENGTH, acts as a simple clock.\nDISTRIBUTION: Even uses Euclidean spacing, Random scatters hits.\nREROLL regenerates the random pattern.",
  Burst = "Rapid burst of triggers.\n\nTIME sets burst duration as percentage of clock period.\n\nSHAPE controls timing between triggers."
}

-- Store active clock IDs globally
local active_clocks = {}

-- Store pattern states globally for rhythmic patterns
local pattern_states = {}

-- Track gate states for CV monitor display (0 = low, 1 = high)
local gate_states = {0, 0, 0, 0}

-- Map full type names to short codes for display
local TYPE_SHORT_CODES = {
  Rhythm = "RTH", Burst = "BST"
}


local get_burst_intervals = EurorackUtils.get_burst_intervals

-- Pattern generation and management

-- Generate rhythm pattern based on distribution param (Even = Euclidean, Random = scattered).
function TxoTrOutput.generate_rhythm_pattern(output_num)
    local length = params:get("txo_tr_" .. output_num .. "_rhythm_length")
    local hits = math.min(params:get("txo_tr_" .. output_num .. "_rhythm_hits"), length)
    local rotation = params:get("txo_tr_" .. output_num .. "_rhythm_rotation")
    local distribution = params:string("txo_tr_" .. output_num .. "_rhythm_distribution")

    if not pattern_states["txo_" .. output_num] then
        pattern_states["txo_" .. output_num] = { pattern = {}, current_step = 1 }
    end

    local pattern
    if distribution == "Even" then
        pattern = EurorackUtils.bjorklund(length, hits, rotation)
    else
        -- Random: scatter hits randomly
        pattern = {}
        local hits_placed = 0
        while hits_placed < hits do
            local pos = math.random(1, length)
            if not pattern[pos] then
                pattern[pos] = true
                hits_placed = hits_placed + 1
            end
        end
        for i = 1, length do
            if not pattern[i] then pattern[i] = false end
        end
    end

    pattern_states["txo_" .. output_num].pattern = pattern
    pattern_states["txo_" .. output_num].current_step = 1
    return pattern
end

function TxoTrOutput.reroll_txo_pattern(output_num)
    TxoTrOutput.generate_rhythm_pattern(output_num)
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
    if type ~= "Rhythm" and type ~= "Burst" then return end

    local clock_interval = params:string("txo_tr_" .. output_num .. "_clock_interval")
    local clock_modifier = params:string("txo_tr_" .. output_num .. "_clock_modifier")
    local clock_offset = params:string("txo_tr_" .. output_num .. "_clock_offset")
    local interval_beats = EurorackUtils.interval_to_beats(clock_interval)
    local modifier_value = EurorackUtils.modifier_to_value(clock_modifier)
    local beats = interval_beats * modifier_value

    if beats == 0 then
        crow.ii.txo.tr(output_num, 0)
        gate_states[output_num] = 0
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
                    gate_states[output_num] = 1
                    clock.sleep(intervals[i] / 2)
                    crow.ii.txo.tr(output_num, 0)
                    gate_states[output_num] = 0
                    clock.sleep(intervals[i] / 2)
                end
            else
                -- Rhythm type: pattern-based gate with distribution
                if not pattern_states["txo_" .. output_num] or not pattern_states["txo_" .. output_num].pattern then
                    TxoTrOutput.generate_rhythm_pattern(output_num)
                end

                local gate_length = params:get("txo_tr_" .. output_num .. "_rhythm_gate_length") / 100
                local beat_sec = clock.get_beat_sec()
                local gate_time = beat_sec * beats * gate_length
                local pattern = pattern_states["txo_" .. output_num].pattern
                local current_step = pattern_states["txo_" .. output_num].current_step

                if pattern[current_step] then
                    crow.ii.txo.tr(output_num, 1)
                    gate_states[output_num] = 1
                    clock.sleep(gate_time)
                    crow.ii.txo.tr(output_num, 0)
                    gate_states[output_num] = 0
                end

                current_step = current_step + 1
                if current_step > #pattern then
                    current_step = 1
                end
                pattern_states["txo_" .. output_num].current_step = current_step
            end

            clock.sync(beats, tonumber(clock_offset) or 0)
        end
    end

    active_clocks["txo_tr_" .. output_num] = clock.run(clock_function)
end

---------------------------------------------------------------
-- Live view: single-output console with voltage bar + PageState chrome
---------------------------------------------------------------
local tr_page_state = nil
local tr_update_arc  -- forward declaration

local function tr_get_selected()
  return { source = "txo_tr", num = params:get("eurorack_selected_number") }
end

local function tr_rebuild_page_state()
  local pages = ArcPages.build_pages_for_output(tr_get_selected())
  if tr_page_state then
    tr_page_state:set_pages(pages)
  else
    tr_page_state = PageState.new({ pages = pages })
  end
end

local function draw_tr_live()
  local selected = tr_get_selected()
  local has_pages = tr_page_state and #tr_page_state.pages > 0 and tr_page_state.pages[1].name ~= "---"

  if not has_pages then
    screen.level(8)
    screen.rect(0, 52, 128, 12)
    screen.fill()
    screen.level(0)
    screen.move(2, 60)
    screen.text("TXO TR " .. selected.num)
    return
  end

  -- Output label — dim when clock is off, with status hint
  local states = TxoTrOutput.get_cv_states()
  local state = states[selected.num]
  local type_label = state and state.type or "---"
  local active = state and state.active
  screen.level(active and 12 or 4)
  screen.move(2, 7)
  screen.text("TR " .. selected.num .. " — " .. type_label)

  -- Type-specific visualization (same area as Composer: 12-45)
  local VIZ_TOP = 12
  local VIZ_BOTTOM = 45

  if state then
    ArcPages.draw_output_viz(state, VIZ_TOP, VIZ_BOTTOM - VIZ_TOP)

    if active then
      screen.level(10)
      screen.move(126, 7)
      screen.text_right(state.current and state.current > 0 and "HIGH" or "LOW")
    end
  end

  tr_page_state:draw_page_indicators()
  tr_page_state:draw_page_flash()
  tr_page_state:draw_footer()
end

tr_update_arc = function()
  local dev = _seeker.arc
  if not dev or not tr_page_state then return end
  tr_page_state:update_arc(dev)
  dev:refresh()
end

local function tr_handle_arc_delta(n, delta)
  if not tr_page_state then return end

  local page_def = tr_page_state.pages[tr_page_state.page]
  if not page_def then return end
  local slot = page_def.slots[n]
  if not slot or not slot.param_id then return end

  local selected = tr_get_selected()
  local prefix = "txo_tr_" .. selected.num .. "_"
  local is_type_change = (slot.param_id == prefix .. "type")

  tr_page_state:handle_arc_delta(n, delta)

  if is_type_change then
    tr_rebuild_page_state()
  end

  tr_update_arc()
  if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

local function tr_handle_arc_key(n, z)
  if not tr_page_state then return end
  tr_page_state:handle_arc_key(n, z)
  tr_update_arc()
  if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

-- Screen UI

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "TXO_TR_OUTPUT",
        name = "TXO TR Output",
        description = Descriptions.TXO_TR_OUTPUT,
        params = {},
    })

    norns_ui.needs_playback_refresh = true
    norns_ui.live_view_enabled = true

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()  -- Rebuild params BEFORE entering (so arc.new_section gets valid params)
        tr_rebuild_page_state()
        original_enter(self)
    end

    norns_ui.draw_live = function(self) draw_tr_live() end
    norns_ui.update_arc = function(self) tr_update_arc() end
    norns_ui.handle_arc_delta = function(self, n, delta) tr_handle_arc_delta(n, delta) end
    norns_ui.handle_arc_key = function(self, n, z) tr_handle_arc_key(n, z) end

    norns_ui.handle_live_enc = function(self, n, d)
      if not tr_page_state then return end
      tr_page_state:handle_enc(n, d)
      tr_update_arc()
      _seeker.screen_ui.set_needs_redraw()
    end

    norns_ui.handle_live_key = function(self, n, z)
      if n == 3 and z == 1 and tr_page_state then
        tr_page_state:next_page()
        tr_update_arc()
        _seeker.screen_ui.set_needs_redraw()
      end
    end

    -- Advance to next arc page (used by grid re-tap)
    norns_ui.cycle_page = function(self)
      if tr_page_state then
        tr_page_state:next_page()
        tr_update_arc()
        _seeker.screen_ui.set_needs_redraw()
      end
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

        if type == "Rhythm" then
            table.insert(param_table, { separator = true, title = "Rhythm" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_rhythm_length" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_rhythm_hits" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_rhythm_distribution" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_rhythm_rotation" })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_rhythm_gate_length", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_rhythm_reroll", is_action = true })
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
    params:add_group("txo_tr_output", "TXO TR OUTPUT", 52)

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

        params:add_option("txo_tr_" .. i .. "_type", "Type", {"Rhythm", "Burst"}, 1)
        params:set_action("txo_tr_" .. i .. "_type", function(value)
            pattern_states["txo_" .. i] = nil
            local types = {"Rhythm", "Burst"}
            if types[value] == "Rhythm" then
                TxoTrOutput.generate_rhythm_pattern(i)
            end
            TxoTrOutput.update_txo_tr(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.txo_tr_output then
                _seeker.eurorack.txo_tr_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        -- Rhythm parameters
        params:add_number("txo_tr_" .. i .. "_rhythm_length", "Length", 1, 32, 8)
        params:set_action("txo_tr_" .. i .. "_rhythm_length", function(value)
            TxoTrOutput.generate_rhythm_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_number("txo_tr_" .. i .. "_rhythm_hits", "Hits", 1, 32, 4)
        params:set_action("txo_tr_" .. i .. "_rhythm_hits", function(value)
            TxoTrOutput.generate_rhythm_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_option("txo_tr_" .. i .. "_rhythm_distribution", "Distribution", {"Even", "Random"}, 1)
        params:set_action("txo_tr_" .. i .. "_rhythm_distribution", function(value)
            TxoTrOutput.generate_rhythm_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_number("txo_tr_" .. i .. "_rhythm_rotation", "Rotation", 0, 31, 0)
        params:set_action("txo_tr_" .. i .. "_rhythm_rotation", function(value)
            TxoTrOutput.generate_rhythm_pattern(i)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_number("txo_tr_" .. i .. "_rhythm_gate_length", "Gate Length", 1, 100, 50, function(param) return param.value .. "%" end)
        params:set_action("txo_tr_" .. i .. "_rhythm_gate_length", function(value)
            TxoTrOutput.update_txo_tr(i)
        end)
        params:add_binary("txo_tr_" .. i .. "_rhythm_reroll", "Reroll", "trigger", 0)
        params:set_action("txo_tr_" .. i .. "_rhythm_reroll", function(value)
            TxoTrOutput.reroll_txo_pattern(i)
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

-- Return gate states for CV monitor display.
-- Returns state table for each TXO TR output (1-4).
-- Base fields: { active, type, current, min, max }
-- Rhythm adds: pattern (bool array), current_step (1-indexed)
-- Burst adds: burst_count, burst_shape, burst_time
function TxoTrOutput.get_cv_states()
  local states = {}
  for i = 1, 4 do
    local interval = params:string("txo_tr_" .. i .. "_clock_interval")
    local type_name = params:string("txo_tr_" .. i .. "_type")
    local short = TYPE_SHORT_CODES[type_name] or type_name
    local is_active = interval ~= "Off"
    local ps = pattern_states["txo_" .. i]
    local state = {
      active = is_active,
      type = short,
      current = gate_states[i],
      min = 0,
      max = 1,
    }
    if type_name == "Rhythm" and ps then
      state.pattern = ps.pattern
      state.current_step = ps.current_step
    elseif type_name == "Burst" then
      state.burst_count = params:get("txo_tr_" .. i .. "_burst_count")
      state.burst_shape = params:string("txo_tr_" .. i .. "_burst_shape")
      state.burst_time = params:get("txo_tr_" .. i .. "_burst_time")
    end
    state._source = "txo_tr"
    state._num = i
    states[i] = state
  end
  return states
end

-- Sync all TXO TR outputs by restarting their clocks
function TxoTrOutput.sync()
    for i = 1, 4 do
        TxoTrOutput.update_txo_tr(i)
    end
end

function TxoTrOutput.init()
    create_params()

    -- Generate initial rhythm patterns (default type is Rhythm)
    for i = 1, 4 do
        TxoTrOutput.generate_rhythm_pattern(i)
    end

    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync = TxoTrOutput.sync,
        get_cv_states = TxoTrOutput.get_cv_states
    }

    return component
end

return TxoTrOutput
