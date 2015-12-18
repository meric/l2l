local itertools = require("l2l.itertools")
local operator = require("l2l.operator")

local list, show, bind = itertools.list, itertools.show, itertools.bind
local scan, map, span = itertools.scan, itertools.map, itertools.span
local last, id, flip = itertools.last, itertools.id, itertools.flip
local cons, pack, zip = itertools.cons, itertools.pack, itertools.zip
local car, cdr, tolist = itertools.car, itertools.cdr, itertools.tolist
local foreach = itertools.foreach
local exception = require("l2l.exception2")
local raise = exception.raise

local UnmatchedRightParenException =
  exception.Exception("Unmatched right parenthesis.")
local EOFException =
  exception.Exception("End of file")
local UnmatchedReadMacroException =
  exception.Exception("Cannot find matching read macro for byte '%s'.")
local UnmatchedLeftParenException =
  exception.Exception("Unmatched left parenthesis.")

-- Create a new type `symbol`.
local symbol = setmetatable({
  __tostring = function(self)
    return tostring(self[1])
  end,
  __eq = function(self, other)
    return getmetatable(self) == getmetatable(other) and
      tostring(self) == tostring(other)
  end
}, {__call = function(symbol, name)
    return setmetatable({name}, symbol)
  end})

symbol.__index = symbol


--- Returns a function that returns whether it's argument `text` matches
-- against any pattern in `...`.
-- @params pattern the lua pattern
local function match(...)
  local patterns = {...}
  return function(text)
    assert(type(text) == "string", type(text))
    for i, pattern in ipairs(patterns) do
      local matches = text:match(pattern)
      if matches then
        return matches
      end
    end
  end
end

--- Returns the index of the read macro in `environment._R` that should be 
-- evaluated, given the next byte is `byte`.
-- @param environment The environment
-- @param byte The next byte.
local function matchreadmacro(environment, byte)
  -- Keep in mind this function is run a lot, everytime an expression needs
  -- to be read, which is all the time during compilation.
  if not byte then
    return nil
  end
  local _R = environment._R

  -- O(1) Single byte macros.
  if _R[byte] and #_R[byte] > 0 then
    return byte
  else
    -- O(N) Pattern macros; N = number of read macro indices.
    for pattern, _ in pairs(_R) do
      if type(pattern) == "string"  -- Ignore default macro.
          and #pattern > 1          -- Ignore single byte macro.
          and byte:match(pattern)   -- Matches pattern.
          and _R[pattern]           -- Is not `false`.
          and #_R[pattern] > 0 then -- Pattern has read macros.
        return pattern
      end
    end
  end

  -- O(N) Default macros; N = number of read macro indices.
  return 1
end

--- Evaluate a function with an environment whose read macro table is patched
-- with `R`. Assign `false` to a read macro index in `R` to hide it from `f`.
-- Example of how to remove the `"("` `read_list` read macro.:
-- ```
--    local value, rest = with_R({
--      _META={},
--      _R = default_R()
--    }, {["("] = false}, function(environment)
--      return read(environment, tolist(" (a)"))
--    end)
-- ```
-- @param environment The environment
-- @param R new _R read macro table that will inherit the existing one.
-- @param f function that will be evaluated with `environment` as the first
--          argument.
-- @param ... Arguments that will be given to `f`.
local function with_R(environment, R, f, ...)
  local _R = environment._R
  local newR = {}
  for k, v in pairs(_R) do
    newR[k] = v
  end
  for k, v in pairs(R or {}) do
    newR[k] = v
  end
  environment._R = newR
  local objs, count = pack(f(environment, ...))
  environment._R = _R
  return table.unpack(objs, 1, count)
end

local default_R

local function environ(bytes)
  return {
    _META={
      origin=bytes,
      source=list.concat(bytes, "")
    }
  }
end

local function execute(reader, environment, bytes)
  environment = environment or environ(bytes)
  local values, rest = reader(environment, bytes)
  if bytes and values and rest ~= bytes then
    environment._META[bytes] = {read=reader, values=values}
  end
  return values, rest
end

--- Returns a list of Lua values read from next lisp expression, from `bytes`,
-- as well as list of remaining bytes that have not been read.
-- @param environment the context to read the bytes with.
-- @param bytes a list of strings, each one character long.
-- @return list of values from next lisp expression, list of remaining bytes
local function read(environment, bytes)
  environment = environment or {_META={}, _R=default_R()}

  -- Store the entry point to the program.
  if not environment._META.origin then
    environment._META.origin = bytes
    environment._META.source = list.concat(bytes, "")
  end

  -- Reading an expression, but no bytes available, is an error.
  if not bytes then
    raise(EOFException(environment, bytes))
  end
  local byte, rest = car(bytes), cdr(bytes)
  local index = matchreadmacro(environment, byte)
  local _R = environment._R
  
  for i, reader in ipairs(_R[index] or {}) do
    if reader then
      local values, rest = execute(reader, environment, bytes)
      -- A read macro return nil to indicate it does not match and the reader
      -- should continue.
      if values ~= nil or rest ~= bytes then
        return values, rest
      end
    end
  end
  raise(UnmatchedReadMacroException(environment, bytes, byte))
end

--[[
optimise scan, span, map
]]

local function read_predicate(environment, transform, predicate, bytes)
  local token = ""
  local previous = nil
  while true do
    if not bytes then
      break
    end
    local byte = bytes[1]
    previous = token
    token = token..byte
    if not predicate(token, byte) then
      token = previous
      break
    end
    bytes = bytes[2]
  end
  if #token == 0 then
    return nil, bytes
  end
  return list(transform(token)), bytes
end

--[[
-- Slow
local function read_predicate(environment, transform, predicate, bytes)
  local tokens, rest = span(car,
    map(function(token, byte) return
        predicate(token, byte) and {token, byte} or {nil, byte}
      end, scan(operator[".."], "", bytes), bytes))
  tokens = map(car, tokens)
  rest = map(cdr, rest)
  local value = (transform or id)(last(tokens))
  return tolist({value}), rest
end
]]--

local function read_symbol(environment, bytes)
  -- Any byte that is not defined as a read macro can be part of a symbol.
  -- ".", "-" and "[0-9]" can always be part of a symbol if it is not the first
  -- character.
  return read_predicate(environment,
    symbol, function(token, byte)
      return byte
        and (matchreadmacro(environment, byte) == 1
          or byte == "."
          or byte == "-"
          or byte:match("[0-9]"))
    end, bytes)
end

local function read_number(environment, bytes)
  local negative, rest = read_predicate(environment,
    id, bind(operator["=="], "-"), bytes)
  local numbers, rest = read_predicate(environment,
    tonumber, match("^%d+%.?%d*$", "^%d*%.?%d+$"), rest)
  if not numbers then
    -- Not a number.
    return nil, bytes
  end
  local number = car(numbers)
  return list(negative and -number or number), rest
end

local function read_quote(environment, bytes)
  local values, rest = read(environment, cdr(bytes))
  return list(cons(symbol('quote'), values)), rest
end

local function read_right_paren(environment, bytes)
  raise(UnmatchedRightParenException(environment, bytes))
end

local function read_whitespace(environment, bytes)
  return read_predicate(environment, id,
    match("^%s+$"), bytes)
end

--- Return next expression after whitespace.
-- @param environment The environment.
-- @param bytes List of bytes to read from.
local function skip_whitespace(environment, bytes)
  local values, rest = execute(read_whitespace, environment, bytes)
  return read(environment, rest)
end

local function read_lua(environment, bytes)
  local lua = require("l2l.lua")
  -- lua.lua_R()
  local dollar, rest = skip_whitespace(environment, cdr(bytes))

  if car(dollar) ~= symbol("$") then
    return nil, bytes
  end

  local values, rest = with_R(environment, lua.block_R(),
    function()
      return read(environment, rest)
    end)

  local ok, parens
  ok, parens, after = pcall(read, environment, rest)
  if ok or getmetatable(parens) ~= UnmatchedRightParenException then
    raise(UnmatchedLeftParenException(environment, cdr(bytes)))
  end
  return values, cdr(rest)
end

local function read_list(environment, bytes)
  local origin = list(nil)
  local last = origin
  local rest = bytes[2]
  return with_R(environment, {
    -- ["."] = cons(read_attribute, environment._R["."]),
    -- [":"] = cons(read_method, environment._R[":"])
  }, function()
    local ok, value, _ = true
    while ok do
      ok, values, rest = pcall(read, environment, rest)
      if ok then
        last[2] = values
        last = last[2] or last
      elseif getmetatable(values) == UnmatchedRightParenException then
        return tolist({origin[2]}), cdr(values.bytes)
      else
        raise(values)
      end
    end
  end)
end

--- Return the default _R table.
function default_R()
  return {
    -- Single byte read macros are prioritised.
    ["("] = list(read_lua, read_list),
    [")"] = list(read_right_paren),
    -- ['{'] = read_table,
    -- ['}'] = read_right_brace,
    -- ['['] = read_vector,
    -- [']'] = read_right_bracket,
    -- ['"'] = read_string,
    -- ['#'] = read_dispatch_macro,
    -- ['`'] = read_quasiquote,
    -- [','] = read_quasiquote_eval,
    ["'"] = list(read_quote),

    ["-"]=list(read_number, read_symbol),

    -- Implement skip_whitespace as a single byte read macro, because
    -- skip_whitespace is the most common read_macro evaluated and pattern
    -- macros are relatively expensive.
    [" "]=list(skip_whitespace),
    ["\t"]=list(skip_whitespace),
    ["\n"]=list(skip_whitespace),
    ["\r"]=list(skip_whitespace),
    ["\r\n"]=list(skip_whitespace),

    -- Pattern indices should not overlap.
    ["[0-9]"]=list(read_number),

    -- Default pattern
    list(read_symbol)
  }
end

if debug.getinfo(3) == nil then
  -- (print ($ ))
  --[[
  (print ($ 
    local $x = 1;
    local $y =1;
    local $z={f=1}
    return x y z.f)
  ]]--
  local values, rest = read(nil, tolist([[
    (print
      ($ return (b))
    )]]))
  -- ($ while(nil)do return(nil),nil end)
  print(values, rest)
  for i, value in ipairs(cdr(car(values))) do
    -- print(value:is_valid())
    print(show(value:representation()))
  end
end

-- (. mario x y)
-- print(value, rest)

return {
  symbol = symbol,
  read = read,
  with_R = with_R,
  default_R = default_R,
  skip_whitespace = skip_whitespace,
  read_whitespace = read_whitespace,
  execute = execute,
  read_predicate = read_predicate,
  read_number = read_number,
  match=match
}
