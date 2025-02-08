-- config_section.lua
local Section = include('lib/ui/section')
local ConfigSection = setmetatable({}, { __index = Section })
ConfigSection.__index = ConfigSection

function ConfigSection.new()
  local section = Section.new({
    id = "CONFIG",
    name = "CONFIG",
    icon = "⚙",
    params = {
      { id = "root_note", name = "Root Note" },
      { id = "scale_type", name = "Scale" },
      { separator = true, name = "ACTIONS" },
      { id = "reset", name = "Reset All", action = true }
    }
  })
  
  setmetatable(section, ConfigSection)

  -- Override modify_param to handle action items
  function section:modify_param(param, delta)
    if param.action then
      if param.id == "reset" then
        -- Reset all params to defaults
        params:reset()
        -- Sync all lanes with default params
        for i = 1, 4 do
          if _seeker.lanes[i] then
            _seeker.lanes[i]:sync_all_stages_from_params()
          end
        end
        print("⚡ Reset to defaults")
      end
    else
      -- Use default param modification for non-action items
      Section.modify_param(self, param, delta)
    end
  end

  -- Override get_param_value to handle action items
  function section:get_param_value(param)
    if param.action then
      return "► Press K3"
    else
      return Section.get_param_value(self, param)
    end
  end

  return section
end

return ConfigSection 