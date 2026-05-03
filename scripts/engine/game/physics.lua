---@diagnostic disable: undefined-global
-- SNKRX Engine Physics Mixin - UrhoX Physics2D Adapter
-- Replaces LÖVE2D's love.physics with UrhoX's component-based Physics2D system.
--
-- Architecture:
--   SNKRX uses a flat Box2D world (love.physics) accessed via the Group.
--   UrhoX uses Scene → Node → RigidBody2D + CollisionShape2D components.
--   This adapter bridges the gap by creating UrhoX physics components under the hood
--   while presenting the same SNKRX Physics mixin API.
--
-- Key mappings:
--   love.physics.newBody(world, x, y, type) → node + RigidBody2D component
--   love.physics.newRectangleShape(w, h) → CollisionBox2D component
--   love.physics.newCircleShape(r) → CollisionCircle2D component
--   love.physics.newPolygonShape(verts) → CollisionPolygon2D component
--   love.physics.newEdgeShape(x1,y1,x2,y2) → CollisionEdge2D component
--   love.physics.newChainShape(loop, verts) → CollisionChain2D component
--   fixture:setCategory/setMask → shape.categoryBits/maskBits (bitmask)
--   fixture:setSensor(true) → shape.trigger = true
--   body:getPosition() → node.position2D (Vector2)
--   body:setLinearVelocity(vx,vy) → rigidBody.linearVelocity = Vector2(vx,vy)

-- Helper: convert SNKRX body type string to UrhoX BodyType2D enum
local function to_body_type(bt)
  if bt == "static" then return BT_STATIC
  elseif bt == "kinematic" then return BT_KINEMATIC
  else return BT_DYNAMIC end
end

-- Helper: convert tag category index (1-based) to bitmask bit
local function category_to_bit(cat)
  return 1 << (cat - 1)
end

-- Helper: convert array of category indices to combined mask bits
local function masks_to_bits(masks)
  if not masks or #masks == 0 then return 0xFFFF end  -- collide with everything
  local bits = 0xFFFF
  for _, cat in ipairs(masks) do
    bits = bits & ~(1 << (cat - 1))
  end
  return bits
end

-- Helper: convert array of trigger category indices to sensor mask bits
local function triggers_to_bits(triggers)
  if not triggers or #triggers == 0 then return 0 end
  local bits = 0
  for _, cat in ipairs(triggers) do
    bits = bits | (1 << (cat - 1))
  end
  return bits
end


Physics = Object:extend()


-- Core setup: create a UrhoX physics node with body + collision shape
function Physics:_create_physics_body(body_type, tag)
  if not self.group then error("The GameObject must have a group defined for the Physics mixin to function") end
  self.tag = tag

  -- Create a node in the physics scene
  local physics_scene = self.group.physics_scene
  if not physics_scene then
    error("Group must be set as physics world before creating physics objects")
  end

  self.physics_node = physics_scene:CreateChild("physics_" .. (self.id or "obj"))
  self.physics_node.position2D = Vector2(self.x or 0, self.y or 0)

  -- Create RigidBody2D
  self.body = self.physics_node:CreateComponent("RigidBody2D")
  self.body:SetBodyType(to_body_type(body_type or "dynamic"))

  -- Store reference back to game object for collision callbacks
  self.physics_node.gameObject = self
  -- Also register in the group's id-to-node map
  if self.group._physics_nodes then
    self.group._physics_nodes[self.id] = self
  end
end


function Physics:_setup_collision_shape(shape_component, shape_type, shape_params)
  local tag_data = self.group.collision_tags[self.tag]
  if tag_data then
    local cat_bit = category_to_bit(tag_data.category)
    local mask_bits = masks_to_bits(tag_data.masks)
    shape_component:SetCategoryBits(cat_bit)
    shape_component:SetMaskBits(mask_bits)
  end
  self.fixture_component = shape_component

  -- Create sensor shape if trigger tags exist
  local trigger_data = self.group.trigger_tags[self.tag]
  if trigger_data and #trigger_data.triggers > 0 then
    self._has_sensor = true
    -- Create a duplicate shape as a sensor/trigger for overlap detection
    local sensor
    if shape_type == 'box' then
      sensor = self.physics_node:CreateComponent("CollisionBox2D")
      sensor:SetSize(shape_params.w, shape_params.h)
      sensor:SetCenter(0, 0)
    elseif shape_type == 'circle' then
      sensor = self.physics_node:CreateComponent("CollisionCircle2D")
      sensor:SetRadius(shape_params.r)
      sensor:SetCenter(0, 0)
    elseif shape_type == 'polygon' then
      sensor = self.physics_node:CreateComponent("CollisionPolygon2D")
      if shape_params.vertices then
        local count = #shape_params.vertices / 2
        sensor:SetVertexCount(count)
        for i = 1, count do
          sensor:SetVertex(i - 1, Vector2(shape_params.vertices[(i - 1) * 2 + 1], shape_params.vertices[(i - 1) * 2 + 2]))
        end
      end
    elseif shape_type == 'edge' then
      sensor = self.physics_node:CreateComponent("CollisionEdge2D")
      sensor:SetVertex1(Vector2(shape_params.x1, shape_params.y1))
      sensor:SetVertex2(Vector2(shape_params.x2, shape_params.y2))
    end
    if sensor then
      sensor:SetTrigger(true)
      local cat_bit = category_to_bit(trigger_data.category)
      local trigger_mask = triggers_to_bits(trigger_data.triggers)
      sensor:SetCategoryBits(cat_bit)
      sensor:SetMaskBits(trigger_mask)
      self.sensor_component = sensor
    end
  end
end


function Physics:set_as_rectangle(w, h, body_type, tag)
  self.tag = tag
  self.shape = Rectangle(self.x, self.y, w, h)
  self:_create_physics_body(body_type, tag)

  local box = self.physics_node:CreateComponent("CollisionBox2D")
  -- UrhoX CollisionBox2D size is in world units
  -- SNKRX uses pixel coordinates; we pass them through as-is since our world is in pixel-space
  box:SetSize(w, h)
  box:SetCenter(0, 0)
  self:_setup_collision_shape(box, 'box', {w = w, h = h})
  return self
end


function Physics:set_as_circle(rs, body_type, tag)
  self.tag = tag
  self.shape = Circle(self.x, self.y, rs)
  self:_create_physics_body(body_type, tag)

  local circle = self.physics_node:CreateComponent("CollisionCircle2D")
  circle:SetRadius(rs)
  circle:SetCenter(0, 0)
  self:_setup_collision_shape(circle, 'circle', {r = rs})
  return self
end


function Physics:set_as_polygon(vertices, body_type, tag)
  self.tag = tag
  self.shape = Polygon(vertices)
  self:_create_physics_body(body_type, tag)

  local poly = self.physics_node:CreateComponent("CollisionPolygon2D")
  -- vertices is a flat array {x1,y1, x2,y2, ...}
  local count = #vertices / 2
  poly:SetVertexCount(count)
  for i = 1, count do
    poly:SetVertex(i - 1, Vector2(vertices[(i - 1) * 2 + 1], vertices[(i - 1) * 2 + 2]))
  end
  self:_setup_collision_shape(poly, 'polygon', {vertices = vertices})
  return self
end


function Physics:set_as_line(x1, y1, x2, y2, body_type, tag)
  self.tag = tag
  self.shape = Line(x1, y1, x2, y2)
  self:_create_physics_body(body_type, tag)

  local edge = self.physics_node:CreateComponent("CollisionEdge2D")
  edge:SetVertex1(Vector2(x1, y1))
  edge:SetVertex2(Vector2(x2, y2))
  self:_setup_collision_shape(edge, 'edge', {x1 = x1, y1 = y1, x2 = x2, y2 = y2})
  return self
end


function Physics:set_as_chain(loop, vertices, body_type, tag)
  self.tag = tag
  self.shape = Chain(loop, vertices)
  self:_create_physics_body(body_type, tag)

  local chain = self.physics_node:CreateComponent("CollisionChain2D")
  -- IMPORTANT: Set vertices BEFORE SetLoop to avoid native crash on some devices.
  -- Box2D's b2ChainShape::CreateLoop requires vertex data to exist first.
  local count = #vertices / 2
  chain:SetVertexCount(count)
  for i = 1, count do
    chain:SetVertex(i - 1, Vector2(vertices[(i - 1) * 2 + 1], vertices[(i - 1) * 2 + 2]))
  end
  chain:SetLoop(loop)
  self:_setup_collision_shape(chain, 'chain', {loop = loop, vertices = vertices})
  return self
end


function Physics:set_as_triangle(w, h, body_type, tag)
  self.tag = tag
  self.shape = Triangle(self.x, self.y, w, h)
  self:_create_physics_body(body_type, tag)

  local poly = self.physics_node:CreateComponent("CollisionPolygon2D")
  local x1, y1 = h / 2, 0
  local x2, y2 = -h / 2, -w / 2
  local x3, y3 = -h / 2, w / 2
  poly:SetVertexCount(3)
  poly:SetVertex(0, Vector2(x1, y1))
  poly:SetVertex(1, Vector2(x2, y2))
  poly:SetVertex(2, Vector2(x3, y3))
  local tri_verts = {x1, y1, x2, y2, x3, y3}
  self:_setup_collision_shape(poly, 'polygon', {vertices = tri_verts})
  return self
end


function Physics:connect(other, direction)
  if not self.joints then self.joints = {} end
  local d = Vector(0, 0)
  if direction == 'right' then d:set(1, 0)
  elseif direction == 'left' then d:set(-1, 0)
  elseif direction == 'up' then d:set(0, -1)
  elseif direction == 'down' then d:set(0, 1) end

  -- Get shape extents (support both rectangle w/h and circle rs)
  local sw = self.shape.w or (self.shape.rs and self.shape.rs * 2) or 0
  local sh = self.shape.h or (self.shape.rs and self.shape.rs * 2) or 0

  -- Create a UrhoX ConstraintRevolute2D
  local constraint = self.physics_node:CreateComponent("ConstraintRevolute2D")
  constraint:SetOtherBody(other.body)
  constraint:SetAnchor(Vector2(self.x + 0.5 * d.x * sw, self.y + 0.5 * d.y * sh))
  self.joints[direction] = constraint
  return self
end


function Physics:destroy()
  if self.physics_node then
    self.physics_node:Remove()
    self.physics_node = nil
    self.body = nil
    self.fixture_component = nil
  end
  if self.group and self.group._physics_nodes then
    self.group._physics_nodes[self.id] = nil
  end
end


function Physics:draw_physics(color, line_width)
  if self.shape then self.shape:draw(color, line_width or 4) end
end


-- Position management
function Physics:update_physics(dt)
  self:update_position()
  self:steering_update(dt)
end


------------------------------------------------------------------------
-- Steering behaviors: convenience methods called directly on game objects
-- (Projectile, Seeker, Critter, EnemyProjectile, EnemyCritter)
------------------------------------------------------------------------

--- Initialize steering on this physics body.
-- Sets max speed, force, turn rate, separation radius, and initial velocity
-- along the current angle.
---@param initial_speed number  Initial speed (and max_speed)
---@param max_force number  Maximum steering force
---@param max_turn_rate number  Maximum turn rate (rad/s)
---@param separation_radius number  Desired separation distance
function Physics:set_as_steerable(initial_speed, max_force, max_turn_rate, separation_radius)
  self.max_speed = initial_speed or 100
  self.max_force = max_force or 1000
  self.max_turn_rate = max_turn_rate or math.pi
  self.separation_radius = separation_radius or 16
  self._steerable = true
  -- Set initial velocity along current angle
  local angle = self.r or 0
  local vx = math.cos(angle) * self.max_speed
  local vy = math.sin(angle) * self.max_speed
  self:set_velocity(vx, vy)
end


--- Accumulate a seek force towards (x, y). Uses max_speed/max_force for clamping.
---@param x number
---@param y number
function Physics:seek_point(x, y)
  if not self._steerable then return end
  local max_speed = self.max_speed or 100
  local max_force = self.max_force or 1000
  local dx, dy = x - self.x, y - self.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d > 0 then
    -- Desired velocity towards target at max speed
    local dvx, dvy = dx / d * max_speed, dy / d * max_speed
    -- Current velocity
    local vx, vy = self:get_velocity()
    -- Steering = desired - current, clamped to max_force
    local fx, fy = dvx - vx, dvy - vy
    local fl = math.sqrt(fx * fx + fy * fy)
    if fl > max_force then
      fx = fx / fl * max_force
      fy = fy / fl * max_force
    end
    self:apply_force(fx, fy)
  end
end


--- Reynolds wander steering behavior.
-- Adds randomness to movement by jittering a target on a circle projected ahead.
---@param angle number  Max wander angle range (degrees)
---@param radius number  Wander circle radius (distance ahead)
---@param jitter number  Random jitter applied per frame (degrees)
function Physics:wander(angle, radius, jitter)
  if not self._steerable then return end
  if not self._wander_angle then
    self._wander_angle = random:float(0, 2 * math.pi)
  end
  -- Apply random jitter to wander angle
  self._wander_angle = self._wander_angle + random:float(-1, 1) * math.rad(jitter)
  -- Clamp wander angle within range
  local half_range = math.rad(angle)
  -- Get current velocity direction
  local vx, vy = self:get_velocity()
  local speed = math.sqrt(vx * vx + vy * vy)
  local heading = 0
  if speed > 0.01 then
    heading = math.atan(vy, vx)
  else
    heading = self.r or 0
  end
  -- Target point on the wander circle
  local target_angle = heading + self._wander_angle
  -- Clamp wander angle to not deviate too far from heading
  if math.abs(self._wander_angle) > half_range then
    self._wander_angle = half_range * (self._wander_angle > 0 and 1 or -1)
  end
  local tx = self.x + math.cos(heading) * radius + math.cos(target_angle) * (radius * 0.5)
  local ty = self.y + math.sin(heading) * radius + math.sin(target_angle) * (radius * 0.5)
  self:seek_point(tx, ty)
end


--- Apply separation force from nearby objects.
-- `group_or_classes` can be:
--   - A list of class constructors (e.g. {Seeker})
--   - A table with `.objects` field (a group's object list)
---@param radius number  Desired separation distance
---@param group_or_classes table
function Physics:steering_separate(radius, group_or_classes)
  if not self._steerable then return end
  local neighbors = {}
  if type(group_or_classes) == 'table' then
    if group_or_classes.objects then
      -- Direct object list
      neighbors = group_or_classes.objects or group_or_classes
    elseif #group_or_classes > 0 then
      -- List of classes or list of objects
      local first = group_or_classes[1]
      if type(first) == 'table' and first.extend then
        -- List of classes — query group for instances
        if self.group then
          for _, cls in ipairs(group_or_classes) do
            local objs = self.group:get_objects_by_class(cls)
            for _, o in ipairs(objs) do table.insert(neighbors, o) end
          end
        end
      else
        -- Assume it's a list of objects directly
        neighbors = group_or_classes
      end
    end
  end

  local max_force = self.max_force or 1000
  local sx, sy, count = 0, 0, 0
  for _, n in ipairs(neighbors) do
    if n ~= self and n.x and n.y then
      local dx, dy = self.x - n.x, self.y - n.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d < radius and d > 0 then
        sx = sx + dx / d / d
        sy = sy + dy / d / d
        count = count + 1
      end
    end
  end
  if count > 0 then
    sx, sy = sx / count, sy / count
    local d = math.sqrt(sx * sx + sy * sy)
    if d > 0 then
      local max_speed = self.max_speed or 100
      local vx, vy = self:get_velocity()
      local fx = sx / d * max_speed - vx
      local fy = sy / d * max_speed - vy
      local fl = math.sqrt(fx * fx + fy * fy)
      if fl > max_force then
        fx = fx / fl * max_force
        fy = fy / fl * max_force
      end
      self:apply_force(fx, fy)
    end
  end
end


--- Apply a one-time steering force of given magnitude at given angle.
---@param magnitude number
---@param angle number  Direction in radians
function Physics:apply_steering_force(magnitude, angle)
  local fx = math.cos(angle) * magnitude
  local fy = math.sin(angle) * magnitude
  self:apply_force(fx, fy)
end


--- Apply a sustained steering force over `duration` seconds.
---@param magnitude number
---@param angle number  Direction in radians
---@param duration number  Duration in seconds
function Physics:apply_steering_impulse(magnitude, angle, duration)
  local fx = math.cos(angle) * magnitude
  local fy = math.sin(angle) * magnitude
  if self.t and duration then
    self.t:during(duration, function()
      self:apply_force(fx, fy)
    end)
  else
    -- Fallback: instant impulse
    self:apply_impulse(fx * 0.016, fy * 0.016)
  end
end


--- Steering update: clamp velocity to max_speed and sync vx/vy for steering math.
function Physics:steering_update(dt)
  if not self._steerable then return end
  -- When being pushed (e.g. Juggernaut, Forcer), steering_enabled is set to false
  -- by game code. We must skip velocity clamping so the push impulse is not negated.
  if self.steering_enabled == false then return end
  local vx, vy = self:get_velocity()
  -- Expose vx/vy on the object for Steering static functions
  self.vx = vx
  self.vy = vy
  -- Clamp to max_speed
  local speed = math.sqrt(vx * vx + vy * vy)
  local max_speed = self.max_speed or 100
  if speed > max_speed then
    vx = vx / speed * max_speed
    vy = vy / speed * max_speed
    self:set_velocity(vx, vy)
    self.vx = vx
    self.vy = vy
  end
  -- Update angle from velocity direction
  if speed > 0.1 then
    self.r = math.atan(vy, vx)
    if not self.fixed_rotation and self.physics_node then
      self.physics_node.rotation2D = self.r * 180 / math.pi
    end
  end
end


function Physics:update_position()
  if self.physics_node then
    local pos = self.physics_node.position2D
    self.x, self.y = pos.x, pos.y
  end
  if self.shape then
    self.shape.x = self.x
    self.shape.y = self.y
  end
  return self
end


function Physics:set_position(x, y)
  if self.physics_node then
    self.physics_node.position2D = Vector2(x, y)
  end
  self.x, self.y = x, y
  if self.shape then
    self.shape.x = x
    self.shape.y = y
  end
  return self
end


function Physics:get_position()
  self:update_position()
  return self.x, self.y
end


-- Velocity
function Physics:set_velocity(vx, vy)
  if self.body then self.body:SetLinearVelocity(Vector2(vx, vy)) end
  return self
end


function Physics:get_velocity()
  if self.body then
    local v = self.body:GetLinearVelocity()
    return v.x, v.y
  end
  return 0, 0
end


-- Damping
function Physics:set_damping(v)
  if self.body then self.body:SetLinearDamping(v) end
  return self
end


-- Angular velocity
function Physics:set_angular_velocity(v)
  if self.body then self.body:SetAngularVelocity(v) end
  return self
end


function Physics:set_angular_damping(v)
  if self.body then self.body:SetAngularDamping(v) end
  return self
end


-- Angle
function Physics:get_angle()
  if self.physics_node then
    return self.physics_node.rotation2D * math.pi / 180  -- UrhoX uses degrees, SNKRX uses radians
  end
  return 0
end


function Physics:set_angle(v)
  if self.physics_node then
    self.physics_node.rotation2D = v * 180 / math.pi  -- radians → degrees
  end
  return self
end


-- Physical properties
function Physics:set_bullet(v)
  if self.body then self.body:SetBullet(v) end
  return self
end


function Physics:set_fixed_rotation(v)
  self.fixed_rotation = v
  if self.body then self.body:SetFixedRotation(v) end
  return self
end


function Physics:set_restitution(v)
  if self.fixture_component then
    self.fixture_component:SetRestitution(v)
  end
  return self
end


function Physics:set_friction(v)
  if self.fixture_component then
    self.fixture_component:SetFriction(v)
  end
  return self
end


function Physics:set_mass(mass)
  if self.body then self.body:SetMass(mass) end
  return self
end


function Physics:set_gravity_scale(v)
  if self.body then self.body:SetGravityScale(v) end
  return self
end


-- Forces and impulses
function Physics:apply_impulse(fx, fy)
  if self.body then
    self.body:ApplyLinearImpulseToCenter(Vector2(fx, fy), true)
  end
  return self
end


function Physics:apply_angular_impulse(f)
  if self.body then self.body:ApplyAngularImpulse(f, true) end
  return self
end


function Physics:apply_force(fx, fy, x, y)
  if self.body then
    if x and y then
      self.body:ApplyForce(Vector2(fx, fy), Vector2(x, y), true)
    else
      self.body:ApplyForceToCenter(Vector2(fx, fy), true)
    end
  end
  return self
end


function Physics:apply_torque(t)
  if self.body then self.body:ApplyTorque(t, true) end
  return self
end


-- Angle/distance helpers (pure math, same as SNKRX)
function Physics:angle_from_point(x, y)
  return math.atan(self.y - y, self.x - x)
end


function Physics:angle_to_point(x, y)
  return math.atan(y - self.y, x - self.x)
end


function Physics:angle_to_object(object)
  return self:angle_to_point(object.x, object.y)
end


function Physics:angle_from_object(object)
  return self:angle_from_point(object.x, object.y)
end


function Physics:angle_to_mouse()
  local mx, my = self.group.camera:get_mouse_position()
  return math.atan(my - self.y, mx - self.x)
end


function Physics:distance_to_point(x, y)
  return math.distance(self.x, self.y, x, y)
end


function Physics:distance_to_object(object)
  return math.distance(self.x, self.y, object.x, object.y)
end


function Physics:distance_to_mouse()
  local mx, my = self.group.camera:get_mouse_position()
  return math.distance(self.x, self.y, mx, my)
end


-- Collision checks (using shape math, same as SNKRX)
function Physics:is_colliding_with_point(x, y)
  if self.shape then return self.shape:is_colliding_with_point(x, y) end
  return false
end


function Physics:is_colliding_with_mouse()
  return self:is_colliding_with_point(self.group.camera:get_mouse_position())
end


function Physics:is_colliding_with_object(object)
  return self:is_colliding_with_shape(object.shape)
end


function Physics:is_colliding_with_shape(shape)
  if self.shape then return self.shape:is_colliding_with_shape(shape) end
  return false
end


function Physics:get_objects_in_shape(shape, object_types)
  return table.select(self.group:get_objects_in_shape(shape, object_types), function(v) return v.id ~= self.id end)
end


function Physics:get_closest_object_in_shape(shape, object_types, exclude_list)
  local objects = self:get_objects_in_shape(shape, object_types)
  local min_d, min_i = 1000000, 0
  exclude_list = exclude_list or {}
  for i, object in ipairs(objects) do
    if not table.any(exclude_list, function(v) return v.id == object.id end) then
      local d = math.distance(self.x, self.y, object.x, object.y)
      if d < min_d then
        min_d = d
        min_i = i
      end
    end
  end
  if min_i ~= 0 then return objects[min_i] end
end


function Physics:get_random_object_in_shape(shape, object_types, opt_exclude_list)
  local objects = self:get_objects_in_shape(shape, object_types)
  local exclude_list = opt_exclude_list or {}
  local random_object = random:table(objects)
  local tries = 0
  if random_object then
    while table.any(exclude_list, function(v) return v.id == random_object.id end) and tries < 20 do
      random_object = random:table(objects)
      tries = tries + 1
    end
  end
  return random_object
end


-- Movement helpers (same as SNKRX)
function Physics:lock_horizontally()
  local vx, vy = self:get_velocity()
  self:set_velocity(vx, 0)
end


function Physics:lock_vertically()
  local vx, vy = self:get_velocity()
  self:set_velocity(0, vy)
end


function Physics:move_towards_object(object, speed, max_time)
  if max_time then speed = self:distance_to_point(object.x, object.y) / max_time end
  local r = self:angle_to_point(object.x, object.y)
  self:set_velocity(speed * math.cos(r), speed * math.sin(r))
  return self
end


function Physics:move_towards_point(x, y, speed, max_time)
  if max_time then speed = self:distance_to_point(x, y) / max_time end
  local r = self:angle_to_point(x, y)
  self:set_velocity(speed * math.cos(r), speed * math.sin(r))
  return self
end


function Physics:move_towards_mouse(speed, max_time)
  if max_time then speed = self:distance_to_mouse() / max_time end
  local r = self:angle_to_mouse()
  self:set_velocity(speed * math.cos(r), speed * math.sin(r))
  return self
end


function Physics:move_towards_mouse_horizontally(speed, max_time)
  if max_time then speed = self:distance_to_mouse() / max_time end
  local r = self:angle_to_mouse()
  local vx, vy = self:get_velocity()
  self:set_velocity(speed * math.cos(r), vy)
  return self
end


function Physics:move_towards_mouse_vertically(speed, max_time)
  if max_time then speed = self:distance_to_mouse() / max_time end
  local r = self:angle_to_mouse()
  local vx, vy = self:get_velocity()
  self:set_velocity(vx, speed * math.sin(r))
  return self
end


function Physics:move_along_angle(speed, r)
  self:set_velocity(speed * math.cos(r), speed * math.sin(r))
  return self
end


function Physics:rotate_towards_object(object, lerp_value)
  self:set_angle(math.lerp_angle(lerp_value, self:get_angle(), self:angle_to_point(object.x, object.y)))
  return self
end


function Physics:rotate_towards_point(x, y, lerp_value)
  self:set_angle(math.lerp_angle(lerp_value, self:get_angle(), self:angle_to_point(x, y)))
  return self
end


function Physics:rotate_towards_mouse(lerp_value)
  self:set_angle(math.lerp_angle(lerp_value, self:get_angle(), self:angle_to_mouse()))
  return self
end


function Physics:rotate_towards_velocity(lerp_value)
  local vx, vy = self:get_velocity()
  self:set_angle(math.lerp_angle(lerp_value, self:get_angle(), self:angle_to_point(self.x + vx, self.y + vy)))
  return self
end


function Physics:accelerate_towards_point(x, y, max_speed, deceleration, turn_coefficient)
  local tx, ty = x - self.x, y - self.y
  local d = math.length(tx, ty)
  if d > 0 then
    local speed = d / ((deceleration or 1) * 0.08)
    speed = math.min(speed, max_speed)
    local current_vx, current_vy = speed * tx / d, speed * ty / d
    local vx, vy = self:get_velocity()
    self:apply_force((current_vx - vx) * (turn_coefficient or 1), (current_vy - vy) * (turn_coefficient or 1))
  end
  return self
end


function Physics:accelerate_towards_object(object, max_speed, deceleration, turn_coefficient)
  return self:accelerate_towards_point(object.x, object.y, max_speed, deceleration, turn_coefficient)
end


function Physics:accelerate_towards_mouse(max_speed, deceleration, turn_coefficient)
  local mx, my = self.group.camera:get_mouse_position()
  return self:accelerate_towards_point(mx, my, max_speed, deceleration, turn_coefficient)
end


function Physics:separate(rs, class_avoid_list)
  local fx, fy = 0, 0
  local objects = table.flatten(table.foreachn(class_avoid_list, function(v) return self.group:get_objects_by_class(v) end), true)
  for _, object in ipairs(objects) do
    if object.id ~= self.id and math.distance(object.x, object.y, self.x, self.y) < 2 * rs then
      local tx, ty = self.x - object.x, self.y - object.y
      local n = Vector(tx, ty):normalize()
      local l = n:length()
      if l > 0 then
        fx = fx + rs * (n.x / l)
        fy = fy + rs * (n.y / l)
      end
    end
  end
  self:apply_force(fx, fy)
  return self
end


--- Bounce (reflect) the velocity off a surface with given normal.
---@param nx number  Surface normal X
---@param ny number  Surface normal Y (optional if nx is two return values)
function Physics:bounce(nx, ny)
  local vx, vy = self:get_velocity()
  -- Reflect: v' = v - 2*(v·n)*n
  local dot = vx * nx + vy * ny
  self:set_velocity(vx - 2 * dot * nx, vy - 2 * dot * ny)
  return self
end
