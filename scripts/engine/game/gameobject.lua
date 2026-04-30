-- SNKRX Engine: GameObject mixin
-- Provides init_game_object(args) and update_game_object(dt) for all game entities.
-- Used via Object:implement(GameObject) — NOT as a base class.
--
-- Original SNKRX pattern:
--   MyClass = Object:extend()
--   MyClass:implement(GameObject)
--   function MyClass:init(args)
--     self:init_game_object(args)
--     ...
--   end

GameObject = Object:extend()
GameObject.class = 'GameObject'

-- Simple UID generator
local _uid_counter = 0
local function uid()
  _uid_counter = _uid_counter + 1
  return _uid_counter
end

--- Initializes the game object from a table of arguments.
--- Called as self:init_game_object(args) inside each class's init().
--- @param args table|nil  Table with {[1]=x, [2]=y, x=, y=, group=, ...}
function GameObject:init_game_object(args)
  args = args or {}

  -- Position: support both positional args[1],args[2] and named args.x,args.y
  self.x = args.x or args[1] or 0
  self.y = args.y or args[2] or 0

  -- Copy all named fields from args to self (skip numeric indices)
  for k, v in pairs(args) do
    if type(k) == "string" then
      self[k] = v
    end
  end

  -- Unique identifier
  self.id = self.id or uid()

  -- Standard object state
  self.dead = self.dead or false
  self.r = self.r or 0
  self.sx = self.sx or 1
  self.sy = self.sy or 1

  -- Timer system (Trigger)
  self.t = Trigger()

  -- Spring for visual juice
  self.spring = Spring(1, 200, 10)

  -- Springs collection (for HitFX)
  self.springs = Springs()

  -- Flashes collection (for HitFX)
  self.flashes = Flashes()

  -- HitFX system (combines springs + flashes for hit feedback)
  self.hfx = HitFX(self)

  -- Register with group if specified
  if self.group then
    self.group:add(self)
  end

  return self
end

--- Updates the game object's subsystems each frame.
--- Called as self:update_game_object(dt) inside each class's update().
--- @param dt number  Delta time in seconds
function GameObject:update_game_object(dt)
  if self.dead then return end

  -- Sync physics position (UrhoX body → SNKRX x,y) and run steering update
  if self.update_physics then self:update_physics(dt) end

  -- Update timer/trigger system
  if self.t then self.t:update(dt) end

  -- Update spring
  if self.spring then self.spring:update(dt) end

  -- Update springs collection
  if self.springs then self.springs:update(dt) end

  -- Update flashes collection
  if self.flashes then self.flashes:update(dt) end

  -- Update hit effects
  if self.hfx then self.hfx:update(dt) end
end

--- Angle from this object to another object (radians).
function GameObject:angle_to_object(other)
  return math.atan(other.y - self.y, other.x - self.x)
end

--- Distance from this object to another object.
function GameObject:distance_to_object(other)
  return math.sqrt((self.x - other.x)^2 + (self.y - other.y)^2)
end

--- Get all objects of given classes within a shape from the group.
--- @param shape table  A shape object with :is_colliding_with_shape(other_shape)
--- @param class_list table  Array of class tables or a Group to search
function GameObject:get_objects_in_shape(shape, class_list)
  local result = {}
  local objects = {}

  -- class_list can be a Group or a list of classes
  if class_list and class_list.objects then
    -- It's a Group — iterate all objects in it
    for _, obj in ipairs(class_list.objects) do
      if not obj.dead then
        table.insert(objects, obj)
      end
    end
  elseif class_list then
    -- It's a list of classes — look up each in self.group
    if self.group then
      for _, cls in ipairs(class_list) do
        local class_objects = self.group.objects.by_class[cls]
        if class_objects then
          for _, obj in ipairs(class_objects) do
            if not obj.dead then
              table.insert(objects, obj)
            end
          end
        end
      end
    end
  end

  for _, obj in ipairs(objects) do
    if obj ~= self and obj.shape then
      if shape:is_colliding_with_shape(obj.shape) then
        table.insert(result, obj)
      end
    end
  end
  return result
end

--- Get the closest object of given classes within a shape from the group.
function GameObject:get_closest_object_in_shape(shape, class_list)
  local objects = self:get_objects_in_shape(shape, class_list)
  if #objects == 0 then return nil end

  local closest = nil
  local min_dist = math.huge
  for _, obj in ipairs(objects) do
    local d = self:distance_to_object(obj)
    if d < min_dist then
      min_dist = d
      closest = obj
    end
  end
  return closest
end

--- Destroy / mark dead and clean up physics resources
function GameObject:destroy()
  self.dead = true
  -- Clean up physics node if this object has physics (Physics mixin)
  if self.physics_node then
    self.physics_node:Remove()
    self.physics_node = nil
    self.body = nil
    self.fixture_component = nil
    self.sensor_component = nil
  end
  if self.group and self.group._physics_nodes and self.id then
    self.group._physics_nodes[self.id] = nil
  end
end

function GameObject:is_dead()
  return self.dead
end
