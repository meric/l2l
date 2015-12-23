local itertools = require("l2l.itertools")
local reader = require("l2l.reader3")
local grammar = require("l2l.grammar")

local list = itertools.list
local car = itertools.car

local match = reader.match
local read_predicate = reader.read_predicate

local SET = grammar.SET
local ALL = grammar.ALL
local ANY = grammar.ANY
local TERM = grammar.TERM
local LABEL = grammar.LABEL
local SKIP = grammar.SKIP
local OPTION = grammar.OPTION
local REPEAT = grammar.REPEAT
local Terminal = grammar.Terminal
local NonTerminal = grammar.NonTerminal
local factor_nonterminal = grammar.factor_nonterminal

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
local unop = factor_nonterminal(unop,
  -- unop ::= ‘-’ | not | ‘#’ | ‘~’
  function() return ANY(
    TERM("-"),
    ALL(TERM("not"), whitespace),
    TERM("#"),
    TERM("~")
  ) end)


($ unop ::= "-" | "not" whitespace | "#" | "~";
   whitespace = function() )
]]--

local Name = NonTerminal("whitespace")

local number = factor_nonterminal("number",
  function() return
    function(environment, bytes)
      local values, rest = reader.read_number(environment, bytes)
      if values then
        return list(tonumber(car(values))), rest
      end
      return nil, bytes
    end
  end)

local whitespace = factor_nonterminal("whitespace",
  function() return
    function(environment, bytes)
    -- * Mandatory whitespace after keywords should not be "SKIP"ed.
    --   Otherwise when output the code could produce like "gotolabel",
    --   which is not valid.
    -- * In "ALL", whitespace prepend content elements that can have
    --   whitespaces prepending it.
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

local Name  = SET(Name, function(environment, bytes)
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

local unop = factor_nonterminal("unop",
  -- unop ::= ‘-’ | not | ‘#’ | ‘~’
  function() return ANY(
    "-",
    ALL("not", whitespace),
    "#",
    "~"
  ) end)

local label = factor_nonterminal("label",
  -- label ::= ‘::’ Name ‘::’
  function() return ALL(
    "::",
    LABEL(whitespace, SKIP, OPTION),
    LABEL(Name),
    LABEL(whitespace, SKIP, OPTION),
    "::"
  ) end)

local _goto = factor_nonterminal("goto",
  -- goto Name
  function() return ALL(
    "goto",
    LABEL(whitespace),
    Name
  ) end)

local exp
local var
local prefixexp
local block
local explist

local args = factor_nonterminal("args",
  -- args ::=  ‘(’ [explist] ‘)’ | tableconstructor | LiteralString 
  function() return ANY(
    ALL(
      "(",
      LABEL(whitespace, SKIP, OPTION),
      LABEL(explist, OPTION),
      LABEL(whitespace, SKIP, OPTION),
      ")")
  ) end)

local functioncall = factor_nonterminal("functioncall",
  -- functioncall ::=  prefixexp args | prefixexp ‘:’ Name args 
  function()
    return ANY(
      ALL(
        prefixexp,
        LABEL(whitespace, SKIP, OPTION),
        args)
  ) end)

local _while = factor_nonterminal("while",
  -- while exp do block end
  function() return ALL(
    "while",
    whitespace, -- omit SKIP to prevent "whilenil"
    LABEL(exp),
    "do",
    whitespace, -- omit SKIP to prevent "doreturn"
    LABEL(block, OPTION),
    "end",
    whitespace
  ) end)

exp = factor_nonterminal("exp",
  -- exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ |  
  --      functiondef | prefixexp | tableconstructor | exp binop exp | unop exp 
  function() return ALL(
    ANY(
      ALL(ANY(
        "nil",
        "false",
        "true",
        LABEL(number),
        "..."),
        LABEL(whitespace)),
      prefixexp,
      ALL(unop, exp)
    )
  ) end)

prefixexp = factor_nonterminal("prefixexp",
  -- prefixexp ::= var | functioncall | ‘(’ exp ‘)’
  function(LEFT)
    return ANY(
      -- Give the parser a hint to avoid infinite loop on Left-recursion.
      -- We must call LEFT in `prefixexp` because the LEFT operator
      -- can only be used when either:
      --  1. the ALL clause argument, e.g. LEFT(ALL(prefixexp, ...))
      --  2. the * argument standing alone
      -- left recursions back to this nonterminal.
      LEFT(functioncall),
      LEFT(var),
      ALL(
        "(",
        LABEL(whitespace, SKIP, OPTION),
        exp,
        LABEL(whitespace, SKIP, OPTION),
        ")",
        LABEL(whitespace, SKIP, OPTION)
      )
    ) end)

var = factor_nonterminal("var",
  -- var ::=  Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name 
  function()
    return ANY(
      ALL(
        prefixexp,
        LABEL(whitespace, SKIP, OPTION),
        "[",
        LABEL(whitespace, SKIP, OPTION),
        exp,
        LABEL(whitespace, SKIP, OPTION),
        "]",
        LABEL(whitespace, SKIP, OPTION)),
      ALL(
        prefixexp,
        LABEL(whitespace, SKIP, OPTION),
        ".",
        LABEL(whitespace, SKIP, OPTION),
        Name),
      Name
    ) end)

local varlist = factor_nonterminal("varlist",
  -- varlist ::= var {‘,’ var}
  function() return ALL(
    var,
    LABEL(ALL(
      LABEL(whitespace, SKIP, OPTION),
      ",",
      LABEL(whitespace, SKIP, OPTION),
      var), REPEAT)
  ) end)

local stat = factor_nonterminal("stat",
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
  function() return ANY(
    ALL(";", LABEL(whitespace, SKIP, OPTION)),
    ALL(
      varlist,
      LABEL(whitespace, SKIP, OPTION),
      "=",
      LABEL(whitespace, SKIP, OPTION),
      explist),
    functioncall,
    label,
    "break",
    _goto,
    ALL("do", block, "end"),
    _while,
    ALL("repeat", block, "until", exp)


    -- do
    --repeat
    -- if
    -- for
    -- funnction
    -- local function
    -- local name list
    
  ) end)


-- stat = factor_nonterminal(
--   ANY(
--     semicolon,
--     ALL(varlist, equals, explist),
--     functioncall,
--     label,
--     break,
--     ALL(goto, Name),
--     ALL(do, block, end)
-- )

explist = factor_nonterminal("explist",
  -- explist ::= exp {‘,’ exp}
  function() return ALL(
    exp,
    LABEL(whitespace, SKIP, OPTION),
    LABEL(ALL(      
      ",",
      LABEL(whitespace, SKIP, OPTION),
      exp), REPEAT)
  ) end)

local retstat = factor_nonterminal("retstat",
  -- retstat ::= return [explist] [‘;’]
  function() return ALL(
    "return",
    whitespace,
    LABEL(explist, OPTION), --should be explist
    LABEL(TERM(";"), OPTION)
  ) end)

block = factor_nonterminal("block",
  -- block ::= {stat} [retstat]
  function() return ALL(
    LABEL(whitespace, SKIP, OPTION),
    LABEL(stat, REPEAT),
    LABEL(whitespace, SKIP, OPTION),
    LABEL(retstat, OPTION)
  ) end)

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
