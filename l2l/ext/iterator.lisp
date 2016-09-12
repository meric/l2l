@import fn
@import local
@import let
@import do
@import quasiquote
@import set
@import cond
@import operators
@import quote

\
--[[
Usage:
  (print
    (map (fn (x) (+ x 2))
      (filter (fn (x) (== (% x 2) 0))
        (map (fn (x) (+ x 1)) {1, 2, 3, 4}))))
]]

(local utils (require "leftry.utils"))
(local lua_iteration (utils.prototype "lua_iteration"
  (fn (lua_iteration iterable)
    (let
      (self (setmetatable {
        iterable = iterable,
        invariant = lua_name:unique("invariant"),
        next = lua_name:unique("next"),
        i = lua_name:unique("i"),
        v = lua_name:unique("v"),
        values = lua_name:unique("values")
      } lua_iteration))
      (set self.block (lua_lazy (fn () `\
        local \,self.next, \,self.invariant, \,self.i = ipairs(\,self.iterable)
        local \,self.values = \,vector()
        while \,self.i do
          local \,self.v
          \,self.i, \,self.v = \,self.next(\,self.invariant, \,self.i)
          if \,self.i then
            \,(self:construct `\(\,self.values):insert(\,self.v))
          end
        end)))
      (set self.cursor self)
      self))))

(fn lua_iteration:construct (suffix)
  \
  local origin = vector()
  local block = origin
  for i, f in ipairs(self) do
    block = f(block) or block
  end
  block:insert(suffix)
  return lua_block(origin))

(fn lua_iteration:__tostring()
  (tostring self.values))

(fn lua_iteration:insert (v)
  (table.insert self v)
  (set self.n #self))

(fn lua_iteration:apply (invariant f output)
  (lua_inline_functioncall invariant f output self.v, self.i))

(fn lua_iteration:reduce (invariant f r output)
  (lua_inline_functioncall invariant f output r self.v))

(fn lua_iteration:gsub ()
  self)

(set lua_ast[lua_iteration] lua_iteration)

(fn compile_map (invariant cdr output insert create)
  (let (
    (f iterable) (:unpack cdr)
    iterable0 (expize invariant iterable output)
    creating (not (utils.hasmetatable iterable0 lua_iteration))
    iterable (cond creating (lua_iteration iterable0) iterable0)
    initialize (cond creating create insert))
    (iterable:insert (fn (block)
      (block:insert (lua_assign.new
        (lua_namelist {iterable.v})
        (iterable:apply invariant f output)))))
    (initialize iterable)))

(fn expize_map (invariant cdr output)
  (compile_map invariant cdr output
    (fn (iterable)
      iterable)
    (fn (iterable)
      (table.insert output iterable.block)
      iterable)))

(fn statize_map (invariant cdr output)
  (compile_map invariant cdr output
    to_stat
    (fn (iterable)
      iterable.block)))

(fn compile_filter (invariant cdr output insert create)
  (let (
    (f iterable) (:unpack cdr)
    iterable0 (expize invariant iterable output)
    creating (not (utils.hasmetatable iterable0 lua_iteration))
    iterable (cond creating (lua_iteration iterable0) iterable0)
    initialize (cond creating create insert)
    condition (iterable:apply invariant f output))
      (iterable:insert (fn (block)
        (let (cursor (lua_block {}))
          (block:insert
            (lua_if.new condition cursor))
          cursor)))
      (initialize iterable)))

(fn expize_filter (invariant cdr output)
  (compile_filter invariant cdr output
    (fn (iterable)
      iterable)
    (fn (iterable)
      (table.insert output iterable.block)
      iterable)))

(fn statize_filter (invariant cdr output)
  (compile_filter invariant cdr output
    to_stat
    (fn (iterable)
      iterable.block)))

(fn compile_reduce (invariant cdr output insert create)
  (let (
    (f initial iterable) (:unpack cdr)
    reduction (lua_name:unique "reduction")
    iterable0 (expize invariant iterable output)
    creating (not (utils.hasmetatable iterable0 lua_iteration))
    iterable (cond creating (lua_iteration iterable0) iterable0)
    initialize (cond creating create insert))
    (table.insert output
      `\local \,reduction = \,(expize invariant initial output))
    (iterable:insert (fn (block)
      (block:insert (lua_assign.new
        (lua_namelist {reduction})
        (iterable:reduce invariant f reduction output)))))
    (initialize iterable reduction)))

(fn expize_reduce (invariant cdr output)
  (compile_reduce invariant cdr output
    (fn (iterable reduction)
      reduction)
    (fn (iterable reduction)
      (table.insert output iterable.block)
      reduction)))

(fn statize_reduce (invariant cdr output)
  (compile_reduce invariant cdr output
    (fn (iterable reduction)
      (to_stat reduction))
    (fn (iterable reduction)
      iterable.block)))

{
  lua = {
    map = {expize = expize_map, statize=statize_map, in_lua=true},
    filter = {expize = expize_filter, statize=statize_filter, in_lua=true},
    reduce = {expize = expize_reduce, statize=statize_reduce, in_lua=true}
  }
}
