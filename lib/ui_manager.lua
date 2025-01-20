-- ui_manager.lua
--
-- Coordinates UI updates between grid and screen components.
-- Core responsibilities:
-- 1. Holds references to both UI components
-- 2. Manages focus state and UI updates
-- 3. Ensures consistent UI state across components
--
-- Note: Core state (focused_lane/stage) lives in _seeker since it represents
-- the instrument's current focus. UIManager is responsible only for
-- coordinating updates when that state changes.
--------------------------------------------------

local UIManager = {}
UIManager.__index = UIManager  -- Add this line to make it a proper class

function UIManager.init(grid, screen)  -- Change back to init
  local mgr = {
    grid = grid,
    screen = screen
  }
  setmetatable(mgr, UIManager)  -- Use UIManager as metatable
  return mgr
end

--------------------------------------------------
-- Focus Management
--------------------------------------------------

-- Change focused lane and update UI appropriately
function UIManager:focus_lane(lane_num)
  _seeker.focused_lane = lane_num
  if self.screen then
    self.screen.current_page = 1  -- LANE page
    self.screen.current_param_index = 1
  end
  self:redraw_all()
end

-- Change focused stage and update UI appropriately
function UIManager:focus_stage(lane_num, stage_num)
  _seeker.focused_lane = lane_num
  _seeker.focused_stage = stage_num
  if self.screen then
    self.screen.current_page = 2  -- STAGE page
    self.screen.current_param_index = 1
  end
  self:redraw_all()
end

function UIManager:redraw_all()
  if self.grid then self.grid.redraw() end
  if self.screen then self.screen.redraw() end
end

return UIManager 