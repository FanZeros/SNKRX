-- Observer: simple event emitter / pub-sub (pure Lua)

Observer = Object:extend()

function Observer:init()
  self.events = {}
  return self
end

function Observer:on(event, action)
  if not self.events[event] then self.events[event] = {} end
  table.insert(self.events[event], action)
  return self
end

function Observer:off(event, action)
  if not self.events[event] then return end
  for i = #self.events[event], 1, -1 do
    if self.events[event][i] == action then
      table.remove(self.events[event], i)
    end
  end
  return self
end

function Observer:trigger(event, ...)
  if not self.events[event] then return end
  for _, action in ipairs(self.events[event]) do
    action(...)
  end
  return self
end
