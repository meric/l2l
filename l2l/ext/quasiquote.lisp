\
local utils = require("leftry.utils")

local function quasiquote_eval(invariant, car, output)
  if utils.hasmetatable(car, list) then
    if car:car() == symbol("quasiquote-eval") then
      local cdr = car:cdr()
      assert(list.__len(cdr) == 1,
        "quasiquote_eval only accepts one parameter.")
      return compiler.compile_exp(invariant, cdr:car(), output)
    end
    return list.cast(car, function(value)
      return quasiquote_eval(invariant, value, output)
    end)
  end
  return car
end

local function compile_quasiquote_eval(invariant, cdr, output)
  local cadr = cdr:car()
  local exp = compiler.compile_exp(invariant,
    quasiquote_eval(invariant, cadr, output), output)
  function exp:repr()
    return exp
  end
  return exp
end

local function escape_lua(invariant, data)
  if lua_ast[getmetatable(data)] then
    return data:repr()
  end
  if utils.hasmetatable(data, list) then
    data = list.cast(data, function(value)
      return escape_lua(invariant, value)
    end)
  end
  return data
end

local function compile_quasiquote(invariant, cdr, output)
  assert(list.__len(cdr) == 1, "quasiquote only accepts one parameter.")
  local cadr = cdr:car()
  return quasiquote_eval(invariant, escape_lua(invariant, cadr), output)
end

local function read_quasiquote(invariant, position)
  local rest, values = read(invariant, position + 1)
  if rest then
    values[1] = list(symbol("quasiquote"), values[1])
    return rest, values
  end
end

local function read_quasiquote_eval(invariant, position)
  local rest, values = read(invariant, position + 1)
  if rest then
    values[1] = list(symbol("quasiquote-eval"), values[1])
    return rest, values
  end
end

return {
  read = {
    [string.byte(",")] = {read_quasiquote_eval},
    [string.byte("`")] = {read_quasiquote}
  },
  lua = {
    ["quasiquote"] = {expize=compile_quasiquote, statize=compile_quasiquote},
    ["quasiquote-eval"] = {expize=compile_quasiquote_eval,
      statize=compile_quasiquote_eval}
  }
}
