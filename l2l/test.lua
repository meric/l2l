local reader = require("l2l.reader")
local compiler = require("l2l.compiler")
local list = require("l2l.list")


local source = [==[
(local a b ((fn () \return 1, 2)))
(print a b)
(print (local c 1))
(print "hello")
(print (+ 1 2 3 4))

(fn add (...) (+ 1 2 3 4 ...))

(print `(1 2 3))
(print `(1 (1) ,(print 1 2)))
(print "apply test 1" (apply + (list 1 2)))
(print "apply test 2" (apply + 1 2 (list 3 4)))
(print "apply test 3" (apply + 1 2 (list)))

-- Use Lua expressions in Lisp S-Expressions with backslash.
(print \function(x) print(x, \'(1 2 3 (a 1) \b(1))) end)

(print \{a=1, b=2, 3, 4} \function()
    for i=1, 3 do print(i) end return 9
end)

-- Infix maths when starting with a number.
(print 1 + 1 * 2; 4)


-- Function definition
(fn add (a b)  \a + b 2)

-- The following is broken.
-- \if (\\local x = 0
--              for i=1, 10 do
--                 x = x + 1
--              end
--              return x) > 0 then
--     print("hello")
-- end

(print (fn (a b) (print 1) \a + b))
(print (fn () (print 1) 2))
]==]

local source = compiler.compile(source)
print(source)
print("--------------------------")
print(load(source)())
print("done")
