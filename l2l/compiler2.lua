local module_path = "l2l."
-- (...):gsub('compiler2$', '')

local reader = require(module_path .. "reader2")
local itertools = require(module_path .. "itertools")
local exception = require(module_path .. "exception2")

local lua = require(module_path .. "lua")

local raise = exception.raise

local symbol = reader.symbol

local show = itertools.show
local tolist = itertools.tolist
local list = itertools.list
local car = itertools.car
local cdr = itertools.cdr
local cadr = itertools.cadr
local cons = itertools.cons
local mapcar = itertools.mapcar
local tolist = itertools.tolist
local filter = itertools.filter
local map = itertools.map
local each = itertools.each
local take = itertools.take
local drop = itertools.drop
local id = itertools.id
local slicecar = itertools.slicecar
local join = itertools.join
local vector = itertools.vector
local rawtostring = itertools.rawtostring
local tonext = itertools.tonext
local search = itertools.search
local index = itertools.index

local IllegalFunctionCallException =
  exception.Exception("Illegal function call")


local FunctionArgumentException =
  exception.Exception("Argument is not a %s")

local compile
local function default_C()
  return {
    vector = function(environment, bytes, metadata)
      return list(list(cons(symbol("LuaVector"),
                    list.prepend(
                      environment._META[bytes][1].index,
                      join(map(function(meta)
                                 return compile(environment, meta.bytes)
                               end, metadata))))))
    end,
    LuaName = function(environment, bytes, metadata)
      return list(list(cons(symbol("LuaName"),
                    list.prepend(
                      environment._META[bytes][1].index,
                      join(map(function(meta)
                                 return meta.values
                               end, metadata))))))
    end,
    LuaExprList = function(environment, bytes, metadata)
      print(metadata)
      return list(list(cons(symbol("LuaExprList"),
                    list.prepend(
                      environment._META[bytes][1].index,
                      join(map(function(meta)
                                 return meta.values
                               end, metadata))))))
    end
  }
end

function compile(environment, bytes, metadata)
  if not environment._META[1] and bytes then
    -- We do the following in the compilation stage because we don't want to
    -- prematurely evaluate `bytes`.
    -- Perhaps save the last element in `environment` and do not go further
    -- so as to not evaluate stuff when not needed to.
    local origin = environment._META.origin
    for i, rest in mapcar(id, origin) do
      if environment._META[rest] then
        for j, meta in tonext(environment._META[rest]) do
          meta.index = i
        end
      end
      environment._META[i] = rest
    end
  end

  if not metadata then
    metadata = tolist(join(
      filter(id,
        map(index(environment._META),
          slicecar(bytes, environment._META[bytes][1].rest, bytes)))))
  end

  if not metadata then
    return
  end

  local metacar, metacdr = car(metadata)

  local expressions = {}

  for _, value in ipairs(metacar.values) do
    local mt = getmetatable(value)
    local i = metacar.index
    local literal

    if type(value) == "string" then
      literal = symbol("LuaString")
    elseif type(value) == "number" then
      literal = symbol("LuaNumber")
    elseif value == symbol("nil") then
      literal = symbol("LuaNil")
    elseif mt == symbol then
      literal = symbol("LuaName")
    end
    if literal then
      table.insert(expressions, tolist({literal, i, value}))
    elseif mt == list then
      local first, rest = car(value)
      print(value,  metacar.children)
      local form = environment._C[tostring(first)]
      if getmetatable(first) == symbol and form then
        for i, value in tonext(
          form(environment,
            car(metacdr).bytes,
              tolist(take(metacar.children, cdr(metacdr))))) do
          table.insert(expressions, value)
        end
      else
        first = compile(environment, car(metacdr).bytes, metacdr)
        rest = {}
        local count = 0
        local i = 0
        metacdr = cdr(metacdr)
        while metacdr do
          for i, value in tonext(compile(environment, car(metacdr).bytes), metacdr) do
            table.insert(rest, value)
            count = count + 1
          end
          for i=1, car(metacdr).children + 1 do
            metacdr = cdr(metacdr)
            if not metacdr then
              break
            end
          end
          if i == metacar.children - 1 then
            break
          end
        end
        table.insert(expressions,
          tolist({symbol("LuaCall"), i, car(first), unpack(rest, 1, count)}))
      end
    end
  end

  return tolist(expressions)
end

if debug.getinfo(3) == nil then
  local environment, bytes = reader.environ([[(print (show 1) [1 2] \x; 2)]])
  local values, rest, meta = reader.read(environment, bytes)
  if values then
    print(values)
    print(compile(environment, bytes))
  end
  -- local values, rest, = reader.read(environment, bytes)
  -- local exprs, stats = compile(environment, values, meta)
  
  -- print(exprs)
end

return {
  default_C = default_C
}