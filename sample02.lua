
local ENV = _ENV
local L2L = setmetatable({}, {__index = ENV})
_ENV = L2L

-- Initialize random variables
math.randomseed(os.time()*os.clock())

--- Trim whitespaces from both ends of a string
-- @param self The string to be trimmed.
-- @return The trimmed string.
function string:trim()
  return self:gsub("^%s*(.-)%s*$", "%1")
end

--- Check whether a string begins with a certain prefix.
-- @param self The string to be checked.
-- @param str The prefix to be checked against.
-- @return Whether the string begins with the prefix.
function string:starts(str)
  return self:sub(1, #str) == str
end

--- Convert a string into Lua. Basically just quotes and escapes the string.
-- @param self The string to be converted.
-- @return The Lua string.
function string:tolua() 
  return '"'..self:gsub('"','\\"')..'"' 
end

--- Convert a string into lisp. Basically just quotes and escapes the string.
-- @param self The string to be converted.
-- @return The lisp string.
function string:tolisp() 
  return '"'..self:gsub('"','\\"')..'"' 
end

--- Split a string into lines, conserving empty lines.
-- @param self The string to be split.
-- @return An array of string.
function string:lines()
  self = self:gsub("\r\n", "\n")
  local t = {}
  for line in self:gmatch("([^\n]*)\n") do
    table.insert(t, line)
  end
  table.insert(t, self:match("\n([^\n]*)$"))
  return t
end

string.split = function(str, pattern)
  pattern = pattern or "[^%s]+"
  if pattern:len() == 0 then pattern = "[^%s]+" end
  local parts = {__index = table.insert}
  setmetatable(parts, parts)
  str:gsub(pattern, parts)
  setmetatable(parts, nil)
  parts.__index = nil
  return parts
end

--- Count how many occurrences of `str` is in the string.
-- @param self The string to be searched.
-- @param str The pattern to search for.
-- @return The number of occurrences.
function string:count(str)
  local c  = 0
  for word in self:gmatch(str) do
    c = c + 1
  end
  return c
end

function wrap(value)
  return function() return value end
end

-- Stack is used for keeping track of macro scope, line numbers, and other 
-- metadata independent of the parser.
Stack = {}

-- Create new Stack
setmetatable(Stack, {__tostring = wrap"Stack", __call=function(self)
  return setmetatable({count = 0}, Stack)
end})

Stack.__index = Stack

--- Push an item into the stack.
-- @param self The stack.
-- @param item The item to be pushed into the stack.
-- @return The item pushed into the stack.
function Stack:push(item)
  self.count = self.count + 1
  self[self.count] = item
  return item
end

--- Pop an item from the stack. Up to user to make sure the stack is not empty.
-- @param self The stack.
-- @return The item popped from the stack.
function Stack:pop()
  local item = self[self.count]
  self[self.count] = nil
  self.count = self.count - 1
  return item
end

--- Peek at the top item in the stack.
-- @param self The stack.
-- @return The item at the top.
function Stack:peek()
  return self[self.count]
end

List = {}

-- Create new List, e.g. List(item1, item2, item3)
setmetatable(List, {__tostring = wrap"List", __call=function(self, ...)
  local parameters = {...}
  local last = setmetatable({nil, nil}, List)
  local first = nil
  for index = 1, table.maxn(parameters) do
    last[2] = setmetatable({parameters[index], nil}, List)
    last = last[2]
    if not first then 
      first = last
    end
    first.last = last
  end
  return first
end})

-- Alternative constructor for List
function Pair(a, b)
  local pair = setmetatable({a, b}, List)
  if getmetatable(b) == List then
    pair.last = b.last
  end
  return pair
end

List.__index = List

function List:__tostring()
  return "("..List.concat(map(tostring, self), " ")..")" 
end

function List:tolisp()
  return "("..List.concat(map(tolisp, self), " ")..")" 
end

function List:tolua()
  return "List("..List.concat(map(tolua, self), ",")..")" 
end

function List:__eq(other)
  return self[1] == other[1] and self[2] == other[2] 
end

function List:__add(other)
  local result = Pair()
  map(function(x) 
    result:append(x)
  end, self or {})
  map(function(x) 
    result:append(x)
  end, other or {})
  return result:cdr()
end

function List:__ipairs()
  local index = 0
  return function() 
    if self then 
      local item = self[1] 
      self=self[2] 
      index = index + 1
      return index, item 
    end 
  end 
end

function List:unpack()
  if self then
    return self[1], List.unpack(self[2])
  end
end

function List:append(item)
  local last = List(item)
  if self.last then
    self.last[2] = last
  end
  if not self[2] then
    self[2] = last
  end
  self.last = last
end

function List:concat(str)
  if self == nil then
    return ""
  end
  local result = tostring(self[1])
  if self[2] then
    result = result .. str .. self[2]:concat(str)
  end
  return result
end

function List:cdr()
  if self[2] then
    self[2].last = self.last
  end
  return self[2]
end

-- Vector, Dictionary, Number, Symbol are intermediate types that will only 
-- exist in parse tree during compile time but not be in code during run-time.
Vector = {}

-- Create new Vector, e.g. Vector(item1, item2, item3)
setmetatable(Vector, {__tostring = wrap"Vector", __call=function(self, ...)
  return setmetatable({...}, Vector)
end})

Vector.__index = Vector

function Vector:__tostring()
  return "["..List.concat(map(tostring, self), " ").."]" 
end

function Vector:tolua()
  local t = {}
  for i, v in ipairs(self) do
    table.insert(t, ({genexpr(v, true)})[1])
  end
  return "({"..List.concat(map(tostring, t), ",").."})"
end

function Vector:tolisp()
  return tostring(self)
end

Dictionary = {}

-- Create new Dictionary, e.g. Dictionary(key1, item1, key2, item2)
setmetatable(Dictionary, {__tostring=wrap"Dictionary",__call=function(self, ...)
  local pair = {...}
  local result =  setmetatable({}, Dictionary)
  for i=1, #pair, 2 do
    result[pair[i]] = pair[i+1]
  end
  return result
end})

Dictionary.__index = Dictionary

function Dictionary:__tostring()
  local t = {}
  for k, v in pairs(self) do
    table.insert(t, k)
    table.insert(t, v)
  end
  return "{"..List.concat(map(tostring, t), " ").."}" 
end

function Dictionary:tolua()
  local t = {}
  for k, v in pairs(self) do
    table.insert(t, "["..genexpr(k).."]".." = ".. genexpr(v))
  end
  return "({"..List.concat(map(tostring, t), ",").."})"
end

function Dictionary:tolisp()
  return tostring(self)
end

function id(...)
  return ...
end

-- Map is usable for all types implementing __ipairs
function map(f, l) 
  local result = Pair()
  for i, v in ipairs(l or {}) do 
    result:append(f(v))
  end 
  return List.cdr(result)
end

-- Permute is usable for all types implementing __pairs
-- Basically a map for both key and value
function permute(f, l)
  local result = {}
  for k, v in pairs(l) do
    k, v = f(k, v)
    if k ~= nil then
      result[k] = v
    end
  end
  return result
end

Symbol = {}

-- Create new Symbol, e.g. Symbol("somestring")
setmetatable(Symbol, {__tostring=wrap"Symbol",__call=function(self,token,unique)
  -- If unique==true generate a unique symbol with token as suffix
  if unique then
    local suffix = token
    repeat
      token = "_"
      local charset = "1234567890abcdefghijklmnopqrstuvwxyz"
      for i=1, 4 do
        local index = math.random(1,#charset)
        token = token..string.char((charset):byte(index))
      end
      token = token..suffix
    until not META.symbol[token]
  end
  -- Mark symbol, so we know if name is taken when we are asked to generate a 
  -- unique symbol
  META.symbol[token] = true
  return setmetatable({name=token}, Symbol)
end})

Symbol.__index = Symbol

function Symbol:__tostring()
  return self.name
end

function Symbol:__eq(other)
  if getmetatable(self) ~= Symbol then
    return false
  end
  if getmetatable(other) ~= Symbol then
    return false
  end
  return self.name == other.name
end

function Symbol:tolua()
  return "Symbol("..self.name:tolua()..")"
end

function Symbol:tolisp()
  return tostring(self)
end

function hash(char)
  return "__c"..char:byte().."__" 
end

function tohash(sym)
  return sym:tohash()
end

-- Lua keywords that needs to be allowed in Lisp
L2LNONKEYWORDS ={
  ["and"] = true, 
  ["break"] = true, 
  ["do"] = true, 
  ["else"] = true, 
  ["elseif"] = true, 
  ["end"] = true,
  ["false"] = false,
  ["for"] = true, 
  ["function"] = true, 
  ["if"] = true, 
  ["in"] = true, 
  ["local"] = true, 
  ["nil"] = false, 
  ["not"] = true, 
  ["or"] = true, 
  ["repeat"] = true, 
  ["return"] = true, 
  ["then"] = true, 
  ["true"] = false, 
  ["until"] = true, 
  ["while"] = true
}

function Symbol:tohash()
  local name = tostring(self.name):gsub("[^_a-zA-Z0-9.%[%]\"]", hash)
  
  name = name:gsub("[^.]+", function(word)
    if L2LNONKEYWORDS[word] then
      return word:gsub("(.)", hash)
    end
    return word
  end)

  if name:sub(1,1) == "." then
    return name
  else
    return name:gsub("[.]([^.]+)", "[\"%1\"]")
  end
end

function gensym(suffix)
  if suffix then
    suffix = "_"..suffix
  end
  return Symbol(suffix or "", true)
end

Number = {}

-- Create new Number, e.g. Number(1)
setmetatable(Number, {__tostring=wrap"Number",__call=function(self, number)
  return setmetatable({number=number}, Number)
end})

Number.__index = Number

function Number:__tostring()
  return tostring(self.number)
end

function Number:tolua()
  return tostring(self.number)
end

function Number:tolisp()
  return tostring(self.number)
end

Operator = {}

setmetatable(Operator, {__tostring = wrap"Operator",__call=function(self,lambda)
  return setmetatable({lambda=lambda}, Operator)
end})

Operator.__index = Operator

function Operator:__call(...)
  return self.lambda(...)
end

function Operator:__tostring()
  if _ENV[self] then
    return _ENV[self]
  end
  -- Search and cache name
  for k, v in pairs(_ENV) do
    if v == self then
        _ENV[self] = k
        return _ENV[self]
    end
  end
  _ENV[self] = "<operator:"..tostring(self.lambda)..">"
  return _ENV[self]
end

String = {}

-- Create new String, e.g. Number(1)
setmetatable(String, {__tostring = wrap"string", __call=function(self, str)
  return setmetatable({str=str}, String)
end})

String.__index = String

function String:__tostring()
  return tostring(self.str)
end

for k, v in pairs(string) do
  String[k] = function(self, ...)
    return v(self.str, ...)
  end
end

-- These types can be translated directly into Lua
L2LTYPES =
  {[String] = true,
   [List] = true,
   [Vector] = true,
   [Dictionary] = true,
   [Symbol] = true,
   [Number] = true}

--- Convert parse tree object into Lua. 
-- @param object The object to be converted into Lua string
-- @return The Lua string.
function tolua(object)
  if L2LTYPES[getmetatable(object)] then
    return object:tolua()
  end
  if object == nil then
    return "nil"
  end
  if type(object) == "string" then
    return object:tolua()
  end
  if type(object) == "number" then
    return tostring(object)
  end
  error("Internal Error: "..tostring(object)..", "..type(object))
end

--- Convert parse tree object back into lisp form. (used by macroexpand)
-- @param object The object to be converted into lisp string
-- @return The lisp string.
function tolisp(object)
  if L2LTYPES[getmetatable(object)] or type(object) == "string" then
    return object:tolisp()
  end
  if object == nil then
    return "nil"
  end
  if type(object) == "number" then
    return tostring(object)
  end
  error("Internal Error: "..tostring(object)..", "..type(object))
end

--- Used by `parse` to generate parse tree out of matching symbols describing 
-- data for some data structure. This is done using the "%bxy" syntax in the Lua
-- pattern language. i.e. "()" > List, "{}" > Dictionary, "[]" > Array
-- @param str The string to be parsed.
-- @param left The leftmost symbol. Must have length == 1.
-- @param right The rightmost symbol. Must have length == 1.
-- @param class The function will be called with contents between left and right
-- symbols. The function should return the appropriate parse tree object.
-- @return A variable number of parse trees.
function collect(str, left, right, class)
  assert(#left == 1 and #right == 1)
  local lindex, rindex = str:find("%b"..left..right)
  if not rindex then
    except(META.object:peek(), 
      "expected \""..right.."\" to close ..\""..left.."\"")
  end
  local content = str:sub(2, rindex - 1)
  META.cursor = META.cursor + 1 
    -- add 1 for the the "(" parenthesis
  META.location:push(META.cursor)
  META.line:push(META.current)
  local data = {line = META.current, location = META.cursor}
  local collection = class(parse(content))
  if collection then
    META[collection] = data
    META.object:push(collection)
  end
  META.current = META.line:pop() + content:count("[\n]")
  META.cursor = META.location:pop() + #content + 1

  return collection, parse(str:sub(rindex + 1))
end

--- Used by `parse` to replace syntactical operators with keyword symbols.
-- E.g. Convert `(+ 1 2) into (quasiquote (+ 1 2))
-- @param str The symbol to be converted. Must have length == 1.
-- @param with The keyword to replace the symbol with.
-- @return A variable number of parse trees.
function replace(replaced, str, with)
  local rest = str:sub(#replaced + 1):match("%s*(.*)")
  META.cursor = META.cursor + #replaced 
  META.line:push(META.current)
  META.location:push(META.cursor)
  local node = List(parse(rest)) 
  META.current = META.line:pop()
  META.cursor = META.location:pop()
  return List(Symbol(with), node[1]), List.unpack(node[2])
end

--- Parse string into one or more parse trees.
-- @param str The string to be parsed.
-- @return A variable number of parse trees.
function parse(str)
  str = str or ""
  META.current = META.current + str:match("^(%s*)"):count("[\n]")
  META.cursor = META.cursor + #str:match("^(%s*)")
  str = str:trim()

  -- Collections
  if str:starts("(") then return collect(str, "(", ")", List) end
  if str:starts(")") then 
    except(META.object:peek(), "unexpected  \")\" after this expression") 
  end
  if str:starts("[") then return collect(str, "[", "]", Vector) end
  if str:starts("{") then return collect(str, "{", "}", Dictionary) end

  -- Comment
  if str:starts(";") then
    local rest = str:sub(2):match("[^\n]*[\n](.*)") 
    META.current = META.current + 1
    META.cursor = META.cursor + 1 + #(str:sub(2):match("([^\n]*[\n])") or "")
    return parse(rest)
  end

  -- Syntax
  if str:starts("~") then return replace("~", str, "unpack") end
  if str:starts("#.") then return replace("#.", str, "directive") end
  if str:starts("#") then return replace("#", str, "length") end
  if str:starts("`") then return replace("`", str, "quasiquote") end
  if str:starts(",") then return replace(",", str, "unquote") end
  if str:starts("'") then return replace("'", str, "quote") end

  -- String
  if str:starts("\"") then
    local escaping, index = false, 2
    while escaping or str:sub(index, index)~="\"" do
      if escaping then escaping = false end
      if str:sub(index, index) == "\\" then escaping = true end 
      index = index + 1
    end 
    local content = str:sub(2, index-1)
    local object = String(content:gsub("\n", "\\n"):gsub("\\\"", "\""))
    META[object] = {line = META.current, location = META.cursor}
    META.object:push(object)
    META.current = META.current + content:count("[\n]")
    META.cursor = META.cursor + #content + 2
    return object, parse(str:sub(index+1))
  end

  -- Number and Symbol
  if #str > 0 then
    local token, rest = str:match("(%S+)(.*)")
    local number = tonumber(token)
    if number then
      number = Number(number)
    end
    local object = number or Symbol(token)
    META[object] = {line = META.current, location = META.cursor}
    META.object:push(object)
    META.cursor = META.cursor + #token
    return object, parse(rest)
  end
end

--- Generate lua from a single parse tree (comprising of `List`s).
-- @param tree The parse tree.
-- @return A string of lua.
function genexpr(tree, multret) 
  _ENV = META._ENV:peek() 
  -- _ENV: Current scope for Operators
  if getmetatable(tree) == List then
    local first = tree[1]
    assert(first, "Empty list cannot be executed!")
    local parameters
    local uid = tostring(Symbol("_call", true))
    local declare = "local " .. uid .. " = "
    if getmetatable(first) == Symbol then
      first = first:tohash()
      if getmetatable(_ENV[first]) == Operator then
        return _ENV[first](List.unpack(tree[2]))
      end
      if first:sub(1,1)=="." and first ~="..." then
        assert(tree:cdr(), "Accessor method has no owner: "..tostring(first))
        first = genexpr(tree:cdr()[1])..":"..first:sub(2)
        parameters = List.concat(map(genexpr, tree:cdr():cdr() or {}), ",")
        local line = first.."("..parameters..")"
        if multret then return line end
        table.insert(META.block:peek(), declare..line)
        return uid
      end
      parameters = List.concat(map(genexpr, tree:cdr() or {}), ",")
      local line = first.."("..parameters..")"
      if multret then return line end
      table.insert(META.block:peek(), declare..line)
      return uid
    end
    first = genexpr(first)
    parameters = List.concat(map(genexpr, tree:cdr() or {}), ",")
    local line = first.."("..parameters..")"
    if multret then return line end
    table.insert(META.block:peek(), declare..line)
    return uid
  end
  if getmetatable(tree) == Symbol then
    return tree:tohash()
  end
  return tolua(tree)
end

-- Indent some code by two spaces
function indent(str) 
  return ({str:gsub("\n", "\n  "):gsub("^", "  ")})[1]
end 


--- Converts an array of parameter names into a set.
-- Copies `parameters` array and `parent` set into the set. Hashify Symbols if 
-- necessary. 
-- @param parameters An array of parameter names existing in this scope. 
-- @param parent The parent scope, if available.
function Scope(parameters, parent)
  local scope = permute(id, parent or {})
  map(function(parameter) 
        if getmetatable(parameter) == Symbol then
          parameter = tohash(parameter)
        end
        scope[parameter] = true 
      end, parameters or {})
  return scope
end

META = {line = Stack(), 
        object = Stack(),   -- Contains all parse tree objects
        block = Stack(), 
        current = 1,        -- current line number
        cursor = 0,         -- current string index
        location = Stack(), 
        scope = Stack(),    -- Arguments in scope
        _ENV = Stack(),     -- Actual scope for Operators
        column = {},        -- Map string index -> column
        symbol = {}}        -- Set of used symbol names

--- Compiles a block of parse trees into lua.
-- While compiling also manages block & scope metadata. 
-- If `parameters` is an array of symbol names, returns the last expression.
-- If `parameters` is a symbol or string, assigns last expression to that symbol
-- @param iterable An iterable of parse trees in the block
-- @param parameters An array of names added for this block. (e.g. argument 
-- names to a function) or A unique id.
-- @return string Returns a string of lua.
function genblock(iterable, parameters)
  parameters = parameters or {}
  local line, location, column = nil, nil, nil
  for i, v in ipairs(iterable or {}) do
    if v then 
      local data = META[v] or {}
      line = data.line
      location = data.location
      column = tostring(META.column[data.location])
      break
    end
  end
  local uid = nil
  if parameters == nil then
    parameters = gensym()
  end
  if type(parameters) == "string" or getmetatable(parameters) == Symbol then
    uid = parameters
    if getmetatable(uid) == Symbol then
      uid = uid:tohash()
    end
  end
  local block = {}
  META.block:push(block)
  local scope;
  if not uid then
    scope = Scope(parameters, META.scope:peek())
    local _ENV  = setmetatable({}, {__index = META._ENV:peek()})
    META.scope:push(scope)
    META._ENV:push(_ENV)
  end
  local body = map(genexpr, iterable)
  if body then 
    if uid then
      body = uid  .. " = "..tostring(body.last[1])
    else
      body = "return "..tostring(body.last[1])
    end
  end
  block = META.block:pop()
  if not uid then
    scope = META.scope:pop()
    _ENV = (getmetatable(META._ENV:pop()).__index)
  end
  column = tostring(column)
  local label = "-- ::LINE_"..tostring(line).."_COLUMN_"..column.."::\n"
  body = label..table.concat(block, "\n").."\n"..tostring(body)
  return body
end

--- Compiles lisp into lua.
-- @param source The lisp string.
-- @return The Lua string.
function compile(source)
  META._ENV:push(_ENV)
  META.block:push({})
  META.scope:push({})
  local body = map(genexpr, {parse(source)})
  if body then 
    body.last[1] = "return "..tostring(body.last[1])
    body = ""
  end
  local block = META.block:pop()
  local scope = META.scope:pop()
  META._ENV:pop()
  body = table.concat(block, "\n").."\n"..tostring(body).."\n"
  return body
end

--- Prints error for a parse tree object.
-- @param item The object.
-- @param message The error message.
function except(item, message)
  local data = META[item] or {}
  local line = data.line or -1
  local location = data.location or -1
  local col = ""
  if line > -1 then
    col = META.column[location]
  end
  print("line "..line..", column "..col..": "..message)
  os.exit()
end

--- Check if item is of target class. Emit error message if it isn't.
-- @param item The object.
-- @param kind The expected class.
function expect(item, kind, alt)
  if getmetatable(item) ~= kind  then
    if item == nil and kind == List then
      return
    end
    if kind == string then
      kind = "string"
    else
      kind = tostring(kind)
    end
    alt = alt or item
    except(alt, "expected "..kind..", found "..tolisp(item).." ("..
      tostring(getmetatable(item)) .. ").")
  end
end

-- Define primitives

-- Equality operator
_ENV[Symbol("=="):tohash()] = Operator(function(first, ...)
  local content = 
    List.concat(map(function(node)
      return genexpr(node).. " == ".. genexpr(first)
    end, {...}), " and ") 
  return "(".. (content == "" and "true" or content) .. ")"
end)

-- Inequality operator
_ENV[Symbol("!="):tohash()] = Operator(function(first, ...)
  local content = 
    List.concat(map(function(node)
      return genexpr(node).. " ~= ".. genexpr(first)
    end, {...}), " and ") 
  return "(".. (content == "" and "true" or content) .. ")"
end)

-- Multiplication operator
_ENV[Symbol("*"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(genexpr, {...}), " * ") .. ")"
end)

-- Addition operator
_ENV[Symbol("+"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(genexpr, {...}), " + ") .. ")"
end)

-- Greater than operator
_ENV[Symbol(">"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(genexpr, {...}), " > ") .. ")"
end)

-- Greater than equal to operator
_ENV[Symbol(">="):tohash()] = Operator(function(...)
  return "(".. List.concat(map(genexpr, {...}), " >= ") .. ")"
end)


-- Less than operator
_ENV[Symbol("<"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(genexpr, {...}), " < ") .. ")"
end)

-- Less than equal to operator
_ENV[Symbol("<="):tohash()] = Operator(function(...)
  return "(".. List.concat(map(genexpr, {...}), " <= ") .. ")"
end)

-- And operator
_ENV[Symbol("and"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(genexpr, {...}), " and ") .. ")"
end)

-- Or operator
_ENV[Symbol("or"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(genexpr, {...}), " or ") .. ")"
end)

-- Subtraction and negation operator
_ENV[Symbol("-"):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return "(-"..genexpr(parameters[1])..")"
  end
  return "(".. List.concat(map(genexpr, parameters), " - ") .. ")"
end)

-- Division operator
_ENV[Symbol("/"):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return "(1 /"..genexpr(parameters[1])..")"
  end
  return "(".. List.concat(map(genexpr, parameters), " / ") .. ")"
end)

-- String concatenation operator
_ENV[Symbol(".."):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return genexpr(parameters[1])
  end
  return "(".. List.concat(map(genexpr, parameters), " .. ") .. ")"
end)

-- Is this node an atom?
atom = Operator(function(node) 
  return "(getmetatable("..genexpr(node)..")~=List)" 
end)


-- define local variables and execute some code with those locals in context
let = Operator(function(labels, ...)
  expect(labels, List)
  local uid = tostring(Symbol("_let", true))
  if (#{...} == 0) then
    except(labels, "expected Something, found nothing.")
  end
  block = META.block:peek()
  table.insert(block, "local " .. uid)
  table.insert(block, "do")
  block = META.block:push({})
  local declarations = {}
  for index, item in ipairs(labels or {}) do
    if index % 2 == 1 then 
      expect(item, Symbol)
      declarations[(index+1)/2] = "local "..genexpr(item) .. " = "
    else
      declarations[index/2] = declarations[index/2]..genexpr(item)
      table.insert(block, declarations[index/2])
    end
  end
  for i, v in ipairs(declarations) do
  end
  table.insert(block, genblock({...}, uid))
  block = META.block:pop()
  table.insert(META.block:peek(), indent(table.concat(block, "\n")))
  block = META.block:peek()
  table.insert(block, "end")
  return uid
end)

-- works globally unless used on variable defined by (let (a v1 b v2) ...)
set = Operator(function(name, value) 
  expect(name, Symbol)
  table.insert(META.block:peek(),genexpr(name) .." = ".. genexpr(value))
  return "nil"
end)
car = Operator(function(node)
  return genexpr(node).."[1]"
end)

cdr = Operator(function(node)
  return genexpr(node)..":cdr()"
end)

cons = Operator(function(first, second)
  expect(second, List)
  return ("Pair(%s, %s)"):format(genexpr(first), genexpr(second))
end)

-- Define anonymous function. e.g. (lambda (a b) (+ a b))
lambda = Operator(function(arguments, ...) 
  expect(arguments, List)
  local arglist = List.concat(map(function(a)
      expect(a, Symbol)
      return a:tohash()
    end, arguments or {}), ",")
  local body = genblock({...}, map(tohash, arguments or {}))
  return "(function("..arglist..")\n"..indent(body).."\nend)" 
end)

-- Like lambda but named.
defun = Operator(function(name, arguments, ...)
  expect(name, Symbol)
  expect(arguments, List, arguments or name)
  local arglist = List.concat(map(function(a)
      expect(a, Symbol)
      return a:tohash()
    end, arguments or {}), ",")
  local body = genblock({...}, map(tohash, arguments or {}))
  name = name:tohash()
  table.insert(META.block:peek(), "function "..name.."("..arglist..")\n"
              ..indent(body).."\nend" )
  return name
end)


defmacro = Operator(function(name, arguments, ...)
  expect(name, Symbol)
  local name = name:tohash()
  local index = 0
  local has = Scope(arguments or {})
  local lifted = permute(function(parameter, bool)
                          if bool and not has[parameter] then
                            index = index + 1
                            return index, Symbol(parameter)
                          end
                        end, META.scope:peek())
  arguments = map(tohash, arguments or {})

  local arglist = List.concat(arguments, ",")
  local prefix = ""
  for i, v in pairs(lifted or {}) do
    prefix = prefix .. "local " .. v:tohash() .. " = " .. v:tolua().."\n"
  end

  local body = map(genexpr, {...})
  if body then 
    body.last[1] = "return genexpr("..tostring(body.last[1])..")"
  end
  body = prefix..List.concat(body, "\n")
  local f, m = load("return function("..arglist..")\n"..indent(body).."\nend", 
                    "defmacro", "t", _ENV)
  if m then print(m, body) end
  _ENV[name] = Operator(f())

  -- Create macroexpand version. 
  body = map(genexpr, {...})
  if body then 
    body.last[1] = "return "..tostring(body.last[1])
  end
  body = prefix..List.concat(body, "\n")
  f, m = load("return function("..arglist..")\n"..indent(body).."\nend", 
              "defmacro", "t", _ENV)
  macroexpand[name] = Operator(f())
  return ""
end)

function eval(form)
  return load("return "..genexpr(form), "eval", "t", _ENV)()
end

_ENV[Symbol("macroexpand-1"):tohash()] = function(form)
  if getmetatable(form) ~= List then
    return form, false
  end
  local first = parse(tolisp(form))[1]
  if getmetatable(first) ~= Symbol then
    return form, false
  end
  local name = first:tohash()
  if not macroexpand[name] then 
    return form, false
  end
  local parameters = form:cdr()
  return macroexpand[name](List.unpack(parameters)), true
end

-- Creating psuedo-functor object because macroexpand table will be used to
-- store macroexpand functions for each macros.
macroexpand = setmetatable({
  lambda = function (form)
    local macroexpand1 = _ENV[Symbol("macroexpand-1"):tohash()]
    if getmetatable(form) ~= List then
      return form
    end
    local expanded, first, rest
    first = macroexpand(parse(tolisp(form))[1])
    rest = map(macroexpand, form:cdr() or {})
    form, expanded = macroexpand1(Pair(first, rest))

    -- Recursively expand while expansion was performed successfully.
    while expanded do
      first = macroexpand(parse(tolisp(form))[1])
      rest = map(macroexpand, form:cdr() or {})
      form, expanded = macroexpand1(Pair(first, rest))
    end
    return form
  end
}, {__call = function(self, ...) return self.lambda(...) end})

quote = Operator(function(tree)
  if getmetatable(tree) == List then
    if tree[1] == nil and tree[2] == nil then
      return "nil"
    end
    return tree:tolua()
  end
  return tolua(tree)
end)

quasiquote = Operator(function(tree)
  if getmetatable(tree) == Vector then
    return "Vector("..List.concat(map(quasiquote, tree),",")..")"
  end
  if getmetatable(tree) ~= List then
    return quote(tree)
  end
  if tree[1] == Symbol("unquote") then
    return genexpr(tree:cdr()[1])
  end
  if tree[1] == nil and tree[2] == nil then
    return "nil"
  end
  return "List("..List.concat(map(quasiquote, tree),",")..")"
end)

unpack = Operator(function(item)
  return "List.unpack(map(id,"..genexpr(item).."))"
end)

cond = Operator(function(...)
  local block = META.block:peek()
  local uid = tostring(Symbol("_cond", true))
  table.insert(block, "local " .. uid)
  table.insert(block, "do")
  local branches = map(function(branch) 
    expect(branch, List)
    local body = genblock(branch:cdr(), uid)
    local line = "if "..genexpr(branch[1]).." then\n"..
                    indent(body)..
                    "\n  goto "..uid..
                  "\nend" 
    table.insert(block, indent(line)) 
  end, {...})
  table.insert(block, "::"..uid.."::")
  table.insert(block, "end")
  return uid
end)

length = Operator(function(statement)
  return "#("..genexpr(statement)..")"
end)

-- Compile time code execution
directive = Operator(function(statement)
  local _ENV = META._ENV:peek()
  local code
  META.block:push({})
  local body = {genexpr(statement)}
  local block = META.block:pop()
  body = table.concat(block, "\n") .. "\n"
  local f, m = load(body, "directive", "t", _ENV)
  if m then except(statement, body .. m) end
  f()
  -- emit empty lua code
  return ""
end)

;
-- END --
function sum(list)
  -- ::LINE_7_COLUMN_3::
  local _77ya_cond
  do
    if list then
      -- ::LINE_7_COLUMN_12::
      local _gwqp_call = sum(list:cdr())
      _77ya_cond = (list[1] + _gwqp_call)
      goto _77ya_cond
    end
    if true then
      -- ::LINE_7_COLUMN_43::
      
      _77ya_cond = 0
      goto _77ya_cond
    end
  ::_77ya_cond::
  end
  return _77ya_cond
end

return _ENV
