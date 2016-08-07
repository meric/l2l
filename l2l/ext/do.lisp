#import local
#import fn
#import quasiquote

\--[[
Usage:
  (do
    (local x 1)
    (local y 2)
    (+ x y))
]]

(fn expize_do (invariant cdr output)
  \
  if not cdr then
    return lua_nil()
  end
  (local block {})
  (local len \#cdr)
  (local var (lua_name:unique "_do"))
  (table.insert output `\local \,var)
  \
  for i, value in ipairs(cdr) do
    if i < len then
      local stat = compile_stat(invariant, value, block)
      if stat then
        table.insert(block, stat)
      end
    else
      table.insert(block, \`\\,var = \,(compile_exp invariant value block))
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
  \
  for i, value in ipairs(cdr) do
    local stat = compile_stat(invariant, value, block)
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
