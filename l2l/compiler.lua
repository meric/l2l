local utils = require("leftry").utils
local list = require("l2l.list")
local lua = require("l2l.lua")
local reader = require("l2l.reader")
local vector = require("l2l.vector")
local symbol = reader.symbol

local invariantize = require("leftry.elements.utils").invariantize

local lua_functioncall = lua.lua_functioncall
local lua_function = lua.lua_function
local lua_explist = lua.lua_explist
local lua_number = lua.lua_number
local lua_name = lua.lua_name
local lua_ast = lua.lua_ast
local lua_local = lua.lua_local
local lua_namelist = lua.lua_namelist
local lua_retstat = lua.lua_retstat


local function validate_functioncall(car)
  assert(
    getmetatable(car) ~= lua_number and (
    utils.hasmetatable(car, list) or
    utils.hasmetatable(car, symbol) or
    lua_ast[getmetatable(car)]),
    "only expressions and symbols can be called.")
end

local function expize(invariant, data, output)
  if utils.hasmetatable(data, list) then
    local car = data:car()
    if utils.hasmetatable(car, symbol) and invariant.L[car[1]] then
      return invariant.L[car[1]].expize(invariant, data:cdr(), output)
    end
    local cdr = vector.cast(data:cdr(), function(value)
      return expize(invariant, value, output)
    end)
    validate_functioncall(car)
    return lua_functioncall.new(
      expize(invariant, car),
      lua.lua_args.new(lua_explist(cdr)))
  elseif utils.hasmetatable(data, symbol) then
    return lua_name(data:hash())
  elseif lua_ast[getmetatable(data)] then
    return data
  elseif data == nil then
    return "nil"
  elseif data == reader.lua_none then
    return
  end
  error("cannot not expize.."..tostring(data))
end

local function to_stat(exp, name)
  -- convert exp to stat
  local name = name or lua_name:unique("_var")
  assert(exp)
  return lua_local.new(lua_namelist({name}), lua_explist({exp}))
end

local function statize(invariant, data, output, last)
  if last then
    return lua_retstat.new(lua_explist({expize(invariant, data, output)}))
  end
  if utils.hasmetatable(data, list) then
    local car = data:car()
    if utils.hasmetatable(car, symbol) and invariant.L[car[1]] then
      return invariant.L[car[1]].statize(invariant, data:cdr(), output)
    end
    local cdr = vector.cast(data:cdr(), function(value)
      return expize(invariant, value, output)
    end)
    validate_functioncall(car)
    return lua_functioncall.new(
      expize(invariant, car),
      lua.lua_args.new(lua_explist(cdr)))
  elseif lua_ast[getmetatable(data)] then
    if not utils.hasmetatable(data, lua_functioncall) then
      return to_stat(data)
    end
    return data
  elseif data == reader.lua_none then
    return
  end
  error("cannot not statize.."..tostring(data))
end

local function compile_stat(invariant, data, output)
  return statize(invariant, reader.transform(invariant, data), output)
end

local function compile_exp(invariant, data, output)
  return expize(invariant, reader.transform(invariant, data), output)
end

local function register_L(invariant, name, exp, stat)
  local L = invariant.L
  L[name] = {expize=exp, statize=stat}
end

local function compile_lua_block(invariant, cdr, output)
  return cdr:car()
end

local function compile_lua_block_into_exp(invariant, cdr, output)
  local cadr = cdr:car()
  local retstat = cadr[#cadr]

  assert(utils.hasmetatable(retstat, lua_retstat),
    "block must end with return statement when used as an exp.")

  for i=1, #cadr - 1 do
    table.insert(output, cadr[i])
  end

  return retstat.explist
end

local exports

local function header(source)
  local head = {
    [[local lua = require("l2l.lua")]],
    [[local reader = require("l2l.reader")]],
    [[local compiler = require("l2l.compiler")]],
  }
  for name, _ in pairs(lua) do
    if string.match(source, name) then
      table.insert(head, "local "..name.." = lua."..name)
    end
  end
  for name, _ in pairs(reader) do
    if string.match(source, name) then
      table.insert(head, "local "..name.." = reader."..name)
    end
  end
  for name, _ in pairs(exports) do
    if string.match(source, name) then
      table.insert(head, "local "..name.." = compiler."..name)
    end
  end
  return table.concat(head, "\n")
end

local function compile(source, parent)
  local invariant

  if not parent then
    invariant = reader.environ(source, 1)
  else
    invariant = reader.inherit(parent, source)
  end

  local output = {}

  for rest, values in reader.read, invariant do
    for i, value in ipairs(values) do
      local stat = compile_stat(invariant, value, output)
      if stat then
        table.insert(output, stat)
      end
    end
  end

  for i, value in ipairs(output) do
    output[i] = tostring(value)
  end

  output = table.concat(output, "\n")
  output = header(output).."\n"..output
  return output
end

exports = {
  compile=compile,
  compile_lua_block = compile_lua_block,
  compile_lua_block_into_exp = compile_lua_block_into_exp,
  hash = reader.hash,
  statize = statize,
  expize = expize,
  hash = hash,
  compile_stat = compile_stat,
  compile_exp = compile_exp,
  to_stat = to_stat,
  expand = expand,
  register_L = register_L
}

return exports