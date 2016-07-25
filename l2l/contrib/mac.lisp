\
local invariant = ...
local reader = require("l2l.reader")
local compiler = require("l2l.compiler")
local utils = require("leftry").utils
local vector = require("l2l.vector")

local symbol = reader.symbol
local lua_none = reader.lua_none

local function import_macro(invariant, cddr)
  local caddr = cddr:car()
  local cadddr
  if cddr:cdr() then
    cadddr = cddr:cdr():car()
  end
  if utils.hasmetatable(caddr, symbol) then
    local mod = caddr[1]
    local path = string.gsub(mod, "[.]", "/")..".lisp"
    local f = io.open(path)
    if f then
      local source = f:read("*a")
      f:close()
      local f, err = load(compiler.compile(source))
      if f then
        m = f(invariant)
      else
        error(err)
      end
    else
      m = require(mod)
    end
    assert(type(m) == "table", "-# MACRO module missing.")
    local prefix
    if cadddr then
      prefix = cadddr[1]
    end
    for k, v in pairs(m) do
      local name = k
      if prefix and prefix ~= "#-" then
        name = prefix.."."..k
      end
      assert(type(v) == "function")
      reader.register_T(invariant, name, function(invariant, cdr)
        return v(unpack(vector.cast(cdr)))
      end)
    end
    return lua_none
  end
  error("MACRO must have symbol argument.")
end

reader.register_E(invariant, "MACRO", import_macro)
