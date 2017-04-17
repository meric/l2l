@import quasiquote
@import quote
@import fn
@import local
@import cond
@import do

\--[[
Usage:
  (do
    (locals 
      (a b) {1, 2}
      (a (c d)) {(f)}
      (c d) x
      {e, f} y
      {g=f} z
      h 1
      i 2)
    (print c)
    (print d))
]]

(local destructure (import "l2l.lib.destructure"))

(fn stat_locals (invariant cdr output)
    \
    local body = {destructure.locals_block(cdr:unpack())}
    for i,value in ipairs(body) do
        table.insert(output, compiler.statize(invariant, value, output))
    end
    return nil)

(fn statize_locals (invariant cdr output)
    (stat_locals invariant cdr output))

(fn expize_locals (invariant cdr output)
    (stat_locals invariant cdr output)
    (lua.lua_nil))


{
  lua = {
    [symbol("locals")] = { expize=expize_locals, statize=statize_locals }
  }
}

