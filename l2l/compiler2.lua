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

local IllegalFunctionCallException =
  exception.Exception("Illegal function call")


local FunctionArgumentException =
  exception.Exception("Argument is not a %s")

local made = false
local function compile(environment, bytes, forms, positions)
  local rest = environment._META[bytes].rest
  local expressions = {}
  if not made then
    made = true
    positions = tolist(
      map(function(meta) return meta.position end,
        filter(id,
          map(function(position) return environment._META[position] end,
            slicecar(bytes, rest, bytes)))))
  end

  for i, data in ipairs(forms) do
    if type(data) == "number" or type(data) == "string" then
      table.insert(expressions, data)
    elseif getmetatable(data) == symbol then
      table.insert(expressions, list(symbol("LuaName"), data))
    elseif getmetatable(data) == list then
      local first, rest = car(data), cdr(data)
      positions = cdr(positions)
      first = cadr(compile(environment, positions[1], list(first), positions))
      positions = cdr(positions)
      rest = compile(environment, positions[1], rest, positions)
      table.insert(expressions, list(symbol("LuaCall"), first, rest))
    elseif data == nil then
      raise(IllegalFunctionCallException(environment, positions[1]))
    end
    positions = cdr(positions)
  end
  return list(symbol("LuaExpList"), unpack(expressions))
end

local bytes = itertools.tolist("(print (print 1 2 () 3 5))")
local environment = reader.environ(bytes)
local values, rest = reader.read(environment, bytes)

values, rest = compile(environment, bytes, values)

print(values)
