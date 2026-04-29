-- The base Springs class.
-- This class is used to manage all springs in an object.
Springs = Object:extend()
function Springs:init()
  self.names = {}
end


function Springs:update(dt)
  for _, name in ipairs(self.names) do
    self[name]:update(dt)
  end
end


-- Adds a new spring to the object.
function Springs:add(name, x, k, d)
  if name == 'parent' or name == 'names' or name == 'trigger' or name == 'add' or name == 'use' or name == 'update' or name == 'init' or name == 'pull' or name == 'flash' then
    error("Invalid name to be added to the Springs object. 'add', 'flash', 'init', 'names', 'parent', 'pull', 'trigger', 'update' and 'use' are reserved names, choose another.")
  end
  self[name] = Spring(x, k, d)
  table.insert(self.names, name)
end
