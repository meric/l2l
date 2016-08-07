requires https://github.com/meric/leftry cloned as a sibling to this repo.

```
lua l2l/test.lua
```

See [do.lisp](/meric/l2l/blob/rewrite/l2l/ext/do.lisp) for an example.

`do.lisp` implements the `(do ...)` special form.

`do.lisp` compiles into:

```lua
--4027068.2
local lua = require("l2l.lua")
local lua_namelist = lua.lua_namelist
local compiler = require("l2l.compiler")
local compile_exp = compiler.compile_exp
local lua_block = lua.lua_block
local lua_do = lua.lua_do
local lua_explist = lua.lua_explist
local lua_nil = lua.lua_nil
local compile_stat = compiler.compile_stat
local lua_varlist = lua.lua_varlist
local lua_name = lua.lua_name
local lua_assign = lua.lua_assign
local lua_local = lua.lua_local

local function expize_do(invariant,cdr,output)
  if not cdr then return lua_nil() end
  local block = {};
  local len =  # cdr;
  local var = lua_name:unique("_do");
  table.insert(output,
    lua_block({
      lua_local.new(
        lua_namelist({var}))
      }));
  for i, value in ipairs(cdr) do
    if i < len then
      local stat = compile_stat(invariant,value,block);
      if stat then
        table.insert(block,stat)
      end
    else
      table.insert(block,
        lua_block({
          lua_assign.new(
            lua_varlist({var}),
              lua_explist({
                compile_exp(invariant,value,block)
              }))
        }))
    end
  end;
  table.insert(output,
    lua_block({
      lua_do.new(
        lua_block({
          lua_block({unpack(block)})
        }))
    }));
  return var
end

local function statize_do(invariant,cdr,output)
  if not cdr then return  end;
  local block = {};
  for i,value in ipairs(cdr) do
    local stat = compile_stat(invariant,value,block);
    if stat then table.insert(block,stat) end
  end;
  return lua_block({
    lua_do.new(
      lua_block({
        lua_block({unpack(block)})
      }))
  })
end

return {
  lua={
    ["do"]={expize=expize_do,statize=statize_do}
  }
}
```
