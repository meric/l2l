local utils = require("leftry").utils

local unpack = table.unpack or _G["unpack"]

local vector = utils.prototype("vector", function(vector, ...)
  return setmetatable(table.pack(...), vector)
end)

function vector:insert(value)
  self.n = self.n + 1
  self[self.n] = value
  return self
end

function vector:append(t, f)
  local n = self.n
  self.n = n + #t
  for i, v in ipairs(t) do
    n = n + 1
    if f then
      self[n] = f(v, i)
    else
      self[n] = v
    end
  end
  return self
end

function vector:pop()
  assert(self.n > 0)
  local value = self[self.n]
  self[self.n] = nil
  self.n = self.n-1
  return value
end

function vector:next(i)
  if i < self.n then
    return i + 1, self[i + 1]
  end
end

function vector:__ipairs()
  return vector.next, self, 0
end

function vector:__tostring()
  local text = {}
  for i=1, self.n do
    if type(self[i]) == "string" then
      text[i] = utils.escape(self[i])
    else
      text[i] = tostring(self[i])
    end
  end
  return "vector.cast({n="..self.n..","..table.concat(text, ",").."})"
end

function vector.sub(t, from, to)
  from = from or 1
  to = to or #t
  return vector.cast(t, nil, function(i)
    return i >= from and i <= to
  end)
end

function vector:__eq(v)
  if not (getmetatable(v) == getmetatable(self) and self.n == v.n) then
    return false
  end
  for i=1, math.max(self.n, v.n) do
    if self[i] ~= v[i] then
      return false
    end
  end
  return true
end

function vector.cast(t, f, g)
  if not t then
    return setmetatable({n=0}, vector)
  end
  local u = setmetatable({}, vector)
  local n = 0
  for i, v in ipairs(t) do
    if not g or g(i, v) then
      n = n + 1
      if f then
        u[n] = f(v, i)
      else
        u[n] = v
      end
      u.n = n
    end
  end
  u.n = n
  return u
end

function vector:unpack()
  return unpack(self, 1, #self)
end

function vector:__len()
  return self.n or #self
end

return vector
