-- Stats: simple key-value attribute bag (pure Lua)

Stats = Object:extend()

function Stats:init(args)
  for k, v in pairs(args) do self[k] = v end
  return self
end

function Stats:set(args)
  for k, v in pairs(args) do self[k] = v end
  return self
end

function Stats:update(dt)
  return self
end
