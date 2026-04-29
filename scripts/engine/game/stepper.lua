-- Stepper: ping-pong value iterator (pure Lua)
-- Goes through values back and forth: 1, 2, 3, 2, 1, 2, 3, ...

Stepper = Object:extend()

function Stepper:init(values)
  self.values = values
  self.index = 0
  self.direction = 1
  return self
end

function Stepper:next()
  self.index = self.index + self.direction
  if self.index > #self.values or self.index < 1 then
    self.direction = -self.direction
    self.index = self.index + 2 * self.direction
  end
  return self.values[self.index]
end

function Stepper:get()
  return self.values[self.index]
end
