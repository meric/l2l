local reader = require("l2l.reader")
local compiler = require("l2l.compiler")
local list = require("l2l.list")

local invariant = reader.environ([=[
-- Install quote and quasiquote read macro and special forms.

(-# LANGUAGE l2l.contrib.quote #-)
(-# LANGUAGE l2l.contrib.quasiquote #-)
(-# LANGUAGE l2l.contrib.fn #-)
(-# LANGUAGE l2l.contrib.mac #-)

(-# MACRO l2l.macro.math math #-)

(print (math.+ 1 2 3 + 7))

(math.+)

-- Semicolons have no effect.
;;;

-- Escape into Lua with backslash.
-- When using Lua statements ending with parenthesis, use semicolon at the end,
-- so the compiler doesn't think any lisp statements after as being another
-- function call.

(print \function test() end return test)
(print \local x; x = x + 1 return x)

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
(print 0 + x * y; 4)

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
]=])

-- print((1 + (2 + 3 + 7)))
-- function test() end
-- print(test)
-- local x
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
-- print(0 + x * y,4)
-- local function add(a,b)local _var0 = a + b;return 2 end
-- if ((function()local x = 0;for i=1,10 do x=x + 1 end;return x end)()) > 0 then print("hello") end
-- print(function(a,b)print(1);return a + b end)
-- print(function()print(1);return 2 end)

local output = {}

for rest, values in reader.read, invariant do
  for i, value in ipairs(values) do
    local stat = compiler.compile_stat(invariant, value, output)
    if stat then
      table.insert(output, stat)
    end
  end
end

for i, value in ipairs(output) do
  print(value)
end

-- \! Syntax Proposal:

--     \{a=1, \(1 2 <- {x = 1} [for i=2, 100 do x = x + 1 end])}

