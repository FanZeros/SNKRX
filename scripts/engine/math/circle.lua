-- SNKRX Engine: Circle (2D circle geometry)
-- Ported to UrhoX: removed love.graphics.circle draw

Circle = Object:extend()

function Circle:init(x, y, r)
  self.x = x or 0
  self.y = y or 0
  self.r = r or 0
  self.rs = self.r  -- SNKRX game code uses .rs (radius for shape/sprite)
  return self
end

function Circle:clone()
  return Circle(self.x, self.y, self.r)
end

function Circle:get_bounding_box()
  return self.x - self.r, self.y - self.r, 2*self.r, 2*self.r
end

function Circle:is_point_inside(x, y)
  return math.sqrt((x - self.x)*(x - self.x) + (y - self.y)*(y - self.y)) <= self.r
end

function Circle:move(x, y)
  self.x = self.x + x
  self.y = self.y + y
  return self
end

function Circle:move_to(x, y)
  self.x = x
  self.y = y
  return self
end

function Circle:scale(s)
  self.r = self.r*s
  return self
end

function Circle:is_colliding_with_shape(other)
  if other:is(Circle) then
    -- Circle vs Circle
    local dx = self.x - other.x
    local dy = self.y - other.y
    return (dx*dx + dy*dy) <= (self.r + other.r)*(self.r + other.r)
  elseif other.w ~= nil then
    -- Circle vs Rectangle (center-based rect: x,y center, w,h half-extents)
    local dx = math.abs(self.x - other.x)
    local dy = math.abs(self.y - other.y)
    if dx > other.w + self.r then return false end
    if dy > other.h + self.r then return false end
    if dx <= other.w then return true end
    if dy <= other.h then return true end
    local cx = dx - other.w
    local cy = dy - other.h
    return (cx*cx + cy*cy) <= self.r*self.r
  end
  return false
end

function Circle:draw(x, y)
  -- NanoVG draw stub: implement in graphics adapter if needed
end
