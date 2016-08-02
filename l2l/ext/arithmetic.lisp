#import quasiquote
#import quote
#import fn

(fn + (a ...)
 \if a == symbol("...") then
    if ... then
      error("... must be last argument.")
    end
    -- a = \'(+ ...) will not work because we can't embed lisp nodes
    -- in lua nodes.
    a = \'\(\+)(...)
  end
  if not a then
    return 0
  elseif ... then
    -- Use recursion to build the (+ a b c d) into equivalent lua form.
    return \`\(\,a + \,(+ ...))
  end
  return a)

\return {
  macro = {
    -- Symbols aren't useful for use as a key. We hash it to convert it into
    -- string.
    [(\'+):hash()] = \+
  }
}
