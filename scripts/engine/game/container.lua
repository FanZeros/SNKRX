-- Container: simple object collection (pure Lua, no engine dependency)

Container = Object:extend()

function Container:init(args)
  self.type = 'container'
  self.objects = {}
  self.cells = {}
  self.x, self.y = args and args.x or 0, args and args.y or 0
  self.w, self.h = args and args.w or 0, args and args.h or 0
  return self
end

function Container:update(dt)
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

function Container:add(object)
  table.insert(self.objects, object)
  return self
end

function Container:remove(object)
  for i, o in ipairs(self.objects) do
    if o == object then
      table.remove(self.objects, i)
      return
    end
  end
  return self
end

function Container:get_objects_by_class(class)
  local objects = {}
  for _, object in ipairs(self.objects) do
    if object:is(class) then
      table.insert(objects, object)
    end
  end
  return objects
end

function Container:destroy()
  for _, object in ipairs(self.objects) do
    if object.destroy then object:destroy() end
  end
  self.objects = {}
  return self
end
