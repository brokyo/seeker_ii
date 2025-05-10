-- lane_utils.lua
-- Shared utilities for working with lanes

local params_manager = include('lib/params_manager')

local lane_utils = {}

-- Get the instrument name for a lane
function lane_utils.get_lane_instrument(lane_num)
  local lane = _seeker.conductor.lanes[lane_num]
  local instrument_id = lane:get_param("instrument")
  local instruments = params_manager.get_instrument_list()
  return instruments[instrument_id]
end

return lane_utils 