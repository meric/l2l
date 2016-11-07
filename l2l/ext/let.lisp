@import quasiquote
@import quote
@import fn
@import local
@import cond
@import do
@import iterator
@import boolean

-- http://exploringjs.com/es6/ch_destructuring.html#sec_destructuring-algorithm

\--[[
Usage:
  (let (
    (a b) {1, 2}
    (a (c d)) {(f)}
    (c d) x
    {e, f} y
    {g=f} z
    h 1
    i 2)
    (print c)
    (print d))
]]
--[[
For each assignment,
   convert to a list of assignments
]]--

(local utils (require "leftry.utils"))

(fn is_strictly_array (self)
  (apply and
    (map
      (fn (field) (or (utils.hasmetatable field lua_name) (not (getmetatable field))))
      self.fieldlist)))

(:where destructure lua_table (fn (self value)
  (cond
    (and (utils.hasmetatable value lua_table)
         (is_strictly_array self)
         (is_strictly_array value))
      -- Both sides are lua_table, cancels out.
      -- {a,b,c,d,e} {unpack({1, 2, 3, 4, 5})}
      `\local \,self.fieldlist = \,value.fieldlist
      -- Right side is not literal table.
      (do
        (local ref (lua_name:unique "ref"))
        (local stats (lua_block {\`\local \,ref = (\,value)}))
        (map (fn (field i)
          (cond
            (utils.hasmetatable field lua_name)
              (stats:insert `\local \,field = (\,ref)[(\,i)])
            (utils.hasmetatable field lua_field_name)
              (do
                (local sub `\(\,ref)[\,(lua_string field.name.value)])
                (cond
                  (destructure:has (getmetatable field.exp))
                    (stats:insert (destructure field.exp sub))
                    (stats:insert `\local \,field.exp = \,sub)))
            (destructure:has (getmetatable field))
              (do
                (local sub `\(\,ref)[(\,i)])
                (stats:insert (destructure field sub)))
            (error "cannot destructure "..str(field))))
        self.fieldlist)
        stats))))

(:where destructure list (fn (self value)
  (cond
    (and (utils.hasmetatable value lua_table))
      -- (a b c) {1,2,3}
      (do
        (assert (is_strictly_array value)
          "table with keys cannot be destructred into list")
        `\local \,(lua_namelist (vector.cast self lua_name)) =
          \,value.fieldlist)
    (and (utils.hasmetatable value list)
         (== (:car value) (symbol "quote")))
      -- (d e f) '(4 5 (+ 6 8))
        `\local \,(lua_namelist (vector.cast self lua_name)) =
          \,(lua_explist (vector.cast (:car (:cdr value))))
    `\local \,(lua_namelist (map lua_name self)) = (\,value):unpack())))

(:where destructure "nil" (fn (self)
  (error "let only allows symbols and list on left hand side, not.."..
      tostring(getmetatable(self)))))

(fn assign (names value)
  (cond
    (utils.hasmetatable names symbol)
      `(local ,names ,value)
    (destructure names value)))

(fn locals (names values ...)
  (cond ...
    \return assign(names, values), locals(...)
    (assign names values)))

(fn let (vars ...)
  (cond \(len(vars)) > 0
    `(do ,(vector.unpack
      (:append
        (vector (locals (list.unpack vars)))
        (vector ...))))
    `(do ,...)))

{
  macro = {
    let = let
  }
}
