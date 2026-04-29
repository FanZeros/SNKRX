-- The base HitFX class.
-- Combination of Springs and Flashes for interaction feedback.
HitFX = Object:extend()
function HitFX:init(parent)
  self.parent = parent
  self.names = {}
end


function HitFX:update(dt)
  if not self.parent then return end
  if self.parent and self.parent.dead then self.parent = nil; return end

  for _, name in ipairs(self.names) do
    self[name].x = self.parent.springs[name].x
    self[name].f = self.parent.flashes[name].f
  end
end


function HitFX:add(name, x, k, d, default_flash_duration)
  if name == 'parent' or name == 'names' or name == 'trigger' or name == 'add' or name == 'use' or name == 'update' or name == 'init' or name == 'pull' or name == 'flash' then
    error("Invalid name to be added to the HitFX object. 'add', 'flash', 'init', 'names', 'parent', 'pull', 'trigger', 'update' and 'use' are reserved names, choose another.")
  end
  self.parent.flashes:add(name, default_flash_duration)
  self.parent.springs:add(name, x, k, d)
  table.insert(self.names, name)
  self[name] = {x = self.parent.springs[name].x, f = self.parent.flashes[name].f}
end


function HitFX:use(name, x, k, d, flash_duration)
  if not self.parent then return end
  self.parent.flashes[name]:flash(flash_duration)
  self.parent.springs[name]:pull(x, k, d)
end


function HitFX:pull(name, ...)
  self.parent.springs[name]:pull(...)
end


function HitFX:flash(name, ...)
  self.parent.flashes[name]:flash(...)
end
