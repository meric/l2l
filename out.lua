-- Lisp to Lua Compiler by Eric Man
-- License undecided.

local input, output = arg[1] or "test.lsp", arg[2] or "out.lua"

local ENV = _ENV
local L2L = setmetatable({}, {__index = ENV})
_ENV = L2L


List = {}

-- Create new List, e.g. List(item1, item2, item3)
setmetatable(List, {__call=function(self, ...)
  local parameters = {...}
  local last = setmetatable({nil, nil}, List)
  local first = nil
  for index = 1, #parameters do
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
Pair = function (a, b)
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

function List:__ipairs()
  return function() 
    if self then 
      local item = self[1] 
      self=self[2] 
      return item or self, item 
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
setmetatable(Vector, {__call=function(self, ...)
  return setmetatable({...}, Vector)
end})

Vector.__index = Vector

function Vector:__tostring()
  return "["..List.concat(map(tostring, self), " ").."]" 
end

function Vector:tolua()
  local t = {}
  for i, v in ipairs(self) do
    table.insert(t, v:tolua())
  end
  return "({"..List.concat(map(tostring, self), ",").."})"
end

function Vector:tolisp()
  return tostring(self)
end

Dictionary = {}

-- Create new Dictionary, e.g. Dictionary(key1, item1, key2, item2)
setmetatable(Dictionary, {__call=function(self, ...)
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
    table.insert(t, "["..generate(k).."]".." = ".. generate(v))
  end
  return "({"..List.concat(map(tostring, t), ",").."})"
end

function Dictionary:tolisp()
  return tostring(self)
end

-- Map is usable for all types implementing __ipairs
function map(f, l) 
  local result = Pair()
  for i, v in ipairs(l) do 
    result:append(f(v))
  end 
  return List.cdr(result)
end


Symbol = {}

-- Create new Symbol, e.g. Symbol("somestring")
setmetatable(Symbol, {__call=function(self, token)
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

Number = {}

-- Create new Number, e.g. Number(1)
setmetatable(Number, {__call=function(self, number)
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

setmetatable(Operator, {__call=function(self, lambda)
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

-- String additions
function string:trim()
  return self:gsub("^%s*(.-)%s*$", "%1")
end

function string:starts(str)
  return self:sub(1, #str) == str
end

function string.tolua(str) 
  return '"'..str:gsub('"','\\"')..'"' 
end

function string.tolisp(str) 
  return '"'..str:gsub('"','\\"')..'"' 
end

-- These types can be translated directly into Lua
L2LTYPES =
  {[string] = true,
   [List] = true,
   [Vector] = true,
   [Dictionary] = true,
   [Symbol] = true,
   [Number] = true}

-- Convert parse tree object into lua form.
function tolua(object)
  if L2LTYPES[getmetatable(object)] or type(object) == "string" then
    return object:tolua()
  end
  if object == nil then
    return "nil"
  end
  if type(object) == "number" then
    return tostring(object)
  end
  error("Internal Error: "..tostring(object)..", "..type(object))
end

-- Convert parse tree object back into lisp form. (used by macroexpand)
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

-- Parse string into parse tree
function parse(str)
  str = (str or ""):trim()
  -- List
  if str:starts("(") then
    local lparen, rparen = str:find("%b()")
    assert(rparen, "Expected \")\" to close \"(\"")
    local collection = List(parse(str:sub(2, rparen - 1)))
    return collection, parse(str:sub(rparen + 1))
  end

  -- Vector
  if str:starts("[") then
    local lbracket, rbracket = str:find("%b[]")
    local collection = Vector(parse(str:sub(2, rbracket - 1)))
    return collection, parse(str:sub(rbracket + 1))
  end

  -- Dictionary
  if str:starts("{") then
    local lbrace, rbrace = str:find("%b{}")
    local collection = Dictionary(parse(str:sub(2, rbrace - 1)))
    return collection, parse(str:sub(rbrace + 1))
  end

  -- Comment
  if str:starts(";") then
    local rest = str:sub(2):match("%s*.-\n(.*)") 
    return parse(rest)
  end

  -- Replace with Execute
  if str:starts("#") then
    local rest = str:sub(2):match("%s*(.*)")
    local node = List(parse(rest)) 
    return List(Symbol("directive"), node[1]), List.unpack(node[2])
  end

  -- Replace with Quasiquote
  if str:starts("`") then
    local rest = str:sub(2):match("%s*(.*)")
    local node = List(parse(rest)) 
    return List(Symbol("quasiquote"), node[1]), List.unpack(node[2])
  end

  -- Replace with Unquote
  if str:starts(",") then
    local rest = str:sub(2):match("%s*(.*)")
    local node = List(parse(rest)) 
    return List(Symbol("unquote"), node[1]), List.unpack(node[2])
  end

  -- Replace with Quote
  if str:starts("'") then
    local rest = str:sub(2):match("%s*(.*)")
    local node = List(parse(rest)) 
    return List(Symbol("quote"), node[1]), List.unpack(node[2])
  end

  -- String
  if str:starts("\"") then
    local escaping, index = false, 2
    while escaping or str:sub(index, index)~="\"" do
      if escaping then escaping = false end
      if str:sub(index, index) == "\\" then escaping = true end 
      index = index + 1
    end 
    return str:sub(2, index-1), parse(str:sub(index+1))
  end

  -- Number and Symbol
  if #str > 0 then
    local token, rest = str:match("(%S+)"), str:match("%S+%s+(.*)")
    local number = tonumber(token)
    if number then
      number = Number(number)
    end
    return number or Symbol(token), parse(rest)
  end
end

-- Generate lua from parse tree
function generate(tree) 
  if getmetatable(tree) == List then
    local first = tree[1]
    assert(first, "Empty list cannot be executed!")
    local parameters = List.concat(map(generate, tree[2] or {}), ",")
    if getmetatable(first) == Symbol then
      first = first:tohash()
      if getmetatable(_ENV[first]) == Operator then
        return _ENV[first](List.unpack(tree[2]))
      end
      if first:sub(1,1)=="." and first ~="..." then
        assert(tree:cdr(), "Accessor method has no owner: "..tostring(first))  
        parameters = List.concat(map(generate, tree:cdr():cdr() or {}), ",")
        return generate(tree:cdr()[1])..":"..first:sub(2).."("..parameters..")"
      end
      return first.."("..parameters..")"
    end
    return generate(first).."("..parameters..")"
  end
  if getmetatable(tree) == Symbol then
    return tree:tohash()
  end
  return tolua(tree)
end

-- Indent some code by two spaces
function indent(str) 
  return str:gsub("\n", "\n  "):gsub("^", "  ")
end 

-- Generate lua for block of parse trees, and return last item in the block
function compile(iterable)
  local body = map(generate, iterable)
  if body then 
    body.last[1] = "return "..tostring(body.last[1])
  end
  body = List.concat(body, ";\n")
  return body
end

-- Define primitives

-- Equality operator
_ENV[Symbol("=="):tohash()] = Operator(function(first, ...)
  local content = 
    List.concat(map(function(node)
      return generate(node).. " == ".. generate(first)
    end, {...}), " and ") 
  return "(".. (content == "" and "true" or content) .. ")"
end)

-- Multiplication operator
_ENV[Symbol("*"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(generate, {...}), " * ") .. ")"
end)

-- Addition operator
_ENV[Symbol("+"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(generate, {...}), " + ") .. ")"
end)

-- Subtraction and negation operator
_ENV[Symbol("-"):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return "(-"..generate(parameters[1])..")"
  end
  return "(".. List.concat(map(generate, parameters), " - ") .. ")"
end)

-- Division operator
_ENV[Symbol("/"):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return "(1 /"..generate(parameters[1])..")"
  end
  return "(".. List.concat(map(generate, parameters), " / ") .. ")"
end)

-- String concatenation operator
_ENV[Symbol(".."):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return generate(parameters[1])
  end
  return "(".. List.concat(map(generate, parameters), " .. ") .. ")"
end)

-- Is this node an atom?
atom = Operator(function(node) 
  return "(getmetatable("..generate(node)..")~=List)" 
end)

-- define local variables and execute some code with those locals in context
let = Operator(function(labels, ...)
  assert(getmetatable(labels)==List, "Expected List: "..tostring(labels))
  local declarations = {}
  local index = 0
  for i, item in ipairs(labels) do
    index = index + 1
    if index % 2 == 1 then 
      -- name
      assert(getmetatable(item) == Symbol, "Expected Symbol: "..tostring(item))
      declarations[(index+1)/2] = "local "..generate(item) .. " = "
    else
      declarations[index/2] = declarations[index/2]..generate(item)
    end
  end
  local body = compile({...})
  body = List.concat(map(tostring, declarations), "\n").."\n"..body
  return "(function()\n"..indent(body).."\nend)()"
end)

-- works globally unless used on variable defined by (let (a v1 b v2) ...)
set = Operator(function(name, value) 
  assert(getmetatable(name)==Symbol, "Expected Symbol: " .. tostring(name))
  return generate(name) .." = ".. generate(value)
end)
car = Operator(function(node)
  return generate(node).."[1]"
end)

cdr = Operator(function(node)
  return generate(node).."[2]"
end)

cons = Operator(function(first, second)
  assert(getmetatable(second) == List, "Expected List: " .. tostring(second))
  return ("Pair(%s, %s)"):format(generate(first), generate(second))
end)

-- Define anonymous function. e.g. (lambda (a b) (+ a b))
lambda = Operator(function(arguments, ...) 
  local arglist = List.concat(map(function(a)
      assert(getmetatable(a) == Symbol, "Expected Symbol: "..tostring(arguments))
      return a:tohash()
    end, arguments or {}), ",")
  local body = compile({...})
  return "(function("..arglist..")\n"..indent(body).."\nend)" 
end)

-- Like lambda but named.
defun = Operator(function(name, arguments, ...)
  assert(getmetatable(name) == Symbol, "Expected Symbol: "..tostring(name))
  local arglist = List.concat(map(function(a)
      assert(getmetatable(a) == Symbol, "Expected Symbol: "..tostring(a))
      return a:tohash()
    end, arguments or {}), ",")
  local body = compile({...})
  name = name:tohash()
  return "function "..name.."("..arglist..")\n"..indent(body).."\nend" 
end)


-- Shortcut function to generate sibling parse trees.
-- E.g. for block of code in functions.
function compile(iterable)
  local body = map(generate, iterable)
  if body then 
    body.last[1] = "return "..tostring(body.last[1])
  end
  body = List.concat(body, ";\n")
  return body
end

defmacro = Operator(function(name, arguments, ...)
  assert(getmetatable(name) == Symbol, "Expected Symbol: "..tostring(name))
  local name = name:tohash()
  local arglist = List.concat(map(function(a)
      assert(getmetatable(a) == Symbol, "Expected Symbol: "..tostring(a))
      return a:tohash()
    end, arguments or {}), ",")

  -- Actual macro body
  local macrobody = map(generate, {...})
  if macrobody then 
    macrobody.last[1] = "return generate("..tostring(macrobody.last[1])..")"
  end
  macrobody = List.concat(macrobody, ";\n")

  -- Create macro expand version. 
  -- (Yes, we're duplicating work just for ease of use)
  local expandbody  = map(generate, {...})
  if expandbody then 
    expandbody.last[1] = "return "..tostring(expandbody.last[1])
  end
  expandbody = List.concat(expandbody, ";\n")

  _ENV[name] = Operator(load("return function("..arglist..")\n"..
    indent(macrobody).."\nend", "defmacro", "t", _ENV)())
  macroexpand[name] = Operator(load("return function("..arglist..")\n"
    ..indent(expandbody).."\nend", "defmacro", "t", _ENV)())
  return ""
end)

function eval(form)
  return load("return "..generate(form), "eval", "t", _ENV)()
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
  if getmetatable(tree) ~= List then
    return quote(tree)
  end
  if tree[1] == Symbol("unquote") then
    return generate(tree:cdr()[1])
  end
  if tree[1] == nil and tree[2] == nil then
    return "nil"
  end
  return "List("..List.concat(map(quasiquote, tree),",")..")"
end)

cond = Operator(function(...)
  local branches = map(function(branch) 
    local body = compile(branch:cdr())
    return "if "..generate(branch[1]).." then\n"..indent(body).."\nend" 
  end, {...})
  local body = indent("\n"..List.concat(branches, "\n"))
  return "(function()"..body.."\nend)()" 
end)

-- Compile time code execution
directive = Operator(function(statement)
  -- run code straight away, while being parsed.
  load(generate(statement), "directive", "t", _ENV)()
  -- emit empty lua code
  return ""
end)

;
-- END --
print("\n--- Example 1 ---\n");

function __c33__(n)
  return (function()  
    if (0 == n) then
      return 1
    end
    if (1 == n) then
      return 1
    end
    if true then
      return (n * __c33__((n - 1)))
    end
  end)()
end;

print(__c33__(100));

print("\n--- Example 2 ---\n");

function __c206____c163__()
  return print("ΣΣΣ")
end;

__c206____c163__();

print("\n--- Example 3 ---\n");

hello__c45__world = "hello gibberish world";

print(string["gsub"](hello__c45__world,"gibberish ",""));

print("\n--- Example 4 ---\n");

map(print,List(1,2,3,map((function(x)
  return (x * 5)
end),List(1,2,3))));

print("\n--- Example 5 ---\n");

(function()
  local a = (1 + 2)
  local b = (3 + 4)
  print(a);
  return print(b)
end)();

print("\n--- Example 6 ---\n");

({["write"] = (function(self,x)
  return print(x)
end)}):write("hello-world");

print("\n--- Example 7 ---\n");

print((function(x,y)
  return (x + y)
end)(10,20));

print("\n--- Example 8 ---\n");

(function()
  local a = (7 * 8)
  return map(print,({1,2,a,4}))
end)();

print("\n--- Example 9 ---\n");

(function()
  local dict = ({["a"] = "b",[1] = 2,["3"] = 4})
  print(dict["a"],"b");
  print(dict["a"],"b");
  print(dict[1],2);
  return print(dict["3"],4)
end)();

print("\n--- Example 10 ---\n");

;

-- This is a comment;

;

;

;

print("\n--- Example 11 ---\n");

print("\n--- Did you see what was printed while compiling? ---\n");

(function()
  print(1);
  return print(2)
end)();

;

print("\n--- Example 12 ---\n");

;

(function()
  local a = 2
  return (function()  
    if ("1" == a) then
      return print("a == 1")
    end
    if true then
      return (function()  
        if (2 == a) then
          return print("a == 2")
        end
        if true then
          return print("a != 2")
        end
      end)()
    end
  end)()
end)();

;

;

;

;

;

return 
