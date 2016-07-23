--[[

A very fast Lua linked list implementation that has a program lifetime.

The maximum number of cons cells created is the maximum integer that can be

held accurately in a lua number.

It has an inherent memory leak, because the cdr part of a cons cell is never

garbage collected, it stores a value pointing to the next cell.

]]--

local utils = require("leftry").utils

local data = setmetatable({n=0}, { __mode = 'v' })

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
  local self = setmetatable({position = data.n + 1}, list)
  if not t or #t == 0 then
    return
  end
  local n = data.n
  data.n = data.n + #t * 2
  for i, v in ipairs(t) do
    n = n + 1
    if f then
      data[n] = f(v)
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

