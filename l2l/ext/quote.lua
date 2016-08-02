--1392635.7
local list = require("l2l.list")
local lua = require("l2l.lua")
local lua_ast = lua.lua_ast
local reader = require("l2l.reader")
local read_quote = reader.read_quote
local symbol = reader.symbol
local read = reader.read
local function compile_quote(invariant,cdr,output)assert(list.__len(cdr) == 1,"quote only accepts one parameter.");local cadr = cdr:car();if lua_ast[getmetatable(cadr)] then cadr=cadr:repr() end;return cadr end;local function read_quote(invariant,position)local rest,values = read(invariant,position + 1);if rest then values[1]=list(symbol("quote"),values[1]);return rest,values end end;return {lua={["quote"]={expize=compile_quote,statize=compile_quote}},read={[string.byte("'")]={read_quote}}}