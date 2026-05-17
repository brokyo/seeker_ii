-- perform.lua
-- Dialogue: performance effects via shared PerformEngine.
-- Provides mute and velocity multiplier for lane_handlers.

local PerformEngine = include("lib/modes/motif/infrastructure/perform_engine")
local LaneMap = include("lib/lanes/lane_map")

local DialoguePerform = {}

local function get_param_prefix(lane_id)
  return "lane_" .. lane_id .. "_dialogue_performance"
end

function DialoguePerform.get_velocity_multiplier(lane_id)
  return PerformEngine.get_velocity_multiplier(lane_id, get_param_prefix(lane_id))
end

function DialoguePerform.is_muted(lane_id)
  return PerformEngine.is_muted(lane_id, get_param_prefix(lane_id))
end

function DialoguePerform.is_active(lane_id)
  return PerformEngine.is_active(lane_id)
end

local function create_params()
  for _, i in ipairs(LaneMap.lanes_for_mode("dialogue")) do
    local prefix = get_param_prefix(i)
    PerformEngine.create_params_for_lane(i, prefix, "LANE " .. i .. " DIALOGUE PERFORMANCE")
  end
end

function DialoguePerform.init()
  create_params()
  return {}
end

return DialoguePerform
