\
local utils = require("leftry").utils

local function stat_lua_function(invariant, output, name, parameters, body)
  local stats = {}
  local local_function = lua_local_function.new(
    lua_name(name:mangle()),
    lua_funcbody.new(
      lua_namelist(vector.cast(parameters, function(value)
          return lua_name(value:mangle())
        end)),
      lua_block(vector.cast(body, function(value, i)
        return compiler.statize(invariant, value, stats, i == #body) end))))
  for i, stat in ipairs(local_function.body.block) do
    table.insert(stats, stat)
  end
  local_function.body.block = lua_block(stats)
  return local_function
end

local function exp_lua_lambda_function(invariant, output, parameters, body)
  return lua_lambda_function.new(lua_funcbody.new(
    lua_namelist(vector.cast(parameters, function(value)
        return lua_name(value:mangle())
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
  if utils.hasmetatable(cadr, symbol) then
    assert(#cdr >= 3, "function missing parameters or body")
    return stat_lua_function(invariant, output,
      cadr, cdr:cdr():car(), cdr:cdr():cdr())
  else
    assert(#cdr >= 2, "function missing parameters or body")
    return to_stat(exp_lua_lambda_function(invariant, output, cadr, cdr:cdr()))
  end
end

return {
  lua = {
    fn = {expize=compile_fn_exp, statize=compile_fn_stat}
  }
}
