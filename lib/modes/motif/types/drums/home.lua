-- home.lua
-- Drums home screen: step count, gate length, voice note, euclidean fills

local NornsUI = include("lib/ui/base/norns_ui")

local DrumsHome = {}

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "DRUMS_HOME",
    name = "Drums",
    description = "Trigger step sequencer. Toggle steps on the grid. Each lane is an independent voice with its own pattern length and timing.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    self.params = {
      { separator = true, title = "Pattern" },
      { id = "lane_" .. lane_idx .. "_drum_steps" },
      { id = "lane_" .. lane_idx .. "_drum_gate_length", arc_multi_float = {0.1, 0.05, 0.01} },
      { id = "lane_" .. lane_idx .. "_drum_voice_note" },
      { separator = true, title = "Euclidean" },
      { id = "lane_" .. lane_idx .. "_drum_euclidean_fills" },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

function DrumsHome.init()
  return { screen = create_screen_ui() }
end

return DrumsHome
