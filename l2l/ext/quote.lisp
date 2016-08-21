\
local utils = require("leftry.utils")
local function compile_quote(invariant, cdr, output)
  assert(list.__len(cdr) == 1, "quote only accepts one parameter.")
  local cadr = cdr:car()
  if lua_ast[getmetatable(cadr)] then
    return cadr:repr()
  end
  if utils.hasmetatable(cadr, list) then
    return cadr:repr()
  end
  return cadr
end

local function read_quote(invariant, position)
  local rest, values = read(invariant, position + 1)
  if rest then
    values[1] = list(symbol("quote"), values[1])
    return rest, values
  end
end

{
  lua = {
    ["quote"] = {expize=compile_quote, statize=compile_quote}
  },
  read = {
    ["'"] = {read_quote}
  }
}
