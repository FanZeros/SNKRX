-- Copies the table deeply, including metatables
function table.copy(t)
  local t_type = type(t)
  local copy
  if t_type == "table" then
    copy = {}
    for k, v in next, t, nil do
      copy[table.copy(k)] = table.copy(v)
    end
    setmetatable(copy, table.copy(getmetatable(t)))
  else
    copy = t
  end
  return copy
end


function table.shallow_copy(t)
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = v
  end
  return copy
end


function table.array(t, n)
  for i = 1, n do
    table.push(t, i)
  end
  return t
end


function table.get(t, i, j)
  if i < 0 then i = #t + i + 1 end
  if not j then return t[i] end
  if j < 0 then j = #t + j + 1 end
  if i == j then return t[i] end
  local out = {}
  for k = i, j, math.sign(j-i) do
    table.push(out, t[k])
  end
  return out
end


function table.set(t, i, j, v)
  if i < 0 then i = #t + i + 1 end
  if not v then t[i] = j; return t end
  if j < 0 then j = #t + j + 1 end
  if i == j then t[i] = v; return t end
  for k = i, j, math.sign(j-i) do
    t[k] = v
  end
  return t
end


function table.index(t, v)
  for i, u in ipairs(t) do
    if u == v then
      return i
    end
  end
end


function table.back(t)
  return t[#t]
end


function table.head(t, n)
  local out = {}
  for i = 1, (n or 1) do
    table.push(out, t[i])
  end
  if n then return out
  else
    if #out == 1 then return out[1]
    else return out end
  end
end


function table.tail(t, n)
  local out = {}
  for i = #t-(n or #t-1)+1, #t do
    table.push(out, t[i])
  end
  if n then return out
  else
    if #out == 1 then return out[1]
    else return out end
  end
end


function table.push(t, v)
  table.insert(t, v)
  return t
end


function table.shift(t, n)
  local out = {}
  for i = 1, (n or 1) do
    table.insert(out, table.remove(t, 1))
  end
  if #out == 1 then return out[1], t
  else return out, t end
end


function table.unshift(t, ...)
  for j, v in ipairs({...}) do
    table.insert(t, 1+j-1, v)
  end
  return t
end


function table.pop(t)
  return table.remove(t, #t), t
end


function table.delete(t, v)
  if type(v) == 'function' then
    for i = #t, 1, -1 do
      if v(t[i]) then
        table.remove(t, i)
      end
    end
  else
    for i = #t, 1, -1 do
      if v == t[i] then
        table.remove(t, i)
      end
    end
  end
  return t
end


function table.slice(t, i, j)
  if i < 0 then i = #t + i + 1 end
  if not j then return t[i] end
  if j < 0 then j = #t + j + 1 end
  if i == j then return t[i] end
  local out = {}
  for k = j, i, -math.sign(j-i) do
    table.insert(out, table.remove(t, k))
  end
  if #out == 1 then return out[1], t
  else return table.reverse(out), t end
end


function table.unify(t, f)
  if not f then f = function(v) return v end end
  local seen = {}
  for i = #t, 1, -1 do
    if not seen[f(t[i])] then
      seen[f(t[i])] = true
    else
      table.remove(t, i)
    end
  end
  return t
end


function table.count(t, v)
  local n = 0
  for i = 1, #t do
    if t[i] == v then
      n = n + 1
    end
  end
  return n
end


function table.map(t, f, ...)
  for k, v in ipairs(t) do
    t[k] = f(v, k, ...)
  end
  return t
end


function table.reduce(t, f, dv, ...)
  local memo = dv or t[1]
  if dv then
    for i = 1, #t do
      memo = f(memo, t[i], i, ...)
    end
  else
    for i = 2, #t do
      memo = f(memo, t[i], i, ...)
    end
  end
  return memo
end


function table.foreach(t, f, ...)
  for k, v in ipairs(t) do
    f(v, k, ...)
  end
  return t
end


function table.foreachn(t, f, ...)
  local out = {}
  for k, v in ipairs(t) do
    table.insert(out, f(v, k, ...))
  end
  return out
end


function table.reject(t, f, ...)
  local out = {}
  for i = #t, 1, -1 do
    if f(t[i], i, ...) then
      table.insert(out, table.remove(t, i))
    end
  end
  if #out == 1 then return out[1], t
  else return table.reverse(out), t end
end


function table.select(t, f, ...)
  local out = {}
  for i = 1, #t do
    if f(t[i], i, ...) then
      table.insert(out, t[i])
    end
  end
  return out
end


function table.any(t, f, ...)
  for i, v in ipairs(t) do
    if f(v, i, ...) then
      return true
    end
  end
end


function table.all(t, f, ...)
  for i, v in ipairs(t) do
    if not f(v, i, ...) then
      return false
    end
  end
  return true
end


function table.contains(t, v)
  if type(v) == "function" then
    for i, u in ipairs(t) do
      if v(u) then return i end
    end
  else
    for i, u in ipairs(t) do
      if u == v then return i end
    end
  end
end


function table.flatten(t, shallow)
  local out = {}
  local u
  for k, v in ipairs(t) do
    if type(v) == "table" and getmetatable(t) == nil then
      u = shallow and v or table.flatten(v)
      for _, x in ipairs(u) do
        table.insert(out, x)
      end
    else
      table.insert(out, v)
    end
  end
  return out
end


function table.tostring(t)
  if type(t) == "table" then
    local str = "{"
    for k, v in pairs(t) do
      if type(k) ~= "number" then k = '"' .. k .. '"' end
      str = str .. "[" .. k .. "] = " .. table.tostring(v) .. ", "
    end
    if str ~= "{" then return str:sub(1, -3) .. "}"
    else return str .. "}" end
  elseif type(t) == "string" then
    return '"' .. tostring(t) .. '"'
  else return tostring(t) end
end


function table.first(t, n)
  if n == 1 then return t[1] end
  local out = {}
  for i = 1, (n or 1) do
    table.push(out, t[i])
  end
  if #out == 1 then return out[1]
  else return out end
end


function table.first2(t, n)
  if n == 1 then return {t[1]} end
  local out = {}
  for i = 1, (n or 1) do
    table.push(out, t[i])
  end
  return out
end


function table.last(t, n)
  if n == 1 then return t[#t] end
  local out = {}
  for i = #t-n+1, #t do
    table.push(out, t[i])
  end
  if #out == 1 then return out[1]
  else return out end
end


function table.reverse(t, i, j)
  if not i then i = 1 end
  if i < 0 then i = #t + i + 1 end
  if not j then j = #t end
  if j < 0 then j = #t + j + 1 end
  if i == j then return t end
  for k = 0, (j-i+1)/2-1, math.sign(j-i) do
    t[i+k], t[j-k] = t[j-k], t[i+k]
  end
  return t
end


function table.rotate(t, n)
  if not n then n = 1 end
  if n < 0 then n = #t + n end
  t = table.reverse(t, 1, #t)
  t = table.reverse(t, 1, #t-n)
  t = table.reverse(t, #t-n+1, #t)
  return t
end


-- Adapted for UrhoX: replaced love.math.random with math.random
function table.random(t)
  return t[math.random(1, #t)]
end


-- Adapted for UrhoX: replaced love.math.random with math.random
function table.shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end


function table.merge(t1, t2)
  local out = {}
  for k, v in pairs(t1) do out[k] = v end
  for k, v in pairs(t2) do out[k] = v end
  return out
end
