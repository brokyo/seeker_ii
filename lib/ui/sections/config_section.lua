-- config_section.lua
-- Global level settings that affect all layers and clocks

local Section = include('lib/ui/section')
local ConfigSection = setmetatable({}, { __index = Section })
ConfigSection.__index = ConfigSection

function ConfigSection.new()
  local section = Section.new({
    id = "CONFIG",
    name = "CONFIG",
    description = "Global level configuration. Press k3 to trigger actions.",
    params = {
      { separator = true, name = "Global Tuning" },
      { id = "tuning_preset", name = "Preset" },
      { id = "root_note", name = "Root Note" },
      { id = "scale_type", name = "Scale" },
      { separator = true, name = "Clock" },
      { id = "clock_tempo", name = "BPM" },
      { id = "clock_pulse_out", name = "Clock Gate Out" },
      { id = "clock_division", name = "Clock Division" },
      { separator = true, name = "Visuals" },
      { id = "background_brightness", name = "Background Brightness" },
      { separator = true, name = "MIDI" },
      { id = "snap_midi_to_scale", name = "Snap MIDI to Scale" },
      { id = "record_midi_note", name = "Record Toggle Note" },
      { id = "overdub_midi_note", name = "Overdub Toggle Note" },
      { separator = true, name = "Actions" },
      { id = "test_pulse", name = "Test Pulse", action = true, spec = { type = "action"} },
      { id = "reset", name = "Clear Layers", action = true, spec = { type = "action"} }
    }
  })
  
  setmetatable(section, ConfigSection)

  -- Override modify_param to handle action items
  function section:modify_param(param, delta)
    if param.action then
      if param.id == "reset" then
        for i = 1, 8 do
          if _seeker.lanes[i] then
            _seeker.lanes[i]:clear()            
            -- Reset all stage transforms to noop
            for stage_idx = 1, 4 do
              for transform_idx = 1, 3 do
                _seeker.lanes[i]:change_stage_transform(i, stage_idx, transform_idx, "noop")
              end
            end
          end
        end
        print("⚡ Reset all layers")
      elseif param.id == "test_pulse" then
        -- Send a test pulse to the selected output
        local pulse_out = params:get("clock_pulse_out")
        if pulse_out > 1 then
          if pulse_out <= 5 then
            -- Crow pulse
            crow.output[pulse_out - 1].volts = 5
            -- Schedule pulse off after 100ms
            clock.run(function()
              clock.sleep(0.1)
              crow.output[pulse_out - 1].volts = 0
            end)
          else
            -- TXO pulse (subtract 5 to get 1-4 range)
            crow.ii.txo.tr(pulse_out - 5, 1)
            -- Schedule pulse off after 100ms
            clock.run(function()
              clock.sleep(0.1)
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