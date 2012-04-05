local input, output = arg[1] or "test.lsp", arg[2] or "out.lua"

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

Pair = function (a, b)
  return setmetatable({a, b}, List)
end

List.__index = List

function List:__tostring()
  return "("..List.concat(map(tostring, self), " ")..")" 
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
    if getmetatable(k) == Symbol then
      k = k:tohash()
    end
    table.insert(t, "["..tolua(k).."]".." = ".. generate(v))
  end
  return "({"..List.concat(map(tostring, t), ",").."})"
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

function hash(char)
  return "_c"..char:byte().."_" 
end

LUAKEYWORDS ={
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
  local name = tostring(self.name):gsub("[-?!@#$%^&*=_+|\\/{}<>~`,]",
    function(a) 
      if a ~= "." then 
        return hash(a)
      else 
        return "." 
      end 
    end)
  if LUAKEYWORDS[name] then
    name = name:gsub("(.)", hash)
  end
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

Operator = {}

setmetatable(Operator, {__call=function(self, lambda)
  return setmetatable({lambda=lambda}, Operator)
end})

Operator.__index = Operator

function Operator:__call(...)
  return self.lambda(...)
end

function Operator:__tostring()
  if _G[self] then
    return _G[self]
  end
  -- Search and cache name
  for k, v in pairs(_G) do
    if v == self then
        _G[self] = k
        return _G[self]
    end
  end
  _G[self] = "<operator:"..tostring(self.lambda)..">"
  return _G[self]
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
-- These types can be translated directly into Lua
LUATYPES =
  {[string] = true,
   [List] = true,
   [Vector] = true,
   [Dictionary] = true,
   [Symbol] = true,
   [Number] = true}

function tolua(object)
  if LUATYPES[getmetatable(object)] or type(object) == "string" then
    return object:tolua()
  end
  -- if type(object) == "table" then
  --   return setmetatable(object, Dictionary):tolua()
  -- end
  if object == nil then
    return "nil"
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
    return List(Symbol("execute"), node[1]), List.unpack(node[2])
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
      if getmetatable(_G[first]) == Operator then
        return _G[first](List.unpack(tree[2]))
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

_G[Symbol("=="):tohash()] = Operator(function(first, ...)
  local content = 
    List.concat(map(function(node)
      return generate(node).. " == ".. generate(first)
    end, {...}), " and ") 
  return "(".. (content == "" and "true" or content) .. ")"
end)

_G[Symbol("*"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(generate, {...}), " * ") .. ")"
end)

_G[Symbol("+"):tohash()] = Operator(function(...)
  return "(".. List.concat(map(generate, {...}), " + ") .. ")"
end)

_G[Symbol("-"):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return "(-"..generate(parameters[1])..")"
  end
  return "(".. List.concat(map(generate, parameters), " - ") .. ")"
end)

_G[Symbol("/"):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return "(1 /"..generate(parameters[1])..")"
  end
  return "(".. List.concat(map(generate, parameters), " / ") .. ")"
end)

_G[Symbol(".."):tohash()] = Operator(function(...)
  local parameters = {...}
  if #parameters == 1 then
    return generate(parameters[1])
  end
  return "(".. List.concat(map(generate, parameters), " .. ") .. ")"
end)


atom = Operator(function(node) 
  return "(getmetatable("..generate(node)..")~=List)" 
end)

set = Operator(function(name, value) 
  assert(getmetatable(name)==Symbol, "Expected Symbol: " .. tostring(name))
  return generate(name) .." = ".. generate(value)
end)

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

car = Operator(function(node)
  return generate(node).."[1]"
end)

cdr = Operator(function(node)
  return generate(node).."[2]"
end)

cons = Operator(function(first, second)
  assert(getmetatable(second) == List, "Expected List: " .. tostring(second))
  return ("setmetatable({%s, %s}, List)"):format(generate(first), generate(second))
end)

lambda = Operator(function(arguments, ...) 
  local arglist = List.concat(map(function(a)
      assert(getmetatable(a) == Symbol, "Expected Symbol: "..tostring(a))
      return a:tohash()
    end, arguments), ",")
  local body = compile({...})
  return "(function("..arglist..")\n"..indent(body).."\nend)" 
end)

defun = Operator(function(name, arguments, ...)
  assert(getmetatable(name) == Symbol, "Expected Symbol: "..tostring(name))
  local arglist = List.concat(map(function(a)
      assert(getmetatable(a) == Symbol, "Expected Symbol: "..tostring(a))
      return a:tohash()
    end, arguments))
  local body = compile({...})
  name = name:tohash()
  return "function "..name.."("..arglist..")\n"..indent(body).."\nend" 
end)

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

execute = Operator(function(statement)
  load(generate(statement))()
  return ""
end)

;
-- END --

if not input or not output then 
  os.exit() 
end

source_file = io.open(input, "r") 
source = source_file:read("*all") 
source_file:close()
output_file = io.open(output, "w") 
l2l_file = io.open("l2l.lua", "r")
local line = ""
repeat
  line = l2l_file:read("*line")
  output_file:write(line.."\n") 
until line:match("-- END --") 
l2l_file:close()
local body = map(generate, {parse(source)})
if body then 
  body.last[1] = "return "..tostring(body.last[1])
end
body = List.concat(body, ";\n\n")
output_file:write(body.."\n") 
output_file:close()


