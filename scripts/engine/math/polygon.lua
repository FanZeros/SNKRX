-- SNKRX Engine: Polygon (2D polygon geometry)
-- Ported to UrhoX: removed love.graphics.polygon draw

Polygon = Object:extend()

function Polygon:init(vertices)
  self.vertices = vertices or {}
  return self
end

function Polygon:clone()
  local vertices = {}
  for _, v in ipairs(self.vertices) do
    table.insert(vertices, v:clone())
  end
  return Polygon(vertices)
end

function Polygon:get_centroid()
  local cx, cy = 0, 0
  for _, v in ipairs(self.vertices) do
    cx = cx + v.x
    cy = cy + v.y
  end
  return cx/#self.vertices, cy/#self.vertices
end

function Polygon:get_area()
  local area = 0
  for i = 1, #self.vertices do
    local j = i%#self.vertices + 1
    area = area + self.vertices[i].x*self.vertices[j].y - self.vertices[j].x*self.vertices[i].y
  end
  return math.abs(area/2)
end

function Polygon:get_bounding_box()
  local min_x, min_y = self.vertices[1].x, self.vertices[1].y
  local max_x, max_y = self.vertices[1].x, self.vertices[1].y
  for i = 2, #self.vertices do
    min_x = math.min(min_x, self.vertices[i].x)
    min_y = math.min(min_y, self.vertices[i].y)
    max_x = math.max(max_x, self.vertices[i].x)
    max_y = math.max(max_y, self.vertices[i].y)
  end
  return min_x, min_y, max_x - min_x, max_y - min_y
end

function Polygon:is_convex()
  local n = #self.vertices
  if n < 3 then return false end
  local sign = nil
  for i = 1, n do
    local j = i%n + 1
    local k = j%n + 1
    local cross = (self.vertices[j].x - self.vertices[i].x)*(self.vertices[k].y - self.vertices[j].y) - (self.vertices[j].y - self.vertices[i].y)*(self.vertices[k].x - self.vertices[j].x)
    if sign == nil then
      if cross ~= 0 then sign = cross > 0 end
    else
      if cross ~= 0 and (cross > 0) ~= sign then return false end
    end
  end
  return true
end

function Polygon:is_point_inside(x, y)
  local n = #self.vertices
  local inside = false
  local j = n
  for i = 1, n do
    if (self.vertices[i].y > y) ~= (self.vertices[j].y > y) and x < (self.vertices[j].x - self.vertices[i].x) * (y - self.vertices[i].y) / (self.vertices[j].y - self.vertices[i].y) + self.vertices[i].x then
      inside = not inside
    end
    j = i
  end
  return inside
end

function Polygon:get_edges()
  local edges = {}
  for i = 1, #self.vertices do
    local j = i%#self.vertices + 1
    table.insert(edges, Line(self.vertices[i].x, self.vertices[i].y, self.vertices[j].x, self.vertices[j].y))
  end
  return edges
end

function Polygon:get_closest_edge(x, y)
  local edges = self:get_edges()
  local min_d, min_edge = math.huge, nil
  for _, e in ipairs(edges) do
    local d = e:distance_to_point(x, y)
    if d < min_d then
      min_d = d
      min_edge = e
    end
  end
  return min_edge, min_d
end

function Polygon:get_closest_vertex(x, y)
  local min_d, min_v = math.huge, nil
  for _, v in ipairs(self.vertices) do
    local d = v:distance(x, y)
    if d < min_d then
      min_d = d
      min_v = v
    end
  end
  return min_v, min_d
end

function Polygon:move(x, y)
  for _, v in ipairs(self.vertices) do
    v.x = v.x + x
    v.y = v.y + y
  end
  return self
end

function Polygon:move_to(x, y)
  local cx, cy = self:get_centroid()
  local dx, dy = x - cx, y - cy
  for _, v in ipairs(self.vertices) do
    v.x = v.x + dx
    v.y = v.y + dy
  end
  return self
end

function Polygon:rotate(r, cx, cy)
  cx, cy = cx or 0, cy or 0
  for _, v in ipairs(self.vertices) do
    local x, y = v.x - cx, v.y - cy
    v.x = x*math.cos(r) - y*math.sin(r) + cx
    v.y = x*math.sin(r) + y*math.cos(r) + cy
  end
  return self
end

function Polygon:scale(sx, sy, opt_cx, opt_cy)
  local cx, cy = opt_cx or 0, opt_cy or 0
  for _, v in ipairs(self.vertices) do
    v.x = (v.x - cx)*sx + cx
    v.y = (v.y - cy)*(sy or sx) + cy
  end
  return self
end

function Polygon:draw(x, y)
  -- NanoVG draw stub: implement in graphics adapter if needed
end
