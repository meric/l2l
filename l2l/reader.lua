local utils = require("leftry").utils
local lua = require("l2l.lua")
local list = require("l2l.list")
local vector = require("l2l.vector")
local ipairs = require("l2l.iterator")
local len = require("l2l.len")

local lua_keyword = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["for"] = true,
  ["function"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["until"] = true,
  ["while"] = true
}

local read, readifnot

local lua_none = setmetatable({}, {__tostring = function()
  return "lua_none"
end})

local function matchreadmacro(R, byte)
  if not byte or not R then
    return nil
  end
  if R[byte] then
    for i=1, #R[byte] do
      if R[byte][i] then
        return byte, R[byte]
      end
    end
  else
    -- O(N) Pattern macros; N = number of read macro indices.
    for pattern, _ in pairs(R) do
      if type(pattern) == "string"  -- Ignore default macro.
          and #pattern > 1          -- Ignore single byte macro.
          and string.char(byte):match(pattern)   -- Matches pattern.
          and R[pattern]           -- Is not `false`.
          and #R[pattern] > 0 then -- Pattern has read macros.
        return pattern
      end
    end
  end

  -- O(N) Default macros; N = number of read macro indices.
  return 1, R[1]
end



local symbol = utils.prototype("symbol", function(symbol, name)
  if not symbol.cache[name] then
    symbol.cache[name] = setmetatable({name}, symbol)
  end
  return symbol.cache[name]
end)

symbol.cache = {}

local function _mangle(text)
  if text == "-" then
    return "_45"
  end
  if utils.hasmetatable(text, symbol) then
    text = text[1]
  end
  local prefix, pattern = ""
  if text == "..." then
    return "..."
  end
  if lua_keyword[text] then
    pattern = "(.)"
    prefix = text
  else
    pattern = "[^:_a-zA-Z0-9.%[%]]"
  end
  text = text:gsub("[.][.]", "_dot_dot")
  return prefix..text:gsub(pattern, function(char)
    if char == "-" then
      return "_"
    elseif char == "!" then
      return "_bang"
    else
      return "_"..char:byte()
    end
  end)
end

local function mangle(text)
  if text:find("[.][.]") and text ~= '...'  and text ~= '..' then
    error("Lisp names cannot have two dots consecutively unless "..
      "it is the vararg `...` or concatenate `..`")
  end
  if not text:find("[.][.]") then
    local sections = {}
    for section in text:gmatch("[^.]+") do
      table.insert(sections, _mangle(section))
    end
    return table.concat(sections, ".")
  end
  return _mangle(text)
end

function symbol:__eq(sym)
  return getmetatable(self) == getmetatable(sym) and
    self:mangle() == sym:mangle()
end

function symbol:__tostring()
  return "symbol("..utils.escape(tostring(self[1]))..")"
end

function symbol:mangle()
  return mangle(self[1])
end

function symbol:__index(k)
  if k == "name" then
    return self[1]
  end
  return symbol[k]
end

local function read_symbol(invariant, position)
  local source, rest = invariant.source
  local R = invariant.read
  local dot, zero, nine, minus = 46, 48, 57, 45
  for i=position, #source do
    local byte = source:byte(i)
    rest = i + 1
    if not byte or (matchreadmacro(R, byte) ~= 1
        and byte ~= dot and byte ~= minus
        and not (byte >= zero and byte <= nine)) then
      rest = rest - 1
      break
    end
  end

  if not rest or rest == position then
    return
  end

  return rest, {symbol(source:sub(position, rest-1))}
end

local function read_right_paren()
  error("unmatched right parenthesis")
end

local function read_length(invariant, position)
  local rest, values = read(invariant, position + 1)
  if rest then
    if not values[1] then
      error('nothing to length')
    end
    values[1] = lua.lua_unop_exp.new(lua.lua_unop("#"), values[1])
    return rest, values
  end
end

local function read_quote(invariant, position)
  local rest, values = read(invariant, position + 1)
  if rest then
    if not values[1] then
      error('nothing to quote')
    end
    values[1] = list(symbol("quote"), values[1])
    return rest, values
  end
end

local function read_list(invariant, position)
  local size = #invariant.source
  local t = vector()
  local ok, rest, values = true, position + 1
  while ok do
    if rest > size then
      error("no bytes")
    end
    ok, rest, values = readifnot(invariant, rest, read_right_paren)
    if ok then
      for _, value in ipairs(values) do
        t:insert(value)
      end
    end
  end

  if not rest then
    return
  end

  local value = list.cast(t)
  -- Add 1 for the right_paren.
  if value then
    invariant.index[value] = {position, rest + 1}
  end
  return rest + 1, vector(value)
end

local function read_right_brace()
  error("unmatched right brace")
end

local function read_dict(invariant, position)
  local size = #invariant.source
  local t = vector()
  local ok, rest, values = true, position + 1
  while ok do
    if rest > size then
      error("no bytes")
    end
    ok, rest, values = readifnot(invariant, rest, read_right_brace)
    if ok then
      for _, value in ipairs(values) do
        t:insert(value)
      end
    end
  end

  if not rest then
    return
  end

  local n = #t
  if n % 2 == 1 then
    error("table dictionary constructor requires an even number of expressions")
  end

  local parameters = {}
  for i = 1, n, 2 do
    local k = t[i]
    -- sugar for string keys
    if utils.hasmetatable(k, symbol) then
      local first = string.sub(k.name, 1, 1)
      if first == "." then
        k = lua.lua_string(k.name:sub(2))
      end
    end
    table.insert(parameters, lua.lua_field_key.new(k, t[i+1]))
  end

  local value = lua.lua_table.new(lua.lua_fieldlist(parameters))
  -- Add 1 for the right_brace.
  if value then
    invariant.index[value] = {position, rest + 1}
  end
  return rest + 1, {value}

end

local whitespace = {
  [string.byte(" ")] = true,
  [string.byte("\t")] = true,
  [string.byte("\r")] = true,
  [string.byte("\n")] = true
}

local function skip_whitespace(invariant, position)
  local source, rest = invariant.source
  for i=position, #source do
    if not whitespace[source:byte(i)] then
      rest = i
      break
    end
  end
  -- If no values returned, readifnot will keep advancing, which is what we
  -- want for skip_whitespace.
  return rest
end

local function read_semicolon(_, position)
  return position + 1, {}
end

local function read_lua(invariant, position)
  local rest, value = lua.Block(invariant, position + 1)
  if rest then
    invariant.index[value] = {position, rest}
    return rest, {value}
  end
  rest, value = lua.Exp(invariant, position + 1)
  invariant.index[value] = {position, rest}
  return rest, {value}
end

local function read_lua_comment(invariant, position)
  local rest, value = lua.Comment(invariant,
    skip_whitespace(invariant, position))
  if rest then
    if value then
      invariant.index[value] = {position, rest + 1}
    end
    return rest, {}
  end
end

local function read_lua_number(invariant, position)
  local rest, value = lua.Numeral(invariant, position)
  if rest then
    return rest, {value}
  end
end

local function read_lua_string(invariant, position)
  local rest, value = lua.LiteralString(invariant, position)
  if rest then
    return rest, {value}
  end
end

local function read_lua_literal(invariant, position)
  local rest, value = lua.Exp(invariant, position)
  if not value then
    -- not a valid lua literal
    return
  end
  invariant.index[value] = {position, rest}
  return rest, {value}
end

function readifnot(invariant, position, stop)
  local R, source = invariant.read, invariant.source
  local rest, macro = position

  if position > #source then
    return false
  end

  local values

  while (not macro or not values) and rest <= #source do
    local byte = source:byte(rest)
    local index = matchreadmacro(R, byte)
    position = rest
    for i=1, #R[index] do
      macro = R[index][i]
      if stop == macro then
        return false, rest
      end
      rest, values = macro(invariant, rest)
      if rest then
        break
      elseif i < #R[index] then
        rest = position
      end
    end
    if rest and values then
      return true, rest, values
    elseif not rest then
      return false
    end
  end
  return false
end

local function load_extension(invariant, mod, alias)
  -- Special form and Macro extensions can be alias namespaced.
  -- Read macros cannot.
  if mod.lua then
    for k, x in pairs(mod.lua) do
      if utils.hasmetatable(k, symbol) then
        k = k.name
      end
      if alias then
        k = alias .. "." .. k
      end
      invariant.lua[k] = x
    end
  end
  if mod.macro then
    for k, x in pairs(mod.macro) do
      if utils.hasmetatable(k, symbol) then
        k = k.name
      end
      if alias then
        k = alias .. "." .. k
      end
      invariant.macro[k] = x
    end
  end
  if mod.read then
    assert(not alias, "read macros cannot be namespaced.")
    for k, xs in pairs(mod.read) do
      if type(k) == "string" then
        k = string.byte(k)
      end
      for _, x in ipairs(xs) do
        invariant.read[k] = invariant.read[k] or {}
        if not utils.contains(invariant.read[k], x) then
          table.insert(invariant.read[k], x)
        end
      end
    end
  end
end

local function import_extension(_, name, verbose)
  local compiler = require("l2l.compiler")
  local ok, mod = pcall(compiler.import, name, nil, verbose)
  if not ok and string.match(mod, "not found") then
    mod = compiler.import("l2l.ext."..name, {}, verbose)
  end
  if not mod then
    error("cannot load "..name)
  end
  return mod
end

local function dispatch_import(invariant, position)
  local rest, values = read_symbol(invariant, position+1)
  local sym, alias
  if rest then
    sym = values[1]
  else
    rest, values = read_list(invariant, position+1)
    sym = values[1]:car()
    if len(values[1]) > 1 then
      alias = values[1]:cdr():car().name
    end
  end
  if rest then
    local name = sym[1]
    local mod = import_extension(invariant, name, invariant.debug)
    load_extension(invariant, mod, alias)
    return rest, {}
  end
end

local function read_dispatch(invariant, position)
  local rest, values = read_symbol(invariant, position+1)
  if rest then
    local name = values[1]:mangle()
    local dispatches = invariant.dispatch[name]
    if not dispatches then
      error("no dispatch: "..name)
    end
    for _, dispatch in ipairs(dispatches) do
      local r, v = dispatch(invariant, rest)
      if r then
        return r, v
      end
    end
    error("no matched dispatch: "..name)
  end
end

local function expand(invariant, data)
  -- assert(invariant, "missing invariant")
  local origin = data
  local expanded = false
  local _expand = function(value)
    local d, x = expand(invariant, value)
    expanded = expanded or x
    return d
  end
  local macro = invariant.macro
  if utils.hasmetatable(data, list) then
    local car, cdr = data:car(), data:cdr()
    if utils.hasmetatable(car, symbol) and macro[car.name] then
      return expand(invariant, macro[car.name](
        vector.unpack(vector.cast(cdr, _expand)))), true
    else
      data = list.cast(data, _expand)
      invariant.index[data] = invariant.index[origin]
      return data, expanded
    end
  elseif lua.lua_ast[getmetatable(data)] then
    data = data:gsub(list, function(value)
      local d, x = expand(invariant, value)
      expanded = expanded or x
      return d
    end)
    invariant.index[data] = invariant.index[origin]
    return data, expanded
  end
  return data, expanded
end

local function inherit(invariant, source)
  local new = {}
  for k, v in pairs(invariant) do
    if k ~= "source" then
      new[k] = v
    else
      new.source = source
    end
  end
  return new
end


local function environ(source, verbose)
  return {
    debug = verbose or false,
    index = {},
    sourcemap = {},
    events = {},
    macro = {},
    dispatch = {
      ["import"] = {dispatch_import}
    },
    lua = {},
    read = {
      [string.byte("@")] = {read_dispatch},
      [string.byte("#")] = {read_length},
      [string.byte("\\")] = {read_lua},
      [string.byte("(")] = {read_list},
      [string.byte(";")] = {read_semicolon},
      [string.byte(")")] = {read_right_paren},
      [string.byte('{')] = {read_lua_literal, read_dict},
      [string.byte('"')] = {read_lua_string},
      [string.byte("-")] = {read_lua_number, read_lua_comment, read_symbol},
      -- [string.byte("[")] = {read_dict},
      [string.byte("}")] = {read_right_brace},

      -- Implement skip_whitespace as a single byte read macro, because
      -- skip_whitespace is the most common read_macro evaluated and pattern
      -- macros are relatively expensive.
      [string.byte(" ")]={skip_whitespace},
      [string.byte("\t")]={skip_whitespace},
      [string.byte("\n")]={skip_whitespace},
      [string.byte("\r")]={skip_whitespace},

      -- Pattern indices should not overlap with any other pattern index.
      ["[0-9]"]={read_lua_number},

      -- Default read macro.
      {read_symbol}
    },
    source = source:match("^(.-)%s*$")
  }
end

function read(invariant, position)
  return select(2, readifnot(invariant, position or 1))
end


return {
  lua_none = lua_none,
  read = read,
  expand = expand,
  environ = environ,
  load_extension = load_extension,
  import_extension = import_extension,
  inherit = inherit,
  mangle = mangle,
  read_lua = read_lua,
  read_list = read_list,
  read_right_paren = read_right_paren,
  read_dict = read_dict,
  read_right_brace = read_right_brace,
  read_lua_literal = read_lua_literal,
  read_quote = read_quote,
  read_symbol = read_symbol,
  symbol=symbol,
  skip_whitespace = skip_whitespace
}
