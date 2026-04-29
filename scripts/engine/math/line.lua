-- SNKRX Engine: Line (2D line segment geometry)
-- Ported to UrhoX: removed love.graphics.line draw, math.atan2 -> math.atan

Line = Object:extend()

function Line:init(x1, y1, x2, y2)
  self.x1 = x1 or 0
  self.y1 = y1 or 0
  self.x2 = x2 or 0
  self.y2 = y2 or 0
  return self
end

function Line:clone()
  return Line(self.x1, self.y1, self.x2, self.y2)
end

function Line:get_length()
  return math.sqrt((self.x2 - self.x1)*(self.x2 - self.x1) + (self.y2 - self.y1)*(self.y2 - self.y1))
end

function Line:get_length_squared()
  return (self.x2 - self.x1)*(self.x2 - self.x1) + (self.y2 - self.y1)*(self.y2 - self.y1)
end

function Line:get_midpoint()
  return (self.x1 + self.x2)/2, (self.y1 + self.y2)/2
end

function Line:get_direction()
  local length = self:get_length()
  return (self.x2 - self.x1)/length, (self.y2 - self.y1)/length
end

function Line:get_normal()
  local dx, dy = self:get_direction()
  return -dy, dx
end

function Line:get_angle()
  return math.atan(self.y2 - self.y1, self.x2 - self.x1)
end

function Line:is_point_on(x, y)
  return math.abs((y - self.y1)*(self.x2 - self.x1) - (x - self.x1)*(self.y2 - self.y1)) < 0.0001
end

function Line:distance_to_point(px, py)
  local dx, dy = self.x2 - self.x1, self.y2 - self.y1
  local t = ((px - self.x1)*dx + (py - self.y1)*dy) / (dx*dx + dy*dy)
  t = math.max(0, math.min(1, t))
  local closest_x, closest_y = self.x1 + t*dx, self.y1 + t*dy
  return math.sqrt((px - closest_x)*(px - closest_x) + (py - closest_y)*(py - closest_y))
end

function Line:closest_point(px, py)
  local dx, dy = self.x2 - self.x1, self.y2 - self.y1
  local t = ((px - self.x1)*dx + (py - self.y1)*dy) / (dx*dx + dy*dy)
  t = math.max(0, math.min(1, t))
  return self.x1 + t*dx, self.y1 + t*dy
end

function Line:intersects_line(other)
  local x1, y1, x2, y2 = self.x1, self.y1, self.x2, self.y2
  local x3, y3, x4, y4 = other.x1, other.y1, other.x2, other.y2
  local d = (x1 - x2)*(y3 - y4) - (y1 - y2)*(x3 - x4)
  if d == 0 then return false end
  local t = ((x1 - x3)*(y3 - y4) - (y1 - y3)*(x3 - x4))/d
  local u = -((x1 - x2)*(y1 - y3) - (y1 - y2)*(x1 - x3))/d
  if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
    return true, x1 + t*(x2 - x1), y1 + t*(y2 - y1)
  end
  return false
end

function Line:move(x, y)
  self.x1 = self.x1 + x
  self.y1 = self.y1 + y
  self.x2 = self.x2 + x
  self.y2 = self.y2 + y
  return self
end

function Line:rotate(r, cx, cy)
  cx, cy = cx or (self.x1 + self.x2)/2, cy or (self.y1 + self.y2)/2
  local x1, y1 = self.x1 - cx, self.y1 - cy
  local x2, y2 = self.x2 - cx, self.y2 - cy
  local c, s = math.cos(r), math.sin(r)
  self.x1 = x1*c - y1*s + cx
  self.y1 = x1*s + y1*c + cy
  self.x2 = x2*c - y2*s + cx
  self.y2 = x2*s + y2*c + cy
  return self
end

function Line:draw(x, y)
  -- NanoVG draw stub: implement in graphics adapter if needed
end
