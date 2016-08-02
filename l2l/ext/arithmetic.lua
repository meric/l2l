--2426113
local compiler = require("l2l.compiler")
local import = compiler.import
local arithmetic = import("l2l.lib.arithmetic")
local _43 = arithmetic._43
local list = require("l2l.list")
local reader = require("l2l.reader")
local symbol = reader.symbol
local lua = require("l2l.lua")
local lua_number = lua.lua_number
local lua_paren_exp = lua.lua_paren_exp
local lua_binop = lua.lua_binop
local lua_binop_exp = lua.lua_binop_exp
local function _43(a,...)if a == symbol("...") then if ... then error("... must be last argument.") end;a=list(symbol("+"), symbol("...")) end;if  not a then return lua_number(0) end;if ... then return lua_paren_exp.new(lua_binop_exp.new(a,lua_binop("+"),_43(...))) end;return a end
return {macro={[(symbol("+")):hash()]=_43}}