@import quasiquote
@import quote
@import fn
@import local
@import cond
@import do

\--[[
Usage:
  (let (
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

(fn let (vars ...)
  (cond \(len(vars)) > 0
    `(do ,(vector.unpack
      (:append
        (vector (destructure.locals_block (list.unpack vars)))
        (vector ...))))
    `(do ,...)))

{
  macro = {
    let = let
  }
}
