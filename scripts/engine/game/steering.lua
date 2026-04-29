-- SNKRX Engine: Steering (steering behaviors for AI)
-- Ported to UrhoX: no changes needed (pure Lua math, depends only on Vector)

Steering = Object:extend()

function Steering:init(gameobject)
  self.gameobject = gameobject
  self.behaviors = {}
  self.force = Vector()
  return self
end

function Steering:add(behavior, weight, ...)
  table.insert(self.behaviors, {behavior = behavior, weight = weight or 1, args = {...}})
  return self
end

function Steering:remove(behavior)
  for i = #self.behaviors, 1, -1 do
    if self.behaviors[i].behavior == behavior then
      table.remove(self.behaviors, i)
    end
  end
  return self
end

function Steering:update(dt)
  self.force = Vector()
  for _, b in ipairs(self.behaviors) do
    local f = b.behavior(self.gameobject, table.unpack(b.args))
    if f then self.force = self.force:add(f:mul(b.weight)) end
  end
  return self.force
end

function Steering.seek(gameobject, target_x, target_y, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  local dx, dy = target_x - gameobject.x, target_y - gameobject.y
  local d = math.sqrt(dx*dx + dy*dy)
  if d > 0 then
    dx, dy = dx/d*max_speed, dy/d*max_speed
    return Vector(dx - (gameobject.vx or 0), dy - (gameobject.vy or 0))
  end
  return Vector()
end

function Steering.flee(gameobject, target_x, target_y, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  local dx, dy = gameobject.x - target_x, gameobject.y - target_y
  local d = math.sqrt(dx*dx + dy*dy)
  if d > 0 then
    dx, dy = dx/d*max_speed, dy/d*max_speed
    return Vector(dx - (gameobject.vx or 0), dy - (gameobject.vy or 0))
  end
  return Vector()
end

function Steering.arrive(gameobject, target_x, target_y, slow_radius, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  slow_radius = slow_radius or 100
  local dx, dy = target_x - gameobject.x, target_y - gameobject.y
  local d = math.sqrt(dx*dx + dy*dy)
  if d > 0 then
    local speed = max_speed
    if d < slow_radius then speed = max_speed*d/slow_radius end
    dx, dy = dx/d*speed, dy/d*speed
    return Vector(dx - (gameobject.vx or 0), dy - (gameobject.vy or 0))
  end
  return Vector()
end

function Steering.pursue(gameobject, target, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  local dx, dy = target.x - gameobject.x, target.y - gameobject.y
  local d = math.sqrt(dx*dx + dy*dy)
  local t = d/(max_speed + (target.max_speed or 100))
  local future_x = target.x + (target.vx or 0)*t
  local future_y = target.y + (target.vy or 0)*t
  return Steering.seek(gameobject, future_x, future_y, max_speed)
end

function Steering.evade(gameobject, target, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  local dx, dy = target.x - gameobject.x, target.y - gameobject.y
  local d = math.sqrt(dx*dx + dy*dy)
  local t = d/(max_speed + (target.max_speed or 100))
  local future_x = target.x + (target.vx or 0)*t
  local future_y = target.y + (target.vy or 0)*t
  return Steering.flee(gameobject, future_x, future_y, max_speed)
end

function Steering.wander(gameobject, circle_distance, circle_radius, angle_change)
  circle_distance = circle_distance or 60
  circle_radius = circle_radius or 20
  angle_change = angle_change or 0.5
  gameobject.wander_angle = gameobject.wander_angle or 0
  local vx, vy = gameobject.vx or 0, gameobject.vy or 0
  local speed = math.sqrt(vx*vx + vy*vy)
  local cx, cy
  if speed > 0 then
    cx, cy = vx/speed*circle_distance, vy/speed*circle_distance
  else
    cx, cy = circle_distance, 0
  end
  cx, cy = cx + gameobject.x, cy + gameobject.y
  local wx = cx + math.cos(gameobject.wander_angle)*circle_radius
  local wy = cy + math.sin(gameobject.wander_angle)*circle_radius
  gameobject.wander_angle = gameobject.wander_angle + (math.random()*2 - 1)*angle_change
  return Steering.seek(gameobject, wx, wy)
end

function Steering.separation(gameobject, neighbors, desired_separation, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  desired_separation = desired_separation or 50
  local sx, sy, count = 0, 0, 0
  for _, n in ipairs(neighbors) do
    if n ~= gameobject then
      local dx, dy = gameobject.x - n.x, gameobject.y - n.y
      local d = math.sqrt(dx*dx + dy*dy)
      if d < desired_separation and d > 0 then
        sx = sx + dx/d/d
        sy = sy + dy/d/d
        count = count + 1
      end
    end
  end
  if count > 0 then
    sx, sy = sx/count, sy/count
    local d = math.sqrt(sx*sx + sy*sy)
    if d > 0 then
      sx, sy = sx/d*max_speed, sy/d*max_speed
      return Vector(sx - (gameobject.vx or 0), sy - (gameobject.vy or 0))
    end
  end
  return Vector()
end

function Steering.alignment(gameobject, neighbors, neighbor_radius, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  neighbor_radius = neighbor_radius or 100
  local ax, ay, count = 0, 0, 0
  for _, n in ipairs(neighbors) do
    if n ~= gameobject then
      local dx, dy = n.x - gameobject.x, n.y - gameobject.y
      local d = math.sqrt(dx*dx + dy*dy)
      if d < neighbor_radius then
        ax = ax + (n.vx or 0)
        ay = ay + (n.vy or 0)
        count = count + 1
      end
    end
  end
  if count > 0 then
    ax, ay = ax/count, ay/count
    local d = math.sqrt(ax*ax + ay*ay)
    if d > 0 then
      ax, ay = ax/d*max_speed, ay/d*max_speed
      return Vector(ax - (gameobject.vx or 0), ay - (gameobject.vy or 0))
    end
  end
  return Vector()
end

function Steering.cohesion(gameobject, neighbors, neighbor_radius, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  neighbor_radius = neighbor_radius or 100
  local cx, cy, count = 0, 0, 0
  for _, n in ipairs(neighbors) do
    if n ~= gameobject then
      local dx, dy = n.x - gameobject.x, n.y - gameobject.y
      local d = math.sqrt(dx*dx + dy*dy)
      if d < neighbor_radius then
        cx = cx + n.x
        cy = cy + n.y
        count = count + 1
      end
    end
  end
  if count > 0 then
    cx, cy = cx/count, cy/count
    return Steering.seek(gameobject, cx, cy, max_speed)
  end
  return Vector()
end

function Steering.path_follow(gameobject, path, path_index, path_radius, max_speed)
  max_speed = max_speed or gameobject.max_speed or 100
  path_radius = path_radius or 20
  if not path or #path < 2 then return Vector() end
  local target = path[path_index or 1]
  local dx, dy = target.x - gameobject.x, target.y - gameobject.y
  local d = math.sqrt(dx*dx + dy*dy)
  if d < path_radius then
    path_index = (path_index or 1) + 1
    if path_index > #path then path_index = 1 end
    target = path[path_index]
  end
  return Steering.seek(gameobject, target.x, target.y, max_speed), path_index
end
