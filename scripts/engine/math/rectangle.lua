-- SNKRX Engine: Rectangle (2D axis-aligned rectangle)
-- Ported to UrhoX: removed love.graphics.rectangle draw

Rectangle = Object:extend()

function Rectangle:init(x, y, w, h)
  self.x = x or 0
  self.y = y or 0
  self.w = w or 0
  self.h = h or 0
  return self
end

function Rectangle:clone()
  return Rectangle(self.x, self.y, self.w, self.h)
end

function Rectangle:get_center()
  return self.x + self.w/2, self.y + self.h/2
end

function Rectangle:get_area()
  return self.w*self.h
end

function Rectangle:get_perimeter()
  return 2*(self.w + self.h)
end

function Rectangle:is_point_inside(x, y)
  return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Rectangle:overlaps(other)
  return self.x < other.x + other.w and self.x + self.w > other.x and self.y < other.y + other.h and self.y + self.h > other.y
end

function Rectangle:contains(other)
  return other.x >= self.x and other.x + other.w <= self.x + self.w and other.y >= self.y and other.y + other.h <= self.y + self.h
end

function Rectangle:get_intersection(other)
  local x = math.max(self.x, other.x)
  local y = math.max(self.y, other.y)
  local w = math.min(self.x + self.w, other.x + other.w) - x
  local h = math.min(self.y + self.h, other.y + other.h) - y
  if w > 0 and h > 0 then return Rectangle(x, y, w, h) end
  return nil
end

function Rectangle:get_union(other)
  local x = math.min(self.x, other.x)
  local y = math.min(self.y, other.y)
  local w = math.max(self.x + self.w, other.x + other.w) - x
  local h = math.max(self.y + self.h, other.y + other.h) - y
  return Rectangle(x, y, w, h)
end

function Rectangle:get_vertices()
  return {
    Vector(self.x, self.y),
    Vector(self.x + self.w, self.y),
    Vector(self.x + self.w, self.y + self.h),
    Vector(self.x, self.y + self.h),
  }
end

function Rectangle:to_polygon()
  return Polygon(self:get_vertices())
end

function Rectangle:move(x, y)
  self.x = self.x + x
  self.y = self.y + y
  return self
end

function Rectangle:move_to(x, y)
  self.x = x - self.w / 2
  self.y = y - self.h / 2
  return self
end

function Rectangle:scale(sx, sy)
  local cx, cy = self:get_center()
  self.w = self.w*sx
  self.h = self.h*(sy or sx)
  self.x = cx - self.w/2
  self.y = cy - self.h/2
  return self
end

function Rectangle:is_colliding_with_shape(other)
  if other:is(Circle) then
    -- Rectangle vs Circle: delegate to Circle
    return other:is_colliding_with_shape(self)
  elseif other.w ~= nil then
    -- Rectangle vs Rectangle (center-based: x,y center, w,h half-extents)
    return math.abs(self.x - other.x) <= (self.w + other.w) and
           math.abs(self.y - other.y) <= (self.h + other.h)
  end
  return false
end

function Rectangle:draw(x, y)
  -- NanoVG draw stub: implement in graphics adapter if needed
end
