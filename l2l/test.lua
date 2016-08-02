local reader = require("l2l.reader")
local compiler = require("l2l.compiler")
local list = require("l2l.list")

local source = [=[
-- Install quote and quasiquote read macro and special forms.

-- #import mac

#import (arithmetic a)

(print (a.+ 1 2 3 7))

-- (+)

-- (fn add (...) (math.+ ...))

-- Semicolons have no effect.
;;;

-- Escape into Lua with backslash.
-- When using Lua statements ending with parenthesis, use semicolon at the end,
-- so the compiler doesn't think any lisp statements after as being another
-- function call.

(print \function test() end return test)
(print \local x = 0; x = x + 1 return x)

\print(1);
\print(1 --[[This is a Lua multiline comment]]);
(print "this line is not turned into print(...)(...)")

-- Normal Lisp statements.
(print "hello world")

-- Using the LANGUAGE extensions.
(print '(1 2 3))
(print `(1 (1) ,(print 1 2)))

-- Use Lua expressions in Lisp S-Expressions with backslash.
(print \function(x) print(x, \'(1 2 3 (a 1) \b(1))) end)

(print \{a=1, b=2, 3, 4} \function()
    for i=1, 3 do print(i) end return 9
end)

-- Infix maths when starting with a number.
(print 1 + 1 * 2; 4)
(print 0 + x * x; 4)

-- Function definition
(fn add (a b)  \a + b 2)

\if (\\local x = 0
             for i=1, 10 do
                x = x + 1
             end
             return x) > 0 then
    print("hello")
end

(print (fn (a b) (print 1) \a + b))
(print (fn () (print 1) 2))
]=]

-- local lua = require("l2l.lua")
-- local reader = require("l2l.reader")
-- local compiler = require("l2l.compiler")
-- local symbol = reader.symbol
-- local list = require("l2l.list")
-- local import = compiler.import
-- local math = import("l2l.lib.math")
-- print((1 + (2 + 3 + 7)))
-- local _var0 = 0
-- local function add(...)return _43(...) end
-- function test() end
-- print(test)
-- local x = 0
-- ;
-- x=x + 1
-- print(x)
-- print(1)
-- print(1)
-- print("this line is not turned into print(...)(...)")
-- print("hello world")
-- print(list(1, 2, 3))
-- print(list(1, list(1), print(1,2)))
-- print(function(x)print(x,list(1, 2, 3, list(symbol("a"), 1), b(1))) end)
-- print({a=1,b=2,3,4},function()for i=1,3 do print(i) end;return 9 end)
-- print(1 + 1 * 2,4)
-- print(0 + x * x,4)
-- local function add(a,b)local _var1 = a + b;return 2 end
-- if ((function()local x = 0;for i=1,10 do x=x + 1 end;return x end)()) > 0 then print("hello") end
-- print(function(a,b)print(1);return a + b end)
-- print(function()print(1);return 2 end)

local source = compiler.compile(source)
print(source)
print(load(source)())

