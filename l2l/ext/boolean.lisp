@import quasiquote
@import quote
@import fn
@import local
@import do
@import let
@import cond

(fn circuit_and (invariant cdr output truth)
  (cond cdr
    (let (
      car (:car cdr)
      ref (lua_name:unique "_and_value")
      inner_output {}
      inner
        (cond (:cdr cdr)
          (circuit_and invariant (:cdr cdr) inner_output truth)
          `,truth = ,ref)
      )
      `\
        local \,ref = \,\(expize(invariant, car, output))
        if \,ref then
          \,truth = \,ref
          \,(lua.lua_block inner_output)
          \,inner
        else
          \,truth = false
        end)))

(fn expize_and (invariant cdr output)
  (let (ref (lua_name:unique "_and_bool"))
    (table.insert output `\local \,ref = true)
    (table.insert output (circuit_and invariant cdr output ref))
    ref))

(fn statize_and (invariant cdr output)
  (to_stat (expize_and invariant cdr output)))

(fn circuit_or (invariant cdr output truth)
  (cond cdr
    (let (
      car (:car cdr)
      ref (lua_name:unique "_or_value")
      exp_output {}
      cond_exp (expize invariant car exp_output)
      inner_output {}
      inner
        (cond (:cdr cdr)
          (circuit_or invariant (:cdr cdr) inner_output truth))
      )
      `\
        if not \,truth then
          \,(lua.lua_block exp_output)
          local \,ref = \,cond_exp
          if \,ref then
            \,truth = \,ref
          end
        end
        \,(lua.lua_block inner_output)
        \,inner)))

(fn expize_or (invariant cdr output)
  (let (ref (lua_name:unique "_or_bool"))
    (table.insert output `\local \,ref = false)
    (table.insert output (circuit_or invariant cdr output ref))
    ref))

(fn statize_or (invariant cdr output)
  (to_stat (expize_or invariant cdr output)))

{
  lua = {
    ["and"] = {expize=expize_and, statize=statize_and},
    ["or"] = {expize=expize_or, statize=statize_or}
  }
}
