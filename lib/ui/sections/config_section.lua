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
      { id = "tuning_preset", name = "Tuning" },
      { id = "root_note", name = "Root Note" },
      { id = "scale_type", name = "Scale" },
      { id = "clock_pulse_out", name = "Clock Out" },
      { id = "clock_division", name = "Clock Div" },
      { id = "background_brightness", name = "Background Brightness" },
      { separator = true, name = "ACTIONS" },
      { id = "test_pulse", name = "Test Pulse", action = true },
      { id = "sync_lanes", name = "Sync Lanes", action = true },
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
      elseif param.id == "sync_lanes" then
        -- Call conductor's sync_lanes function
        _seeker.conductor:sync_lanes()
        print("⚡ Synced all lanes")
      elseif param.id == "test_pulse" then
        -- Send a test pulse to the selected output
        local pulse_out = params:get("clock_pulse_out")
        if pulse_out > 1 then
          if pulse_out <= 5 then
            -- Crow pulse
            crow.output[pulse_out - 1].volts = 5
            -- Schedule pulse off after 10ms
            clock.run(function()
              clock.sleep(0.01)
              crow.output[pulse_out - 1].volts = 0
            end)
          else
            -- TXO pulse (subtract 5 to get 1-4 range)
            crow.ii.txo.tr(pulse_out - 5, 1)
            -- Schedule pulse off after 10ms
            clock.run(function()
              clock.sleep(0.01)
              crow.ii.txo.tr(pulse_out - 5, 0)
            end)
          end
          print("⚡ Sent test pulse")
        end
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