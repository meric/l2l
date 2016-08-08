#import quasiquote
#import fn
#import local
#import cond
#import do

\--[[
Usage:
  (let (
    (a b) (unpack {1, 2})
    c 1
    d 2)
    (print c)
    (print d))
]]


(local utils (require "leftry.utils"))

(fn assign (names values)
  (cond
    (utils.hasmetatable names symbol)
      `(local ,names ,values)
    (utils.hasmetatable names list)
      `(local ,(lua_namelist names) ,values)
    (error "let only allows symbols and list on left hand side, not.."..
      tostring(getmetatable(names)))))

(fn locals (names values ...)
  (cond ...
    \return assign(names, values), locals(...)
    (assign names values)))

(fn let (vars ...)
  (cond \#vars > 0
    `(do ,(vector.unpack
      (:append
        (vector (locals (list.unpack vars)))
        (vector ...))))
    `(do ,...)))

{
  macro = {
    let = let
  }
}
