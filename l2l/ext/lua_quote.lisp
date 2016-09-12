@import local

(local quote (require "l2l.ext.quote"))

{
  lua = {
    ["lua_quote"] = {
        expize=quote.lua.quote.expize,
        statize=quote.lua.quote.statize,
        in_lua=true
    }
  }
}
