
--[[

-- itertools.filter and itertools.map are custom special forms.

for i, v in \(filter (-> x 5 < x)
               (map (-> x 2 * x)
                 (iter \ipairs({1, 2, 3, 4, 5})))) do
end

local next, invariant, state = ipairs({1, 2, 3, 4, 5})
local function _next(invariant, state)
  local value
  state, value = next(invariant, state)
  if not state then
    return
  end
  value = value * 2
  if not (value > 5) then
    return _next(invariant, state)
  end
  return state, value
end

for i, v in _next, invariant, state  do
  print(i, v)
end
]]--

local next, invariant, state = ipairs({1, 2, 3, 4, 5})
local function _next(invariant, state)
  local value
  state, value = next(invariant, state)
  if not state then
    return
  end
  value = value * 2
  if not (value > 5) then
    return _next(invariant, state)
  end
  return state, value
end

for i, v in _next, invariant, state  do
  print(i, v)
end
