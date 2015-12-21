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
local READ = grammar.READ
local SKIP = grammar.SKIP
local OPT = grammar.OPT
local REPEAT = grammar.REPEAT
local Terminal = grammar.Terminal
local NonTerminal = grammar.NonTerminal
local read_nonterminal = grammar.read_nonterminal

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


_elseif = Terminal("elseif")
_if = Terminal("if")

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

]]--

local Name = NonTerminal("Name")
local label = NonTerminal("label")
local funcname = NonTerminal("funcname")
local varlist = NonTerminal("varlist")
local exp = NonTerminal("exp")
local stat = NonTerminal("stat")
local block = NonTerminal("block")
local retstat = NonTerminal("retstat")
local whitespace = NonTerminal("whitespace")
local _goto = NonTerminal("goto")
local _while = NonTerminal("while")
local prefixexp = NonTerminal("prefixexp")
local explist = NonTerminal("explist")
local unop = NonTerminal("unop")
local label = NonTerminal("label")
local number = NonTerminal("number")
local var = NonTerminal("var")
local functioncall = NonTerminal("functioncall")
local _args = NonTerminal("args")

local read_number = SET(number, function(environment, bytes)
  local values, rest = reader.read_number(environment, bytes)
  if values then
    return list(Terminal(car(values))), rest
  end
  return nil, bytes
end)

local read_whitespace = SET(whitespace, function(environment, bytes)
-- * Mandatory read_whitespace after keywords should not be "SKIP"ed.
--   Otherwise when output the code could produce like "gotolabel",
--   which is not valid.
-- * In "ALL", read_whitespace prepend content elements that can have
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
    return list(whitespace("")), bytes
  end

  for byte, _ in pairs(bounds) do
    table.insert(patterns, "^%"..byte.."$")
  end

  local values, rest = read_predicate(environment, whitespace,
    match("^%s+$", unpack(patterns)), bytes)

  -- Convert boundary characters into zero string tokens.
  if values and bounds[tostring(car(values))] then
    return list(whitespace("")), bytes
  end
  return values, rest
end)

local read_Name  = SET(Name, function(environment, bytes)
  -- Names (also called identifiers) in Lua can be any string of letters,
  -- digits, and underscores, not beginning with a digit and not being a
  -- reserved word. Identifiers are used to name variables, table fields, and
  -- labels.
  local values, rest = read_predicate(environment,
    Name, function(token, byte)
      return (token..byte):match("^[%w_][%w%d_]*$")
    end, bytes)
  if values and car(values) and keywords[tostring(car(values))] then
    return nil, bytes
  end
  return values, rest
end)

local read_unop = read_nonterminal(unop,
  -- unop ::= ‘-’ | not | ‘#’ | ‘~’
  function() return ANY(
    TERM("-"),
    ALL(TERM("not"), read_whitespace),
    TERM("#"),
    TERM("~")
  ) end, true)

local read_label = read_nonterminal(label,
  -- label ::= ‘::’ Name ‘::’
  function() return ALL(
    TERM("::"),
    READ(read_whitespace, SKIP, OPT),
    READ(read_Name),
    READ(read_whitespace, SKIP, OPT),
    TERM("::")
  ) end, true)

local read_goto = read_nonterminal(_goto,
  -- goto Name
  function() return ALL(
    TERM("goto"),
    READ(read_whitespace),
    read_Name
  ) end, true)

local read_exp
local read_var
local read_prefixexp
local read_block
local read_explist

local read_args = read_nonterminal(_args,
  -- args ::=  ‘(’ [explist] ‘)’ | tableconstructor | LiteralString 
  function() return ANY(
    ALL(
      TERM("("),
      READ(read_whitespace, SKIP, OPT),
      READ(read_explist, OPT),
      READ(read_whitespace, SKIP, OPT),
      TERM(")"))
  ) end, true)

local read_functioncall = read_nonterminal(functioncall,
  -- functioncall ::=  prefixexp args | prefixexp ‘:’ Name args 
  function()
    return ANY(
      ALL(
        read_prefixexp,
        READ(read_whitespace, SKIP, OPT),
        read_args)
  ) end, true)

local read_while = read_nonterminal(_while,
  -- while exp do block end
  function() return ALL(
    TERM("while"),
    read_whitespace, -- omit SKIP to prevent "whilenil"
    READ(read_exp),
    TERM("do"),
    read_whitespace, -- omit SKIP to prevent "doreturn"
    READ(read_block, OPT),
    TERM("end"),
    read_whitespace
  ) end, true)

read_exp = read_nonterminal(exp,
  -- exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ |  
  --      functiondef | prefixexp | tableconstructor | exp binop exp | unop exp 
  function() return ALL(
    ANY(
      ALL(ANY(
        TERM("nil"),
        TERM("false"),
        TERM("true"),
        READ(read_number),
        TERM("...")),
        READ(read_whitespace)),
      read_prefixexp,
      ALL(read_unop, read_exp)
    )
  ) end, true)

read_prefixexp = read_nonterminal(prefixexp,
  -- prefixexp ::= var | functioncall | ‘(’ exp ‘)’
  function(left)
    local read_head = ALL(
      READ(TERM("("), OPT),
      READ(read_whitespace, SKIP, OPT),
      read_Name,
      READ(read_whitespace, SKIP, OPT),
      READ(TERM(")"), OPT))

    return ANY(
      -- Give the parser a hint to avoid infinite loop on Left-recursion.
      -- `var` can only begin with a Name or "(".
      left(read_head, read_functioncall),
      left(read_head, read_var),
      ALL(
        TERM("("),
        READ(read_whitespace, SKIP, OPT),
        read_exp,
        READ(read_whitespace, SKIP, OPT),
        TERM(")"),
        READ(read_whitespace, SKIP, OPT)
      )
    ) end)

read_var = read_nonterminal(var,
  -- var ::=  Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name 
  function()
    return ANY(
      ALL(
        read_prefixexp,
        READ(read_whitespace, SKIP, OPT),
        TERM('['),
        READ(read_whitespace, SKIP, OPT),
        read_exp,
        READ(read_whitespace, SKIP, OPT),
        TERM("]"),
        READ(read_whitespace, SKIP, OPT)),
      ALL(
        read_prefixexp,
        READ(read_whitespace, SKIP, OPT),
        TERM("."),
        READ(read_whitespace, SKIP, OPT),
        read_Name),
      read_Name
    ) end, true)

local read_varlist = read_nonterminal(varlist,
  -- varlist ::= var {‘,’ var}
  function() return ALL(
    read_var,
    READ(ALL(
      READ(read_whitespace, SKIP, OPT),
      TERM(","),
      READ(read_whitespace, SKIP, OPT),
      read_var), REPEAT)
  ) end, true)

local read_stat = read_nonterminal(stat,
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
    ALL(TERM(";"), READ(read_whitespace, SKIP, OPT)),
    ALL(
      read_varlist,
      READ(read_whitespace, SKIP, OPT),
      TERM("="),
      READ(read_whitespace, SKIP, OPT),
      read_explist),
    read_functioncall,
    -- do
    --repeat
    -- if
    -- for
    -- funnction
    -- local function
    -- local name list
    read_label,
    TERM("break"),
    read_goto,
    read_while
  ) end, true)


-- read_stat = read_nonterminal(
--   ANY(
--     read_semicolon,
--     ALL(read_varlist, read_equals, read_explist),
--     read_functioncall,
--     read_label,
--     read_break,
--     ALL(read_goto, read_Name),
--     ALL(read_do, read_block, read_end)
-- )

read_explist = read_nonterminal(explist,
  -- explist ::= exp {‘,’ exp}
  function() return ALL(
    read_exp,
    READ(read_whitespace, SKIP, OPT),
    READ(ALL(      
      TERM(","),
      READ(read_whitespace, SKIP, OPT),
      read_exp), REPEAT)
  ) end, true)

local read_retstat = read_nonterminal(retstat,
  -- retstat ::= return [explist] [‘;’]
  function() return ALL(
    TERM("return"),
    READ(read_whitespace),
    READ(read_explist, OPT), --should be explist
    READ(TERM(";"), OPT)
  ) end, true)

read_block = read_nonterminal(block,
  function() return ALL(
    READ(read_whitespace, SKIP, OPT),
    READ(read_stat, REPEAT),
    READ(read_whitespace, SKIP, OPT),
    READ(read_retstat, OPT)
  ) end, true)

--- Return the default _R table.
local function block_R()
  return {
    list(read_block)
  }
end

return {
    block_R = block_R,
    read_functioncall = read_functioncall,
    read_retstat = read_retstat,
    read_Name = read_Name
}
