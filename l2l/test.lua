local t = require("lunatest")

local vector = require("l2l.vector")
local list = require("l2l.list")
local compiler = require("l2l.compiler")
local lua = require("l2l.lua")
local loadstring = _G["loadstring"] or _G["load"]

local function assert_exec_equal(source, ...)
  local src = compiler.compile(source, "test")
  local ret = {loadstring(src)()}
  for i=1, math.max(select("#", ...), #ret) do
    t.assert_equal(select(i, ...), ret[i])
  end
  return src
end

local function assert_exec_error_contains(message, source, ...)
  local src = compiler.compile(source, "test", true)
  local ok, ret = pcall(loadstring(src))
  t.assert_equal(ok, false)
  local found = tostring(ret):find(message, 1, true) and true
  if not found then
    print(ret)
  end
  t.assert_equal(found, true)
end

local function assert_exec_equal_print(source, ...)
  local src = compiler.compile(source, "test")
  print(src)
  local ret = {loadstring(src)()}
  for i=1, math.max(select("#", ...), #ret) do
    t.assert_equal(select(i, ...), ret[i])
  end
end

function test_local()
  assert_exec_equal(
    [[(local a b ((fn () \return 1, 2)))]],
    1, 2)
  assert_exec_equal(
    [[(local c d 1)]],
    1)
end

function test_dot()
  assert_exec_equal(
    [[(.x {x=1})]],
    1)
  assert_exec_equal(
    [[(:f {f=function() return 2 end})]],
    2)
end

function test_length()
  assert_exec_equal(
    [[#{1, 2, 3, 4}]],
    4)
end

function test_string()
  assert_exec_equal(
    [["hello"]],
    "hello")
end

function test_math()
  assert_exec_equal(
    [[(+ 1 2 3 4)]],
    10)
  assert_exec_equal(
    [[(- 100 5 3 1)]],
    91)
  assert_exec_equal(
    [[((fn (...) \return \(- ...)) 1)]],
    -1)
  assert_exec_equal(
    [[((fn (...) (/ 4 ...)) 1 2 3)]],
    4/6)
  assert_exec_equal(
    [[(- 10)]],
    -10)
  assert_exec_equal(
    [[-10]],
    -10)
  assert_exec_equal(
    [[(+ 1 (+ 1 2))]],
    4)
  assert_exec_equal(
    [[(== 1 2 - 1)]],
    true)
end

function test_set()
  assert_exec_equal(
    [[(set yy "yyyy") yy]],
    "yyyy")
end

function test_length()
  assert_exec_equal(
    [[#{1,2,3,4,5}]],
    5)
end

function test_iterator()
  assert_exec_equal([[
    @import iterator
    (map (fn (x) (+ x 2))
     (filter (fn (x) (== (% x 2) 0))
        (map (fn (x) (+ x 1)) {1, 2, 3, 4})))]],
    vector(4, 6))
  assert_exec_equal([[
    @import iterator
    \
    map(function(x) return x + 2 end,
      filter(function(x) return x % 2 == 0 end,
        map(function(x) return x + 1 end, {1, 2, 3, 4})))]],
    vector(4, 6))
end

function test_reduce()
  assert_exec_equal([[
    @import iterator
    (set z 1)
    (reduce (fn (x y) (+ x y)) z {1, 2, 3})
  ]], 7)
end

function test_lua_quote()
  assert_exec_equal([[
    @import lua_quote
    \
    return #(lua_quote(\\local x = 1; print(x)))
  ]], 3)
end

function test_accessor()
  local src = assert_exec_equal([[
    \local x = {a = { 2}}
    return \(. x "a" 1)
    ]],
    2)
end

function test_let0()
  local src = assert_exec_equal([[
    (let (
      {a, b, hello=c, world={f}} {1, 2, hello=4, world={5}}
      d 3
      e 4)
      \return a, b, c, d, e, f)
    ]],
    1, 2, 4, 3, 4, 5)
end

function test_let()
  local src = assert_exec_equal([[
    (let (
      {a, b, c, d, e} {unpack({1, 2, 3, 4, 5})}
      x {}
      {f} x)
      \return a, b, c, d, e)
    ]],
    1, 2, 3, 4, 5)
end

function test_let3()
  local src = assert_exec_equal([[
    @import iterator
    (let (
      (a b c) {1,2,3}
      (d e f) '(4 5 (+ 6 8))
      (g h i) `(4 5 ,(+ 6 8)))
      \return a, b, c, d, e, f, g, h, i)
    ]],
    1, 2, 3, 4, 5, 14, 4, 5, 14)
end

function test_and()
  assert_exec_equal(
    [[(and 1 (+ 1 2))]], 
    3)
  assert_exec_equal(
    [[(and true true)]],
    true)
  assert_exec_equal(
    [[(and)]],
    true)
end

function test_or()
  assert_exec_equal(
    [[(or 1 (+ 1 2))]],
    1)
  assert_exec_equal(
    [[(or false true)]],
    true)
  assert_exec_equal(
    [[(or false false)]],
    false)
  assert_exec_equal(
    [[(or false false true)]],
    true)
  assert_exec_equal(
    [[(or)]],
    false)
end

function test_do()
  assert_exec_equal(
    [[(do ">>")]],
    ">>")
  assert_exec_equal(
    [[(do (local x 1) 7 + x)]],
    8)
  assert_exec_equal([[
    (do
      (local x 1)
      (set x 7 + x)
      (set x 8 + x)
      (set x 9 + x))]],
    25)
end

function test_cond()
  assert_exec_equal([[
    (cond 1
      (local a 2)
      3 4
      1)]],
    2)
  assert_exec_equal(
    [[(cond 1)]],
    1)
end

function test_fn()
  assert_exec_equal(
    [[((fn (...) (+ 1 2 3 4 ...)) 5)]],
    15)
  assert_exec_equal(
    [[((fn add (...) (+ 1 2 3 4 ...)) 5)]],
    15)
end

function test_quasiquote()
  assert_exec_equal(
    [[`(1 2 3)]],
    list.cast({1, 2, 3}, lua.lua_number))
  assert_exec_equal(
    [[`(1 (2) ,(+ 2 1))]],
    list(1, list(2), 3))
end

function test_apply()
  assert_exec_equal(
    [[(apply + (list 1 2))]],
    3)
  assert_exec_equal(
    [[(apply + 1 2 (list 3 4))]],
    10)
  assert_exec_equal(
    [[(apply + 1 2 (list))]],
    3)
end

function test_error()
  assert_exec_error_contains(
    "Line 1, column 1:",
    [[0 + 1 +
      (0 + nil)]],
    2, "")

  assert_exec_error_contains(
    "Line 3, column 15:",
    [[(let (x 1
            y 2
            z 3 + nil) z)]],
    2, "")

  assert_exec_error_contains(
    "Line 5, column 14:",
    [[(fn q (u)
        (let (x 1
            y 2
            z 3 + u) z))
      (print (q nil))
      (print 1)]],
    2, "")
end

function test_backslash()
  assert_exec_equal(
    [[(\function(x) return x + 1 + \(+ 2 3) end 1)]],
    7)
  assert_exec_equal(
    [[(vector.cast \{1, 2, 3, 4})]],
    vector(1, 2, 3, 4))
end

function test_infix()
  -- Infix maths when starting with a number.
  assert_exec_equal(
    [[1 + 1 * 2]],
    3)
end

function test_extension_alias()
  assert_exec_equal([[
    @import (iterator iterator)
    \
    iterator.map(function(x) return x * 2 end,
      iterator.map(function(x) return x + 2 end, {1, 2, 3}))]],
    vector(6,8,10))
end

t.run(nil, {"--verbose"})
