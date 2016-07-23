local utils = require("leftry").utils
local list = require("l2l.list")
local lua = require("l2l.lua")
local reader = require("l2l.reader")
local vector = require("l2l.vector")
local symbol = reader.symbol

local invariantize = require("leftry.elements.utils").invariantize

local lua_functioncall = lua.lua_functioncall
local lua_explist = lua.lua_explist
local lua_number = lua.lua_number
local lua_name = lua.lua_name
local lua_ast = lua.lua_ast

local lua_keyword = {
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

local function hash(text)
  local prefix = ""
  if text == "..." then
    return "..."
  end
  if lua_keyword[text] then
    pattern = "(.)"
    prefix = text
  else
    pattern = "[^_a-zA-Z0-9.%[%]]"
  end
  return prefix..text:gsub(pattern, function(char)
    if char == "-" then
      return "_"
    elseif char == "!" then
      return "_bang"
    else
      return "_"..char:byte()
    end
  end)
end

local function expand(data)
  return data
end

local function validate_functioncall(car)
  assert(
    getmetatable(car) ~= lua_number and (
    utils.hasmetatable(car, list) or
    utils.hasmetatable(car, symbol) or
    lua_ast[getmetatable(car)]),
    "only expressions and symbols can be called.")
end

local function luaize(invariant, data, output)
  invariant._luaize = invariant._luaize or function(value)
    return luaize(invariant, value)
  end
  if utils.hasmetatable(data, list) then
    local car = data:car()
    if utils.hasmetatable(car, symbol) and invariant.L[car[1]] then
      return invariant.L[car[1]](invariant, data:cdr(), output)
    end
    local cdr = vector.cast(data:cdr(), invariant._luaize)
    validate_functioncall(car)
    return lua_functioncall.new(
      luaize(invariant, car),
      lua.lua_args.new(lua_explist(cdr)))
  elseif utils.hasmetatable(data, symbol) then
    return hash(tostring(data[1]))
  elseif lua_ast[getmetatable(data)] then
    return data
  elseif data == nil then
    return "nil"
  elseif data == reader.lua_none then
    return
  end
  error("cannot not luaize.."..tostring(data))
end


local function compile(invariant, data, output)
  return luaize(invariant, expand(reader.transform(invariant, data)), output)
end

local function register_L(invariant, name, f)
  local L = invariant.L
  assert(not L[name], "L function has already been registered.."
    ..tostring(name))
  L[name] = f
end


-- local function compile(data)
--   return luaize(data)
-- end

return {
  compile = compile,
  luaize = luaize,
  expand = expand,
  register_L = register_L
}
