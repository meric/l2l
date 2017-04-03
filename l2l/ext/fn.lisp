@import quasiquote

\
--[[
Usage:
  (fn my_function_name (arg1 arg2)
    (+ arg1 arg2))

  (print (fn (arg1 arg2) (+ arg1 arg2)))
]]

local utils = require("leftry").utils

local function stat_lua_function(invariant, name, parameters, body)
  assert(utils.hasmetatable(parameters, list) or parameters == nil,
    "fn.lisp:stat_lua_function")
  return \`\function \,name(\,\lua_namelist(parameters))
      \,\unpack(utils.inserts(
        function(value, i, stats)
          return compiler.statize(invariant, value, stats, i == len(body))
        end, body))
    end
end

local function exp_lua_lambda_function(invariant, parameters, body)
  return \`\function(\,\lua_namelist(parameters))
      \,\unpack(utils.inserts(
        function(value, i, stats)
          return compiler.statize(invariant, value, stats, i == len(body))
        end, body))
    end
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
    assert(len(cdr) >= 3, "function missing parameters or body")
    local stat = stat_lua_function(invariant,
      cadr, cdr:cdr():car(), cdr:cdr():cdr())
    table.insert(output, stat)
    return lua_name(cadr)
  else
    assert(len(cdr) >= 2, "function missing parameters or body")
    return exp_lua_lambda_function(invariant, cadr, cdr:cdr())
  end
end

local function statize_fn(invariant, cdr, output)
  local cadr = cdr:car()
  validate_function(cadr)
  if utils.hasmetatable(cadr, symbol) then
    assert(len(cdr) >= 3, "function missing parameters or body")
    return stat_lua_function(invariant,
      cadr, cdr:cdr():car(), cdr:cdr():cdr())
  else
    assert(len(cdr) >= 2, "function missing parameters or body")
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
