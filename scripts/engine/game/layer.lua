-- Layer: deferred draw command list + object management (pure Lua)

Layer = Object:extend()

function Layer:init(args)
  self.objects = {}
  self.draw_commands = {}
  return self
end

function Layer:update(dt)
  for i = #self.objects, 1, -1 do
    local object = self.objects[i]
    if object.dead then
      table.remove(self.objects, i)
    else
      object:update(dt)
    end
  end
  return self
end

function Layer:draw()
  for _, dc in ipairs(self.draw_commands) do
    dc()
  end
  self.draw_commands = {}
  return self
end

function Layer:add(object)
  table.insert(self.objects, object)
  return self
end

function Layer:remove(object)
  for i, o in ipairs(self.objects) do
    if o == object then
      table.remove(self.objects, i)
      return
    end
  end
  return self
end

function Layer:draw_command(f)
  table.insert(self.draw_commands, f)
  return self
end

function Layer:get_objects_by_class(class)
  local objects = {}
  for _, object in ipairs(self.objects) do
    if object:is(class) then
      table.insert(objects, object)
    end
  end
  return objects
end
