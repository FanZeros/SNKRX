-- The base Random class.
-- Adapted for UrhoX: uses Lua 5.4 built-in math.random instead of love.math.newRandomGenerator.
-- A global instance of this called "random" is available by default.
Random = Object:extend()
function Random:init(seed)
  seed = seed or os.time()
  math.randomseed(seed)
end


-- Returns true at the given chance.
-- random:bool(50) -> returns true 50% of the time
function Random:bool(chance)
  if math.random(1, 1000) < 10*(chance or 50) then
    return true
  end
end


-- Returns a random real number between the range.
-- random:float(0, 1) -> returns a random number between 0 and 1
function Random:float(min, max)
  min = min or 0
  max = max or 1
  return (min > max and (math.random()*(min - max) + max)) or (math.random()*(max - min) + min)
end


-- Returns a random integer number between the range.
-- random:int(1, 7) -> returns a random integer between 1 and 7
function Random:int(min, max)
  return math.random(min or 0, max or 1)
end


-- Returns a random value of the table.
function Random:table(t)
  if #t == 0 then return nil end
  return t[math.random(1, #t)]
end

-- Returns a random value of the table and also removes it.
function Random:table_remove(t)
  if #t == 0 then return nil end
  return table.remove(t, math.random(1, #t))
end


-- Returns a 1 at the given chance, otherwise returns -1.
function Random:sign(chance)
  if math.random(1, 1000) < 10*(chance or 50) then return 1
  else return -1 end
end


-- Returns a random index at the given weights.
-- random:weighted_pick(50, 30, 20) -> will return 1 50%, 2 30%, 3 20% of the time
function Random:weighted_pick(...)
  local weights = {...}
  local total_weight = 0
  local pick = 0
  for _, weight in ipairs(weights) do total_weight = total_weight + weight end

  total_weight = self:float(0, total_weight)
  for i = 1, #weights do
    if total_weight < weights[i] then
      pick = i
      break
    end
    total_weight = total_weight - weights[i]
  end
  return pick
end


-- Returns a unique identifier.
function Random:uid()
  local fn = function(x)
    local r = self:int(1, 16) - 1
    r = (x == "x") and (r + 1) or (r % 4) + 9
    return ("0123456789abcdef"):sub(r, r)
  end
  return (("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"):gsub("[xy]", fn))
end
