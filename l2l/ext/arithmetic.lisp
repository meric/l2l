#import quasiquote
#import quote
#import fn
#import cond

\--[[
Usage:
  (+ 1 2 3 4)
]]
(fn + (a ...)
  (cond
      \not a 0
      ... `\(\,a + \,(+ ...))
      \a == symbol("..."); '\(\+)(...)
      a))

{
  macro = {
    [(\'+)]= \+
  }
}
