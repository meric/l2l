#import quasiquote
#import quote
#import fn
#import local

\--[[
Usage:
  (cond
    false (+ 1 2)
    true (+ 1 2 3)
    (else_clause some arg))
]]

(fn stat_cond (invariant output value found condition action ...)
  (assert \(condition and action);
    "cond requires positive even number of arguments.")
  (local rest {})
  (local block {})

  \if found then
    \(table.insert block `\\,found = true)
  end

  (table.insert block `\\,value = \,(compile_exp invariant action block))  

  \if ... then
    \(table.insert rest (stat_cond invariant block value found ...))
  end

  return \`\if \,(compile_exp invariant condition output) then
      \,(unpack block)
    else
      \,(unpack rest)
    end)

(fn stat_else (invariant value found default)
  (local block {})
  (table.insert block `\\,value = \,(compile_exp invariant default block))
  `\if not \,found then
    \,(unpack block)
  end)

(fn statize_cond (invariant cdr output)
  (local clauses (vector.cast cdr))
  \
  if #clauses == 1 then
    return compile_stat(invariant, cdr:car(), output)
  end
  (local value (lua_name:unique "_cond_value"))
  (local found (lua_name:unique "_cond_found"))
  (table.insert output `\local \,value)
  \
  if #clauses % 2 == 0 then
    return \(stat_cond invariant output value nil (vector.unpack clauses))
  end
  (table.insert output `\local \,found)
  (local default (clauses:pop))
  (table.insert output (stat_cond invariant output value found
    (vector.unpack clauses)))
  (stat_else invariant value found default)
)

(fn expize_cond (invariant cdr output)
  (local clauses (vector.cast cdr))
  \
  if #clauses == 1 then
    return compile_exp(invariant, cdr:car(), output)
  end
  (local value (lua_name:unique "_cond_value"))
  (local found (lua_name:unique "_cond_found"))
  (table.insert output `\local \,value)
  \
  if #clauses % 2 == 0 then
    \(table.insert output
      (stat_cond invariant output value nil (vector.unpack clauses)))
    return value
  end
  (table.insert output `\local \,found)
  (local default (clauses:pop))
  (table.insert output (stat_cond invariant output value found
    (vector.unpack clauses)))
  (table.insert output (stat_else invariant value found default))
  value
)

{
  lua = {
    cond = {expize=expize_cond, statize=statize_cond}
  }
}