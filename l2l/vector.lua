local utils = require("leftry").utils

local vector = utils.prototype("vector", function(vector, ...)
  return setmetatable({n=select("#", ...), ...}, vector)
end)

function vector:insert(value)
  self.n = self.n + 1
  self[self.n] = value
  return self
end

function vector:append(t, f, g)
  local n = self.n
  for i, v in ipairs(t) do
    if not g or g(i, v) then
      n = n + 1
      local j = n
      if f then
        self[j] = f(v, i)
      else
        self[j] = v
      end
      self.n = n
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
