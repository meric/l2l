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
local rawtostring = itertools.rawtostring

local IllegalFunctionCallException =
  exception.Exception("Illegal function call")


local FunctionArgumentException =
  exception.Exception("Argument is not a %s")

local function default_C()
  return {
    vector = function(environment, bytes, values, stats, metadata)
      -- iterate values, advance metadata?
      return list(cons(symbol("LuaVector"), values)), stats
    end
  }
end

local function compile(environment, bytes, values, stats, metadata)
  -- return a lua block and an expression list?
  stats = stats or {}
  local expressions = {}

  if not metadata and bytes then
    metadata = tolist(join(
      filter(id,
        map(function(position) return environment._META[position] end,
          slicecar(bytes, car(environment._META[bytes]).rest, bytes)))))
  end

  for i, value in ipairs(values) do
    local mt = getmetatable(value)
    if type(value) == "number" or type(value) == "string" then
      table.insert(expressions, list(symbol("LuaValue"), rawtostring(bytes), value))
    elseif mt == symbol then
      table.insert(expressions, list(symbol("LuaName"), rawtostring(bytes), value))
    elseif mt == list then
      local first, rest = car(value), cdr(value)
      if getmetatable(first) == symbol and environment._C[tostring(first)] then
        metadata = cdr(metadata)
        values = environment._C[tostring(first)](environment, metadata[1].position, rest, stats, metadata)
        for i, value in ipairs(values or {}) do
          table.insert(expressions, value)
        end
      else
        metadata = cdr(metadata)
        first = compile(environment, metadata[1].position, list(first), stats, metadata)
        if rest ~= nil then
          metadata = cdr(metadata)
          rest = compile(environment, metadata[1].position, rest, stats, metadata)
          table.insert(expressions,
            list(symbol("LuaCall"), rawtostring(bytes), car(first), rest))
        else
          table.insert(expressions,
            list(symbol("LuaCall"), rawtostring(bytes), car(first)))
        end
      end
    elseif value == nil then
      table.insert(expressions, list(symbol("LuaNil"), rawtostring(bytes)))
    end
    metadata = cdr(metadata)
  end
  return tolist(expressions), stats
end

if debug.getinfo(3) == nil then
  local bytes = itertools.tolist("(print [1 2 3 nil])")
  local environment = reader.environ(bytes)
  local values, rest = reader.read(environment, bytes)
  -- print(values, rest)
  local exprs, stats = compile(environment, bytes, values)
  print(exprs)
end

return {
  default_C = default_C
}