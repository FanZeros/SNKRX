-- Draft: weighted random selection with removal (drafting)
-- Adapted: love.math.random() → math.random()

Draft = Object:extend()

function Draft:init(pairs)
  self.pairs = pairs
  self:_build()
  return self
end

function Draft:_build()
  self.values = {}
  for _, p in ipairs(self.pairs) do
    table.insert(self.values, { value = p[1], weight = p[2] })
  end
end

function Draft:next()
  local total = 0
  for _, v in ipairs(self.values) do total = total + v.weight end
  local r = math.random() * total
  local cumulative = 0
  local index = 1
  for i, v in ipairs(self.values) do
    cumulative = cumulative + v.weight
    if r <= cumulative then
      index = i
      break
    end
  end
  local value = self.values[index].value
  table.remove(self.values, index)
  if #self.values == 0 then self:_build() end
  return value
end
