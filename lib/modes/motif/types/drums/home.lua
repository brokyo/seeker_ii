-- home.lua
-- Drums rhythm monitor: all 4 lanes visible simultaneously.
-- Focused lane gets large dot pattern viz, 3 others get compact strips.
-- K2 toggles between live view and param editing. Arc pages via PageState.

local NornsUI = include("lib/ui/base/norns_ui")
local LaneMap = include("lib/lanes/lane_map")
local PageState = include("lib/ui/components/page_state")

local DrumsHome = {}

local page_state = nil

local function build_pages()
  return {
    {
      name = "pattern",
      slots = {
        {
          label = "Hits",
          param_id_fn = function()
            return "lane_" .. _seeker.ui_state.get_focused_lane() .. "_drum_hits"
          end,
          threshold = 56,
        },
        {
          label = "Len",
          param_id_fn = function()
            return "lane_" .. _seeker.ui_state.get_focused_lane() .. "_drum_length"
          end,
          threshold = 56,
        },
        {
          label = "Dist",
          param_id_fn = function()
            return "lane_" .. _seeker.ui_state.get_focused_lane() .. "_drum_distribution"
          end,
          threshold = 56,
        },
        {
          label = "Rot",
          param_id_fn = function()
            return "lane_" .. _seeker.ui_state.get_focused_lane() .. "_drum_rotation"
          end,
          threshold = 56,
        },
      },
    },
    {
      name = "timing",
      slots = {
        {
          label = "Gate",
          param_id_fn = function()
            return "lane_" .. _seeker.ui_state.get_focused_lane() .. "_drum_gate_length"
          end,
          threshold = PageState.THRESH_RANGE,
        },
        {
          label = "Swng",
          param_id_fn = function()
            return "lane_" .. _seeker.ui_state.get_focused_lane() .. "_drum_swing"
          end,
          threshold = PageState.THRESH_RANGE,
        },
        {
          label = "Prob",
          param_id_fn = function()
            return "lane_" .. _seeker.ui_state.get_focused_lane() .. "_drum_probability"
          end,
          threshold = PageState.THRESH_RANGE,
        },
        {
          label = "Div",
          param_id_fn = function()
            return "lane_" .. _seeker.ui_state.get_focused_lane() .. "_drum_division"
          end,
          threshold = 56,
        },
      },
    },
  }
end

local function draw_lane_pattern(lane_id, y_top, h, is_focused)
  local StepGrid = include("lib/modes/motif/types/drums/step_grid")
  local length = StepGrid.get_length(lane_id)
  local state = StepGrid.get_step_state(lane_id)
  local lane = _seeker.lanes[lane_id]

  local playing = lane and lane.playing
  local current_step = nil
  if playing and lane.motif and lane.motif.duration > 0 then
    local division_idx = params:get("lane_" .. lane_id .. "_drum_division")
    local division_values = {0.25, 1/3, 0.5, 2/3, 1, 1.5, 2, 3, 4}
    local division = division_values[division_idx]
    local beat_pos = lane.current_beat_position or 0
    current_step = math.floor(beat_pos / division) + 1
    if current_step > length then current_step = ((current_step - 1) % length) + 1 end
  end

  local dot_spacing = 124 / length
  local mid_y = y_top + math.floor(h / 2)
  local dot_r = is_focused and util.clamp(math.floor(dot_spacing / 3), 1, 4) or util.clamp(math.floor(dot_spacing / 4), 1, 2)

  for i = 1, length do
    local cx = 2 + math.floor((i - 0.5) * dot_spacing)
    local is_current = playing and (i == current_step)

    if state[i].active then
      screen.level(is_current and 15 or (is_focused and 10 or 6))
      screen.circle(cx, mid_y, dot_r)
      screen.fill()
    else
      screen.level(is_current and 8 or (is_focused and 3 or 1))
      screen.circle(cx, mid_y, dot_r)
      screen.stroke()
    end
  end
end

local function draw_live()
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local lane_ids = LaneMap.lanes_for_mode("drums")

  local focused_local = focused_lane - LaneMap.OFFSETS.drums
  local focused_label = "D" .. focused_local
  local length = params:get("lane_" .. focused_lane .. "_drum_length")
  local hits = params:get("lane_" .. focused_lane .. "_drum_hits")
  local lane = _seeker.lanes[focused_lane]
  local playing = lane and lane.playing

  -- Header
  screen.level(playing and 15 or 8)
  screen.move(2, 7)
  screen.text(focused_label .. " " .. hits .. "/" .. length)

  if playing then
    screen.level(4)
    screen.move(126, 7)
    screen.text_right("*")
  end

  -- Focused lane: large viz
  draw_lane_pattern(focused_lane, 10, 20, true)

  -- Compact lanes: stacked below
  local compact_y = 33
  local compact_h = 8
  local compact_count = 0
  for _, lid in ipairs(lane_ids) do
    if lid ~= focused_lane then
      local local_idx = lid - LaneMap.OFFSETS.drums
      local l = _seeker.lanes[lid]
      local l_playing = l and l.playing
      local l_length = params:get("lane_" .. lid .. "_drum_length")
      local l_hits = params:get("lane_" .. lid .. "_drum_hits")

      -- Label
      screen.level(l_playing and 8 or 3)
      screen.move(2, compact_y + compact_h - 1)
      screen.text("D" .. local_idx)

      -- Pattern dots offset to clear label
      local save_state = screen.peek and nil -- norns doesn't have peek
      local label_width = 12
      screen.level(0)

      draw_lane_pattern(lid, compact_y, compact_h, false)

      compact_y = compact_y + compact_h + 1
      compact_count = compact_count + 1
    end
  end

  -- PageState footer and indicators
  if page_state then
    page_state:draw_page_indicators()
    page_state:draw_page_flash()
    page_state:draw_footer()
  end
end

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "DRUMS_HOME",
    name = "Drums",
    description = "Polymetric drum sequencer. Toggle steps on the grid, configure pattern and timing here.",
    params = {}
  })

  norns_ui.live_view_enabled = true
  norns_ui.needs_playback_refresh = true

  norns_ui.rebuild_params = function(self)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local StepGrid = include("lib/modes/motif/types/drums/step_grid")
    local step = StepGrid.selected_step
    local s = StepGrid.get_step(lane_id, step)
    local step_label = "Step " .. step .. (s.active and " *" or " o")

    params:set("drum_step_velocity", s.velocity, true)
    params:set("drum_step_ratchet", s.ratchet, true)

    local local_idx = lane_id - LaneMap.OFFSETS.drums
    self.name = "D" .. local_idx .. " " .. step_label

    self.params = {
      { id = "drum_step_velocity" },
      { id = "drum_step_ratchet" },
    }
  end

  norns_ui.draw_live = function(self) draw_live() end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

local function create_step_edit_params()
  local StepGrid = include("lib/modes/motif/types/drums/step_grid")

  params:add_group("drum_step_edit", "DRUM STEP EDIT", 2)

  params:add_number("drum_step_velocity", "Step Velocity", 1, 127, 100)
  params:set_action("drum_step_velocity", function(value)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local sub_mode = LaneMap.from_flat(lane_id)
    if sub_mode ~= "drums" then return end
    local s = StepGrid.get_step(lane_id, StepGrid.selected_step)
    if s then
      s.velocity = value
      StepGrid.rebuild_motif(lane_id)
    end
  end)

  params:add_number("drum_step_ratchet", "Ratchet", 1, 8, 1)
  params:set_action("drum_step_ratchet", function(value)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local sub_mode = LaneMap.from_flat(lane_id)
    if sub_mode ~= "drums" then return end
    local s = StepGrid.get_step(lane_id, StepGrid.selected_step)
    if s then
      s.ratchet = value
      StepGrid.rebuild_motif(lane_id)
    end
  end)
end

function DrumsHome.init()
  create_step_edit_params()

  -- Build PageState with param_id_fn-based pages
  local pages_def = build_pages()
  local resolved_pages = {}
  for _, page in ipairs(pages_def) do
    local resolved_slots = {}
    for _, slot in ipairs(page.slots) do
      if slot.param_id_fn then
        local param_id = slot.param_id_fn()
        table.insert(resolved_slots, {
          label = slot.label,
          param_id = param_id,
          threshold = slot.threshold,
        })
      else
        table.insert(resolved_slots, slot)
      end
    end
    table.insert(resolved_pages, { name = page.name, slots = resolved_slots })
  end
  page_state = PageState.new({ pages = resolved_pages })

  local screen = create_screen_ui()

  -- Wire PageState for arc/enc/key routing
  page_state:wire(screen, {
    refresh = function()
      -- Rebuild page slots with current focused lane's param IDs
      local pages_def_refresh = build_pages()
      local new_pages = {}
      for _, page in ipairs(pages_def_refresh) do
        local slots = {}
        for _, slot in ipairs(page.slots) do
          if slot.param_id_fn then
            table.insert(slots, {
              label = slot.label,
              param_id = slot.param_id_fn(),
              threshold = slot.threshold,
            })
          else
            table.insert(slots, slot)
          end
        end
        table.insert(new_pages, { name = page.name, slots = slots })
      end
      page_state:set_pages(new_pages)

      local dev = _seeker.arc
      if dev then page_state:update_arc(dev); dev:refresh() end
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end,
  })

  return { screen = screen }
end

return DrumsHome
