local t = require("lunatest")

local vector = require("l2l.vector")
local list = require("l2l.list")
local compiler = require("l2l.compiler")
local lua = require("l2l.lua")

local function assert_exec_equal(source, ...)
  local lua = compiler.compile(source, "test")
  local ret = {load(lua)()}
  for i=1, math.max(select("#", ...), #ret) do
    t.assert_equal(ret[i], select(i, ...))
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

function test_let()
  assert_exec_equal([[
    (let (
      (a b) (unpack {1, 2})
      c 3
      d 4)
      \return a, b, c, d)
    ]],
    1, 2, 3, 4)
end

function test_and()
  assert_exec_equal(
    [[(and 1 (+ 1 2))]], 
    3)
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
