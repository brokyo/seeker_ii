-- perform.lua
-- Drums: performance effects via shared PerformEngine.
-- Provides mute and velocity multiplier for lane_handlers.

local PerformEngine = include("lib/modes/motif/infrastructure/perform_engine")
local LaneMap = include("lib/lanes/lane_map")

local DrumsPerform = {}

local function get_param_prefix(lane_id)
  return "lane_" .. lane_id .. "_drums_performance"
end

function DrumsPerform.get_velocity_multiplier(lane_id)
  return PerformEngine.get_velocity_multiplier(lane_id, get_param_prefix(lane_id))
end

function DrumsPerform.is_muted(lane_id)
  return PerformEngine.is_muted(lane_id, get_param_prefix(lane_id))
end

function DrumsPerform.is_active(lane_id)
  return PerformEngine.is_active(lane_id)
end

local function create_params()
  for _, i in ipairs(LaneMap.lanes_for_mode("drums")) do
    local prefix = get_param_prefix(i)
    PerformEngine.create_params_for_lane(i, prefix, "LANE " .. i .. " DRUMS PERFORMANCE")
  end
end

function DrumsPerform.init()
  create_params()
  return {}
end

return DrumsPerform
