--[[

A very fast Lua linked list implementation that has a program lifetime.

The maximum number of cons cells created is the maximum integer that can be

held accurately in a lua number.

Likely to have unsolved memory leaks.
]]--

local utils = require("leftry").utils

local data = setmetatable({n=0, free=0}, {})

local list = utils.prototype("list", function(list, ...)
  local self = setmetatable({position = data.n + 1}, list)
  local count = select("#", ...)
  local index = self.position
  for i=1, count do
    local datum = (select(i, ...))
    data.n = data.n + 1
    data[data.n] = datum
    data.n = data.n + 1
    if i < count then
      data[data.n] = index + i * 2
    end
  end
  return self
end)

function list:__gc()
  -- Create cdr for Lua to gc, to trigger __gc for subsequent cells.
  local cdr = self:cdr()
  -- Free this cell.
  data[self.position] = nil
  data[self.position + 1] = nil
  data.free = data.free + 1
  if data.free == data.n then
    -- Take the opportunity to reset `data`.
    data = setmetatable({n=0}, {})
  end
end

function list:__tostring()
  local text = {}
  local cdr = self
  local i = 0
  while cdr do
    i = i + 1
    local car = cdr:car()
    if type(car) == "string" then
      car = utils.escape(car)
    end
    text[i] = tostring(car)
    cdr = cdr:cdr()
  end
  return "list("..table.concat(text, ", ")..")"
end

function list:__ipairs()
  local cdr = self
  local i = 0
  return function(invariant, state)
    if not cdr then
      return
    end
    i = i + 1
    local car = cdr:car()
    cdr = cdr:cdr()
    return i, car
  end
end

function list:__len()
  if not self then
    return 0
  end
  local cdr = self:cdr()
  local count = 1
  while cdr do
    count = count + 1
    cdr = cdr:cdr()
  end
  return count
end

function list:car()
  return data[self.position]
end

function list:cdr()
  local position = data[self.position + 1]
  if position then
    return setmetatable({position = position}, list)
  end
end

function list:unpack()
  local car, cdr = self:car(), self:cdr()
  if cdr then
    return car, cdr:unpack()
  end
  return car
end

function list.cast(t, f)
  -- Cast an ipairs-enumerable object into a list.
  if not t or #t == 0 then
    return nil
  end
  local self = setmetatable({position = data.n + 1}, list)
  local n = data.n
  data.n = data.n + #t * 2
  for i, v in ipairs(t) do
    n = n + 1
    if f then
      data[n] = f(v, i)
    else
      data[n] = v
    end
    n = n + 1
    if i < #t then
      data[n] = n + 1
    end
  end
  return self
end

function list:cons(car)
  -- Prepend car to the list and return a new head.
  data.n = data.n + 1
  local position = data.n
  data[data.n] = car
  data.n = data.n + 1
  if self then
    data[data.n] = self.position
  end
  return setmetatable({position = position}, list)  
end

return list

