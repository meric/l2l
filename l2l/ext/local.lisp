#import fn
#import quote
#import quasiquote

\
local compiler = require("l2l.compiler")
\

(fn compile_local_stat (invariant cdr output)
  \
  local args = vector.cast(cdr)
  local val = args[#args]
  local names = {}
  for i=1, #args-1 do
    names[i] = lua_name(args[i])
  end
  names = lua_namelist(names)
  `\local ,names = \,\compiler.compile_exp(invariant, val, output))

(fn compile_local_exp (invariant cdr output)
  (error "cannot use local as expression."))

\return {
  lua = {
    [symbol("local")] = {
        expize=compile_local_exp,
        statize=compile_local_stat
    }
  }
}
