\--[[
(map print
  (map (fn (x i) (+ x 2))
    (filter (fn (x i) (== (% x 2) 0))
      (ipairs {1, 2, 3, 4})))

-- (mac (invariant i)
--     (cond
--       (<= ,i #,invariant)
--         \return \,i, \,invariant[i]))


(list.map print @table {1, 2, 3, 4})
(table.map print @list {1, 2, 3, 4})

local next, invariant, i = ipairs({1, 2, 3, 4})
while i do
  local v
  i, v = nil
  if i <= #invariant then
    i, v = i, invariant[i]
  end
  -- i, v = next(invariant, i)
  if i then
    if v % 2 == 0 then
      v = v + 2
      print(v, i)
    end
  end
end

(map print {1 2 3 4})
]]

@import fn
@import local
@import let
@import do
@import quasiquote
@import set

(local utils (require "leftry.utils"))
(local lua_iteration (utils.prototype "lua_iteration"
  (fn (lua_iteration next invariant i)
    (let
      (self (setmetatable {
        args = {next, invariant, i},
        invariant = lua_name:unique("_iter_invariant_"),
        next = lua_name:unique("_iter_next_"),
        i = lua_name:unique("_iter_i_"),
        v = lua_name:unique("_iter_v_"),
        values = lua_name:unique("_iter_values_")
      } lua_iteration))
      (set self.cursor self)
      self))))

(fn lua_iteration:__tostring()
  (tostring
    `\
    local \,self.next, \,self.invariant, \,self.i = \,(lua_namelist self.args);
    local \,self.values = \,vector()
    while \,self.i do
      local \,self.v
      \,self.i, \,self.v = \,self.next(\,self.invariant, \,self.i)
      if \,self.i then
        \,(lua_block self);
        (\,self.values):insert(\,self.v)
      end
    end))

(fn lua_iteration:insert (v)
  (table.insert self v))

(fn lua_iteration:shift (v block)
  (table.insert self v)
  (set self.cursor (lua_block block)))

(fn lua_iteration:call (invariant f output)
  (lua_inline_functioncall invariant f output self.v, self.i))


(fn statize_map (invariant cdr output)
  (local f next _invariant i (:unpack cdr))
  (local block {})
  (let (ctx (lua_iteration
    (compile_exp invariant next block)
    (compile_exp invariant _invariant block)
    (compile_exp invariant i block)))
    (ctx:insert (lua_assign.new
      (lua_namelist {ctx.v})
      (ctx:call invariant f block)))
    (table.insert block ctx)
    (lua_block block)))

(fn expize_map (invariant cdr output)
  (local f next _invariant i (:unpack cdr))
  (let (ctx (lua_iteration
    (compile_exp invariant next output)
    (compile_exp invariant _invariant output)
    (compile_exp invariant i output)))
    (ctx:insert (lua_assign.new
      (lua_namelist {ctx.v})
      (ctx:call invariant f output)))
    (table.insert output ctx)
    ctx.values))

(fn filter (invariant cdr output)
  (local f next _invariant i (:unpack cdr))
  (print (compile_stat invariant next output))

  (compile_exp invariant next output))

{
  lua = {
    map = {expize = expize_map, statize=statize_map},
    filter = {expize = filter}
  }
}


-- --[[

-- (map print
--   (map (fn (x i) (+ x 2))
--     (filter (fn (x i) (== (% x 2) 0))
--       (ipairs {1, 2, 3, 4})))


-- ]]--



-- -- for i, v in ipairs({1, 2, 3, 4}) do
-- --   print(i, v)
-- -- end

-- source = [[
-- \
-- for i, v in
--   \(map (fn (x) (+ x 2))
--     (filter (fn (x) (== (% x 2) 0))
--       (ipairs {1, 2, 3, 4}))) do
--   print(i, v)
-- end
-- return 1

-- ]]

-- source = [[
-- @import local

-- (fn add (x) (+ x 1))
-- (local next invariant i (ipairs {1, 2, 3, 4}))
-- (print (filter (fn () true) (map (fn (x) (add x)) next invariant i)))
-- 1
-- ]]




















