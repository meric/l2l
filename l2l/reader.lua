--local module_path = (...):gsub('reader$', '')
local module_path = "l2l."
local import = require(module_path .. "import")
local exception = require(module_path .. "exception")
local raise = exception.raise

local itertools = require(module_path .. "itertools")
local pack, pair, tolist = itertools.pack, itertools.pair, itertools.tolist


-- Create a new type `symbol`.
symbol = setmetatable({
  __tostring = function(self)
    return tostring(self[1])
  end,
  __eq = function(self, other)
    return getmetatable(self) == getmetatable(other) and
      tostring(self) == tostring(other)
  end
}, {__call = function(self, name)
    return setmetatable({name}, symbol)
  end})
symbol.__index = symbol

local function tofile(data)
  local tmpfile = io.tmpfile()
  tmpfile:write(tostring(data))
  tmpfile:seek("set")
  return tmpfile
end

local EOFException =
  exception.exception("End of file")

local UnmatchedRightBracketException =
  exception.exception("Unmatched right bracket.")

local UnmatchedRightBraceException =
  exception.exception("Unmatched right brace.")

local UnmatchedLeftBracketException =
  exception.exception("Unmatched left bracket.")

local UnmatchedLeftBraceException =
  exception.exception("Unmatched left brace.")

local UnmatchedRightParenException =
  exception.exception("Unmatched right parenthesis.")

local UnmatchedLeftParenException = 
  exception.exception(
    function(self, stream, position)
      local index = stream:seek("cur")
      local src = stream:seek("set", 0) and stream:read("*all")
      stream:seek("set", index)
      local messages = exception.formatsource(src,
        "Unmatched left parenthesis.\nLeft parenthesis", position)
      table.insert(messages, "")
      return table.concat(messages, "\n").."Missing right parenthesis detected"
    end)

local UnmatchedDoubleQuoteException =
  exception.exception("Unmatched double quote.")

local UndefinedDispatchMacroException =
  exception.exception("Undefined dispatch macro.")


local function read_number(stream, byte)
  local number = ""
  repeat
    number = number..byte
    byte = stream:read(1)
  until not byte or byte:match("%s") or not tonumber(number..tostring(byte))
  if byte then    
    stream:seek("cur", -1)
  end
  return tonumber(number)
end

local function read_symbol(stream, byte)
  local sym = ""
  repeat
    sym = sym..byte
    byte = stream:read(1)
  until (_R[byte] and byte ~= ".") or not byte or byte:match("%s")
  if byte then
    stream:seek("cur", -1)
  end
  return symbol(sym)
end

--- Reads a lisp expression from string.
-- @param input (Optional) An input stream, by default the current stream.
local function read(input, suppress_eof_error)
  input = input or io.input()
  local byte
  repeat
    byte = input:read(1)
    local count, objs
    if _R[byte] then
      objs, count = pack(_R[byte](input, byte))
    elseif byte then
      if byte:match('-') then
        if input:read(1):match('[0-9]') then
          input:seek("cur", -1)
          objs, count = pack(read_number(input, byte))
        else
          input:seek("cur", -1)
          objs, count = pack(read_symbol(input, byte))
        end
      elseif byte:match('[0-9]') then
        objs, count = pack(read_number(input, byte))
      elseif not byte:match('%s') then
        objs, count = pack(read_symbol(input, byte))
      end
    end
    if count and count > 0 then
      return table.unpack(objs, 1, count)
    end
  until byte == nil
  input:seek("cur", -1)
  if suppress_eof_error then
    return
  end
  raise(EOFException(input))
end 

local function _read(stream, exceptions)
  local objs, count = pack(pcall(read, stream))
  local ok = table.remove(objs, 1)
  if ok then
    return table.unpack(objs, 1, count - 1)
  else
    local except = objs[1]
    if exceptions[getmetatable(except)] then
      exceptions[getmetatable(except)](except)
    elseif type(except) ~= "string" then
      raise(except)
    else
      error(except)
    end
  end
end

local function with_R(newR, f, ...)
  local R = _R
  _G._R = setmetatable(newR, {__index = R})
  local objs, count = pack(f(...))
  _G._R = R
  return table.unpack(objs, 1, count)
end

local function read_hash_literal(stream, byte)
  return symbol("#")
end

local function read_comment(stream, byte)
  repeat
    byte = stream:read(1)
  until not byte or byte == "\n"
end

local function read_right_paren(stream, byte)
  raise(UnmatchedRightParenException(stream))
end

local function read_right_brace(stream, byte)
  raise(UnmatchedRightBraceException(stream))
end

local function read_right_bracket(stream, byte)
  raise(UnmatchedRightBracketException(stream))
end

local function read_string(stream)
  local str, byte = "", ""
  local escaped = false
  repeat
    if not escaped and byte == '\\' then
      escaped = true
    else
      if escaped and byte == "n" then
        byte = "\n"
      end
      str = str..byte  
      escaped = false
    end
    byte = stream:read(1)
  until not byte or (byte:match('"') and not escaped)
  if not byte then
    raise(UnmatchedDoubleQuoteException(stream:seek("cur", -1) and stream))
  end
  return str
end

local function read_attribute(stream, byte)
  local position = stream:seek("cur")
  local char = stream:read(1)
  stream:seek("set", position)

  if char and (char:match("%s") or char:match("[.]")) then
    stream:seek("set", position)
    return with_R({["."] = false}, read_symbol, stream, byte)
  end

  local act = nil
  local attr = _read(stream, {
      [UnmatchedRightParenException] = function(Exception)
        act = false
      end
    })

  if act == false then
    stream:seek("set", position)
    return read_symbol(stream, byte)
  end
  
  local obj = _read(stream, {
      [UnmatchedRightParenException] = function(Exception)
        act = false
        stream:seek("set", position)
      end
    })

  if act == false then
    stream:seek("set", position)
    return read_symbol(stream, byte)
  end
  return symbol(byte), tostring(attr), obj
end

local read_method = read_attribute


local function read_vector(stream, byte)
  local orig = {}
  local parameters = {}
  while true do
    local rightbracket = false
    local append, count = pack(_read(stream, {
      [UnmatchedRightBracketException] = function(Exception)
        rightbracket = true
      end,
      [EOFException] = function(Exception)
        raise(UnmatchedLeftBracketException(stream))
      end
    }))
    for i=1, count, 2 do
      local obj = append[i]
      table.insert(parameters, obj)
    end
    if rightbracket then
      return pair({symbol("vector"), tolist(parameters)})
    end
  end
end

local function read_table(stream, byte)
  local orig = {}
  local parameters = {}
  while true do
    local rightbrace = false
    local append, count = pack(_read(stream, {
      [UnmatchedRightBraceException] = function(Exception)
        rightbrace = true
      end,
      [EOFException] = function(Exception)
        raise(UnmatchedLeftBraceException(stream))
      end
    }))
    for i=1, count, 2 do
      local obj = append[i]
      table.insert(parameters, obj)
    end
    if rightbrace then
      return pair({symbol("dict"), tolist(parameters)})
    end
  end
end

local function read_list(stream, byte)
  local objs = nil
  local orig = nil
  local position = stream:seek("cur")

  -- local R = _R
  local index = 1

  return with_R({
    ["."] = read_attribute,
    [":"] = read_method,
  }, function()
    while true do
      local rightparen = false
      local append, count = pack(_read(stream, {
        [UnmatchedRightParenException] = function(Exception)
          rightparen = true
        end,
        [EOFException] = function(Exception)
          raise(UnmatchedLeftParenException(stream, position))
        end
      }))
      local _position = stream:seek("cur")
      for i=1, count do
        local obj = append[i]
        if objs == nil then
          orig = pair({obj, nil})
          objs = orig
          _R.META[orig] = {
            [0] = _position,
            [index] = _position
          }
        else
          objs[2] = pair({obj, nil})
          objs = objs[2]
          _R.META[orig][index] = _position
        end
        index = index + 1
      end
      if rightparen then
        return orig
      end
    end
  end)
end

local function read_table_quote(stream)
  return pair({symbol('table-quote'), tolist({read(stream)})})
end

local function read_quote(stream)
  return pair({symbol('quote'), tolist({read(stream)})})
end

local function read_quasiquote(stream)
  return pair({symbol('quasiquote'), tolist({read(stream)})})
end

local function read_quasiquote_eval(stream)
  return pair({symbol('quasiquote-eval'), tolist({read(stream)})})
end

local function read_negative(stream)
  local byte = stream:read(1)
  stream:seek("cur", -1)
  if not byte:match(" ") then
    return pair({symbol('-'), tolist({read(stream)})})
  else
    return symbol('-')
  end
end

local function read_dispatch_macro(stream)
  local byte = stream:read(1)
  if not byte then
    raise(EOFException(stream:seek("cur", -1) and stream))
  elseif not _D[byte] then
    raise(UndefinedDispatchMacroException(stream))
  else
    local objs, count = pack(_D[byte](stream, byte))
    if count > 0 then
      return table.unpack(objs, 1, count)
    end
  end
end


-- Dispatch character table. See `read_dispatch_macro`.
_D = {
--  ['\\'] = read_character,
  ['\''] = read_table_quote,
  [' '] = read_hash_literal
}

-- Read macro table. See `read`.
-- A read macro table entry can be swapped during read time to modify the
-- reader while it is reading. Use `with_R` to swap a read macro table
-- entry temporarily and reset the _R table at the end of the operation.
_R = {
  -- `META` stores the position of each element read using `read_list`.
  -- Do not swap out META.
  META = {},
  -- `position` is a method for retrieving positions of elements previously
  -- read using read_list, which were stored in META.
  -- Do not swap out position.
  position = function(alist, index)
    if alist and _R.META[alist] then
      return _R.META[alist][index or 0]
    end
  end,
  [';'] = read_comment,
  ['{'] = read_table,
  ['}'] = read_right_brace,
  ['['] = read_vector,
  [']'] = read_right_bracket,
  ['('] = read_list,
  [')'] = read_right_paren,
  ['"'] = read_string,
  ['#'] = read_dispatch_macro,
  ['`'] = read_quasiquote,
  [','] = read_quasiquote_eval,
  ["'"] = read_quote,
}

return {
  tofile = tofile,
  EOFException = EOFException,
  UnmatchedRightParenException = UnmatchedRightParenException,
  UnmatchedLeftParenException = UnmatchedLeftParenException,
  UnmatchedDoubleQuoteException = UnmatchedDoubleQuoteException,
  UndefinedDispatchMacroException = UndefinedDispatchMacroException,
  read = read,
  read_method = read_method,
  read_attribute = read_attribute,
  read_number = read_number,
  read_symbol = read_symbol,
  read_quasiquote = read_quasiquote,
  read_string = read_string,
  read_vector = read_vector,
  read_dispatch_macro = read_dispatch_macro,
  read_list = read_list,
  read_right_bracket = read_right_bracket,
  read_right_brace = read_right_brace,
  read_right_paren = read_right_paren,
  read_quasiquote_eval = read_quasiquote_eval,
  read_table_quote = read_table_quote,
  read_table = read_table,
  read_comment = read_comment,
  read_dispatch_macro = read_dispatch_macro
}
