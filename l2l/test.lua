local t = require("lunatest")

local vector = require("l2l.vector")
local list = require("l2l.list")
local compiler = require("l2l.compiler")
local lua = require("l2l.lua")
local loadstring = _G["loadstring"] or _G["load"]

local reader = require("l2l.reader")

local function assert_exec_equal(source, ...)
  local src = compiler.compile(source, "test")
  local f, err = loadstring(src)
  if not f then
    print(src, err)
  end
  local ret = {pcall(f)}
  local ok = table.remove(ret, 1)
  if not ok then
    print(src)
  end
  for i=1, math.max(select("#", ...), #ret) do
    t.assert_equal(select(i, ...), ret[i], src)
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

local function assert_parse_contains(source, expected)
  local src = compiler.compile(source, "test")
  t.assert_match(expected
    :gsub("[^a-zA-Z0-9 ]", "%%%1")
    :gsub("%s", "%%s+"), src)
end

local function assert_parse_error_contains(message, source, ...)
  local ok, ret = pcall(compiler.compile, source, "test", true)
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
  -- \r is not being tested due to weirdness related to windows, file opening modes, and 
  -- the lua error "unfinished string near ..."
  assert_exec_equal(
    [["hello"]],
    "hello")
  assert_exec_equal(
    [["\t\a\n\b\f\v\"\'\\"]],
    "\t\a\n\b\f\v\"\'\\")
  assert_exec_equal(
    [["\n\t\a\b\f\v\x0a\x0A\123\40\"\'\\"]],
    "\n\t\a\b\f\v\x0a\x0A\123\40\"\'\\")
  assert_exec_equal(
    [["a\na\ta\aa\ba\faa\va\x0aa\x0Aa\123a\40a\"a\'a\\a"]],
    "a\na\ta\aa\ba\faa\va\x0aa\x0Aa\123a\40a\"a\'a\\a")
  assert_exec_equal(
    [["aaa\123456aaa"]],
    "aaa{456aaa")
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
  assert_exec_equal([[
    @import iterator
    (local acc (map (fn (v) (.. "1" v.a)) (list {.a "x"} {.a "y"} {.a "z"})))
    (reduce (fn (curr n) (.. curr n)) "" acc)
    ]], "1x1y1z")
  assert_exec_equal([[
    @import iterator
    (local acc (map (fn (v) (.. "1" v[1])) (list {[1]="x"} {[1]="y"} {[1]="z"})))
    (reduce (fn (curr n) (.. curr n)) "" acc)
    ]], "1x1y1z")
  assert_exec_equal([[
    @import iterator
    (local acc (map (fn (a) (.. "1" a.a.a)) (list {.a {.a "x"}} {.a {.a "y"}} {.a {.a "z"}})))
    (reduce (fn (curr n) (.. curr n)) "" acc)
    ]], "1x1y1z")
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
      {y, {z}} {1, {2}}
      d 3
      e 4)
      \return a, b, c, d, e, f, z)
    ]],
    1, 2, 4, 3, 4, 5, 2)
end

function test_let()
  local src = assert_exec_equal([[
    (let (
      {a, b, c, d, {e}} {unpack({1, 2, 3, 4, {5}})}
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
  assert_exec_equal(
    [[(do "a" "b")]],
    "b")
  assert_exec_equal(
    [[(do 1 2)]],
    2)
  assert_exec_equal(
    [=[(do 1 2 --[[hello]] 3)]=],
    3)
  assert_exec_equal(
    [=[(do 1 2 --[[hello]])]=],
    2)
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

function test_table_constructor()
  assert_exec_equal(
    [[ (.a {"a" "b"}) ]],
    "b")
  assert_exec_equal(
    [[ (.a {"a" -- comment
    "b"}) ]],
    "b")
  assert_parse_error_contains(
    "table dictionary constructor requires an even number of expressions",
    [[ (.a {"a" "b" "c"}) ]])
  assert_exec_equal(
    [[ (. {(+ 1 2) (* 10 20) (+ 3 4) (/ 10 20)} 3) ]],
    200)
  assert_exec_equal(
    [[ (.hey {\("he".."y") (+ 1 2) "b" (+ 3 4)}) ]],
    3)
  assert_exec_equal(
    [[ (do (local v "heh") (+ (.heh {v 3 .a 10}) (.kw {.kw 4 .a 11})) ) ]],
    7)
  assert_exec_equal([[
    (let (
      {a, b, hello=c, world={f} } {1 1 2 2 "hello" 4 "world" {1 5}}
      {y, {z}}  {1 1 2 {1 2}}
      d 3
      e 4)
      \return a, b, c, d, e, f, z)
    ]],
    1, 2, 4, 3, 4, 5, 2)
end

function test_seti()
  assert_parse_error_contains(
    "seti requires at least 2 arguments",
    [[ (seti v) ]])
  assert_exec_equal(
    [[ (seti v 5) ]],
    5)
  assert_exec_equal(
    [[ (do
          (local t {})
          (seti t "a" 10)
          (.a t)) ]],
    10)
  assert_exec_equal(
    [[ (do
          (local t {})
          (local expcase (seti t 1 10))
          expcase) ]],
    10)
  assert_exec_equal(
    [[ (do
          (local t {})
          (local f (fn () t))
          (seti (f) "a" {})
          (seti (f) "a" "b" 20)
          (.a.b t)) ]],
    20)
end

function test_if()
  assert_parse_error_contains(
    "if requires 2 or 3 arguments",
    [[ (if 1) ]])
  assert_parse_error_contains(
    "if requires 2 or 3 arguments",
    [[ (if 1 2 3 4) ]])
  assert_exec_equal(
    [[ (if 1 1 2) ]],
    1)
  assert_exec_equal(
    [[ (if 1 2) ]],
    2)
  assert_exec_equal(
    [[ (if nil 2) ]],
    nil)
  assert_exec_equal(
    [[ (if nil 2 3) ]],
    3)
  assert_parse_error_contains(
    "when requires 2 or more arguments",
    [[ (when 1) ]])
  assert_exec_equal(
    [[ (when 1 "a" "b" "c") ]],
    "c")
  assert_exec_equal(
    [[ (when false "a" "b" "c") ]],
    nil)
  assert_exec_equal(
    [[ (do
          (local v 0)
          (when 1
            (set v (+ v 1))
            (set v (+ v 1))
            "a")
          v) ]],
    2)
  assert_parse_error_contains(
    "unless requires 2 or more arguments",
    [[ (unless 1) ]])
  assert_exec_equal(
    [[ (unless 1 "a" "b" "c") ]],
    nil)
  assert_exec_equal(
    [[ (unless false "a" "b" "c") ]],
    "c")
  assert_exec_equal(
    [[ (do
          (local v 0)
          (unless nil
            (set v (+ v 1))
            (set v (+ v 1))
            "a")
          v) ]],
    2)

end

function test_nested_macro()
  assert_parse_contains([[`(cond (not ,true))]],
    [[return list(symbol("cond"), list(symbol("not"), true))]])
  assert_parse_contains([[((fn () (not true)))]],
    "return (function() return not true end)()")
  assert_exec_equal([[((fn () (not true)))]], false)
end

function test_concat()
  assert_exec_equal([[(.. "1" "2")]], "12")
end

function test_while()
  assert_exec_equal([[
    (local n 0)
    (while (< n 9)
      (set n (+ n 1)))
    n
  ]], 9)
  assert_exec_equal([[
    (local n 0)
    (while
      (do
        (local v (* n 10))
        (local f (fn (p) (/ p 10)))
        (if (< (f v) 7) true false))
      (set n (+ n 1)))
    n
  ]], 7)
  assert_exec_equal([[
    (local n 0)
    (while (< n 9)
      (set n (+ n 1))
      (when (== n 4)
        (break)))
    n
  ]], 4)

end

function test_list_index()
  assert_exec_equal([[
    (let
      (a '("a" "b" "c" "d")
       b `(,a[4] ,a[3] ,a[2] ,a[1]))
      b)
  ]], list("d", "c", "b", "a"))

  assert_exec_equal([[
    (let
      (a '("a" "b" "c" "d")
       b '(1 2 3 4))
      \b[1] = a[4]
      \b[2] = a[3]
      \b[3] = a[2]
      \b[4] = a[1]
      b)
  ]], list("d", "c", "b", "a"))
end

function test_locals()
  assert_exec_equal([[
    (locals
      {a, b, hello=c, world={f}} {1, 2, hello=4, world={5}}
      {y, {z}} {1, {2}}
      d 3
      e 4)
      \return a, b, c, d, e, f, z
    ]],
    1, 2, 4, 3, 4, 5, 2)
  assert_exec_equal([[
    (locals
      {a, b, c, d, {e}} {unpack({1, 2, 3, 4, {5}})}
      x {}
      {f} x)
      \return a, b, c, d, e
    ]],
    1, 2, 3, 4, 5)
  assert_exec_equal([[
    @import iterator
    (locals
      (a b c) {1,2,3}
      (d e f) '(4 5 (+ 6 8))
      (g h i) `(4 5 ,(+ 6 8)))
      \return a, b, c, d, e, f, g, h, i
    ]],
    1, 2, 3, 4, 5, 14, 4, 5, 14)
end


t.run(nil, {"--verbose"})
