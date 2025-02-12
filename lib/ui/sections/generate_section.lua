-- generate_section.lua
local Section = include('lib/ui/section')
local MotifGenerator = include('lib/motif_generator')
local GenerateSection = setmetatable({}, { __index = Section })
GenerateSection.__index = GenerateSection

function GenerateSection.new()
  local section = Section.new({
    id = "GENERATE",
    name = "Generate",
    params = {}
  })
  setmetatable(section, GenerateSection)

  function section:get_param_value(param)
    if param.id == "generator_type" then
      return MotifGenerator.get_current()
    else
      local params = MotifGenerator.get_params(MotifGenerator.get_current())
      local param_data = params[param.id]
      return param_data.spec.formatter and param_data.spec.formatter(param_data.value) or tostring(param_data.value)
    end
  end

  function section:modify_param(param, delta)
    if param.id == "generator_type" then
      -- Get ordered list of generators
      local generators = MotifGenerator.get_generators()
      local current = MotifGenerator.get_current()
      
      -- Find current index
      local current_idx = 1
      for i, gen in ipairs(generators) do
        if gen.id == current then
          current_idx = i
          break
        end
      end
      
      -- Calculate new index
      local new_idx = util.clamp(current_idx + delta, 1, #generators)
      local new_generator = generators[new_idx].id
      
      if new_generator ~= current then
        if MotifGenerator.select_generator(new_generator) then
          self:update_param_list()
        end
      end
    else
      -- Modify parameter value
      local params = MotifGenerator.get_params(MotifGenerator.get_current())
      local param_data = params[param.id]

      -- Section handler for custom params
      local new_value = Section.modify_param(self, {
        id = param.id,
        value = param_data.value,
        spec = param_data.spec
      }, delta)

      MotifGenerator.set_param(param.id, new_value)
    end
  end

  function section:update_param_list()
    -- Get current generator info
    local current = MotifGenerator.get_current()
    local params = MotifGenerator.get_params(current)
    
    -- Build parameter list
    self.params = {
      {
        id = "generator_type",
        name = "Generator Type",
        spec = { 
          type = "option", 
          values = MotifGenerator.get_generators() 
        }
      }
    }
    
    -- Add generator-specific parameters
    for id, param_data in pairs(params) do
      table.insert(self.params, {
        id = id,
        name = "  " .. (param_data.spec.name or id),
        spec = param_data.spec
      })
    end
  end

  -- Initialize param list
  section:update_param_list()

  return section
end

return GenerateSection 