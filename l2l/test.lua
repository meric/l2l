local reader = require("l2l.reader")
local compiler = require("l2l.compiler")

local invariant = reader.environ([=[
-- Install quote and quasiquote read macro and special forms.

(-# LANGUAGE l2l.contrib.quote #-)
(-# LANGUAGE l2l.contrib.quasiquote #-)

-- Semicolons have no effect.
;;;

-- Escape into Lua with backslash.
-- When using Lua statements ending with parenthesis, use semicolon at the end,
-- so the compiler doesn't think any lisp statements after as being another
-- function call.

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
]=])

-- print(1)
-- print(1)
-- print("this line is not turned into print(...)(...)")
-- print("hello world")
-- print(list(1, 2, 3))
-- print(list(1, list(1), print(1,2)))
-- print(function(x) print(x,list(1, 2, 3)) end)

local output = {}

for rest, values in reader.read, invariant do
  for i, value in ipairs(values) do
    local ref = compiler.compile(invariant, value, compile)
    if ref then
      table.insert(output, ref)
    end
  end
end

for i, value in ipairs(output) do
  print(value)
end

-- \! Syntax Proposal:

--     \{a=1, \(1 2 \!
--                  local x = 1
--                  for i=2, 100 do
--                     x = x + 1
--                  end
--                  return x)}

