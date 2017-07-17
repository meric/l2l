local utils = require("leftry").utils
local vector = require("l2l.vector")
local lua = require("l2l.lua")
local ipairs = require("l2l.iterator")
local len = require("l2l.len")

local index_base = 1

local list = utils.prototype("list", function(list, ...)
  if select("#", ...) == 0 then
    return vector()
  end
  local count = select("#", ...)
  local self = {}
  for i=1, count do
    local datum = (select(i, ...))
    self[i + index_base - 1] = datum
  end
  self.n = count
  return setmetatable(self, list)
end)

function list:repr()
  local parameters = {}
  for i,v in ipairs(self) do
    if type(v) == "string" then
      v = utils.escape(v)
    end
    parameters[i] = v
  end
  return lua.lua_functioncall.new(lua.lua_name("list"),
    lua.lua_args.new(
      lua.lua_explist(parameters)))
end

function list:__tostring()
  local text = {}
  for i,v in ipairs(self) do
    if type(v) == "string" then
      v = utils.escape(v)
    end
    text[i] = tostring(v)
  end
  return "list("..table.concat(text, ", ")..")"
end

-- we can store nil, so we need our own ipairs
-- also ipairs i is always 1-based
function list:__ipairs()
  local s = self
  local i = -1
  return function()
    i = i + 1
    if i >= s.n then
      return
    end
    return i + 1, s[i + index_base]
  end, self, 0
end

function list:__len()
  if not self then
    return 0
  end
  return self.n
end

function list:car()
  return self[index_base]
end

function list:cdr()
  if self.n < 2 then
    return nil
  end
  local r = {}
  for i=1, self.n - 1 do
    r[i + index_base - 1] = self[i + index_base]
  end
  r.n = self.n - 1
  return setmetatable(r, list)
end

function list:__eq(l)
  if rawequal(self, l) then
    return true
  end
  if getmetatable(self) ~= getmetatable(l) then
    return false
  end
  if self.n ~= l.n then
    return false
  end
  for i=index_base,self.n - 1 + index_base do
    if self[i] ~= l[i] then
      return false
    end
  end
  return true
end

function list:unpack_i(i)
  if i == self.n  - 1 + index_base then
    return self[i]
  end
  return self[i], self:unpack_i(i + 1)
end

function list:unpack()
  if not self then
    return
  end
  return self:unpack_i(index_base)
end

-- WARNING, this uses 1-based
function list.sub(t, from, to)

  -- to = to or len(t)
  -- from = from or 1
  -- local j = index_base
  -- local r = {}
  -- for i=from - 1 + index_base, to - 1 + index_base do
  --   r[j] = t[i]
  --   j = j + 1
  -- end
  -- r.n = j - 1
  -- return setmetatable(r, list)

  to = to or len(t)
  from = from or 1
  return list.cast(t, function(i)
    return i >= from and i <= to
  end)
end

function list.cast(t, f)
  -- Cast an ipairs-enumerable object into a list.
  local count = len(t)
  if not t or count == 0 then
    return nil
  end
  local self = setmetatable({n = count}, list)
  for i, v in ipairs(t) do
    if f then
      self[i - 1 + index_base] = f(v, i)
    else
      self[i - 1 + index_base] = v
    end
  end
  return self
end

function list:cons(car)
  local r = {}
  for i=self.n - 1 + index_base, index_base, -1 do
    r[i+1] = self[i]
  end
  r[index_base] = car
  r.n = self.n + 1
  return setmetatable(r, list)
end

-- function list:prepend(t)
--   local position = data.n + 1
--   local count = len(t)
--   for i, datum in ipairs(t) do
--     data.n = data.n + 1
--     data[data.n] = datum
--     data.n = data.n + 1
--     if i < count then
--       data[data.n] = position + i * 2
--     else
--       data[data.n] = self.position
--     end
--   end
--   retain(position)
--   return setmetatable({position = position}, list)
-- end

return list
