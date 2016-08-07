#import local
#import fn
#import quasiquote

(fn compile_do_exp (invariant cdr output)
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

(fn compile_do_stat (invariant cdr output)
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
    ["do"] = {expize=compile_do_exp, statize=compile_do_stat}
  }
}
