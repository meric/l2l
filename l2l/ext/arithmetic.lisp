#import quasiquote
#import quote
#import fn

(fn + (a ...)
  \
  --[[
  Usage:
    (+ 1 2 3 4)
  ]]
  if not a then
    return 0
  elseif ... then
    -- Use recursion to build the (+ a b c d) into equivalent lua form.
    return \`\(\,a + \,(+ ...))
  elseif a == symbol("...") then
    -- a = \'(+ ...) won't work because we can't embed lisp nodes in lua nodes.
    return \'\(\+)(...)
  end
  return a)

{
  macro = {
    [(\'+)]= \+
  }
}
