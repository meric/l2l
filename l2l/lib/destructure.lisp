@import quasiquote
@import quote
@import fn
@import local
@import cond
@import do

-- Destructure implementation shared by let and locals syntax
-- Based on:
-- http://exploringjs.com/es6/ch_destructuring.html#sec_destructuring-algorithm

\--[[
Example block that can be passed to locals_block for (local ...) binding:
    (a b) {1, 2}
    (a (c d)) {(f)}
    (c d) x
    {e, f} y
    {g=f} z
    h 1
    i 2
]]
--[[
For each assignment,
   convert to a list of assignments
]]--

(local utils (require "leftry.utils"))
(local boolean (require "l2l.lib.operators"))

(fn is_strictly_array (self)
  (apply boolean.and
    (utils.map
      (fn (field) (boolean.and
        (not (utils.hasmetatable field lua_field_key))
        (not (utils.hasmetatable field lua_field_name))))
      self.fieldlist)))

(fn is_strictly_lua_name_array (self)
  (apply boolean.and
    (utils.map
      (fn (field) (boolean.or
        (utils.hasmetatable field lua_name)
        (not (getmetatable field))))
      self.fieldlist)))

(:where destructure lua_table (fn (self value)
  (cond
    (boolean.and (utils.hasmetatable value lua_table)
         (is_strictly_lua_name_array self)
         (is_strictly_array value))
      -- Both sides are lua_table, cancels out.
      -- {a,b,c,d,e} {unpack({1, 2, 3, 4, 5})}
      `\local \,self.fieldlist = \,value.fieldlist
      -- Right side is not literal table.
      (do
        (local ref (lua_name:unique "ref"))
        (local stats (lua_block {\`\local \,ref = (\,value)}))
        (utils.map (fn (field i)
          (cond
            (utils.hasmetatable field lua_name)
             -- {a, b, hello=c, world={f}}
             -- The simple `a, b` part.
              (stats:insert `\local \,field = (\,ref)[(\,i)])
            (utils.hasmetatable field lua_field_name)
              -- {a, b, hello=c, world={f}} {1, 2, hello=4, world={5}}
              -- The nested string keys part.
              (do
                (local sub `\(\,ref)[\,(lua_string field.name.value)])
                (cond
                  (destructure:has (getmetatable field.exp))
                    (stats:insert (destructure field.exp sub))
                    (stats:insert `\local \,field.exp = \,sub)))
            (destructure:has (getmetatable field))
              -- {a, b, c, d, {e}} {unpack({1, 2, 3, 4, {5}})}
              -- The nested {e} part.
              (do
                (local sub `\(\,ref)[(\,i)])
                (stats:insert (destructure field sub)))
            (error "cannot destructure "..str(field))))
        self.fieldlist)
        stats))))

(:where destructure list (fn (self value)
  (cond
    (boolean.and (utils.hasmetatable value lua_table))
      -- (a b c) {1,2,3}
      (do
        (assert (is_strictly_array value)
          "table with keys cannot be destructured into list")
        `\local \,(lua_namelist (vector.cast self lua_name)) =
          \,value.fieldlist)
    (boolean.and (utils.hasmetatable value list)
         (== (:car value) (symbol "quote")))
      -- (d e f) '(4 5 (+ 6 8))
        `\local \,(lua_namelist (vector.cast self lua_name)) =
          \,(lua_explist (vector.cast (:car (:cdr value))))
    `\local \,(lua_namelist (vector.cast self lua_name))=(\,value):unpack())))

(:where destructure "nil" (fn (self)
  (error "destructure block only allows symbols, list or table on left hand side, not.."..
      tostring(getmetatable(self)))))

(fn assign_local (names value)
  (cond
    (utils.hasmetatable names symbol)
      `(local ,names ,value)
    (destructure names value)))

(fn locals_block (names values ...)
  (cond ...
    \return assign_local(names, values), locals_block(...)
    (assign_local names values)))

{
  locals_block = locals_block
}
