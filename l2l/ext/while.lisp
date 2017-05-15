@import fn
@import if
@import cond
@import local
@import quasiquote

\
--[[
Usage:
  (while condition ...)
  you can (break) inside ...
]]

local utils = require("leftry").utils
local loadstring = _G["loadstring"] or _G["load"]


-- If the current Lua version does not support having statements between
-- `break` and `end` then wrap it in `do end` block.
(local _break (if
    (loadstring "while true do break; print(1) end") `\break
    `\do break end))

(fn expize_break (invariant cdr output)
  (table.insert output _break)
  (lua.lua_nil))

(fn statize_break (invariant cdr output)
  _break)

(fn stat_while (invariant cdr output)
  \
  local condition = cdr:car()
  local body = cdr:cdr()
  local stats = {}
  local breaker = lua.lua_if.new(
    lua.lua_unop_exp.new(lua_unop("not"), compiler.expize(invariant, condition, stats)),
    lua.lua_block({lua.lua_break()}))
  table.insert(stats, breaker)
  for i, value in ipairs(body) do
    table.insert(stats, compiler.statize(invariant, value, stats))
  end
  return lua.lua_while.new(lua.lua_true(), lua.lua_block(stats)))

(fn statize_while (invariant cdr output)
  (stat_while invariant cdr output))

(fn expize_while (invariant cdr output)
  (table.insert output (stat_while invariant cdr output))
  (lua.lua_nil))

{
  lua = {
    [symbol("break")] = { expize=expize_break, statize=statize_break },
    [symbol("while")] = { expize=expize_while, statize=statize_while }
  }
}
