-- SNKRX Engine: Triangle (2D triangle geometry)
-- Ported to UrhoX: removed love.graphics.polygon draw

Triangle = Object:extend()

function Triangle:init(x1, y1, x2, y2, x3, y3)
  self.x1 = x1 or 0
  self.y1 = y1 or 0
  self.x2 = x2 or 0
  self.y2 = y2 or 0
  self.x3 = x3 or 0
  self.y3 = y3 or 0
  return self
end

function Triangle:clone()
  return Triangle(self.x1, self.y1, self.x2, self.y2, self.x3, self.y3)
end

function Triangle:get_centroid()
  return (self.x1 + self.x2 + self.x3)/3, (self.y1 + self.y2 + self.y3)/3
end

function Triangle:get_area()
  return math.abs((self.x1*(self.y2 - self.y3) + self.x2*(self.y3 - self.y1) + self.x3*(self.y1 - self.y2))/2)
end

function Triangle:is_point_inside(x, y)
  local d1 = (x - self.x2)*(self.y1 - self.y2) - (self.x1 - self.x2)*(y - self.y2)
  local d2 = (x - self.x3)*(self.y2 - self.y3) - (self.x2 - self.x3)*(y - self.y3)
  local d3 = (x - self.x1)*(self.y3 - self.y1) - (self.x3 - self.x1)*(y - self.y1)
  local has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
  local has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
  return not (has_neg and has_pos)
end

function Triangle:to_polygon()
  return Polygon({Vector(self.x1, self.y1), Vector(self.x2, self.y2), Vector(self.x3, self.y3)})
end

function Triangle:move(x, y)
  self.x1 = self.x1 + x
  self.y1 = self.y1 + y
  self.x2 = self.x2 + x
  self.y2 = self.y2 + y
  self.x3 = self.x3 + x
  self.y3 = self.y3 + y
  return self
end

function Triangle:draw(x, y)
  -- NanoVG draw stub: implement in graphics adapter if needed
end
