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


-- Helper: hit-test a point against an object's shape (center-based).
local function _hit_test(object, mx, my)
  local shape = object.shape
  if not shape then return false end
  if shape.w then
    return mx >= object.x - shape.w / 2 and mx <= object.x + shape.w / 2
        and my >= object.y - shape.h / 2 and my <= object.y + shape.h / 2
  elseif shape.r then
    local dx, dy = mx - object.x, my - object.y
    return (dx * dx + dy * dy) <= shape.r * shape.r
  elseif shape.rs then
    local dx, dy = mx - object.x, my - object.y
    return (dx * dx + dy * dy) <= shape.rs * shape.rs
  end
  return false
end

-- Compute the mouse position in this group's coordinate space.
function Group:_get_group_mouse_pos()
  local mx, my
  if mouse then mx, my = mouse.x, mouse.y end
  if mx and my and self.camera then
    mx = mx + self.camera.x - self.camera.w / 2
    my = my + self.camera.y - self.camera.h / 2
  end
  return mx, my
end

-- Run hover detection for all interactive objects in this group.
-- Calls on_mouse_enter / on_mouse_exit as needed.
function Group:_run_hover_detection(mx, my)
  if not self._hover_state then self._hover_state = {} end
  for _, object in ipairs(self.objects) do
    if not object.dead and object.interact_with_mouse and object.shape then
      -- On touch devices, skip sticky-hovered objects (managed separately)
      if input and input._is_touch and self._touch_hover_obj_id == object.id then
        goto skip_hover
      end
      local inside = _hit_test(object, mx, my)
      local was_inside = self._hover_state[object.id]
      if inside and not was_inside then
        if object.on_mouse_enter then object:on_mouse_enter() end
        self._hover_state[object.id] = true
      elseif not inside and was_inside then
        if object.on_mouse_exit then object:on_mouse_exit() end
        self._hover_state[object.id] = false
      end
      ::skip_hover::
    end
  end
end

-- Phase 1 of two-phase touch update.
-- Must be called for ALL groups BEFORE any group's update() runs.
-- This ensures cross-group sticky hover signals (_touch_sticky_active,
-- _touch_confirm_group) are fully resolved before any object processes
-- input.m1.pressed.
--
-- Screens that call pre_touch_scan must clear the global signals first:
--   input._touch_sticky_active = nil
--   input._touch_confirm_group = nil
--   group1:pre_touch_scan()
--   group2:pre_touch_scan()
--   ...
--   group1:update(dt)
--   group2:update(dt)
function Group:pre_touch_scan()
  if not (input and input._is_touch) or input.touch_zone_steering then return end

  local mx, my = self:_get_group_mouse_pos()
  if not mx or not my then return end

  -- Mark that hover + sticky logic was already done (update() will skip it)
  self._pre_touch_done = true
  if not self._hover_state then self._hover_state = {} end

  -- Hover detection (on_mouse_enter / on_mouse_exit)
  self:_run_hover_detection(mx, my)

  -- Sticky hover logic
  self._touch_suppress_m1 = false
  local m1_pressed = input.m1 and input.m1.pressed
  if m1_pressed then
    local prev_id = self._touch_hover_obj_id
    local prev_obj = prev_id and self.objects.by_id[prev_id]

    -- Priority: check if touch is on the sticky-hovered object (confirm tap)
    local touched_obj = nil
    if prev_obj and not prev_obj.dead and prev_obj.shape then
      if _hit_test(prev_obj, mx, my) then
        touched_obj = prev_obj
      end
    end

    -- If not on sticky object, find which other object was actually touched
    if not touched_obj then
      for _, object in ipairs(self.objects) do
        if not object.dead and object.interact_with_mouse and object.shape
            and _hit_test(object, mx, my) then
          touched_obj = object
          break
        end
      end
    end

    if touched_obj then
      -- Ensure the touched object has on_mouse_enter called (it may have been
      -- skipped by _run_hover_detection if it was the sticky-hovered object,
      -- or just entered for the first time on this tap)
      if not self._hover_state[touched_obj.id] then
        if touched_obj.on_mouse_enter then touched_obj:on_mouse_enter() end
        self._hover_state[touched_obj.id] = true
      end

      if prev_id == touched_obj.id then
        -- Same object tapped again
        local elapsed = love.timer.getTime() - (self._touch_hover_time or 0)
        if elapsed <= 0.5 then
          -- Within double-tap window → confirm (second tap)
          self._touch_hover_obj_id = nil
          self._touch_hover_time = nil
          input._touch_confirm_group = self
        else
          -- Too slow → treat as new first tap (re-show info)
          self._touch_hover_time = love.timer.getTime()
          self._touch_suppress_m1 = true
          input._touch_sticky_active = true
        end
      else
        -- Different object → exit previous, enter new
        if prev_obj and not prev_obj.dead and self._hover_state[prev_id] then
          if prev_obj.on_mouse_exit then prev_obj:on_mouse_exit() end
          self._hover_state[prev_id] = false
        end
        if touched_obj.touch_direct then
          -- Object handles its own touch → bypass sticky, let click through
          self._touch_hover_obj_id = nil
          self._touch_hover_time = nil
        elseif touched_obj.info_text then
          -- Has hover info → sticky, suppress click
          self._touch_hover_obj_id = touched_obj.id
          self._touch_hover_time = love.timer.getTime()
          self._touch_suppress_m1 = true
          input._touch_sticky_active = true
        else
          -- No hover info → direct click
          self._touch_hover_obj_id = nil
          self._touch_hover_time = nil
        end
      end
    else
      -- Tapped empty space → clear sticky hover and suppress click
      if prev_obj and not prev_obj.dead then
        if self._hover_state[prev_id] then
          if prev_obj.on_mouse_exit then prev_obj:on_mouse_exit() end
          self._hover_state[prev_id] = false
        end
      end
      self._touch_hover_obj_id = nil
      self._touch_hover_time = nil
      self._touch_suppress_m1 = true
    end
  end
end


function Group:update(dt)
  self.t:update(dt)

  -- Mouse hover detection BEFORE object:update so that touch-down on mobile
  -- sets selected=true in the same frame as input.m1.pressed.
  -- Skip if pre_touch_scan() already handled this (two-phase mode).
  local mx, my = self:_get_group_mouse_pos()
  if mx and my and not self._pre_touch_done then
    if not self._hover_state then self._hover_state = {} end
    self:_run_hover_detection(mx, my)
  end

  -- Touch sticky hover: when pre_touch_scan was NOT called (single-phase
  -- fallback for screens that don't use two-phase), run the inline logic.
  -- When pre_touch_scan WAS called, only apply the suppression signals here.
  local _saved_m1_pressed = nil
  if input and input._is_touch and not input.touch_zone_steering then
    if self._pre_touch_done then
      -- Two-phase mode: use results from pre_touch_scan
      if self._touch_suppress_m1 then
        _saved_m1_pressed = true
        input.m1.pressed = false
        self._touch_suppress_m1 = false
      end
      -- Check cross-group signals
      if input._touch_sticky_active and _saved_m1_pressed == nil and input.m1 and input.m1.pressed then
        for _, object in ipairs(self.objects) do
          if not object.dead and object.interact_with_mouse and object.shape
              and self._hover_state and self._hover_state[object.id] and not object.info_text then
            _saved_m1_pressed = true
            input.m1.pressed = false
            break
          end
        end
      end
      if input._touch_confirm_group and input._touch_confirm_group ~= self
          and _saved_m1_pressed == nil and input.m1 and input.m1.pressed then
        for _, object in ipairs(self.objects) do
          if not object.dead and object.interact_with_mouse and object.shape
              and self._hover_state and self._hover_state[object.id] and not object.info_text then
            _saved_m1_pressed = true
            input.m1.pressed = false
            break
          end
        end
      end
    else
      -- Single-phase fallback (for screens that don't call pre_touch_scan)
      local m1_pressed = input.m1 and input.m1.pressed
      if m1_pressed and mx and my then
        local prev_id = self._touch_hover_obj_id
        local prev_obj = prev_id and self.objects.by_id[prev_id]

        local touched_obj = nil
        if prev_obj and not prev_obj.dead and prev_obj.shape then
          if _hit_test(prev_obj, mx, my) then
            touched_obj = prev_obj
          end
        end
        if not touched_obj then
          for _, object in ipairs(self.objects) do
            if not object.dead and object.interact_with_mouse and object.shape
                and _hit_test(object, mx, my) then
              touched_obj = object
              break
            end
          end
        end

        if touched_obj then
          if not self._hover_state[touched_obj.id] then
            if touched_obj.on_mouse_enter then touched_obj:on_mouse_enter() end
            self._hover_state[touched_obj.id] = true
          end
          if prev_id == touched_obj.id then
            self._touch_hover_obj_id = nil
            input._touch_confirm_group = self
          else
            if prev_obj and not prev_obj.dead and self._hover_state[prev_id] then
              if prev_obj.on_mouse_exit then prev_obj:on_mouse_exit() end
              self._hover_state[prev_id] = false
            end
            if touched_obj.info_text then
              self._touch_hover_obj_id = touched_obj.id
              _saved_m1_pressed = true
              input.m1.pressed = false
              input._touch_sticky_active = true
            else
              self._touch_hover_obj_id = nil
            end
          end
        else
          if prev_obj and not prev_obj.dead then
            if self._hover_state[prev_id] then
              if prev_obj.on_mouse_exit then prev_obj:on_mouse_exit() end
              self._hover_state[prev_id] = false
            end
          end
          self._touch_hover_obj_id = nil
        end
      end

      -- Single-phase cross-group checks (may be stale for groups updated earlier)
      if input._touch_sticky_active and _saved_m1_pressed == nil and input.m1 and input.m1.pressed then
        for _, object in ipairs(self.objects) do
          if not object.dead and object.interact_with_mouse and object.shape
              and self._hover_state and self._hover_state[object.id] and not object.info_text then
            _saved_m1_pressed = true
            input.m1.pressed = false
            break
          end
        end
      end
      if input._touch_confirm_group and input._touch_confirm_group ~= self
          and _saved_m1_pressed == nil and input.m1 and input.m1.pressed then
        for _, object in ipairs(self.objects) do
          if not object.dead and object.interact_with_mouse and object.shape
              and self._hover_state and self._hover_state[object.id] and not object.info_text then
            _saved_m1_pressed = true
            input.m1.pressed = false
            break
          end
        end
      end
    end
  end
  self._pre_touch_done = false -- reset for next frame

  for _, object in ipairs(self.objects) do
    if not object.dead then
      if object.force_update then
        object:update(1 / refresh_rate)
      else
        object:update(dt)
      end
    end
  end

  -- Restore m1.pressed after this group's object updates, so other groups
  -- (updated later) see the original value and handle their own sticky hover.
  if _saved_m1_pressed and input and input.m1 then
    input.m1.pressed = _saved_m1_pressed
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
      if self._touch_hover_obj_id == self.objects[i].id then self._touch_hover_obj_id = nil end
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
    -- UrhoX: use urho_input.mousePosition (physical pixels),
    -- convert to logical pixels then to design-space coordinates
    local inp = urho_input or input
    local pos = inp.mousePosition
    if not pos then return 0, 0 end
    local dpr = urho_graphics and urho_graphics:GetDPR() or 1
    local mx, my = pos.x / dpr, pos.y / dpr
    local ox = screen_ox or 0
    local oy = screen_oy or 0
    return (mx - ox) / sx, (my - oy) / sy
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

    -- For wall collisions (chain shapes), ALWAYS use axis-aligned normals.
    -- Identify wall by .vertices field (chain shape); mover is the other object.
    local wall_obj = (oa.vertices and oa) or (ob.vertices and ob) or nil
    local mover = wall_obj and (wall_obj == oa and ob or oa) or nil
    local is_wall_collision = wall_obj ~= nil and mover ~= nil

    if is_wall_collision then
      if not got_contact then
        -- Use the mover (projectile) position as contact point, not the midpoint.
        -- Wall objects may have their origin at arena center, so midpoint is inaccurate.
        cx = mover.x
        cy = mover.y
      end
      -- Determine closest wall edge using mover position
      if wall_obj.vertices and #wall_obj.vertices >= 8 then
        local mx, my = mover.x, mover.y
        local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
        for vi = 1, #wall_obj.vertices, 2 do
          local vx, vy = wall_obj.vertices[vi], wall_obj.vertices[vi+1]
          if vx < minX then minX = vx end
          if vx > maxX then maxX = vx end
          if vy < minY then minY = vy end
          if vy > maxY then maxY = vy end
        end
        local dLeft = math.abs(mx - minX)
        local dRight = math.abs(mx - maxX)
        local dTop = math.abs(my - minY)
        local dBottom = math.abs(my - maxY)
        local dMin = math.min(dLeft, dRight, dTop, dBottom)
        if dMin == dLeft then
          cnx, cny = -1, 0
        elseif dMin == dRight then
          cnx, cny = 1, 0
        elseif dMin == dTop then
          cnx, cny = 0, -1
        else
          cnx, cny = 0, 1
        end
      end
    elseif not got_contact then
      if oa.x and oa.y and ob.x and ob.y then
        cx = (oa.x + ob.x) * 0.5
        cy = (oa.y + ob.y) * 0.5
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
