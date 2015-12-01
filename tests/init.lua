local _, compiler = require("l2l.compat"), require("l2l.compiler")
local reader = require("l2l.reader")
local show = require("l2l.itertools").show

function dolispfile(filename)
  local f = io.open(filename, "r")
  assert(f, "File not found: " .. filename)
  stream = reader.tofile(f:read("*all"))
  f:close()
  local ok, form = pcall(reader.read, stream, true)
  assert(ok, "Compilation failed")
  return compiler.eval(form)
end

local add = dolispfile("tests/add.lsp")
assert(add == 65, "Addition failed! ".. add)
local mathy = dolispfile("tests/math.lsp")
assert(mathy == -40, "Math failed! " .. mathy)

local listy = dolispfile("tests/list.lsp")
assert(listy[1] == 5, "List car failed! " .. tostring(listy[1]))
assert(listy[2][1] == 9, "List cadr failed.")
assert(listy[2][2] == 51, "List cddr failed.")

-- TODO: calling tostring(listy[2]) here on an improper list crashes it:
-- lua: ./l2l/itertools.lua:141: attempt to index local 'self' (a number value)

local fac, fib = unpack(dolispfile("tests/y.lsp"))
assert(fac(8) == 40320, "Factorial failed!")
assert(fib(16) == 987, "Fibonacci failed!")
