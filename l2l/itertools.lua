local function resolve(str, t)
  local obj = t or _G
  for name in str:gmatch("[^.]+") do
    if obj then
      obj = obj[name]
    end
  end
  return obj
end

local function pack(...)
  return {...}, select("#", ...)
end

local function dict(...)
  local count = select('#', ...)
  if count % 2 ~= 0 then
    error("dict takes an even number of arguments. Received "..tostring(count))
  end
  local t = {}
  for i=1, count, 2 do
    t[select(i, ...)] = select(i+1, ...)
  end
  return t
end

local function vector(...)
  return {...}
end

local function bind(f, ...)
  assert(f, "missing f argument")
  local count = select("#", ...)
  local parameters = {...}
  return function(...)
    local count2 = select("#", ...)
    local all = {}
    for i=1, count do
      all[i] = parameters[i]
    end
    for i=1, count2 do
      all[count + i] = select(i, ...)
    end
    return f(table.unpack(all, 1, count + count2))
  end
end

local function show(obj)
  if type(obj) == "table" and getmetatable(obj) == nil then
    local t = {}
    for name, value in pairs(obj) do
      table.insert(t, show(name))
      table.insert(t, show(value))
    end
    return "{" .. table.concat(t, " ") .. "}"
  elseif type(obj) ~= 'string' then
    obj = tostring(obj)
  else
    obj = '"' .. obj:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
  end
  return obj
end

local function fold(f, initial, objs)
  if objs == nil then
    return
  end
  for _, v in ipairs(objs or {}) do
    initial = f(initial, v)
  end 
  return initial
end

local function foreach(f, objs)
  local orig = {}
  for i, v in pairs(objs or {}) do
    orig[i] = f(v, i)
  end 
  return orig
end

local list, pair

list = setmetatable({
  unpack = function(self)
    if self then
      return self[1], list.unpack(self[2])
    end
  end,
  push = function(self, obj, ...)
    if not ... then
      return pair({obj, self})
    else
      return list.push(pair({obj, self}), ...)
    end
  end,
  contains = function(self, obj)
    if not self then
      return false
    end
    for _, v in ipairs(self) do
      if v == obj then
        return true
      end
    end
    return false
  end,
  concat = function(self, separator)
    separator = separator or ""
    if self == nil then
      return ""
    end
    local str = tostring(self[1])
    if self[2] then
      str = str .. separator .. self[2]:concat(separator)
    end
    return str
  end,
  __eq = function(self, other)
    while self and other do
      if self == nil and other == nil then
        return true
      end
      if self == nil and other ~= nil or
         self ~= nil and other  == nil then
        return false
      end
      if self[1] ~= other[1] then
        return false
      end
      self = self[2]
      other = other[2]
    end
    return self == other
  end,
  __ipairs = function(self)
    local orig = self
    local i = 0
    return function() 
      if self then
        if self[2] ~= nil and getmetatable(self[2]) ~= list then
          error("cannot iterate improper list "..show(orig))
        end
        local obj = self[1]
        self = self[2]
        i = i + 1
        return i, obj 
      end 
    end
  end,
  __tostring = function(self)
    local str = "("
    repeat
      if getmetatable(self) ~= list then
        return str..")"
      end
      str = str .. show(self[1])
      self = self[2]
      if getmetatable(self) == list then
        str = str .. " "
      elseif self ~= nil then
        str = str .. " . " .. tostring(self)
      end
    until not self
    return str .. ")"
  end
}, {__call = function(_, ...)
    local orig = setmetatable({}, list)
    local last = orig
    for i=1, select('#', ...) do
      last[2] = setmetatable({select(i, ...), nil}, list)
      last = last[2]
    end
    return orig[2]
  end})

list.__index = list

local function id(...)
  return ...
end

local function tolist(t, obj)
  -- tolist({1, 2}, 3) == '(1 2 . 3)
  local orig = setmetatable({}, list)
  local last = orig
  if type(t) == "table" then
    local maxn = table.maxn or function(tb) return #tb end
    for i=1, maxn(t) do
      last[2] = setmetatable({t[i], nil}, list)
      last = last[2]
    end
    last[2] = obj
  elseif type(t) == "string" then
    for i=1, #t do
      last[2] = setmetatable({string.char(t:byte(i)), nil}, list)
      last = last[2]
    end
    last[2] = obj
  end
  return orig[2]
end

local function zip(...)
  local parameters = {}
  local smallest
  for i=1, select("#", ...) do
    local collection = select(i, ...)
    local count = 0
    for j, obj in ipairs(collection) do
      if smallest and j > smallest then
        break
      end
      if i == 1 then
        parameters[j] = {}
      end
      parameters[j][i] = obj
      count = count + 1
    end
    smallest = math.min(smallest or count, count)
  end
  local trimmed = {}
  for i = 1, smallest do
    trimmed[i] = parameters[i]
  end
  return tolist(trimmed)
end

pair = function(t)
  return setmetatable(t, list)
end

local function cons(a, b)
  return pair({a, b})
end

local function map1(f, objs)
  local origin = cons(nil)
  local last = origin
  for i, value in ipairs(objs or {}) do
    last[2] = cons(f(value))
    last = last[2]
  end
  return origin[2]
end

local function map(f, ...)
  local count = select("#", ...)
  if count == 1 then
    return map1(f, ...)
  end
  local iterators = {}
  for i=1, count do
    iterators[i] = ipairs(select(i, ...) or {})
  end

  local origin = pair({nil})
  local last = origin
  local index = 0
  while true do
    local parameters = {}
    local do_break = false
    for i=1, count do
      local _index, value = iterators[i](select(i, ...) or {}, index)
      if not _index then
        do_break = true
      end
      parameters[i] = value
    end
    index = index + 1
    if do_break then
      return origin[2]
    end
    last[2] = cons(f(unpack(parameters)))
    last=last[2]
  end
end

local function each(f, objs)
  if objs == nil then
    return nil
  end
  local orig = pair({nil})
  local last = orig
  for i, v in ipairs(objs or {}) do
    last[2] = pair({f(v, i), nil})
    last=last[2]
  end 
  return orig[2]
end

local function contains(objs, target)
  for _, v in pairs(objs or {}) do
    if v == target then
      return target
    end
  end
  return false
end

local function span(predicate, objs)
  local left, right = list(nil), list(nil)
  local left_last, right_last = left, right
  for i, value in ipairs(objs or {}) do
    if predicate and predicate(value) then
      left_last[2] = cons(value)
      left_last = left_last[2]
    else
      predicate = nil
      right_last[2] = cons(value)
      right_last = right_last[2]
    end
  end
  return left[2], right[2]
end

local function scan(f, initial, objs)
  local origin = cons(nil)
  local last = origin
  for i, value in ipairs(objs or {}) do
    initial = f(initial, value)
    last[2] = cons(initial)
    last = last[2]
  end
  return origin[2]
end

local function last(objs)
  local obj
  for i, value in ipairs(objs or {}) do
    obj = value
  end
  return obj
end

local function flip(f)
  return function(b, a, ...)
    return f(a, b, ...)
  end
end

local function filter(f, objs)
  f = f or id
  local origin = cons(nil)
  local last = origin
  for i, obj in ipairs(objs) do
    if f(obj) then
      last[2] = cons(obj)
      last = last[2]
    end
  end
  return origin[2]
end

--- Returns array inclusive of start and finish indices.
-- 1 is first position. 0 is last position. -1 is second last position.
-- @objs iterable to slice.
-- @start first index.
-- @finish second index
local function slice(objs, start, finish)
  if finish <= 0 then
    finish = #objs + finish
  end

  local orig = {}
  for i, v in ipairs(objs) do
    if i >= start and i <= finish then
      table.insert(orig, v)
    end
  end
  return orig
end

local function car(t)
  assert(t)
  return t[1]
end

local function cdr(t)
  assert(t)
  return t[2]
end

local function take(n, objs)
  local orig = cons(nil)
  local last = orig
  for i, v in ipairs(objs or {}) do
    last[2] = cons(v)
    last = last[2]
    if i == n then
      break
    end
  end
  return orig[2]
end

local function drop(n, objs)
  if n <= 0 then
    return objs
  end
  return drop(n-1, cdr(objs))
end


return {
  vector=vector,
  dict=dict,
  pair=pair,
  cons=cons,
  list=list,
  zip=zip,
  map=map,
  fold=fold,
  show=show,
  foreach=foreach,
  pack=pack,
  resolve=resolve,
  bind=bind,
  contains=contains,
  slice=slice,
  each=each,
  tolist=tolist,
  id=id,
  scan=scan,
  span=span,
  last=last,
  flip=flip,
  car=car,
  cdr=cdr,
  take=take,
  drop=drop,
  filter=filter
}
