local itertools = require("l2l.itertools")
local reader = require("l2l.reader3")
local grammar = require("l2l.grammar")

local list = itertools.list
local car = itertools.car

local match = reader.match
local read_predicate = reader.read_predicate

local associate = grammar.associate
local span = grammar.span
local any = grammar.any
local mark = grammar.mark
local skip = grammar.skip
local option = grammar.option
local repeating = grammar.repeating
local Terminal = grammar.Terminal
local NonTerminal = grammar.NonTerminal
local factor = grammar.factor

local ParseException = grammar.ParseException

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
${x} means hash
$ => hash next lisp symbol into Name.
${} => quasiquote eval???

(print ${<div>Hello</div>})
(print $.{1 + 2})
(print ${ x << local x = 1 + $z + $(+ 7 8)})


(let
  (z 8)
  (print ${x <- local x = 1 + $z + $(+ 7 8)}) ;; Prints 9
  (print `${x <- local x = 1 + ${z} + $z))

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
LuaLabel
LuaFunctionName
LuaVariableList
LuaExpression
LuaStatement
LuaBlock
LuaReturnStatement
LuaWhitespace
LuaGoto
LuaWhile
LuaPrefixExpression
LuaExpressionList
LuaUnaryOperation
LuaLabel
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


local Name = NonTerminal("space")

local number = factor("number",
  function() return
    function(environment, bytes)
      local values, rest = reader.read_number(environment, bytes)
      if values then
        return list(tonumber(car(values))), rest
      end
      return nil, bytes
    end
  end)

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

local Name  = associate(Name, function(environment, bytes)
  -- Names (also called identifiers) in Lua can be any string of letters,
  -- digits, and underscores, not beginning with a digit and not being a
  -- reserved word. Identifiers are used to name variables, table fields, and
  -- labels.
  local values, rest = read_predicate(environment, bytes,
    Name, function(token, byte)
      return (token..byte):match("^[%w_][%w%d_]*$")
    end)
  if values and car(values) and keywords[tostring(car(values))] then
    return nil, bytes
  end
  return values, rest
end)

local unop = factor("unop", function() return
    -- unop ::= ‘-’ | not | ‘#’ | ‘~’
    any("-", span("not", space), "#", "~")
  end)

local label = factor("label", function() return
    -- label ::= ‘::’ Name ‘::’
    span("::", __, Name, __, "::")
  end)

local exp
local var
local prefixexp
local block
local explist

local args = factor("args", function() return
  -- args ::=  ‘(’ [explist] ‘)’ | tableconstructor | LiteralString 
    any(span("(", __, mark(explist, option), __, ")"))
  end)

local functioncall = factor("functioncall", function() return
  -- functioncall ::=  prefixexp args | prefixexp ‘:’ Name args 
    any(span(prefixexp, __, args), span(prefixexp, __, ":", __, Name, __, args))
  end)

exp = factor("exp", function() return
  -- exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ |  
  --      functiondef | prefixexp | tableconstructor | exp binop exp | unop exp 
    any(
      span(any("nil", "false", "true", number, "..."), space),
      prefixexp,
      span(unop, exp))
  end)

prefixexp = factor("prefixexp", function(left) return
  -- prefixexp ::= var | functioncall | ‘(’ exp ‘)’
  --
  -- Give the parser a hint to avoid infinite loop on Left-recursion.
  -- We must call left in `prefixexp` because the left operator
  -- can only be used when either:
  --  1. the all clause argument, e.g. left(span(prefixexp, ...))
  --  2. the * argument standing alone
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
    span("repeat", block, "until", exp))
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
    list(block)
  }
end

return {
    block_R = block_R,
    functioncall = functioncall,
    retstat = retstat,
    Name = Name,
    stat = stat,
    functioncall = functioncall,
    var = var,
    prefixexp = prefixexp
}
