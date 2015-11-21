#!/usr/bin/env lua

require("compat")

local reader = require("reader")
local import = require("import")
local compiler = require("compiler")
local exception = require("exception")
local itertools = require("itertools")

local hash = compiler.hash

setmetatable(_G, {__index=function(self, key)
  error("undefined '"..key.."'")
end})

_PROMPT = "> "

-- Prompt string.
_P = ">> "

-- Only act as a compiler if this file is invoked directly through the shell.
-- Does not act on any arguments when this file is executed by
-- `require("core")`.
local function repl()
  print(";; Welcome to Lua-To-Lisp REPL!")
  print(";; Type '(print \"hello world!\") to start.")
  while true do
    local str = ""
    local form = nil
    local ok = false
    local stream = nil
    io.stdout:write(_P)
    while ok == false do
      local line = io.stdin:read("*line*")
      if line == nil then
        os.exit()
      end
      str = str .." ".. (line or "")
      stream = reader.tofile(str)
      ok, form = pcall(reader.read, stream, true)
      if not ok then
        local metatable = getmetatable(form)
        if metatable ~= reader.UnmatchedLeftBraceException and 
           metatable ~= reader.UnmatchedLeftParenException then
          print(form)
          break
        end
      end
    end
    if ok then
      local position = stream:seek("cur")
      local _ok, _form = pcall(reader.read, stream)
      if getmetatable(_form) ~= reader.EOFException then
        stream:seek("set", position)
        print("Unexpected input: "..stream:read("*all*"))
      else
        local _, result = pcall(compiler.eval, form)
        print("=", result)
      end
    end
  end
end

local function interpret()
  local src = io.stdin:read("*all*")
  local stream = reader.tofile(src)
  local ok, form
  repeat
    ok, form = pcall(reader.read, stream)
    if ok then
      local _ok, _err = pcall(compiler.eval, form)
      if not _ok then
        error(_err)
      end
    else
      if getmetatable(form) ~= reader.EOFException then
        error(form)
      end
    end
  until not ok
end

if debug.getinfo(3) == nil then
  compiler.bootstrap(_G)

  local script = false
  for i=1, #arg do
    if arg[i] == "--script" then
      table.remove(arg, i)
      script = true
    end
  end

  if #arg == 0 then
    if not script then
      repl()
    else
      interpret()
    end
  end
  for i=1, #arg do
    local file
    if arg[i] == "-" and not script then
      file = reader.tofile(io.stdin:read("*all*"))
    else
      file = io.open(arg[i])
    end
    local src = compiler.build(file)

    local f, err = load(src)
    if (err) then
      print(src)
      error(err)
    elseif not script then
      local name = arg[i]:match("^([^.]+)")
      if #name == 0 then
        error("Invalid module name " + arg[i])
      end
      print("local " .. hash(name) .. "= (function() ")
      print(src)
      print("end)()")
    elseif script then
      f()
    end
  end
end

local core = {
  repl = repl,
  import = require("import"),
  compile = compiler.compile,
  compiler = compiler,
  hash = hash,
  read = reader.read,
  reader = reader,
  exception = exception,
  raise = exception.raise,
  eval = compiler.eval
}

for index, value in pairs(itertools) do
  core[index] = value
end

return core
