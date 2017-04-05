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

(fn expize_seti(invariant cdr output)
  (local args (vector.cast cdr))
  (assert (>= (len args) 3))
  (local value (args:pop))
  (local left (indexer invariant output args))
  (table.insert output `\\,left = \,(expize invariant value output))
  
  --(print invariant.debug)
  --(print left)
  --(local b `\\,left = \,(expize invariant value output))
  --(print b)

  left)
  

(fn statize_seti(invariant cdr output)
  (print "TO DO")
  1
  )

{
  lua = {
    ["seti"] = {expize=expize_seti, statize=statize_seti}
  }
}
