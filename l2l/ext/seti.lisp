@import fn
@import quasiquote
@import local

\--[[
Usage:
  (seti x 1 1)
  (print (seti y 1 2))
]]

(local utils (require "leftry.utils"))

(fn indexer(invariant output data)
  \
  local compiled = vector.cast(data, function(value)
    return expize(invariant, value, output)
  end)
  local exp = compiled[1]
  for i, v in ipairs(compiled) do
    if i > 1 then
      exp = lua.lua_index.new(lua.lua_paren_exp.new(exp), compiled[i])
    end
  end
  return exp)

(fn compile_seti(invariant cdr output)
  (local args (vector.cast cdr))
  \if len(args) < 2 then
    error("seti requires at least 2 arguments: (seti left-expression [index1 ...] value)")
  end
  (local value (args:pop))
  (local left (indexer invariant output args))
  \return left, value)

(fn expize_seti(invariant cdr output)
  (local left value (compile_seti invariant cdr output))
  (table.insert output `\\,left = \,(expize invariant value output))
  left)

(fn statize_seti(invariant cdr output)
  (local left value (compile_seti invariant cdr output))
  `\\,left = \,(expize invariant value output)
  )

{
  lua = {
    ["seti"] = {expize=expize_seti, statize=statize_seti}
  }
}
