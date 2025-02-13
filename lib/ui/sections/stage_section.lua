-- stage_section.lua
local Section = include('lib/ui/section')
local transforms = include('lib/transforms')
local StageSection = setmetatable({}, { __index = Section })
StageSection.__index = StageSection

function StageSection.new()
  local section = Section.new({
    id = "STAGE",
    name = "Stage 0",
    icon = "⌸",
    params = {}
  })
  
  setmetatable(section, StageSection)

  -- Get sorted list of transform names once
  local transform_names = {}
  for name, _ in pairs(transforms.available) do
    table.insert(transform_names, name)
  end
  table.sort(transform_names)
  section.transform_names = transform_names

  function section:get_param_value(param)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage_idx = _seeker.ui_state.get_focused_stage()
    local stage = _seeker.lanes[lane_idx].stages[stage_idx]
    
    -- Handle transform params
    if param.id:match("^transform_") then
      if not stage.transforms[1] then return "" end
      local transform = stage.transforms[1]
      
      if param.id:match("_type$") then
        return transform.name
      else
        local param_name = param.id:match("transform_(.+)$")
        local value = transform.config[param_name]
        
        -- Use formatter if available
        local param_spec = transforms.available[transform.name].params[param_name]
        if param_spec and param_spec.formatter then
          return param_spec.formatter(value)
        end
        
        -- Default formatting
        if type(value) == "number" then
          return string.format("%.2f", value)
        end
        return tostring(value or "")
      end
    end

    -- Handle other stage params
    return params:get(param.id)
  end

  function section:modify_param(param, delta)
    if param.id:match("^transform_") then
      self:set_transform_param_value(param.id, delta)
    else
      params:delta(param.id, delta)
    end
  end

  function section:set_transform_param_value(param_id, delta)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage_idx = _seeker.ui_state.get_focused_stage()
    local stage = _seeker.lanes[lane_idx].stages[stage_idx]
    
    if not stage.transforms[1] then return end
    local transform = stage.transforms[1]

    if param_id:match("_type$") then
      -- Change transform type
      local current_idx = tab.key(self.transform_names, transform.name)
      local new_idx = util.clamp(current_idx + delta, 1, #self.transform_names)
      local new_name = self.transform_names[new_idx]
      
      _seeker.lanes[lane_idx]:change_stage_transform(lane_idx, stage_idx, 1, new_name)
      -- After changing transform type, update the section to show new params
      self:update_focused_stage(stage_idx)
    else
      -- Modify transform parameter
      local param_name = param_id:match("transform_(.+)$")
      local param_spec = transforms.available[transform.name].params[param_name]
      local current = transform.config[param_name]
      local step = param_spec.step or (param_spec.type == "integer" and 1 or (param_spec.max - param_spec.min) / 20)
      
      local new_value = util.clamp(
        current + (delta * step),
        param_spec.min,
        param_spec.max
      )

      transform.config[param_name] = new_value
      if param_spec.type == "integer" then
        transform.config[param_name] = math.floor(transform.config[param_name] + 0.5)
      end
    end
  end

  function section:update_focused_stage(new_stage_idx)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage = _seeker.lanes[lane_idx].stages[new_stage_idx]
    
    -- Build param list starting with stage controls
    self.params = {
      { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_mute", name = "Mute" },
      { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_reset_motif", name = "Reset Motif" },
      { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_loops", name = "Loops" },
      { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_loop_trigger", name = "Loop Trigger" },
      { separator = true, name = "TRANSFORM" }
    }

    -- Add transform params if stage has transforms
    if stage and stage.transforms and stage.transforms[1] then
      local transform = stage.transforms[1]
      local transform_def = transforms.available[transform.name]
      
      -- Add transform type selector with header
      table.insert(self.params, {
        id = "transform_type",
        name = "Transform",
        value = transform.name,
        values = self.transform_names,
        is_header = true
      })

      -- Add transform-specific params
      if transform_def and transform_def.params then
        for param_name, param_spec in pairs(transform_def.params) do
          table.insert(self.params, {
            id = "transform_" .. param_name,
            name = "  " .. param_name,  -- Indent params
            value = transform.config[param_name],
            spec = param_spec
          })
        end
      end
    end

    self.name = string.format("Stage %d", new_stage_idx)
    _seeker.ui_state.dirty = true -- Mark UI for refresh
  end

  return section
end

return StageSection

