-- SNKRX Engine System Utilities - UrhoX Adapter
-- Replaces love.system utilities with pure Lua equivalents.

-- Rolling average delta time over the last 60 frames
local _delta_times = {}

function get_average_delta(dt)
  table.insert(_delta_times, dt)
  if #_delta_times > 60 then table.remove(_delta_times, 1) end
  local sum = 0
  for _, v in ipairs(_delta_times) do sum = sum + v end
  return sum / #_delta_times
end
