local itertools = require("l2l.itertools")
local reader = require("l2l.reader2")
local grammar = require("l2l.grammar")
local exception = require("l2l.exception2")

local list = itertools.list
local car = itertools.car

local match = reader.match
local read_predicate = reader.read_predicate
local skip_whitespace = reader.skip_whitespace
local symbol = reader.symbol

local associate = grammar.associate
local span = grammar.span
local any = grammar.any
local mark = grammar.mark
local skip = grammar.skip
local option = grammar.option
local repeating = grammar.repeating
local factor = grammar.factor

local raise = exception.raise

local ExpectedSymbolException =
  exception.Exception("ExpectedSymbolException", "Expected Lisp symbol.")

-- Lua Grammar
-- chunk ::= block
-- block ::= {stat} [retstat]
-- stat ::=  ‘;’ | 
--      varlist ‘=’ explist | 
--      functioncall | 
--      label | 
--      break | 
--      goto Name | 
--      do block end | 
--      while exp do block end | 
--      repeat block until exp | 
--      if exp then block {elseif exp then block} [else block] end | 
--      for Name ‘=’ exp ‘,’ exp [‘,’ exp] do block end | 
--      for namelist in explist do block end | 
--      function funcname funcbody | 
--      local function Name funcbody | 
--      local namelist [‘=’ explist] 

-- retstat ::= return [explist] [‘;’]
-- label ::= ‘::’ Name ‘::’
-- funcname ::= Name {‘.’ Name} [‘:’ Name]
-- varlist ::= var {‘,’ var}
-- var ::=  Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name 
-- namelist ::= Name {‘,’ Name}
-- explist ::= exp {‘,’ exp}
-- exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ | functiondef | 
--      prefixexp | tableconstructor | exp binop exp | unop exp 
-- prefixexp ::= var | functioncall | ‘(’ exp ‘)’
-- functioncall ::=  prefixexp args | prefixexp ‘:’ Name args 
-- args ::=  ‘(’ [explist] ‘)’ | tableconstructor | LiteralString 
-- functiondef ::= function funcbody
-- funcbody ::= ‘(’ [parlist] ‘)’ block end
-- parlist ::= namelist [‘,’ ‘...’] | ‘...’
-- tableconstructor ::= ‘{’ [fieldlist] ‘}’
-- fieldlist ::= field {fieldsep field} [fieldsep]
-- field ::= ‘[’ exp ‘]’ ‘=’ exp | Name ‘=’ exp | exp
-- fieldsep ::= ‘,’ | ‘;’
-- binop ::=  ‘+’ | ‘-’ | ‘*’ | ‘/’ | ‘//’ | ‘^’ | ‘%’ | 
--      ‘&’ | ‘~’ | ‘|’ | ‘>>’ | ‘<<’ | ‘..’ | 
--      ‘<’ | ‘<=’ | ‘>’ | ‘>=’ | ‘==’ | ‘~=’ | 
--      and | or
-- unop ::= ‘-’ | not | ‘#’ | ‘~’


local keywords ={
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

--[[[

(let
  (z 8)
  (print \ (x y z)
     local x = 1;
           y = x + \(+ 2 3);
           z = y * 2;)
  (print \ 1 * 2))

print((1 + (+ 2 3)) * 7);
(do
  (print 5));

--------------------------------------------------------------------------------
(filter g (map f (range 5)))
for i=1, 5 do
  if g(f(i)) then
    ...
  end
end

(reduce + 0 (map (@> (x i) `(* ,x ,x)) (range 5)))


--------------------------------------------------------------------------------

(range 10) -> iterator
function(invariant, index)
  local value = start + index * step
  if not stop or value <= stop then
    return index + 1, start + index * step
  end
end, step, 0

(take 5 (range 10)) ->
function(invariant, index)
  -- range application
  local value = start + index * step
  -- take application

  -- take return
  if index > n then
    break
  end
  -- range return
  if not stop or value <= stop then
    return index + 1, start + index * step
  end
end

An iterator context contains a stack of transforms, then a stack of returns.
minimum one function call loop.

function (block, bytes, expr_or_transform, expr_or_iteration)
    --> return lua expr?
    --> check if luaexpr table, string, or (function, invariant, state) tuple.
    --> If function then go in? but don't know where is "middle".
    --> maybe it should return a wrapper.

  -- expr_or_iteration could be lua expr, or iterable.
  -- tonext will be applied to it.
  local iterable = functional(block, bytes, expr_or_iteration)
  return iterable(
  -- Value Transform
  function(invariant, index, value)
    return compile_call(expr_or_transform, value, index)
  end,
  function(invariant, index, value)
    return
  end)
end

(take 2 (map (@> (x i) `(* ,x ,x)) (range 5)))
function(invariant, index)
  -- Identity
  local value = index
  -- Range transform
  value = start + index * step
  -- Map transform
  value = value * value
  -- Take transform
  -- Default

  -- Take return
  if index > n then
    return
  end
  -- Map return
  -- Default
  
  -- Range return
  if stop and value > stop then
    return
  end
  return index + 1, value
end, invariant, index

--------------------------------------------------------------------------------


(let 
  (z-x 7)
  (print ${} (x) <<
  local $x = 0;
  local $y = 7;
   x = x + y + $z-x;))

(print $ 7 + 8; (+ 1 3))
(print `${print("hello"..${7 + 8})})

(print (quote (LuaExp (LuaFunctionCall (LuaName "print") Terminal("(") ))))....

LuaName
LuaNameList
LuaLabel
LuaFunctionCall
LuaVariableList
LuaExpression
LuaExpressionList
LuaStatement
LuaBlock
LuaReturnStatement
LuaWhitespace
LuaGoto
LuaWhile
LuaDo
LuaIf
LuaPrefixExpression
LuaExpressionList
LuaUnaryOperation
LuaNumber
LuaVariable

--?>
local unop = factor(unop,
  -- unop ::= ‘-’ | not | ‘#’ | ‘~’
  function() return any(
    TERM("-"),
    span(TERM("not"), space),
    TERM("#"),
    TERM("~")
  ) end)


($ unop ::= "-" | "not" space | "#" | "~";
   space = function() )
]]--

local number = factor("number", function() return reader.read_number end)

local space = factor("space",
  function() return
    function(environment, bytes)
    -- * Mandatory space after keywords should not be "skip"ed.
    --   Otherwise when output the code could produce like "gotolabel",
    --   which is not valid.
    -- * In "all", space prepend content elements that can have
    --   spaces prepending it.
      local patterns = {}
      local bounds = {
        ["("]=true,
        [")"]=true,
        ["{"]=true,
        ["}"]=true,
        [","]=true,
        [";"]=true,
      }

      if not bytes then
        return list(""), bytes
      end

      for byte, _ in pairs(bounds) do
        table.insert(patterns, "^%"..byte.."$")
      end

      local values, rest = read_predicate(environment, bytes, tostring,
        match("^%s+$", unpack(patterns)))

      -- Convert boundary characters into zero string tokens.
      if values and bounds[tostring(car(values))] then
        return list(""), bytes
      end
      return values, rest
    end
  end)

local __ = mark(space, skip, option)

local LiteralString = factor("LiteralString", function() return
    span(mark(any('"', "'"), skip), function(environment, bytes)      
        return reader.read_string(environment, bytes)
      end)
  end, function(nonterminal, ...)
    return list(symbol("LuaString"), ...)
  end)

local luaname
luaname = associate("luaname", function(environment, bytes)
  -- Names (also called identifiers) in Lua can be any string of letters,
  -- digits, and underscores, not beginning with a digit and not being a
  -- reserved word. Identifiers are used to name variables, table fields, and
  -- labels.
  local values, rest = read_predicate(environment, bytes,
    itertools.id, function(token, byte)
      return (token..byte):match("^[%w_][%w%d_]*$")
    end)
  if not values or values and car(values) and keywords[tostring(car(values))] then
    return nil, bytes
  end
  return list(symbol(car(values))), rest
end)


local lispname = factor("lispname", function() return
  span("\\", function(environment, bytes) return
    reader.with_R(environment, false, reader.default_R(), function()
        local values, rest, read = reader.read(environment, bytes)
        if read ~= reader.read_symbol or not values then
          raise(ExpectedSymbolException(environment, bytes))
        end
        return values, rest
      end)
    end)
  end)

local Name = factor("Name", function() return
    any(luaname, lispname)
  end, function(_, ...)
    return list(symbol("LuaName"), ...)
  end)

local unop = factor("unop", function() return
    -- unop ::= ‘-’ | not | ‘#’ | ‘~’
    any("-", span("not", space), "#", "~")
  end)

local label = factor("label", function() return
    -- label ::= ‘::’ Name ‘::’
    span("::", __, Name, __, "::")
  end)

local binop = factor("binop", function() return
    -- binop ::=  ‘+’ | ‘-’ | ‘*’ | ‘/’ | ‘//’ | ‘^’ | ‘%’ |
    --      ‘&’ | ‘~’ | ‘|’ | ‘>>’ | ‘<<’ | ‘..’ |
    --      ‘<’ | ‘<=’ | ‘>’ | ‘>=’ | ‘==’ | ‘~=’ |
    --      and | or
    any("+", "-", "*", "/", "//", "^", "%", "&", "~", "|", ">>", "<<", "..",
        "<", "<=", ">", ">=", "==", "~=")
  end, function(nonterminal, ...)
    return ...
  end)

local exp
local var
local prefixexp
local block
local explist
local namelist

local args = factor("args", function() return
  -- args ::=  ‘(’ [explist] ‘)’ | tableconstructor | LiteralString 
    any(span("(", __, mark(explist, option), __, ")"), LiteralString)
  end)

local functioncall = factor("functioncall", function() return
  -- functioncall ::=  prefixexp args | prefixexp ‘:’ Name args 
    any(
      span(prefixexp, __, args) %
        function(...)
          return ...
        end,
      span(prefixexp, __, ":", __, Name, __, args))
  end)

local lispexp = factor("lispexp", function() return
  span("\\", function(environment, bytes) return
    reader.with_R(environment, false, reader.default_R(), function() return
        reader.read(environment, bytes)
      end)
    end)
  end)

exp = factor("exp", function(left) return
  -- exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ |  
  --      functiondef | prefixexp | tableconstructor | exp binop exp | unop exp 
    any(
      left(span(exp, __, binop, __, exp) % function(...)
        return list(...)
      end, 3), -- 3 => binop is an infix operator with precedence.
      span(any("nil", "false", "true", number, "..."), __),
      LiteralString,
      lispexp,
      prefixexp,
      span(unop, exp))
  end, function(_, ...)
    return ...
  end)

prefixexp = factor("prefixexp", function(left) return
  -- prefixexp ::= var | functioncall | ‘(’ exp ‘)’
  --
  -- Give the parser a hint to avoid infinite loop on Left-recursion.
  -- We must call left in `prefixexp` because the left operator
  -- can only be used when either:
  --  1. the span clause argument, e.g. left(span(prefixexp, ...))
  --  2. the nonterminal standing alone
  -- left recursions back to this nonterminal.
   any(left(functioncall), left(var), span("(", __, exp, __, ")", __))
  end)

var = factor("var", function() return 
  -- var ::=  Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name 
    any(
      span(prefixexp, __, "[", __, exp, __, "]", __),
      span(prefixexp, __, ".", __, Name),
      Name)
  end)

local varlist = factor("varlist", function() return
  -- varlist ::= var {‘,’ var}
    span(var, mark(span(__, ",", __, var), repeating))
  end)

-- Operator Precedence
local stat = factor("stat", function() return
  -- stat ::=  ‘;’ | 
  --      varlist ‘=’ explist | 
  --      functioncall | 
  --      label | 
  --      break | 
  --      goto Name | 
  --      do block end | 
  --      while exp do block end | 
  --      repeat block until exp | 
  --      if exp then block {elseif exp then block} [else block] end | 
  --      for Name ‘=’ exp ‘,’ exp [‘,’ exp] do block end | 
  --      for namelist in explist do block end | 
  --      function funcname funcbody | 
  --      local function Name funcbody | 
  --      local namelist [‘=’ explist] 
  any(
    span(";", __),
    span(varlist, __, "=", __, explist),
    functioncall,
    label,
    "break",
    span("goto", space, Name),
    span("do", block, "end"),
    span("while", space, exp, "do", space, mark(block, option), "end", space),
    span("repeat", block, "until", exp),
    span("local", space, namelist, __, mark(span("=", __, explist), option)))
    -- if
    -- for
    -- funnction
    -- local function
    -- local name list
  end)

explist = factor("explist", function() return
    -- explist ::= exp {‘,’ exp}
    span(exp, __, mark(span(",", __, exp), repeating))
  end)

namelist = factor("namelist", function() return
    -- namelist ::= Name {‘,’ Name}
    span(Name, __, mark(span(",", __, Name), repeating))
  end)

local retstat = factor("retstat", function() return
    -- retstat ::= return [explist] [‘;’]
    span("return", space, mark(explist, option), mark(";", option))
  end)

block = factor("block", function() return
    -- block ::= {stat} [retstat]
    span(__, mark(stat, repeating), __, mark(retstat, option))
  end)

--- Return the default _R table.
local function block_R()
  return {
    list(block),
    [" "]=list(skip_whitespace),
    ["\t"]=list(skip_whitespace),
    ["\n"]=list(skip_whitespace),
    ["\r"]=list(skip_whitespace),
    ["\r\n"]=list(skip_whitespace)
  }
end

--- Return the default _R table.
local function explist_R()
  return {
    list(explist),
    [" "]=list(skip_whitespace),
    ["\t"]=list(skip_whitespace),
    ["\n"]=list(skip_whitespace),
    ["\r"]=list(skip_whitespace),
    ["\r\n"]=list(skip_whitespace)
  }
end

return {
    block_R = block_R,
    explist_R = explist_R,
    functioncall = functioncall,
    retstat = retstat,
    Name = Name,
    stat = stat,
    var = var,
    prefixexp = prefixexp,
    exp = exp,
    LiteralString = LiteralString,
    explist = explist
}
