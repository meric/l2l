local utils = require("leftry").utils
local list = require("l2l.list")
local lua = require("l2l.lua")
local reader = require("l2l.reader")
local vector = require("l2l.vector")
local symbol = reader.symbol

local invariantize = require("leftry.elements.utils").invariantize

local lua_functioncall = lua.lua_functioncall
local lua_function = lua.lua_function
local lua_explist = lua.lua_explist
local lua_number = lua.lua_number
local lua_name = lua.lua_name
local lua_ast = lua.lua_ast
local lua_local = lua.lua_local
local lua_namelist = lua.lua_namelist
local lua_retstat = lua.lua_retstat


local function validate_functioncall(car)
  assert(
    getmetatable(car) ~= lua_number and (
    utils.hasmetatable(car, list) or
    utils.hasmetatable(car, symbol) or
    lua_ast[getmetatable(car)]),
    "only expressions and symbols can be called.")
end

local function expize(invariant, data, output)
  if utils.hasmetatable(data, list) then
    local car = data:car()
    if utils.hasmetatable(car, symbol) and invariant.L[car[1]] then
      return invariant.L[car[1]].expize(invariant, data:cdr(), output)
    end
    local cdr = vector.cast(data:cdr(), function(value)
      return expize(invariant, value, output)
    end)
    validate_functioncall(car)
    return lua_functioncall.new(
      expize(invariant, car),
      lua.lua_args.new(lua_explist(cdr)))
  elseif utils.hasmetatable(data, symbol) then
    return lua_name(data:hash())
  elseif lua_ast[getmetatable(data)] then
    return data
  elseif data == nil then
    return "nil"
  elseif data == reader.lua_none then
    return
  end
  error("cannot not expize.."..tostring(data))
end

local function to_stat(exp, name)
  -- convert exp to stat
  local name = name or lua_name:unique("_var")
  assert(exp)
  return lua_local.new(lua_namelist({name}), lua_explist({exp}))
end

local function statize(invariant, data, output, last)
  if last then
    return lua_retstat.new(lua_explist({expize(invariant, data, output)}))
  end
  if utils.hasmetatable(data, list) then
    local car = data:car()
    if utils.hasmetatable(car, symbol) and invariant.L[car[1]] then
      return invariant.L[car[1]].statize(invariant, data:cdr(), output)
    end
    local cdr = vector.cast(data:cdr(), function(value)
      return expize(invariant, value, output)
    end)
    validate_functioncall(car)
    return lua_functioncall.new(
      expize(invariant, car),
      lua.lua_args.new(lua_explist(cdr)))
  elseif lua_ast[getmetatable(data)] then
    if not utils.hasmetatable(data, lua_functioncall) then
      return to_stat(data)
    end
    return data
  elseif data == reader.lua_none then
    return
  end
  error("cannot not statize.."..tostring(data))
end

local function compile_stat(invariant, data, output)
  return statize(invariant, reader.transform(invariant, data), output)
end

local function compile_exp(invariant, data, output)
  return expize(invariant, reader.transform(invariant, data), output)
end

local function register_L(invariant, name, exp, stat)
  local L = invariant.L
  L[name] = {expize=exp, statize=stat}
end

local function compile_lua_block(invariant, cdr, output)
  return cdr:car()
end

local function compile_lua_block_into_exp(invariant, cdr, output)
  local cadr = cdr:car()
  local retstat = cadr[#cadr]

  assert(utils.hasmetatable(retstat, lua_retstat),
    "block must end with return statement when used as an exp.")

  for i=1, #cadr - 1 do
    table.insert(output, cadr[i])
  end

  return retstat.explist
end

local exports

local dependencies

local function initialize_dependencies()
  if not dependencies then
    dependencies = {}
    for name, _ in pairs(lua) do
      dependencies[name] = {{'require("l2l.lua")', "lua"}}
    end

    for name, _ in pairs(reader) do
      dependencies[name] = {{'require("l2l.reader")', "reader"}}
    end

    for name, _ in pairs(exports) do
      dependencies[name] = {{'require("l2l.compiler")', "compiler"}}
    end

    dependencies["list"] = {{'require("l2l.list")', nil}}
    dependencies["vector"] = {{'require("l2l.vector")', nil}}
    dependencies[symbol("+"):hash()] = {
      "import", {'import("l2l.lib.arithmetic")', "arithmetic"}}
  end
  return dependencies
end

local function header(references, mod)
  local deps = initialize_dependencies()
  local names = {}
  for name, dep in pairs(deps) do
    if references[name] then
      for i, v in ipairs(dep) do
        if type(v) == "string" then
          table.insert(names, v)
        end
      end
      table.insert(names, name)
    end
  end

  local output = {}
  local outputed = {}

  for i, name in ipairs(names) do
    for i, dep in ipairs(deps[name]) do
      if type(dep) == "table" then
        local m, label = dep[1], dep[2]
        if not mod or not string.match(m, mod) then
          if m then
            local l = string.format(m, name)
            local r = string.format("local %s = %s", label or name, m)
            if not outputed[r] then
              outputed[r] = true
              table.insert(output, r)
            end
          end
          if label then
            local l = label.."."..name
            local r = string.format("local %s = %s", name, l)
            if not outputed[r] then
              outputed[r] = true
              table.insert(output, r)
            end
          end
        end
      end
    end
  end
  return table.concat(output, "\n")
end

local function analyse_chunk(references, value)
  for match in lua.Chunk:gmatch(value, lua.Var) do
    if utils.hasmetatable(match, lua.lua_dot) then
      references[tostring(match.prefix)] = match.prefix
    else
      references[tostring(match)] = match
    end
  end
end

local function compile(source, mod, extensions)
  local invariant

  if not parent then
    invariant = reader.environ(source, 1)
  else
    invariant = reader.inherit(parent, source)
  end

  if not extensions then
    extensions = {
      "l2l.contrib.fn",
      "l2l.contrib.quasiquote",
      "l2l.contrib.quote",
      "l2l.contrib.mac"
    }
  end

  for i, m in ipairs(extensions) do
    reader.extend(invariant, m)
  end

  local output = {}

  for rest, values in reader.read, invariant do
    for i, value in ipairs(values) do
      local stat = compile_stat(invariant, value, output)
      if stat then
        table.insert(output, stat)
      end
    end
  end

  local references = {}

  for i, value in ipairs(output) do
    output[i] = tostring(value)
    analyse_chunk(references, output[i])
  end

  output = table.concat(output, "\n")
  return header(references, mod) .. "\n" .. output
end

local function compile_or_cached(source, mod, extends, path)
  local f = io.open(path)
  local h = #source.."@"..source
  if not f then
    local out = compile(source, mod, extends)
    local g = io.open(path, "w")
    g:write(h..out)
    g:close()
    return out
  end
  local code = f:read("*a")
  f:close()
  if code:sub(1, #h) ~= h then
    local out = compile(source, mod, extends)
    local g = io.open(path, "w")
    g:write(h..out)
    g:close()
    return out
  end
  return code:sub(#h + 1)
end

local function build(mod, extends)
  local path = string.gsub(mod, "[.]", "/")..".lisp"
  local f = io.open(path)
  if not f then
    return
  end
  local source = f:read("*a")
  f:close()
  local out = compile_or_cached(source, mod, extends, path.."c")
  local f, err = load(out)
  if f then
    return f
  else
    print(out)
    error(err)
  end
end

local function import(mod)
  local f = build(mod)
  local ok, m
  if f then
    ok, m = pcall(f, mod, path)
    if not ok then
      print(out)
      error(m)
    end
  else
    m = require(mod)
  end
  return m
end

exports = {
  build=build,
  import=import,
  compile=compile,
  compile_lua_block = compile_lua_block,
  compile_lua_block_into_exp = compile_lua_block_into_exp,
  hash = reader.hash,
  statize = statize,
  expize = expize,
  hash = hash,
  compile_stat = compile_stat,
  compile_exp = compile_exp,
  to_stat = to_stat,
  expand = expand,
  register_L = register_L
}

return exports