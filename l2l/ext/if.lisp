@import fn
@import cond
@import local
@import quasiquote

\
--[[
Usage:
  (if exp v-t)
  (if exp v-t v-f)
  (when exp v-t ...)
  (unless exp v-f ...)
]]

local utils = require("leftry").utils

(fn macro_if (...)
  (local n (select "#" ...))
  \if n < 2 or n > 3 then
    error("if requires 2 or 3 arguments: (if condition exp-when-true [exp-when-false])")
  end
  `(cond ,...))

(fn macro_when (condition ...)
  (local n (select "#" ...))
  \if n < 1 then
    error("when requires 2 or more arguments: (when condition exp-when-true ...)")
  end
  `(cond ,condition (do ,...)))

(fn macro_unless (condition ...)
  (local n (select "#" ...))
  \if n < 1 then
    error("unless requires 2 or more arguments: (unless condition exp-when-false ...)")
  end
  `(cond (not ,condition) (do ,...)))

{
  macro = {
    ["if"] = macro_if,
    ["when"] = macro_when,
    ["unless"] = macro_unless
  }
}
