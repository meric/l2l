local reader = require("l2l.reader")
local read = reader.read
local symbol = reader.symbol

local compiler = require("l2l.compiler")
local to_stat = compiler.to_stat

local hash = compiler.hash

local lua = require("l2l.lua")

local list = require("l2l.list")
local vector = require("l2l.vector")

local utils = require("leftry").utils

local lua_local_function = lua.lua_local_function
local lua_lambda_function = lua.lua_lambda_function
local lua_funcbody = lua.lua_funcbody
local lua_name = lua.lua_name
local lua_namelist = lua.lua_namelist
local lua_block = lua.lua_block
local lua_local = lua.lua_local

local function stat_lua_function(invariant, output, name, parameters, body)
  return lua_local_function.new(
    lua_name(name:hash()),
    lua_funcbody.new(
      lua_namelist(vector.cast(parameters, function(value)
          return lua_name(value:hash())
        end)),
      lua_block(vector.cast(body, function(value, i)
        return compiler.statize(invariant, value, output, i == #body) end))))
end

local function exp_lua_lambda_function(invariant, output, parameters, body)
  return lua_lambda_function.new(lua_funcbody.new(
    lua_namelist(vector.cast(parameters, function(value)
        return lua_name(value:hash())
      end)),
    lua_block(vector.cast(body, function(value, i)
      return compiler.statize(invariant, value, output, i == #body) end))))
end

local function validate_function(cadr)
  assert(utils.hasmetatable(cadr, symbol) or utils.hasmetatable(cadr, list)
      or cadr == nil,
      "fn definition requires name or parameter list as first argument.")
end

local function compile_fn_exp(invariant, cdr, output)
  local cadr = cdr:car()
  validate_function(cadr)
  local name, parameters, body
  if utils.hasmetatable(cadr, symbol) then
    assert(#cdr >= 3, "function missing parameters or body")
    local stat = stat_lua_function(invariant, output,
      cadr, cdr:cdr():car(), cdr:cdr():cdr())
    table.insert(output, stat)
    return cadr
  else
    assert(#cdr >= 2, "function missing parameters or body")
    return exp_lua_lambda_function(invariant, output, cadr, cdr:cdr())
  end
end

local function compile_fn_stat(invariant, cdr, output)
  local cadr = cdr:car()
  validate_function(cadr)
  local name, parameters, body
  if utils.hasmetatable(cadr, symbol) then
    assert(#cdr >= 3, "function missing parameters or body")
    return stat_lua_function(invariant, output,
      cadr, cdr:cdr():car(), cdr:cdr():cdr())
  else
    assert(#cdr >= 2, "function missing parameters or body")
    return to_stat(exp_lua_lambda_function(invariant, output, cadr, cdr:cdr()))
  end
end

return function(invariant)
  compiler.register_L(invariant, "fn", compile_fn_exp, compile_fn_stat)
end
