@import fn
@import quasiquote
@import local

\--[[
Usage:
  (set x 1)
  (print (set y 2))
]]

(fn expize_set(invariant cdr output)
  (local args (vector.cast cdr))
  (local value (args:pop))
  \
  args = lua_namelist(args)

  (table.insert output `\\,args = \,(compile_exp invariant value output))
  args)

(fn statize_set(invariant cdr output)
  (local args (vector.cast cdr))
  (local value (args:pop))
  `\\,(lua_namelist args) = \,(compile_exp invariant value output))

{
  lua = {
    ["set"] = {expize=expize_set, statize=statize_set}
  }
}
