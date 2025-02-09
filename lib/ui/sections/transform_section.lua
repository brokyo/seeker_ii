-- transform_section.lua
local Section = include('lib/ui/section')
local transforms = include('lib/transforms')
local TransformSection = setmetatable({}, { __index = Section })
TransformSection.__index = TransformSection

function TransformSection.new()
  local section = Section.new({
    id = "TRANSFORM",
    name = "Transform",
    icon = "⚙️",
    params = {}
  })

  setmetatable(section, TransformSection)

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
    
    -- Parse transform index from param_id
    local transform_idx = tonumber(param.id:match("transform_(%d+)"))
    if not transform_idx or not stage.transforms[transform_idx] then return "" end
    
    local transform = stage.transforms[transform_idx]
    
    if param.id:match("_type$") then
      return transform.name
    else
      local param_name = param.id:match("transform_%d_(.+)$")
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

  function section:modify_param(param, delta)
    self:set_param_value(param.id, delta)
  end

  function section:update()
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage_idx = _seeker.ui_state.get_focused_stage()
    local stage = _seeker.lanes[lane_idx].stages[stage_idx]
    
    -- Build param list
    self.params = {}
    
    -- Add all three transforms and their params
    if stage and stage.transforms then
      for transform_idx = 1, 3 do
        local transform = stage.transforms[transform_idx]
        if transform then
          local transform_def = transforms.available[transform.name]
          
          -- Add transform type selector with header
          table.insert(self.params, {
            id = string.format("transform_%d_type", transform_idx),
            name = string.format("Transform %d", transform_idx),
            value = transform.name,
            values = self.transform_names,
            is_header = true  -- For visual treatment
          })

          -- Add transform-specific params indented
          if transform_def and transform_def.params then
            for param_name, param_spec in pairs(transform_def.params) do
              table.insert(self.params, {
                id = string.format("transform_%d_%s", transform_idx, param_name),
                name = "  " .. param_name,  -- Indent params
                value = transform.config[param_name],
                spec = param_spec,
                transform_idx = transform_idx  -- Track which transform this belongs to
              })
            end
          end
        end
      end
    end
  end

  function section:set_param_value(param_id, delta)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage_idx = _seeker.ui_state.get_focused_stage()
    local stage = _seeker.lanes[lane_idx].stages[stage_idx]

    -- Parse transform index from param_id
    local transform_idx = tonumber(param_id:match("transform_(%d+)"))
    if not transform_idx or not stage.transforms[transform_idx] then 
      print("⎊ Invalid transform index")
      return 
    end
    
    local transform = stage.transforms[transform_idx]

    if param_id:match("_type$") then
      -- Change transform type
      local current_idx = tab.key(self.transform_names, transform.name)
      local new_idx = util.clamp(current_idx + delta, 1, #self.transform_names)
      local new_name = self.transform_names[new_idx]
      
      _seeker.lanes[lane_idx]:change_stage_transform(lane_idx, stage_idx, transform_idx, new_name)
    else
      -- Modify transform parameter
      local param_name = param_id:match("transform_%d_(.+)$")
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

  return section
end

return TransformSection

