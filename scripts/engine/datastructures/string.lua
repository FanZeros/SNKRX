-- Returns the substring to the left of the first instance of the pattern passed in
function string:left(p)
  local i = self:find(p)
  if i then
    local out = self:sub(1, i-1)
    return out ~= "" and out
  end
end


-- Returns the substring to the right of the first instance of the pattern passed in
function string:right(p)
  local _, j = self:find(p)
  if j then
    local out = self:sub(j+1)
    return out ~= "" and out
  end
end


-- Splits the string into words in a table according to the separator pattern passed in
function string:split(s)
  if not s then s = "%s" end
  local out = {}
  for str in self:gmatch("([^" .. s .. "]+)") do
    table.insert(out, str)
  end
  return out
end


-- Returns the character at a particular index
function string:index(i)
  return self:sub(i, i)
end


-- Returns the capitalized string
function string:capitalize()
  return self:gsub("^%l", string.upper)
end
