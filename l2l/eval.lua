-- Functions useful for inline evaluation.

local module_path = (...):gsub('eval$', '')
local reader = require(module_path .. "reader")
local compiler = require(module_path .. "compiler")

local pcall = pcall
local getmetatable = getmetatable
local error = error

local evaluate = function(str, env)
  -- returns a function, when evaluated, will evaluate each form in `str`.
  return function()
    env = env or _G
    local ok, stream, obj, form, _ok
    ok, stream = pcall(reader.tofile, str)
    if not ok then
      return nil
    end
    repeat
      ok, form = pcall(reader.read, stream)
      if ok then
        _ok, obj = pcall(compiler.eval, form, stream, nil, env)
        if not _ok then
          error(obj)
        end
      elseif getmetatable(form) ~= reader.EOFException then
        error(form)
      end
    until not ok

    return obj
  end
end

local function loadfile(filename)
  local f = io.open(filename, "r")
  assert(f, "File not found: " .. filename)
  local stream = reader.tofile(f:read("*all"))
  f:close()
  local forms = {}
  repeat 
    local ok, form = pcall(reader.read, stream, true)
    if ok then
      table.insert(forms, form)
    else
      return nil, form
    end
  until not form
  return function()
    local ret = {}
    for _, form in ipairs(forms) do
      ret = {compiler.eval(form)}
    end
    return unpack(ret)
  end
end

local function dofile(filename)
  local f, err = loadfile(filename)
  if not f then
    error(err)
  end
  return f()
end

return {
  environment = function(env)
    env = env or {}
    for k, value in pairs(compiler.environment()) do
      env[k] = value
    end
    env._G = env
    return env
  end,
  eval = compiler.eval,
  read = reader.read,
  loadstring = evaluate,
  load = evaluate,
  loadfile = loadfile,
  dofile = dofile
}
