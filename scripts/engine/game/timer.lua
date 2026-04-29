-- Timer: simple elapsed-time counter (pure Lua)

Timer = Object:extend()

function Timer:init()
  self.time = 0
  return self
end

function Timer:update(dt)
  self.time = self.time + dt
  return self
end

function Timer:get_time()
  return self.time
end

function Timer:reset()
  self.time = 0
  return self
end
