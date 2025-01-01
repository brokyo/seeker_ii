-- theory_utils.lua
-- Commonly reused musical stuff

local theory_utils = {}

-- Clock division options
theory_utils.clock_divisions = {
  "/16", "/8", "/7", "/6", "/5", "/4", "/3", "/2", "1", "*2", "*3", "*4", "*5", "*6", "*7", "*8", "*16"
}

-- Function to convert clock division index to a readable string
function theory_utils.get_clock_division(index)
  return theory_utils.clock_divisions[index] or "unknown"
end


return theory_utils
