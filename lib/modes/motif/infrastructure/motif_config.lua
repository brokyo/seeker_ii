-- motif_config.lua
-- Arrangement view (cross-lane overview) and global motif settings.

local NornsUI = include("lib/ui/base/norns_ui")
local PageState = include("lib/ui/components/page_state")
local LaneMap = include("lib/lanes/lane_map")
local Descriptions = include("lib/ui/component_descriptions")

local MotifConfig = {}
MotifConfig.__index = MotifConfig

local function create_params()
    params:add_group("motif_config", "MOTIF CONFIG", 6)

    -- Sync trigger
    params:add_binary("motif_config_sync_all_clocks", "Synchronize All", "trigger", 0)
    params:set_action("motif_config_sync_all_clocks", function(value)
        if value == 1 then
            if _seeker and _seeker.conductor then
                _seeker.conductor.sync_all()
            end
            _seeker.ui_state.trigger_activated("motif_config_sync_all_clocks")
        end
    end)

    -- Keyboard layout parameters
    params:add_number("motif_config_column_steps", "Column Spacing", 1, 8, 1)
    params:set_action("motif_config_column_steps", function(value)
        local theory = include('lib/modes/motif/core/theory')
        theory.print_keyboard_layout()
    end)

    params:add_number("motif_config_row_steps", "Row Spacing", 1, 8, 4)
    params:set_action("motif_config_row_steps", function(value)
        local theory = include('lib/modes/motif/core/theory')
        theory.print_keyboard_layout()
    end)

    -- Global tuning
    -- Tuning presets: curated root/scale combinations for emotional palettes
    -- Format: {root_note_index, scale_index} where root 1=C, scale per musicutil.SCALES
    params:add_option("tuning_preset", "Preset",
        {"Custom", "Ethereal", "Mysterious", "Melancholic", "Hopeful", "Contemplative", "Triumphant",
         "Dreamy", "Ancient", "Pastoral", "Nocturne", "Ritual", "Celestial",
         "Moss", "Temple", "Overworld", "Save Point"}, 17)
    params:set_action("tuning_preset", function(value)
        if value > 1 then
            local presets = {
                {6, 7},   -- Ethereal: F Lydian
                {2, 3},   -- Mysterious: C# Harmonic Minor
                {10, 2},  -- Melancholic: A Natural Minor
                {8, 1},   -- Hopeful: G Major
                {5, 5},   -- Contemplative: E Dorian
                {1, 1},   -- Triumphant: C Major
                {9, 7},   -- Dreamy: Ab Lydian
                {3, 6},   -- Ancient: D Phrygian
                {8, 11},  -- Pastoral: G Major Pentatonic
                {4, 3},   -- Nocturne: Eb Harmonic Minor
                {5, 6},   -- Ritual: E Phrygian
                {7, 7},   -- Celestial: F# Lydian
                {3, 44},  -- Moss: D In Sen Pou (Japanese ambient)
                {10, 42}, -- Temple: A Gagaku Ryo Sen Pou (Japanese court)
                {8, 8},   -- Overworld: G Mixolydian (adventure game)
                {4, 7},   -- Save Point: Eb Lydian (RPG rest moment)
            }
            local preset = presets[value - 1]
            params:set("root_note", preset[1], true)
            params:set("scale_type", preset[2], true)
            local theory = include('lib/modes/motif/core/theory')
            theory.print_keyboard_layout()
        end
    end)

    params:add_option("root_note", "Root Note", {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 6)
    params:set_action("root_note", function(value)
        params:set("tuning_preset", 1, true)
        local theory = include('lib/modes/motif/core/theory')
        theory.print_keyboard_layout()
    end)

    local musicutil = require('musicutil')
    local scale_names = {}
    for i = 1, #musicutil.SCALES do
        scale_names[i] = musicutil.SCALES[i].name
    end
    params:add_option("scale_type", "Scale", scale_names, 8)
    params:set_action("scale_type", function(value)
        params:set("tuning_preset", 1, true)
        local theory = include('lib/modes/motif/core/theory')
        theory.print_keyboard_layout()
    end)

end

-- Arrangement view state
local selected_lane = 1
local MARGIN_LEFT = 18
local MARGIN_RIGHT = 4
local ROW_TOP = 2
local ROW_BOTTOM = 44
local ROW_GAP = 2
local BAR_WIDTH = 128 - MARGIN_LEFT - MARGIN_RIGHT

local function get_active_lanes()
    local active = {}
    for i = 1, 16 do
        local lane = _seeker.lanes[i]
        if lane.playing then
            table.insert(active, { id = i, lane = lane })
        end
    end
    return active
end

local function get_lane_label(lane_id)
    local sub_mode, local_idx = LaneMap.from_flat(lane_id)
    return sub_mode:sub(1, 1):upper() .. local_idx
end

local function get_cycle_info(lane)
    local motif_dur = lane.last_motif_duration
    if not motif_dur or motif_dur <= 0 then
        motif_dur = lane.motif:get_duration() / lane.speed
    end
    if motif_dur <= 0 then motif_dur = 1 end

    local play_loops = 0
    for _, stage in ipairs(lane.stages) do
        if stage.active then
            play_loops = play_loops + (stage.effective_loops or stage.loops)
        end
    end

    local rest_loops = lane.rest_loops
    local total_loops = play_loops + rest_loops
    if total_loops == 0 then total_loops = 1 end

    return play_loops, rest_loops, total_loops, motif_dur
end

local function get_cycle_position(lane)
    local play_loops, rest_loops, total_loops, motif_dur = get_cycle_info(lane)

    if lane.resting then
        local rest_done = lane.rest_loops - lane.rest_loops_remaining
        local rest_progress = 0
        if lane.rest_loop_start_time then
            local elapsed = clock.get_beats() - lane.rest_loop_start_time
            rest_progress = math.max(0, math.min(1, elapsed / motif_dur))
        end
        return math.max(0, math.min(1, (play_loops + rest_done + rest_progress) / total_loops))
    end

    local stage = lane.stages[lane.current_stage_index]
    if not stage or not stage.last_start_time then return 0 end

    local loops_before = 0
    for _, s in ipairs(lane.stages) do
        if s.active then
            if s.id == stage.id then break end
            loops_before = loops_before + (s.effective_loops or s.loops)
        end
    end
    loops_before = loops_before + stage.current_loop

    local elapsed_in_loop = clock.get_beats() - stage.last_start_time
    local loop_progress = math.max(0, math.min(1, elapsed_in_loop / motif_dur))
    return math.max(0, math.min(1, (loops_before + loop_progress) / total_loops))
end

local function draw_arrangement()
    local active = get_active_lanes()

    if #active == 0 then
        screen.level(3)
        screen.move(64, 24)
        screen.text_center("no active lanes")
        return
    end

    -- Shared time axis: find the longest cycle in beats
    local max_cycle_beats = 0
    local lane_cycles = {}
    for _, entry in ipairs(active) do
        local play_loops, rest_loops, total_loops, motif_dur = get_cycle_info(entry.lane)
        local cycle_beats = total_loops * motif_dur
        if cycle_beats > max_cycle_beats then max_cycle_beats = cycle_beats end
        lane_cycles[entry.id] = {
            play_loops = play_loops,
            rest_loops = rest_loops,
            total_loops = total_loops,
            motif_dur = motif_dur,
            cycle_beats = cycle_beats,
        }
    end
    if max_cycle_beats <= 0 then max_cycle_beats = 1 end

    local available_height = ROW_BOTTOM - ROW_TOP
    local row_height = math.floor((available_height - (ROW_GAP * (#active - 1))) / #active)
    row_height = math.min(row_height, 12)

    for idx, entry in ipairs(active) do
        local lane = entry.lane
        local lane_id = entry.id
        local y = ROW_TOP + (idx - 1) * (row_height + ROW_GAP)
        local is_selected = (lane_id == selected_lane)
        local ci = lane_cycles[lane_id]

        -- Label
        screen.level(is_selected and 15 or 5)
        screen.move(2, y + row_height - 1)
        screen.text(get_lane_label(lane_id))

        -- Tile the duty cycle pattern across the shared time axis
        local cycle_w = BAR_WIDTH * (ci.cycle_beats / max_cycle_beats)
        local play_w = cycle_w * (ci.play_loops / ci.total_loops)
        local rest_w = cycle_w - play_w
        local num_tiles = math.ceil(max_cycle_beats / ci.cycle_beats)

        for tile = 0, num_tiles - 1 do
            local tile_x = MARGIN_LEFT + tile * cycle_w

            -- Clip to bar bounds
            if tile_x >= MARGIN_LEFT + BAR_WIDTH then break end

            -- Play portion: filled
            local pw = math.min(play_w, MARGIN_LEFT + BAR_WIDTH - tile_x)
            if pw > 0 then
                screen.level(is_selected and 8 or 4)
                screen.rect(tile_x, y, pw, row_height)
                screen.fill()
            end

            -- Rest portion: outlined
            local rest_x = tile_x + play_w
            if rest_w > 0 and rest_x < MARGIN_LEFT + BAR_WIDTH then
                local rw = math.min(rest_w, MARGIN_LEFT + BAR_WIDTH - rest_x)
                if rw > 0 then
                    screen.level(is_selected and 4 or 2)
                    screen.rect(rest_x, y, rw, row_height)
                    screen.stroke()
                end
            end

            -- Stage boundary ticks within play portion
            local loops_accum = 0
            for _, s in ipairs(lane.stages) do
                if s.active then
                    local stage_loops = s.effective_loops or s.loops
                    loops_accum = loops_accum + stage_loops
                    if loops_accum < ci.play_loops then
                        local tick_x = tile_x + cycle_w * (loops_accum / ci.total_loops)
                        if tick_x > MARGIN_LEFT and tick_x < MARGIN_LEFT + BAR_WIDTH then
                            screen.level(is_selected and 12 or 6)
                            screen.move(tick_x, y)
                            screen.line(tick_x, y + row_height)
                            screen.stroke()
                        end
                    end
                end
            end

            -- Cycle boundary (dim vertical line between tiles)
            if tile > 0 then
                screen.level(is_selected and 6 or 3)
                screen.move(tile_x, y)
                screen.line(tile_x, y + row_height)
                screen.stroke()
            end
        end

        -- Position marker (repeats in each tile)
        local pos = get_cycle_position(lane)
        for tile = 0, num_tiles - 1 do
            local marker_x = MARGIN_LEFT + math.floor((tile + pos) * cycle_w)
            if marker_x >= MARGIN_LEFT and marker_x <= MARGIN_LEFT + BAR_WIDTH then
                screen.level(15)
                screen.move(marker_x, y)
                screen.line(marker_x, y + row_height)
                screen.stroke()
            end
        end

        -- Selection bracket
        if is_selected then
            screen.level(15)
            screen.rect(MARGIN_LEFT - 1, y - 1, BAR_WIDTH + 2, row_height + 2)
            screen.stroke()
        end
    end
end

---------------------------------------------------------------
-- PageState: arc rings map to active lanes, 4 per page
---------------------------------------------------------------
local page_state = nil

local function build_arrangement_pages()
    local active = get_active_lanes()
    if #active == 0 then
        return {{ name = "rest", slots = {} }}
    end

    local pages = {}
    for page_start = 1, #active, 4 do
        local slots = {}
        for i = 0, 3 do
            local entry = active[page_start + i]
            if not entry then break end
            local lane_id = entry.id
            local label = get_lane_label(lane_id)
            slots[#slots + 1] = {
                label = label,
                threshold = PageState.THRESH_RANGE,
                on_delta = function(dir)
                    params:delta("lane_" .. lane_id .. "_rest_loops", dir)
                end,
                get_value = function()
                    return _seeker.lanes[lane_id].rest_loops
                end,
                arc_draw = function(dev, ring)
                    PageState.draw_arc_position(dev, ring, _seeker.lanes[lane_id].rest_loops, 0, 16)
                end,
            }
        end
        local first_label = get_lane_label(active[page_start].id)
        local last_entry = active[math.min(page_start + 3, #active)]
        local last_label = get_lane_label(last_entry.id)
        table.insert(pages, { name = first_label .. "-" .. last_label, slots = slots })
    end

    return pages
end

local function refresh_page_state()
    if page_state then
        page_state:set_pages(build_arrangement_pages())
    end
end

---------------------------------------------------------------
-- NornsUI: arrangement view with live drawing
---------------------------------------------------------------
local function create_screen_ui()
    page_state = PageState.new({ pages = build_arrangement_pages() })

    local norns_ui = NornsUI.new({
        id = "MOTIF",
        name = "Arrangement",
        description = "Cross-lane arrangement view.\n\nShows all 16 lanes grouped by mode. Bars show playback progress, dim outlines show resting lanes.\n\nE2 selects lane. E3 adjusts rest loops. Arc rings control the 4 lanes in the selected group.",
        params = {}
    })

    norns_ui.live_view_enabled = true
    norns_ui.needs_playback_refresh = true

    norns_ui.rebuild_params = function(self)
        self.params = {
            { separator = true, title = "Rest Loops" },
        }
        for i = 1, 16 do
            table.insert(self.params, { id = "lane_" .. i .. "_rest_loops" })
        end
    end

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        local active = get_active_lanes()
        if #active > 0 then
            selected_lane = active[1].id
        end
        refresh_page_state()
        original_enter(self)
    end

    norns_ui.draw_live = function(self)
        draw_arrangement()
        page_state:draw_footer()
    end

    page_state:wire(norns_ui, {
        refresh = function()
            local dev = _seeker.arc
            if dev then page_state:update_arc(dev); dev:refresh() end
            if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
        end,
    })

    -- Override E2/E3 for lane selection and rest_loops, preserve E1 for PageState
    local wired_enc = norns_ui.handle_live_enc
    norns_ui.handle_live_enc = function(self, n, d)
        if n == 1 then
            if wired_enc then wired_enc(self, n, d) end
        elseif n == 2 then
            -- Cycle through active lanes
            local active = get_active_lanes()
            if #active == 0 then return end
            local current_idx = 1
            for i, entry in ipairs(active) do
                if entry.id == selected_lane then current_idx = i; break end
            end
            local new_idx = util.clamp(current_idx + d, 1, #active)
            selected_lane = active[new_idx].id
            if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
        elseif n == 3 then
            local param_id = "lane_" .. selected_lane .. "_rest_loops"
            params:delta(param_id, d)
            if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
        end
    end

    return norns_ui
end

local function create_tape_home_screen()
    local norns_ui = NornsUI.new({
        id = "TAPE_HOME",
        name = "Tape Config",
        description = "Grid layout for the tape keyboard.\n\nColumn and row spacing control how notes are arranged on the grid.",
        params = {}
    })

    norns_ui.rebuild_params = function(self)
        self.params = {
            { id = "motif_config_column_steps" },
            { id = "motif_config_row_steps" },
        }
    end

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end

    return norns_ui
end

function MotifConfig.init()
    local component = {
        screen = create_screen_ui(),
        tape_home_screen = create_tape_home_screen(),
    }
    create_params()

    return component
end

return MotifConfig
