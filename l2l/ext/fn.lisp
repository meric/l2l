\
--[[
Usage:
  (fn my_function_name (arg1 arg2)
    (+ arg1 arg2))

  (print (fn (arg1 arg2) (+ arg1 arg2)))
]]

local utils = require("leftry").utils

local function stat_lua_function(invariant, name, parameters, body)
  assert(utils.hasmetatable(parameters, list) or parameters == nil, "fn.lisp:stat_lua_function")
  local stats = {}
  for i, value in ipairs(body) do
    table.insert(stats, compiler.statize(invariant, value, stats, i == #body))
  end
  local constructor = lua_local_function

  if name.name:match(":") then
    constructor = lua_function
  end

  local local_function = constructor.new(
    lua_name(name:mangle()),
    lua_funcbody.new(
      lua_namelist(vector.cast(parameters, function(value, i)
          assert(value, "missing value: ".. i..", " .. tostring(parameters))
          return lua_name(value:mangle())
        end)),
      lua_block(stats)))
  local_function.body.block = lua_block(stats)
  return local_function
end

local function exp_lua_lambda_function(invariant, parameters, body)
  local stats = {}
  for i, value in ipairs(body) do
    table.insert(stats, compiler.statize(invariant, value, stats, i == #body))
  end
  return lua_lambda_function.new(lua_funcbody.new(
    lua_namelist(vector.cast(parameters, function(value)
        return lua_name(value:mangle())
      end)),
    lua_block(stats)))
end

local function validate_function(cadr)
  assert(utils.hasmetatable(cadr, symbol) or utils.hasmetatable(cadr, list)
      or cadr == nil,
      "fn definition requires name or parameter list as first argument.")
end

local function expize_fn(invariant, cdr, output)
  local cadr = cdr:car()
  validate_function(cadr)
  if utils.hasmetatable(cadr, symbol) then
    assert(#cdr >= 3, "function missing parameters or body")
    local stat = stat_lua_function(invariant,
      cadr, cdr:cdr():car(), cdr:cdr():cdr())
    table.insert(output, stat)
    return lua_name(cadr)
  else
    assert(#cdr >= 2, "function missing parameters or body")
    return exp_lua_lambda_function(invariant, cadr, cdr:cdr())
  end
end

local function statize_fn(invariant, cdr, output)
  local cadr = cdr:car()
  validate_function(cadr)
  if utils.hasmetatable(cadr, symbol) then
    assert(#cdr >= 3, "function missing parameters or body")
    return stat_lua_function(invariant,
      cadr, cdr:cdr():car(), cdr:cdr():cdr())
  else
    assert(#cdr >= 2, "function missing parameters or body")
    return to_stat(exp_lua_lambda_function(invariant, cadr, cdr:cdr()))
  end
end


-- if in_lua == true, then 
--  \(fn(\'some_name, \'(a), print(a)))("hello")
-- would work.

{
  lua = {
    fn = {expize=expize_fn, statize=statize_fn}
  }
}
