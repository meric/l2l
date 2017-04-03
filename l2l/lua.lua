-- This file contains the definition of Lua, with one addition, where a
-- backslash allows escaping a l2llisp expression.

local utils = require("leftry.utils")
local ast = require("leftry.ast")
local ipairs = require("l2l.iterator")
local vector = require("l2l.vector")
local map = utils.map
local each =  utils.each

local grammar = require("leftry.grammar")

local opt = grammar.opt
local rep = grammar.rep
local factor = grammar.factor
local term = grammar.term

local lua_varlist
local lua_namelist
local lua_explist
local lua_block
local lua_funcname
local lua_fieldlist

local lua_name
local lua_ast

local loadstring = _G["loadstring"] or _G["load"]

local function lua_nameize(x)
  local reader = require("l2l.reader")
  if getmetatable(x) == reader.symbol then
    x = lua_name(x)
  end
  return x
end

local r
r = each(function(v, k)
    -- Define the Lua syntax tree representations, and corresponding output
    -- format using `ast.reduce`.
    local st = ast.reduce(k,
      type(v) ~= "function" and v or false,
      type(v) == "function" and v or nil)
    function st:repr()
      local reader = require("l2l.reader")
      local parameters = {}
      for _, v2 in ipairs(self.arguments) do
        local value = self[v2[1]]
        if utils.hasmetatable(value, lua_name) then
          table.insert(parameters, value:repr())
        elseif lua_ast[getmetatable(value)] then
          table.insert(parameters, value:repr())
        elseif type(value) == "string" then
          table.insert(parameters, reader.symbol(value))
        else
          table.insert(parameters, value)
        end
      end
      return r.lua_functioncall.new(
        r.lua_dot.new(lua_name(tostring(st)), lua_name("new")),
        r.lua_args.new(lua_explist(parameters)))
    end
    return st
  end, {
  lua_assign = {varlist=1, "=", explist=3},
  lua_dot = {prefix=1, ".", name=3},
  lua_index = {prefix=1, "[", key=3, "]"},
  lua_goto = {"goto ", label=2},
  lua_do = {"do\n", block=2, "\nend"},
  lua_while = {"\nwhile\n", condition=2, " do\n", block=4, "\nend"},
  lua_repeat = {"\nrepeat\n", block=2, "\nuntil ", condition=4},
  lua_if = {"\nif ", condition=2, " then ", block=4, _elseifs=5, _else=6,
    "\nend"},
  lua_elseif = {"\nelseif\n", condition=2, " then\n", block=4},
  lua_else = {"\nelse\n", block=2},
  lua_elseifs = function(self) return
      table.concat(map(tostring, self), "\n")
    end,
  lua_for = {"\nfor ", var=2, "=", initial=4, ",", limit=6, step=7, " do\n",
             block=9, "\nend"},
  lua_step = {",", step=2},
  lua_for_in = {"\nfor ", namelist=2, " in ", explist=4, " do\n", block=6,
                "\nend"},
  lua_function = {"\nfunction ", name=2, body=3},
  lua_lambda_function = {"function", body=2},
  lua_local_function = {"\nlocal", " function ", name=3, body=4},
  lua_retstat = {"\nreturn ", explist=2},
  lua_label = {"::", name=2, "::"},
  lua_binop_exp = {left=1, binop=2, right=3},
  lua_unop_exp = {unop=1, exp=2},
  lua_functioncall = {exp=1, args=2},
  lua_colon_functioncall = {exp=1, ":", name=3, args=4},
  lua_args = {"(", explist=2, ")" },
  lua_table = {"{", fieldlist=2, "}"},
  lua_funcbody = {"(", namelist=2, ")", block=4, "\nend"},
  lua_paren_exp = {"(", exp=2, ")"},
  lua_field_name = {name=1, "=", exp=3},
  lua_field_key = {"[", key=2, "]", "=", exp=5}
})

local lua_assign = r.lua_assign
local lua_dot = r.lua_dot
local lua_index = r.lua_index
local lua_goto = r.lua_goto
local lua_do = r.lua_do
local lua_while = r.lua_while
local lua_repeat = r.lua_repeat
local lua_if = r.lua_if
local lua_elseif = r.lua_elseif
local lua_else = r.lua_else
local lua_elseifs = r.lua_elseifs
local lua_for = r.lua_for
local lua_step = r.lua_step
local lua_for_in = r.lua_for_in
local lua_function = r.lua_function
local lua_lambda_function = r.lua_lambda_function
local lua_local_function = r.lua_local_function
local lua_retstat = r.lua_retstat
local lua_label = r.lua_label
local lua_binop_exp = r.lua_binop_exp
local lua_unop_exp = r.lua_unop_exp
local lua_functioncall = r.lua_functioncall
local lua_colon_functioncall = r.lua_colon_functioncall
local lua_args = r.lua_args
local lua_table = r.lua_table
local lua_funcbody = r.lua_funcbody
local lua_paren_exp = r.lua_paren_exp
local lua_field_name = r.lua_field_name
local lua_field_key = r.lua_field_key

local lua_local = ast.reduce("lua_local", {"\nlocal", namelist=2, explist=3},
  function(self)
    local text = {"\nlocal", tostring(self.namelist)}
    if self.explist then
      table.insert(text, "=")
      table.insert(text, tostring(self.explist))
    end
    return table.concat(text, " ")
  end)

function lua_local:repr()
  local parameters = {}
  for _, v in ipairs(self.arguments) do
    local value = self[v[1]]
    local reader = require("l2l.reader")
    if lua_ast[getmetatable(value)] then
      table.insert(parameters, value:repr())
    elseif type(value) == "string" then
      table.insert(parameters, reader.symbol(value))
    else
      table.insert(parameters, value)
    end
  end
  return r.lua_functioncall.new(
    r.lua_dot.new(lua_name(tostring(lua_local)), lua_name("new")),
    r.lua_args.new(lua_explist(parameters)))
end

local function _list(...)
  local st = ast.list(...)
  function st:repr()
    local reader = require("l2l.reader")
    local parameters = {}
    for _, value in ipairs(self) do
      if lua_ast[getmetatable(value)] then
        table.insert(parameters, value:repr())
      elseif type(value) == "string" then
        table.insert(parameters, utils.escape(value))
      else
        table.insert(parameters, value)
      end
    end
    return r.lua_functioncall.new(lua_name(tostring(st)),
      r.lua_args.new(lua_explist({
        lua_table.new(lua_fieldlist(parameters))
      })))
  end
  return st
end

local function name_cast(values)
  local u = {}
  for _, value in ipairs(values) do
    if utils.hasmetatable(value, lua_namelist) then
      for _, name in ipairs(name_cast(value)) do
        table.insert(u, name)
      end
    else
      if not utils.hasmetatable(value, lua_name) then
        value = lua_name(value)
      end
      table.insert(u, value)
    end
  end
  return u
end

local function var_cast(values)
  local u = {}
  for _, value in ipairs(values) do
    if utils.hasmetatable(value, lua_varlist) then
      for _, name in ipairs(var_cast(value)) do
        table.insert(u, name)
      end
    else
      if not utils.hasmetatable(value, lua_name)
        and not utils.hasmetatable(value, lua_dot)
        and not utils.hasmetatable(value, lua_index) then
        value = lua_name(value)
      end
      table.insert(u, value)
    end
  end
  return u
end

lua_varlist = _list("lua_varlist", ",", nil, var_cast)
lua_namelist = _list("lua_namelist", ",", nil, name_cast)
lua_explist = _list("lua_explist", ",")

-- Check if this Lua supports consecutive semicolons.
-- If not, use `do end` for noop.
if (loadstring(";;")) then
  lua_block = _list("lua_block", ";")
else
  lua_block = _list("lua_block", "\ndo end\n")
end
lua_funcname = _list("lua_funcname")
lua_fieldlist = _list("lua_fieldlist", ",")

local lua_nil = ast.const("lua_nil", "nil")
local lua_true = ast.const("lua_true", "true")
local lua_false = ast.const("lua_false", "false")
local lua_break = ast.const("lua_break", "break")
local lua_vararg = ast.const("lua_vararg", "...")
local lua_semicolon = ast.const("lua_semicolon", ";")


local function ident(...)
  local st = ast.id(...)
  function st:repr()
    local parameters
    if type(self.value) == "string" then
      parameters = {utils.escape(self.value)}
    elseif type(self.value) == "number" then
      parameters = {self.value}
    else
      parameters = {self.value}
    end
    return lua_functioncall.new(
      lua_name(tostring(st)),
      lua_args.new(lua_explist(parameters)))
  end
  return st
end

lua_name = ident("lua_name", nil, nil, function(value)
  local reader = require("l2l.reader")
  if utils.hasmetatable(value, lua_name) then
    value = value.value
  elseif utils.hasmetatable(value, reader.symbol) then
    value = lua_name(value:mangle())
  end
  return value
end)

function lua_name:unique(prefix)
  self.n = self.n or 0
  prefix = prefix..self.n
  self.n = self.n + 1
  return self(prefix)
end

local lua_string = ident("lua_string", "value", function(self)
  return utils.escape(self.value)
end)
local lua_chunk = ident("lua_chunk", "block")
local lua_binop = ident("lua_binop", "value", function(self)
  return " "..self.value.." "
end)
local lua_unop = ident("lua_unop", "value", function(self)
  return " "..self.value.." "
end)

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

-- Non-Terminals


local initializers = require("leftry.initializers")
local reducers = require("leftry.reducers")

local none = initializers.none
local leftflat = initializers.leftflat
local rightflat = initializers.rightflat
local first = reducers.first
local second = reducers.second
local concat = reducers.concat


local Chunk, Block, Stat, RetStat, Label, FuncName, VarList, Var, NameList,
      ExpList, Exp, PrefixExp, FunctionCall, Args, FunctionDef, FuncBody,
      ParList, TableConstructor, FieldList, Field, FieldSep, BinOp, UnOp,
      numeral, Numeral, LiteralString, Name, Comment, LongString,
      LispExp, LispStat, NameOrLispExp, FuncNameOrLispExp

local dquoted, squoted

local is_space = {
  [(" "):byte()] = true,
  [("\t"):byte()] = true,
  [("\r"):byte()] = true,
  [("\n"):byte()] = true,
}

local underscore, alpha, zeta, ALPHA, ZETA = 95, 97, 122, 65, 90
local zero, nine = 48, 57

local function isalphanumeric(byte)
  return byte and (byte == underscore or byte >= alpha and byte <= zeta or
    byte >= ALPHA and byte <= ZETA or byte >= zero and byte <= nine)
end

local function isalpha(byte)
  return byte and (byte == underscore or byte >= alpha and byte <= zeta or
    byte >= ALPHA and byte <= ZETA)
end

Comment = factor("Comment", function() return
  grammar.span("--", function(invariant, position, peek)
    -- Parse --[[ comment ]]
    local value

    if LongString(invariant, position, true) then
      position, value = LongString(invariant, position, peek)
    else
      while invariant.source:sub(position, position) ~= "\n" do
        position = position + 1
      end
    end
    return position, value
  end) end)

local spaces = " \t\r\n"

local function spacing(invariant, position, previous)
  local src, byte = invariant.source

  -- Skip whitespace and comments
  local comment = position
  local rest
  repeat
    rest = comment
    byte = src:byte(rest)
    while is_space[byte] do
      rest = rest + 1
      byte = src:byte(rest)
    end
    comment = Comment(invariant, rest, true)
  until not comment

  -- Check for required whitespace between two alphanumeric nonterminals.
  if rest == position and getmetatable(previous) == term then
    if isalphanumeric(src:byte(position-1)) and isalphanumeric(byte) then
      return
    end
  end

  -- Return advanced cursor.
  return rest
end

local function span(...)
  -- Apply spacing rule to all spans we use in the Lua grammar.
  return grammar.span(...) ^ {spacing=spacing, spaces=spaces}
end

Chunk = factor("Chunk", function() return Block end, lua_chunk)
Block = factor("Block", function() return
  span(rep(Stat), opt(RetStat)) % leftflat end, lua_block)
Stat = factor("Stat", function() return
  term(';') % lua_semicolon,
  span(VarList, "=", ExpList) % lua_assign,
  FunctionCall,
  span("\\", LispStat) % second,
  Label,
  term("break") % lua_break,
  span("goto", Name) % lua_goto,
  span("do", opt(Block), "end") % lua_do,
  span("while", Exp, "do", opt(Block), "end") % lua_while,
  span("repeat", Block, "until", Exp) % lua_repeat,
  span("if", Exp, "then", opt(Block),
    rep(span("elseif", Exp, "then", opt(Block)) % lua_elseif) % lua_elseifs,
    opt(span("else", opt(Block)) % lua_else), "end") % lua_if,
  span("for", Name, "=", Exp, ",", Exp, opt(span(",", Exp) % lua_step),
    "do", Block, "end") % lua_for,
  span("for", NameList, "in", ExpList, "do", opt(Block), "end") % lua_for_in,
  span("function", FuncNameOrLispExp, FuncBody) % lua_function,
  span("local", "function", Name, FuncBody) % lua_local_function,
  span("local", NameList, opt(span("=", ExpList) % second)) % lua_local end)
RetStat = factor("RetStat", function() return
  span("return", opt(ExpList), opt(term(";") % none)) % lua_retstat end)
Label = factor("Label", function() return
  span("::", Name, "::") % lua_label end)
FuncName = factor("FuncName", function() return
  span(
    rep(span(Name, ".") % concat), Name,
    opt(span(":", Name) % concat)) % leftflat end,
  lua_funcname)
VarList = factor("VarList", function() return
  span(Var, rep(span(",", Var) % second))
    % rightflat end, lua_varlist)
Var = factor("Var", function() return
  Name,
  span("\\", LispExp) % second,
  span(PrefixExp, "[", Exp, "]") % lua_index,
  span(PrefixExp, ".", Name) % lua_dot end)
FuncNameOrLispExp = factor("FuncNameOrLispExp", function() return
  FuncName,
  span("\\", LispExp)
    % utils.compose(second, lua_name, vector, lua_funcname) end)
NameOrLispExp = factor("NameOrLispExp", function() return
  Name, span("\\", LispExp) % second end)
NameList = factor("NameList", function() return
  span(NameOrLispExp, rep(span(",", NameOrLispExp) % second))
    % rightflat end, lua_namelist)
ExpList = factor("ExpList", function() return
  span(Exp, rep(span(",", Exp) % second)) % rightflat end, lua_explist)
Exp = factor("Exp", function(Exp2) return
  term("nil") % lua_nil,
  term("false") % lua_false,
  term("true") % lua_true,
  Numeral,
  LiteralString,
  term("...") % lua_vararg,
  FunctionDef,
  PrefixExp,
  TableConstructor,
  span("\\", LispExp) % second,
  span(Exp2, BinOp, Exp2) % lua_binop_exp,
  span(UnOp, Exp2) % lua_unop_exp end)
LispStat = function(invariant, position, peek)
  local reader = require("l2l.reader")
  local ok, rest, values = pcall(reader.read, invariant, position)
  if not ok then
    return
  end
  if peek then
    return rest
  end
  if not rest then
    error("Could not compile Lisp expression embedded in Lua."..
      invariant.source:sub(position, position+10))
  end
  return rest, values[1]
end
LispExp = function(invariant, position, peek)
  local reader = require("l2l.reader")
  local ok, rest, values = pcall(reader.read, invariant, position)
  if not ok then
    return
  end
  if peek then
    return rest
  end
  if not rest then
    error("Could not compile Lisp expression embedded in Lua."..
      invariant.source:sub(position, position+10))
  end
  local expr = values[1]
  return rest, expr
end
FunctionCall = factor("FunctionCall", function() return
  span(PrefixExp, Args) % lua_functioncall,
  span(PrefixExp, ":", Name, Args) % lua_colon_functioncall end)
Args = factor("Args", function() return
  span("(", opt(ExpList), ")") % lua_args,
  TableConstructor,
  LiteralString end)
FunctionDef = factor("FunctionDef", function() return
  span("function", FuncBody) % lua_lambda_function end)
PrefixExp = factor("PrefixExp", function() return
  Var, FunctionCall, span("(", Exp, ")") % lua_paren_exp end)
FuncBody = factor("FuncBody", function() return
  span("(", opt(ParList), ")", opt(Block), "end") % lua_funcbody end)
ParList = factor("ParList", function() return
  span(NameList, opt(span(",", term("...") % lua_vararg) % second)) % leftflat,
  term("...") % lua_vararg end)
TableConstructor = factor("TableConstructor", function() return
  span("{", opt(FieldList), "}") % lua_table end)
FieldList = factor("FieldList", function() return
  span(span(Field, rep(span(FieldSep, Field) % second)) % rightflat,
    opt(FieldSep)) % first end, lua_fieldlist)
FieldSep = factor("FieldSep", function() return
  ",", ";" end)
Field = factor("Field", function() return
  span("[", Exp, "]", "=", Exp) % lua_field_key,
  span(Name, "=", Exp) % lua_field_name, Exp end)
BinOp = factor("BinOp", function() return
  "^", "*", "/", "//", "%", "+", "-", "..", "<<", ">>", "&", "|",  "<=",
  ">=", "<", ">", "~=", "==", "and", "or" end, lua_binop)
UnOp = factor("UnOp", function() return
  "-", "not", "#", "~" end, lua_unop)
LiteralString = factor("LiteralString", function() return
  grammar.span("\"", opt(dquoted), "\"") % second,
  grammar.span("\'", opt(squoted), "\'") % second,
  LongString end, lua_string)

local long_string_quote = grammar.span("[", rep("="), "[")
LongString = function(invariant, position, peek)
  local rest = long_string_quote(invariant, position, true)
  if not rest then
    return
  end
  local level = position - rest - 2
  local endquote = "]"..("="):rep(level) .. "]"
  local endquotestart, endquoteend = invariant.source:find(endquote, rest)
  if not endquotestart then
    return
  end
  local value = invariant.source:sub(rest, endquotestart-1)
  rest = endquoteend + 1
  if peek then
    return rest
  end
  return rest, value
end

-- Functions
local function stringcontent(quotechar)
  return function(invariant, position)
    local src = invariant.source
    local limit = #src
    if position > limit then
      return
    end
    local escaped = false
    local value = {}
    local byte
    for i=position, limit do
      if not escaped and byte == "\\" then
        escaped = true
      else
        if escaped and byte == "n" then
          byte = "\n"
        end
        escaped = false
      end
      if not escaped then
        table.insert(value, byte)
      end
      byte = string.char(invariant.source:byte(i))
      if byte == quotechar and not escaped then
        return i, table.concat(value)
      end
    end
    error("unmatched quote: " .. src)
  end
end

dquoted = stringcontent("\"")
squoted = stringcontent("\'")

numeral = function(invariant, position, peek)
  local sign = position
  local src = invariant.source
  local byte = src:byte(position)
  local dot, minus = 46, 45
  if byte == minus then
    sign = position + 1
  end
  local decimal = false
  local rest
  for i=sign, #src do
    local byte2 = src:byte(i)
    if i ~= sign and byte2 == dot and decimal == false then
      decimal = true
    elseif not (byte2 >= zero and byte2 <= nine) then
      rest = i
      break
    elseif i == #src then
      rest = #src + 1
    end
  end
  if rest == position or rest == sign then
    -- Not a number
    return nil
  end
  if peek then
    return rest
  end
  return rest, tonumber(src:sub(position, rest-1))
end

Numeral = function(invariant, position, peek)
  return numeral(invariant, position, peek)
end

local keywords = {
  ["return"] = true,
  ["function"] = true,
  ["end"] = true,
  ["in"] = true,
  ["not"] = true,
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["for"] = true,
  ["if"] = true,
  ["local"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["then"] = true,
  ["until"] = true,
  ["while"] = true
}

Name = function(invariant, position, peek)
  local src = invariant.source
  local byte = src:byte(position)

  if not isalpha(byte) then
    return nil
  end

  local rest = position + 1
  for i=position+1, #src do
    byte = src:byte(i)
    if not isalphanumeric(byte) then
      break
    end
    rest = i + 1
  end

  local value = src:sub(position, rest-1)

  if keywords[value] then
    return
  end

  if peek then
    return rest
  end

  return rest, lua_name(value)
end

local lua_lazy = utils.prototype("lua_lazy", function(self, f)
  return setmetatable({f=f}, self)
end)

function lua_lazy:__tostring()
  return tostring(self.f())
end

function lua_lazy:gsub(...)
  return self.f():gsub(...)
end

lua_ast = {
  [lua_assign] = lua_assign,
  [lua_dot] = lua_dot,
  [lua_index] = lua_index,
  [lua_goto] = lua_goto,
  [lua_do] = lua_do,
  [lua_while] = lua_while,
  [lua_repeat] = lua_repeat,
  [lua_if] = lua_if,
  [lua_elseif] = lua_elseif,
  [lua_else] = lua_else,
  [lua_elseifs] = lua_elseifs,
  [lua_for] = lua_for,
  [lua_step] = lua_step,
  [lua_for_in] = lua_for_in,
  [lua_function] = lua_function,
  [lua_lambda_function] = lua_lambda_function,
  [lua_local_function] = lua_local_function,
  [lua_retstat] = lua_retstat,
  [lua_label] = lua_label,
  [lua_binop_exp] = lua_binop_exp,
  [lua_unop_exp] = lua_unop_exp,
  [lua_functioncall] = lua_functioncall,
  [lua_colon_functioncall] = lua_colon_functioncall,
  [lua_args] = lua_args,
  [lua_table] = lua_table,
  [lua_funcbody] = lua_funcbody,
  [lua_paren_exp] = lua_paren_exp,
  [lua_local] = lua_local,
  [lua_varlist] = lua_varlist,
  [lua_namelist] = lua_namelist,
  [lua_explist] = lua_explist,
  [lua_block] = lua_block,
  [lua_funcname] = lua_funcname,
  [lua_fieldlist] = lua_fieldlist,
  [lua_nil] = lua_nil,
  [lua_true] = lua_true,
  [lua_false] = lua_false,
  [lua_break] = lua_break,
  [lua_vararg] = lua_vararg,
  [lua_semicolon] = lua_semicolon,
  [lua_string] = lua_string,
  [lua_chunk] = lua_chunk,
  [lua_binop] = lua_binop,
  [lua_unop] = lua_unop,
  [lua_name] = lua_name,
  [lua_lazy] = lua_lazy,
}


local exports = {
  Lua=Chunk,
  Chunk=Chunk,
  Block=Block,
  Stat=Stat,
  RetStat=RetStat,
  Label=Label,
  FuncName=FuncName,
  VarList=VarList,
  Var=Var,
  NameList=NameList,
  ExpList=ExpList,
  Exp=Exp,
  PrefixExp=PrefixExp,
  FunctionCall=FunctionCall,
  Args=Args,
  FunctionDef=FunctionDef,
  FuncBody=FuncBody,
  ParList=ParList,
  TableConstructor=TableConstructor,
  FieldList=FieldList,
  Field=Field,
  FieldSep=FieldSep,
  BinOp=BinOp,
  isalphanumeric=isalphanumeric,
  isalpha=isalpha,
  UnOp=UnOp,
  Numeral=Numeral,
  numeral=numeral,
  LiteralString=LiteralString,
  Name=Name,
  NameOrLispExp=NameOrLispExp,
  FuncNameOrLispExp=FuncNameOrLispExp,
  Comment=Comment,
  LongString=LongString,
  span=span,
  rep=rep,
  spacing=spacing,
  term=term,
  factor=factor,
  spaces=spaces,
  is_space=is_space,
  lua_ast = lua_ast,
  lua_assign = lua_assign,
  lua_dot = lua_dot,
  lua_index = lua_index,
  lua_goto = lua_goto,
  lua_do = lua_do,
  lua_while = lua_while,
  lua_repeat = lua_repeat,
  lua_if = lua_if,
  lua_elseif = lua_elseif,
  lua_else = lua_else,
  lua_elseifs = lua_elseifs,
  lua_for = lua_for,
  lua_step = lua_step,
  lua_for_in = lua_for_in,
  lua_function = lua_function,
  lua_lambda_function = lua_lambda_function,
  lua_local_function = lua_local_function,
  lua_retstat = lua_retstat,
  lua_label = lua_label,
  lua_binop_exp = lua_binop_exp,
  lua_unop_exp = lua_unop_exp,
  lua_functioncall = lua_functioncall,
  lua_colon_functioncall = lua_colon_functioncall,
  lua_args = lua_args,
  lua_table = lua_table,
  lua_funcbody = lua_funcbody,
  lua_paren_exp = lua_paren_exp,
  lua_local = lua_local,
  lua_varlist = lua_varlist,
  lua_namelist = lua_namelist,
  lua_explist = lua_explist,
  lua_block = lua_block,
  lua_funcname = lua_funcname,
  lua_fieldlist = lua_fieldlist,
  lua_nil = lua_nil,
  lua_true = lua_true,
  lua_false = lua_false,
  lua_break = lua_break,
  lua_vararg = lua_vararg,
  lua_semicolon = lua_semicolon,
  lua_string = lua_string,
  lua_chunk = lua_chunk,
  lua_binop = lua_binop,
  lua_unop = lua_unop,
  lua_name = lua_name,
  lua_field_name = lua_field_name,
  lua_field_key = lua_field_key,
  lua_lazy = lua_lazy,
  lua_nameize = lua_nameize
}

for _, v in pairs(exports) do
  if getmetatable(v) == grammar.factor and v ~= LispExp then
    v:setup()
    v:actualize()
  end
end

return exports
