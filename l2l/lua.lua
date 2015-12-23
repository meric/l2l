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

local read_number = factor_nonterminal(number,
  function() return
    function(environment, bytes)
      local values, rest = reader.read_number(environment, bytes)
      if values then
        return list(Terminal(car(values))), rest
      end
      return nil, bytes
    end
  end)

local read_whitespace = factor_nonterminal(whitespace,
  function() return
    function(environment, bytes)
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

      local values, rest = read_predicate(environment, bytes, whitespace,
        match("^%s+$", unpack(patterns)))

      -- Convert boundary characters into zero string tokens.
      if values and bounds[tostring(car(values))] then
        return list(whitespace("")), bytes
      end
      return values, rest
    end
  end)

local read_Name  = SET(Name, function(environment, bytes)
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

local read_unop = factor_nonterminal(unop,
  -- unop ::= ‘-’ | not | ‘#’ | ‘~’
  function() return ANY(
    TERM("-"),
    ALL(TERM("not"), read_whitespace),
    TERM("#"),
    TERM("~")
  ) end)

local read_label = factor_nonterminal(label,
  -- label ::= ‘::’ Name ‘::’
  function() return ALL(
    TERM("::"),
    LABEL(read_whitespace, SKIP, OPTION),
    LABEL(read_Name),
    LABEL(read_whitespace, SKIP, OPTION),
    TERM("::")
  ) end)

local read_goto = factor_nonterminal(_goto,
  -- goto Name
  function() return ALL(
    TERM("goto"),
    LABEL(read_whitespace),
    read_Name
  ) end)

local read_exp
local read_var
local read_prefixexp
local read_block
local read_explist

local read_args = factor_nonterminal(_args,
  -- args ::=  ‘(’ [explist] ‘)’ | tableconstructor | LiteralString 
  function() return ANY(
    ALL(
      TERM("("),
      LABEL(read_whitespace, SKIP, OPTION),
      LABEL(read_explist, OPTION),
      LABEL(read_whitespace, SKIP, OPTION),
      TERM(")"))
  ) end)

local read_functioncall = factor_nonterminal(functioncall,
  -- functioncall ::=  prefixexp args | prefixexp ‘:’ Name args 
  function()
    return ANY(
      ALL(
        read_prefixexp,
        LABEL(read_whitespace, SKIP, OPTION),
        read_args)
  ) end)

local read_while = factor_nonterminal(_while,
  -- while exp do block end
  function() return ALL(
    TERM("while"),
    read_whitespace, -- omit SKIP to prevent "whilenil"
    LABEL(read_exp),
    TERM("do"),
    read_whitespace, -- omit SKIP to prevent "doreturn"
    LABEL(read_block, OPTION),
    TERM("end"),
    read_whitespace
  ) end)

read_exp = factor_nonterminal(exp,
  -- exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ |  
  --      functiondef | prefixexp | tableconstructor | exp binop exp | unop exp 
  function() return ALL(
    ANY(
      ALL(ANY(
        TERM("nil"),
        TERM("false"),
        TERM("true"),
        LABEL(read_number),
        TERM("...")),
        LABEL(read_whitespace)),
      read_prefixexp,
      ALL(read_unop, read_exp)
    )
  ) end)

read_prefixexp = factor_nonterminal(prefixexp,
  -- prefixexp ::= var | functioncall | ‘(’ exp ‘)’
  function(LEFT)
    return ANY(
      -- Give the parser a hint to avoid infinite loop on Left-recursion.
      -- We must call LEFT in `read_prefixexp` because the LEFT operator
      -- can only be used when either:
      --  1. the ALL clause argument, e.g. LEFT(ALL(read_prefixexp, ...))
      --  2. the read_* argument standing alone
      -- left recursions back to this nonterminal.
      LEFT(read_functioncall),
      LEFT(read_var),
      ALL(
        TERM("("),
        LABEL(read_whitespace, SKIP, OPTION),
        read_exp,
        LABEL(read_whitespace, SKIP, OPTION),
        TERM(")"),
        LABEL(read_whitespace, SKIP, OPTION)
      )
    ) end)

read_var = factor_nonterminal(var,
  -- var ::=  Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name 
  function()
    return ANY(
      ALL(
        read_prefixexp,
        LABEL(read_whitespace, SKIP, OPTION),
        TERM('['),
        LABEL(read_whitespace, SKIP, OPTION),
        read_exp,
        LABEL(read_whitespace, SKIP, OPTION),
        TERM("]"),
        LABEL(read_whitespace, SKIP, OPTION)),
      ALL(
        read_prefixexp,
        LABEL(read_whitespace, SKIP, OPTION),
        TERM("."),
        LABEL(read_whitespace, SKIP, OPTION),
        read_Name),
      read_Name
    ) end)

local read_varlist = factor_nonterminal(varlist,
  -- varlist ::= var {‘,’ var}
  function() return ALL(
    read_var,
    LABEL(ALL(
      LABEL(read_whitespace, SKIP, OPTION),
      TERM(","),
      LABEL(read_whitespace, SKIP, OPTION),
      read_var), REPEAT)
  ) end)

local read_stat = factor_nonterminal(stat,
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
    ALL(TERM(";"), LABEL(read_whitespace, SKIP, OPTION)),
    ALL(
      read_varlist,
      LABEL(read_whitespace, SKIP, OPTION),
      TERM("="),
      LABEL(read_whitespace, SKIP, OPTION),
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
  ) end)


-- read_stat = factor_nonterminal(
--   ANY(
--     read_semicolon,
--     ALL(read_varlist, read_equals, read_explist),
--     read_functioncall,
--     read_label,
--     read_break,
--     ALL(read_goto, read_Name),
--     ALL(read_do, read_block, read_end)
-- )

read_explist = factor_nonterminal(explist,
  -- explist ::= exp {‘,’ exp}
  function() return ALL(
    read_exp,
    LABEL(read_whitespace, SKIP, OPTION),
    LABEL(ALL(      
      TERM(","),
      LABEL(read_whitespace, SKIP, OPTION),
      read_exp), REPEAT)
  ) end)

local read_retstat = factor_nonterminal(retstat,
  -- retstat ::= return [explist] [‘;’]
  function() return ALL(
    TERM("return"),
    LABEL(read_whitespace),
    LABEL(read_explist, OPTION), --should be explist
    LABEL(TERM(";"), OPTION)
  ) end)

read_block = factor_nonterminal(block,
  function() return ALL(
    LABEL(read_whitespace, SKIP, OPTION),
    LABEL(read_stat, REPEAT),
    LABEL(read_whitespace, SKIP, OPTION),
    LABEL(read_retstat, OPTION)
  ) end)

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
    read_Name = read_Name,
    read_stat = read_stat,
    read_functioncall = read_functioncall,
    read_var = read_var,
    read_prefixexp = read_prefixexp
}
