local utils = require("leftry").utils
local lua = require("l2l.lua")
local list = require("l2l.list")
local vector = require("l2l.vector")

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

-- Returns byte at `position` in `invariant.source`.
local function byteat(invariant, position)
  return string.char(invariant.source:byte(position))
end

local symbol = utils.prototype("symbol", function(symbol, name)
  return setmetatable({name}, symbol)
end)

local function hash(text)
  if utils.hasmetatable(text, symbol) then
    text = text[1]
  end
  local prefix = ""
  if text == "..." then
    return "..."
  end
  if lua_keyword[text] then
    pattern = "(.)"
    prefix = text
  else
    pattern = "[^_a-zA-Z0-9.%[%]]"
  end
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

symbol.ids = {}

function symbol:__eq(sym)
  return getmetatable(self) == getmetatable(sym) and
    tostring(self) == tostring(sym)
end

function symbol:__tostring(sym)
  return "symbol("..utils.escape(tostring(self[1]))..")"
end

function symbol:hash()
  return hash(self[1])
end

local function read_symbol(invariant, position)
  local source, rest = invariant.source
  local R = invariant.R
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

local function read_right_paren(invariant, position)
  error("unmatched right parenthesis")
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
  local source, rest = invariant.source
  local size = #invariant.source
  local t = vector()
  local ok, rest, value = true, position + 1
  while ok do
    if rest > size then
      error("no bytes")
    end
    local index = rest
    ok, rest, values = readifnot(invariant, rest, read_right_paren)
    if ok then
      for i, value in ipairs(values) do
        t:insert(value)
      end
    end
  end

  -- Add 1 for the right_paren.
  return rest + 1, vector(list.cast(t))
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

local function read_semicolon(invariant, position)
  return position + 1, {}
end

local function read_lua(invariant, position)
  local rest, value = lua.Exp(invariant, position + 1)
  return rest, {value}
end

local function read_lua_comment(invariant, position)
  local rest, value = lua.Comment(invariant,
    skip_whitespace(invariant, position))
  return rest, {}
end

local function read_lua_number(invariant, position)
  local rest, value = lua.Numeral(invariant, position)
  return rest, {value}
end

local function read_lua_literal(invariant, position)
  local rest, value = lua.Exp(invariant, position)
  return rest, {value}
end

function readifnot(invariant, position, stop)
  local R, source = invariant.R, invariant.source
  local rest, macro = position

  if position > #source then
    return false
  end

  local values

  while (not macro or not values) and rest <= #source do
    local byte = source:byte(rest)
    local index = matchreadmacro(R, byte)
    local origin = rest
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

local function transform(invariant, data)
  local T = invariant.T
  if utils.hasmetatable(data, list) then
    local car, cdr = data:car(), data:cdr()
    if utils.hasmetatable(car, symbol) and T[car[1]] then
      for i, transformer in ipairs(T[car[1]]) do
        data = transformer(invariant, cdr)
      end
    end
  end
  return data
end

local function transform_extension(invariant, cdr)
  if cdr then
    local cadr, cddr = cdr:car(), cdr:cdr()
    if cadr == symbol("LANGUAGE") and cddr then
      local caddr = cddr:car()
      if utils.hasmetatable(caddr, symbol) then
        local mod = caddr[1]
        local f = require(mod)
        assert(type(f) == "function", "-# LANGUAGE function missing.")
        f(invariant)
        return lua_none
      end
    end
  end
  return data
end

local function environ(source, position)
  return {
    events = {},
    L = {},
    T = {
      ["-#"] = {transform_extension}
    },
    R = {
      [string.byte("\\")] = {read_lua},
      [string.byte("(")] = {read_list},
      [string.byte(";")] = {read_semicolon},
      [string.byte(")")] = {read_right_paren},
      [string.byte('{')] = {read_lua_literal},
      [string.byte('"')] = {read_lua_literal},
      [string.byte("-")] = {read_lua_number, read_lua_comment, read_symbol},

      -- Implement skip_whitespace as a single byte read macro, because
      -- skip_whitespace is the most common read_macro evaluated and pattern
      -- macros are relatively expensive.
      [string.byte(" ")]={skip_whitespace},
      [string.byte("\t")]={skip_whitespace},
      [string.byte("\n")]={skip_whitespace},
      [string.byte("\r")]={skip_whitespace},

      -- Pattern indices should not overlap with any other pattern index.
      ["[0-9]"]={read_lua_literal},

      -- Default read macro.
      {read_symbol}
    },
    source = source
  }, position or 1
end

local function read(invariant, position)
  return select(2, readifnot(invariant, position or 1))
end

local function register_R(invariant, character, f)
  local R = invariant.R
  local byte = string.byte(character)
  R[byte] = R[byte] or {}
  table.insert(R[byte], f)
end

local function register_T(invariant, name, f)
  local T = invariant.T
  T[name] = T[name] or {}
  table.insert(T[name], f)
end

return {
  lua_none = lua_none,
  read = read,
  transform = transform,
  environ = environ,
  read_lua = read_lua,
  read_list = read_list,
  read_right_paren = read_right_paren,
  read_lua_literal = read_lua_literal,
  read_quasiquote = read_quasiquote,
  read_quasiquote_eval = read_quasiquote_eval,
  read_quote = read_quote,
  read_symbol = read_symbol,
  register_R=register_R,
  register_T=register_T,
  symbol=symbol,
  skip_whitespace = skip_whitespace
}

