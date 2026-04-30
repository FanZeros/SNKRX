-- SNKRX Engine Group - UrhoX Adapter
-- Replaces LÖVE2D's love.physics world management with UrhoX Physics2D scene.
--
-- Architecture:
--   SNKRX Group holds objects, manages a Box2D world, spatial hashing, and drawing.
--   UrhoX version creates a dedicated Scene with PhysicsWorld2D component and
--   routes collision events through SubscribeToEvent.
--
-- Key changes from LÖVE2D version:
--   love.physics.setMeter(m) → stored as self.meter (used for unit scaling)
--   love.physics.newWorld(xg, yg) → Scene + PhysicsWorld2D component
--   world:setCallbacks(...) → SubscribeToEvent("PhysicsBeginContact2D"/End)
--   world:update(dt) → physics world steps automatically in UrhoX
--   world:rayCast(...) → physicsWorld:Raycast(results, startPoint, endPoint)
--   love.mouse.getPosition() → input.mousePosition.x/y


Group = Object:extend()

function Group:init()
  self.t = Trigger()
  self.camera = camera
  self.objects = {}
  self.objects.by_id = {}
  self.objects.by_class = {}
  self.cells = {}
  self.cell_size = 64
  return self
end


function Group:update(dt)
  self.t:update(dt)
  for _, object in ipairs(self.objects) do
    if not object.dead then
      if object.force_update then
        object:update(1 / refresh_rate)
      else
        object:update(dt)
      end
    end
  end

  -- Mouse hover detection for objects with interact_with_mouse
  if not self._hover_state then self._hover_state = {} end
  local mx, my
  if mouse then
    mx, my = mouse.x, mouse.y
  end
  if mx and my then
    for _, object in ipairs(self.objects) do
      if not object.dead and object.interact_with_mouse and object.shape then
        local inside = false
        local shape = object.shape
        if shape.w then
          -- Rectangle: SNKRX uses center-based positioning
          inside = mx >= object.x - shape.w / 2 and mx <= object.x + shape.w / 2
              and my >= object.y - shape.h / 2 and my <= object.y + shape.h / 2
        elseif shape.r then
          -- Circle: distance-based hit test
          local dx, dy = mx - object.x, my - object.y
          inside = (dx * dx + dy * dy) <= shape.r * shape.r
        elseif shape.rs then
          -- Circle variant with .rs
          local dx, dy = mx - object.x, my - object.y
          inside = (dx * dx + dy * dy) <= shape.rs * shape.rs
        end

        local was_inside = self._hover_state[object.id]
        if inside and not was_inside then
          if object.on_mouse_enter then object:on_mouse_enter() end
          self._hover_state[object.id] = true
        elseif not inside and was_inside then
          if object.on_mouse_exit then object:on_mouse_exit() end
          self._hover_state[object.id] = false
        end
      end
    end
  end

  -- UrhoX physics world steps automatically via the engine loop,
  -- no explicit self.world:update(dt) needed.

  -- Spatial hashing rebuild
  self.cells = {}
  for _, object in ipairs(self.objects) do
    local cx, cy = math.floor(object.x / self.cell_size), math.floor(object.y / self.cell_size)
    if tostring(cx) == tostring(0 / 0) or tostring(cy) == tostring(0 / 0) then goto continue end
    if not self.cells[cx] then self.cells[cx] = {} end
    if not self.cells[cx][cy] then self.cells[cx][cy] = {} end
    table.insert(self.cells[cx][cy], object)
    ::continue::
  end

  -- Remove dead objects
  for i = #self.objects, 1, -1 do
    if self.objects[i].dead then
      if self.objects[i].destroy then self.objects[i]:destroy() end
      if self._hover_state then self._hover_state[self.objects[i].id] = nil end
      self.objects.by_id[self.objects[i].id] = nil
      table.delete(self.objects.by_class[getmetatable(self.objects[i])], function(v) return v.id == self.objects[i].id end)
      table.remove(self.objects, i)
    end
  end
end


-- scroll_factor_x and scroll_factor_y can be used for parallaxing (0 to 1)
function Group:draw(scroll_factor_x, scroll_factor_y)
  if self.camera then self.camera:attach(scroll_factor_x, scroll_factor_y) end
  for _, object in ipairs(self.objects) do
    if not object.dead and not object.hidden then
      object:draw()
    end
  end
  if self.camera then self.camera:detach() end
end


-- Draws only objects within the indexed range
function Group:draw_range(i, j, scroll_factor_x, scroll_factor_y)
  if self.camera then self.camera:attach(scroll_factor_x, scroll_factor_y) end
  for k = i, j do
    if self.objects[k] and not self.objects[k].dead and not self.objects[k].hidden then
      self.objects[k]:draw()
    end
  end
  if self.camera then self.camera:detach() end
end


-- Draws only objects of a certain class
function Group:draw_class(class, scroll_factor_x, scroll_factor_y)
  if self.camera then self.camera:attach(scroll_factor_x, scroll_factor_y) end
  for _, object in ipairs(self.objects) do
    if not object.dead and object:is(class) and not object.hidden then
      object:draw()
    end
  end
  if self.camera then self.camera:detach() end
end


-- Draws all objects except those of specified classes
function Group:draw_all_except(classes, scroll_factor_x, scroll_factor_y)
  if self.camera then self.camera:attach(scroll_factor_x, scroll_factor_y) end
  for _, object in ipairs(self.objects) do
    if not object.dead and not table.any(classes, function(v) return object:is(v) end) and not object.hidden then
      object:draw()
    end
  end
  if self.camera then self.camera:detach() end
end


-- Sets this group as one without a camera, useful for UIs
function Group:no_camera()
  self.camera = nil
  return self
end


-- Sorts all objects by their y position (for top-down 2.5D games)
function Group:sort_by_y()
  table.sort(self.objects, function(a, b)
    return (a.y + (a.y_sort_offset or 0)) < (b.y + (b.y_sort_offset or 0))
  end)
end


-- Returns the mouse position based on the camera used by this group
function Group:get_mouse_position()
  if self.camera then
    return self.camera.mouse.x, self.camera.mouse.y
  else
    -- UrhoX: use input.mousePosition and scale by sx, sy
    local mx, my = input.mousePosition.x, input.mousePosition.y
    return mx / sx, my / sy
  end
end


function Group:destroy()
  for _, object in ipairs(self.objects) do
    if object.destroy then object:destroy() end
  end
  self.objects = {}
  self.objects.by_id = {}
  self.objects.by_class = {}
  if self.physics_scene then
    self.physics_scene:Remove()
    self.physics_scene = nil
    self.physics_world = nil
  end
  self._physics_nodes = nil
  return self
end


-- Adds an existing object to the group
function Group:add(object)
  local class = getmetatable(object)
  object.group = self

  if not object.id then object.id = random:uid() end
  self.objects.by_id[object.id] = object
  if not self.objects.by_class[class] then self.objects.by_class[class] = {} end
  table.insert(self.objects.by_class[class], object)
  table.insert(self.objects, object)
  return object
end


-- Returns an object by its unique id
function Group:get_object_by_id(id)
  return self.objects.by_id[id]
end


-- Returns the first object found by property
function Group:get_object_by_property(key, value)
  for _, object in ipairs(self.objects) do
    if object[key] == value then
      return object
    end
  end
end


-- Returns an object after searching by multiple properties
function Group:get_object_by_properties(keys, values)
  for _, object in ipairs(self.objects) do
    local this_is_the_object = true
    for i = 1, #keys do
      if object[keys[i]] ~= values[i] then
        this_is_the_object = false
      end
    end
    if this_is_the_object then
      return object
    end
  end
end


-- Returns all objects of a specific class
function Group:get_objects_by_class(class)
  if not self.objects.by_class[class] then return {}
  else return table.shallow_copy(self.objects.by_class[class]) end
end


-- Returns all objects of the specified classes
function Group:get_objects_by_classes(class_list)
  local objects = {}
  for _, class in ipairs(class_list) do
    table.insert(objects, self:get_objects_by_class(class))
  end
  return table.flatten(objects, true)
end


-- Returns all objects inside the shape using spatial hashing
function Group:get_objects_in_shape(shape, object_types, exclude_list)
  local out = {}
  exclude_list = exclude_list or {}
  local hw = shape.w or shape.r or 0  -- Rectangle uses w/h, Circle uses r
  local hh = shape.h or shape.r or 0
  local cx1, cy1 = math.floor((shape.x - hw) / self.cell_size), math.floor((shape.y - hh) / self.cell_size)
  local cx2, cy2 = math.floor((shape.x + hw) / self.cell_size), math.floor((shape.y + hh) / self.cell_size)
  for i = cx1, cx2 do
    for j = cy1, cy2 do
      local cx, cy = i, j
      if self.cells[cx] then
        local cell_objects = self.cells[cx][cy]
        if cell_objects then
          for _, object in ipairs(cell_objects) do
            if object_types then
              if not table.any(exclude_list, function(v) return v.id == object.id end) then
                if table.any(object_types, function(v) return object:is(v) end) and object.shape and object.shape:is_colliding_with_shape(shape) then
                  table.insert(out, object)
                end
              end
            else
              if object.shape and object.shape:is_colliding_with_shape(shape) then
                table.insert(out, object)
              end
            end
          end
        end
      end
    end
  end
  return out
end


-- Returns the closest object to the given object
function Group:get_closest_object(object, select_function)
  if not select_function then select_function = function(o) return true end end
  local min_distance, min_index = 100000, 0
  for i, o in ipairs(self.objects) do
    if select_function(o) then
      local d = math.distance(o.x, o.y, object.x, object.y)
      if d < min_distance then
        min_distance = d
        min_index = i
      end
    end
  end
  if min_index > 0 then return self.objects[min_index] end
end


-- ============================================================
-- Physics World Setup (UrhoX Adaptation)
-- ============================================================

-- Sets this group as a physics box2d world using UrhoX PhysicsWorld2D.
-- meter: the pixels-per-meter scaling factor (LÖVE2D concept, used for unit conversion)
-- xg, yg: gravity components
-- tags: collision tag names array
function Group:set_as_physics_world(meter, xg, yg, tags)
  self.meter = meter or 192
  self.tags = table.unify(table.push(tags or {}, 'solid'))

  -- Build collision and trigger tag tables
  self.collision_tags = {}
  self.trigger_tags = {}
  for i, tag in ipairs(self.tags) do
    self.collision_tags[tag] = { category = i, masks = {} }
    self.trigger_tags[tag] = { category = i, triggers = {} }
  end

  -- UrhoX: Create a Scene node (or use existing scene) with PhysicsWorld2D
  -- In UrhoX the physics world is a component on the scene.
  -- We create a child node to act as our physics "sub-scene".
  if scene_ then
    self.physics_scene = scene_:CreateChild("PhysicsGroup")
  else
    -- Fallback: create a minimal Scene
    self.physics_scene = Scene()
    self.physics_scene:CreateComponent("Octree")
  end

  self.physics_world = self.physics_scene:CreateComponent("PhysicsWorld2D")
  self.physics_world:SetGravity(Vector2(xg or 0, yg or 0))
  -- Compatibility: SNKRX game code checks self.group.world to verify physics is active
  self.world = self.physics_world

  -- ID-to-gameobject map for collision resolution
  self._physics_nodes = {}

  -- Wire up collision callbacks via UrhoX events
  local group_ref = self
  SubscribeToEvent("PhysicsBeginContact2D", function(eventType, eventData)
    group_ref:_on_physics_begin_contact(eventData)
  end)
  SubscribeToEvent("PhysicsEndContact2D", function(eventType, eventData)
    group_ref:_on_physics_end_contact(eventData)
  end)

  return self
end


-- Internal: handle begin-contact event from UrhoX Physics2D
function Group:_on_physics_begin_contact(eventData)
  local nodeA = eventData["NodeA"]:GetPtr("Node")
  local nodeB = eventData["NodeB"]:GetPtr("Node")
  if not nodeA or not nodeB then return end

  local oa = nodeA.gameObject
  local ob = nodeB.gameObject
  if not oa or not ob then return end

  -- Sync positions from physics engine before processing callbacks.
  -- PhysicsBeginContact2D fires during the physics step, BEFORE
  -- update_game_object syncs self.x/self.y from the physics node.
  -- Without this, collision callbacks use stale positions from the
  -- previous frame, causing spawned effects (HitParticle etc.) to
  -- appear at wrong locations.
  if oa.update_position then oa:update_position() end
  if ob.update_position then ob:update_position() end

  -- Determine if either is a sensor/trigger
  local shapeA = eventData["ShapeA"]:GetPtr("CollisionShape2D")
  local shapeB = eventData["ShapeB"]:GetPtr("CollisionShape2D")
  local sensorA = shapeA and shapeA:IsTrigger() or false
  local sensorB = shapeB and shapeB:IsTrigger() or false

  -- Build a Contact wrapper with position/normal info from UrhoX
  local contact = nil
  if Contact then
    local cx, cy, cnx, cny = 0, 0, 0, -1
    local got_contact = false

    -- Try to extract real contact data from Contacts buffer (2D format: position Vector2 + normal Vector2)
    local ok, contacts_var = pcall(function() return eventData:GetVariant("Contacts") end)
    if ok and contacts_var then
      local buf_ok, buf = pcall(function() return contacts_var:GetBuffer() end)
      if buf_ok and buf and not buf.eof then
        -- Read first contact point: position (x,y) + normal (nx,ny)
        local pos_ok, pos = pcall(function() return buf:ReadVector2() end)
        if pos_ok and pos then
          cx = pos.x
          cy = pos.y
          local norm_ok, norm = pcall(function() return buf:ReadVector2() end)
          if norm_ok and norm then
            cnx = norm.x
            cny = norm.y
            got_contact = true
          end
        end
      end
    end

    -- Fallback: use velocity-based wall normal for proper mirror reflection
    if not got_contact then
      if oa.x and oa.y and ob.x and ob.y then
        cx = (oa.x + ob.x) * 0.5
        cy = (oa.y + ob.y) * 0.5

        -- For wall collisions (chain shapes), determine which wall edge was hit
        -- by checking which arena boundary the moving object is closest to.
        local use_velocity_fallback = false
        if (oa.get_velocity and ob.vertices) or (ob.get_velocity and oa.vertices) then
          -- One is a moving body, other is a wall (chain shape)
          local mover = oa.get_velocity and oa or ob
          local wall_obj = oa.get_velocity and ob or oa
          -- Determine closest wall edge using mover position relative to arena center
          -- Wall vertices form a rectangle; find which edge is nearest
          if wall_obj.vertices and #wall_obj.vertices >= 8 then
            -- Arena walls: find min distance to each edge
            local mx, my = mover.x, mover.y
            -- Extract bounding rect from chain vertices
            local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
            for vi = 1, #wall_obj.vertices, 2 do
              local vx, vy = wall_obj.vertices[vi], wall_obj.vertices[vi+1]
              if vx < minX then minX = vx end
              if vx > maxX then maxX = vx end
              if vy < minY then minY = vy end
              if vy > maxY then maxY = vy end
            end
            -- Distance to each edge
            local dLeft = math.abs(mx - minX)
            local dRight = math.abs(mx - maxX)
            local dTop = math.abs(my - minY)
            local dBottom = math.abs(my - maxY)
            local dMin = math.min(dLeft, dRight, dTop, dBottom)
            if dMin == dLeft then
              cnx, cny = -1, 0   -- wall is to the left, normal points left (into mover)
            elseif dMin == dRight then
              cnx, cny = 1, 0    -- wall is to the right
            elseif dMin == dTop then
              cnx, cny = 0, -1   -- wall is at top
            else
              cnx, cny = 0, 1    -- wall is at bottom
            end
            use_velocity_fallback = true
          end
        end

        if not use_velocity_fallback then
          -- Generic fallback: use position difference
          local dx = ob.x - oa.x
          local dy = ob.y - oa.y
          local len = math.sqrt(dx * dx + dy * dy)
          if len > 0.0001 then
            cnx = dx / len
            cny = dy / len
          end
        end
      end
    end

    contact = Contact(cx, cy, cnx, cny)
  end

  if sensorA or sensorB then
    -- Trigger collision
    if sensorA then
      if oa.on_trigger_enter then oa:on_trigger_enter(ob, contact) end
    end
    if sensorB then
      if ob.on_trigger_enter then ob:on_trigger_enter(oa, contact) end
    end
  else
    -- Physical collision
    if oa.on_collision_enter then oa:on_collision_enter(ob, contact) end
    if ob.on_collision_enter then ob:on_collision_enter(oa, contact) end
  end
end


-- Internal: handle end-contact event from UrhoX Physics2D
function Group:_on_physics_end_contact(eventData)
  local nodeA = eventData["NodeA"]:GetPtr("Node")
  local nodeB = eventData["NodeB"]:GetPtr("Node")
  if not nodeA or not nodeB then return end

  local oa = nodeA.gameObject
  local ob = nodeB.gameObject
  if not oa or not ob then return end

  local shapeA = eventData["ShapeA"]:GetPtr("CollisionShape2D")
  local shapeB = eventData["ShapeB"]:GetPtr("CollisionShape2D")
  local sensorA = shapeA and shapeA:IsTrigger() or false
  local sensorB = shapeB and shapeB:IsTrigger() or false

  if sensorA or sensorB then
    if sensorA then
      if oa.on_trigger_exit then oa:on_trigger_exit(ob) end
    end
    if sensorB then
      if ob.on_trigger_exit then ob:on_trigger_exit(oa) end
    end
  else
    if oa.on_collision_exit then oa:on_collision_exit(ob) end
    if ob.on_collision_exit then ob:on_collision_exit(oa) end
  end
end


-- Enables physical collision between objects of two tags
function Group:enable_collision_between(tag1, tag2)
  table.delete(self.collision_tags[tag1].masks, self.collision_tags[tag2].category)
end


-- Disables physical collision between objects of two tags
function Group:disable_collision_between(tag1, tag2)
  table.insert(self.collision_tags[tag1].masks, self.collision_tags[tag2].category)
end


-- Enables trigger collision between objects of two tags
function Group:enable_trigger_between(tag1, tag2)
  table.insert(self.trigger_tags[tag1].triggers, self.trigger_tags[tag2].category)
end


-- Disables trigger collision between objects of two tags
function Group:disable_trigger_between(tag1, tag2)
  table.delete(self.trigger_tags[tag1].triggers, self.trigger_tags[tag2].category)
end


-- Raycast using UrhoX PhysicsWorld2D
-- Returns a table of hits in the same format as SNKRX:
-- { {x, y, nx, ny, fraction, other = object}, ... }
function Group:raycast(x1, y1, x2, y2)
  if not self.physics_world then return {} end

  local results = self.physics_world:Raycast(Vector2(x1, y1), Vector2(x2, y2))
  if not results then return {} end

  local hits = {}
  for i = 1, #results do
    local r = results[i]
    local node = r.body_:GetNode()
    local obj = node and node.gameObject or nil
    if obj then
      local pos = r.position_
      local normal = r.normal_
      table.insert(hits, {
        x = pos.x,
        y = pos.y,
        nx = normal.x,
        ny = normal.y,
        fraction = r.distance_ or 0,
        other = obj,
      })
    end
  end

  return hits
end
