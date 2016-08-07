#import fn
#import quote
#import quasiquote

\
local compiler = require("l2l.compiler")
local utils = require("leftry").utils
\

(fn stat_local (invariant cdr output)
  \
  local val
  local len = #cdr
  local names = vector.cast(cdr, nil, function(i, v)
    if i == len then
      val = v
    end
    return i <= len-1
  end)
  names = lua_namelist(names)
  return names, \`\local ,names = \,\compiler.compile_exp(invariant, val, output))

(fn compile_local_stat (invariant cdr output)
  (select 2 (stat_local invariant cdr output)))

(fn compile_local_exp (invariant cdr output)
  \
  local names, stat = stat_local(invariant, cdr, output)
  table.insert(output, stat)
  return names)

\return {
  lua = {
    [symbol("local")] = {
        expize=compile_local_exp,
        statize=compile_local_stat
    }
  }
}
