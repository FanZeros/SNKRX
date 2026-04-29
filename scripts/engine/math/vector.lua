-- SNKRX Engine: Vector (2D vector math)
-- Ported to UrhoX: removed love.graphics.circle draw, math.atan2 -> math.atan

Vector = Object:extend()

function Vector:init(x, y)
  self.x = x or 0
  self.y = y or 0
  return self
end

function Vector:clone()
  return Vector(self.x, self.y)
end

function Vector:unpack()
  return self.x, self.y
end

function Vector:set(x, y)
  if x and y then self.x, self.y = x, y
  elseif x then self.x, self.y = x.x, x.y end
  return self
end

function Vector:equals(x, y)
  if x and y then return self.x == x and self.y == y
  elseif x then return self.x == x.x and self.y == x.y end
end

function Vector:add(x, y)
  if x and y then return Vector(self.x + x, self.y + y)
  elseif x then return Vector(self.x + x.x, self.y + x.y) end
end

function Vector:sub(x, y)
  if x and y then return Vector(self.x - x, self.y - y)
  elseif x then return Vector(self.x - x.x, self.y - x.y) end
end

function Vector:mul(x, y)
  if x and y then return Vector(self.x*x, self.y*y)
  elseif x then
    if type(x) == "number" then return Vector(self.x*x, self.y*x)
    else return Vector(self.x*x.x, self.y*x.y) end
  end
end

function Vector:div(x, y)
  if x and y then return Vector(self.x/x, self.y/y)
  elseif x then
    if type(x) == "number" then return Vector(self.x/x, self.y/x)
    else return Vector(self.x/x.x, self.y/x.y) end
  end
end

function Vector:dot(x, y)
  if x and y then return self.x*x + self.y*y
  elseif x then return self.x*x.x + self.y*x.y end
end

function Vector:cross(x, y)
  if x and y then return self.x*y - self.y*x
  elseif x then return self.x*x.y - self.y*x.x end
end

function Vector:length()
  return math.sqrt(self.x*self.x + self.y*self.y)
end

function Vector:length_squared()
  return self.x*self.x + self.y*self.y
end

function Vector:normalize()
  local length = self:length()
  if length == 0 then return Vector(self.x, self.y) end
  return Vector(self.x/length, self.y/length)
end

function Vector:perpendicular()
  return Vector(-self.y, self.x)
end

function Vector:angle()
  return math.atan(self.y, self.x)
end

function Vector:angle_to(x, y)
  if x and y then return math.atan(y - self.y, x - self.x)
  elseif x then return math.atan(x.y - self.y, x.x - self.x) end
end

function Vector:distance(x, y)
  if x and y then return math.sqrt((self.x - x)*(self.x - x) + (self.y - y)*(self.y - y))
  elseif x then return math.sqrt((self.x - x.x)*(self.x - x.x) + (self.y - x.y)*(self.y - x.y)) end
end

function Vector:distance_squared(x, y)
  if x and y then return (self.x - x)*(self.x - x) + (self.y - y)*(self.y - y)
  elseif x then return (self.x - x.x)*(self.x - x.x) + (self.y - x.y)*(self.y - x.y) end
end

function Vector:rotate(r)
  local c, s = math.cos(r), math.sin(r)
  return Vector(c*self.x - s*self.y, s*self.x + c*self.y)
end

function Vector:lerp(x, t)
  return Vector(self.x + (x.x - self.x)*t, self.y + (x.y - self.y)*t)
end

function Vector:floor()
  return Vector(math.floor(self.x), math.floor(self.y))
end

function Vector:ceil()
  return Vector(math.ceil(self.x), math.ceil(self.y))
end

function Vector:round()
  return Vector(math.floor(self.x + 0.5), math.floor(self.y + 0.5))
end

function Vector:abs()
  return Vector(math.abs(self.x), math.abs(self.y))
end

function Vector:min(x, y)
  if x and y then return Vector(math.min(self.x, x), math.min(self.y, y))
  elseif x then return Vector(math.min(self.x, x.x), math.min(self.y, x.y)) end
end

function Vector:max(x, y)
  if x and y then return Vector(math.max(self.x, x), math.max(self.y, y))
  elseif x then return Vector(math.max(self.x, x.x), math.max(self.y, x.y)) end
end

function Vector:clamp(min, max)
  return Vector(math.min(math.max(self.x, min.x), max.x), math.min(math.max(self.y, min.y), max.y))
end

function Vector:angle_between(x, y)
  if x and y then
    local a = math.atan(y, x) - math.atan(self.y, self.x)
    if a < -math.pi then a = a + 2*math.pi end
    if a > math.pi then a = a - 2*math.pi end
    return a
  elseif x then
    local a = math.atan(x.y, x.x) - math.atan(self.y, self.x)
    if a < -math.pi then a = a + 2*math.pi end
    if a > math.pi then a = a - 2*math.pi end
    return a
  end
end

function Vector:bounce(normal)
  return self:sub(normal:mul(2*self:dot(normal)))
end

function Vector:reflect(normal)
  return self:sub(normal:mul(2*self:dot(normal)))
end

function Vector:slide(normal)
  return self:sub(normal:mul(self:dot(normal)))
end

function Vector:limit(max)
  if self:length_squared() > max*max then return self:normalize():mul(max)
  else return Vector(self.x, self.y) end
end

function Vector:dampen(x, dt)
  return self:mul(math.pow(x, dt))
end

function Vector:move_towards(x, max_d)
  local d = self:distance(x)
  if d <= max_d then return Vector(x.x, x.y) end
  return self:add(x:sub(self):normalize():mul(max_d))
end

function Vector:tostring()
  return self.x .. ", " .. self.y
end

function Vector:draw(x, y, r, sx, sy)
  -- NanoVG draw stub: implement in graphics adapter if needed
end
