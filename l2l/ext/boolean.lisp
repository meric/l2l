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
      ref (lua_name:unique "_and_value"))
      `\
        local \,ref = \,\(expize(invariant, car, output))
        if \,ref then
          \,(cond (:cdr cdr)
              (circuit_and invariant (:cdr cdr) output truth)
              `\\,truth = \,ref)
        else
          \,truth = false
        end)))

(fn expize_and (invariant cdr output)
  (let (ref (lua_name:unique "_and_bool"))
    (table.insert output `\local \,ref = true)
    (table.insert output (circuit_and invariant cdr output ref))
    ref))

(fn statize_and (invariant cdr output)
  (to_stat (expize_and (invariant cdr output))))

(fn circuit_or (invariant cdr output truth)
  (cond cdr
    (let (
      car (:car cdr)
      ref (lua_name:unique "_or_value"))
      `\
        local \,ref = \,\(expize(invariant, car, output))
        if \,ref then
          \,truth = \,ref
        else
          \,(cond (:cdr cdr)
              (circuit_and invariant (:cdr cdr) output truth)
              `\\,truth = \,ref)
        end)))

(fn expize_or (invariant cdr output)
  (let (ref (lua_name:unique "_or_bool"))
    (table.insert output `\local \,ref = false)
    (table.insert output (circuit_or invariant cdr output ref))
    ref))

(fn statize_or (invariant cdr output)
  (to_stat (expize_or (invariant cdr output))))

{
  lua = {
    ["and"] = {expize=expize_and, statize=statize_and},
    ["or"] = {expize=expize_or, statize=statize_or}
  }
}