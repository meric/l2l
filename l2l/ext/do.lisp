@import local
@import fn
@import quasiquote

\--[[
Usage:
  (do
    (local x 1)
    (local y 2)
    (+ x y))
]]

(local utils (require "leftry.utils"))

(fn expize_do (invariant cdr output)
  \
  if not cdr then
    return lua_nil()
  end
  (local block {})
  (local count \#cdr)
  (local var (lua_name:unique "_do"))
  (table.insert output `\local \,var)
  \
  for i, value in ipairs(cdr) do
    if i < count then
      local stat = compile_stat(invariant, value, block)
      if stat then
        table.insert(block, stat)
      end
    else
      local exp = compile_exp(invariant, value, block)
      if utils.hasmetatable(exp, lua_block) then
        -- We have no choice, cannot assign lua_block into variable.
        table.insert(block, exp)
      else
        table.insert(block, \`\\,var = \,exp)
      end
    end
  end
  (table.insert output `\do \,(unpack block) end)
  var)

(fn statize_do (invariant cdr output)
  \
  if not cdr then
    return
  end
  (local block {})
  (local count \#cdr)
  \
  for i, value in ipairs(cdr) do
    local stat
    if i < count then
      stat = compile_stat(invariant, value, block)
    else
      stat = to_stat(compile_exp(invariant, value, block))
    end
    if stat then
      table.insert(block, stat)
    end
  end
  `\do \,(unpack block) end)

{
  lua = {
    ["do"] = {expize=expize_do, statize=statize_do}
  }
}
