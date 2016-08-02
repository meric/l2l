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
    -- `0` is not a valid ast node, but `(quote 0)` is, it converts the `0`
    -- into `lua_number(0)`. Escape into lisp and return (quote 0).
    return \'0
  end
  if ... then
    -- Use recursion to build the (+ a b c d) into equivalent lua form.
    return \`\(\,a + \,(+ ...))
  end
  return a)

\return {
  macro = {
    -- Similar to `(quote 0)` above, use (quote +) to get symbol("+").
    -- Symbols aren't useful for use as a key. We hash it to convert it into
    -- string, and this works because by design, 
    -- `symbol(hash(text)) == symbol(text)`
    [(\'+):hash()] = \+
  }
}
