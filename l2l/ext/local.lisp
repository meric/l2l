#import fn
#import quote
#import quasiquote

\
--[[
Usage:
  (local x y ...)
]]

local utils = require("leftry").utils
\

(fn stat_local (invariant cdr output)
  \
  local val
  local count = #cdr
  local names = vector.cast(cdr, nil, function(i, v)
    if i == count then
      val = v
    end
    return i <= count-1
  end)
  names = lua_namelist(names)
  return names,
    \`\local \,names = \,\compiler.compile_exp(invariant, val, output))

(fn statize_local (invariant cdr output)
  (select 2 (stat_local invariant cdr output)))

(fn expize_local (invariant cdr output)
  \
  local names, stat = stat_local(invariant, cdr, output)
  table.insert(output, stat)
  return names)

{
  lua = {
    [symbol("local")] = { expize=expize_local, statize=statize_local }
  }
}
