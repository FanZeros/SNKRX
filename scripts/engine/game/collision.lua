-- Simple collision detection functions (pure math, no engine dependency)

function collision_rectangle(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

function collision_circle(x1, y1, r1, x2, y2, r2)
  local dx, dy = x2 - x1, y2 - y1
  return dx * dx + dy * dy < (r1 + r2) * (r1 + r2)
end

function collision_point_rectangle(px, py, x, y, w, h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end

function collision_point_circle(px, py, cx, cy, r)
  local dx, dy = px - cx, py - cy
  return dx * dx + dy * dy < r * r
end

-- Line vs circle collision
function collision_line_circle(x1, y1, x2, y2, cx, cy, r)
  local dx, dy = x2 - x1, y2 - y1
  local fx, fy = x1 - cx, y1 - cy
  local a = dx * dx + dy * dy
  local b = 2 * (fx * dx + fy * dy)
  local c = fx * fx + fy * fy - r * r
  local discriminant = b * b - 4 * a * c
  if discriminant < 0 then return false end
  discriminant = math.sqrt(discriminant)
  local t1 = (-b - discriminant) / (2 * a)
  local t2 = (-b + discriminant) / (2 * a)
  if t1 >= 0 and t1 <= 1 then return true end
  if t2 >= 0 and t2 <= 1 then return true end
  return false
end
