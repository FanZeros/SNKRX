-- SNKRX Engine: Chain (polyline / vertex chain)
-- Ported to UrhoX: removed love.graphics.line draw

Chain = Object:extend()

function Chain:init(vertices)
  self.vertices = vertices or {}
  return self
end

function Chain:clone()
  local vertices = {}
  for _, v in ipairs(self.vertices) do
    table.insert(vertices, v:clone())
  end
  return Chain(vertices)
end

function Chain:get_length()
  local length = 0
  for i = 1, #self.vertices - 1 do
    length = length + self.vertices[i]:distance(self.vertices[i+1])
  end
  return length
end

function Chain:get_point_at(t)
  if t <= 0 then return self.vertices[1]:clone() end
  if t >= 1 then return self.vertices[#self.vertices]:clone() end
  local total_length = self:get_length()
  local target_length = t*total_length
  local current_length = 0
  for i = 1, #self.vertices - 1 do
    local segment_length = self.vertices[i]:distance(self.vertices[i+1])
    if current_length + segment_length >= target_length then
      local segment_t = (target_length - current_length)/segment_length
      return self.vertices[i]:lerp(self.vertices[i+1], segment_t)
    end
    current_length = current_length + segment_length
  end
  return self.vertices[#self.vertices]:clone()
end

function Chain:get_direction_at(t)
  if t <= 0 then return self.vertices[2]:sub(self.vertices[1]):normalize() end
  if t >= 1 then return self.vertices[#self.vertices]:sub(self.vertices[#self.vertices - 1]):normalize() end
  local total_length = self:get_length()
  local target_length = t*total_length
  local current_length = 0
  for i = 1, #self.vertices - 1 do
    local segment_length = self.vertices[i]:distance(self.vertices[i+1])
    if current_length + segment_length >= target_length then
      return self.vertices[i+1]:sub(self.vertices[i]):normalize()
    end
    current_length = current_length + segment_length
  end
  return self.vertices[#self.vertices]:sub(self.vertices[#self.vertices - 1]):normalize()
end

function Chain:get_closest_point(x, y)
  local min_d, min_point = math.huge, nil
  for i = 1, #self.vertices - 1 do
    local l = Line(self.vertices[i].x, self.vertices[i].y, self.vertices[i+1].x, self.vertices[i+1].y)
    local cx, cy = l:closest_point(x, y)
    local d = math.sqrt((x - cx)*(x - cx) + (y - cy)*(y - cy))
    if d < min_d then
      min_d = d
      min_point = Vector(cx, cy)
    end
  end
  return min_point, min_d
end

function Chain:move(x, y)
  for _, v in ipairs(self.vertices) do
    v.x = v.x + x
    v.y = v.y + y
  end
  return self
end

function Chain:rotate(r, cx, cy)
  cx, cy = cx or 0, cy or 0
  for _, v in ipairs(self.vertices) do
    local x, y = v.x - cx, v.y - cy
    v.x = x*math.cos(r) - y*math.sin(r) + cx
    v.y = x*math.sin(r) + y*math.cos(r) + cy
  end
  return self
end

function Chain:draw(x, y)
  -- NanoVG draw stub: implement in graphics adapter if needed
end
