local compiler = require("l2l.compiler")
local reader = require("l2l.reader")

local version = "0.0.2-pre"

local loadstring = _G["loadstring"] or _G["load"]

local paired_options = {eval=true, load=true, compile=true}
local single_options = {repl=true, help=true, version=true}
local aliases = {r="repl", e="eval", l="load", c="compile",
                 v="version", h="help", ["?"]="help"}

local lookup_alias = function(arg)
  return aliases[arg] or arg
end

local trace, err
local handler = function(e) trace, err = debug.traceback(2), e end
local invariant = reader.environ("")

local function repl(partial)
  if(partial) then
    io.write("... ")
  else
    io.write("> ")
  end
  local input = io.read()
  if input:match("^%s*$") then
    -- Ignore empty space or blank lines.
    return repl()
  end
  if(not input) then
    if(not partial) then
      return
    else
      return repl()
    end
  end
  input = (partial or "") .. input

  invariant.source = input

  local compiled_ok, src_or_err = pcall(compiler.compile, invariant, "*repl*",
    true)

  if(compiled_ok) then
    local vals = {xpcall(loadstring(src_or_err), handler)}
    if(table.remove(vals, 1)) then
      for _,val in ipairs(vals) do
        -- TODO: pretty-print regular tables
        print(val)
      end
    else
      print(err)
      print(trace)
    end
  else
    if(src_or_err:find("no bytes$")) then
      return repl(input) -- partial input
    else
      print("Compiler error:", src_or_err)
    end
    return repl()
  end
  return repl()
end

local run = function(...)
  local args, options, next_in = {...}, {}
  for i,a in ipairs(args) do
    if(a:sub(1, 1) == "-") then
      local option_name = lookup_alias(a:gsub("%-", ""))
      next_in = false
      if(paired_options[option_name]) then
        next_in = option_name
      elseif(single_options[option_name]) then
        options[option_name] = true
      else
        error("Unknown argument: " .. a)
      end
    elseif(next_in) then
      table.insert(options, {how=next_in, val=a})
    elseif(i ~= #args) then
      error("Unknown argument: " .. a)
    else -- last arg is assumed to be a file
      table.insert(options, {how="load", val=a})
    end
  end

  if(#args == 0 or options.help) then
    print("Welcome to l2l.")
    print("Usage: l2l [<option> ...] <argument>")
    print("Options:")
    print("  -r / --repl          open a repl session")
    print("  -e / --eval FORM     evaluate and print a given FORM")
    print("  -l / --load FILE     load a given FILE")
    print("  -c / --compile FILE  print compiled lua for a given FILE")
    print("  -h / --help          print this message and exit")
    print("  -v / --version       print version information and exit")
    os.exit(0)
  elseif(options.version) then
    print("l2l version " .. version)
    os.exit(0)
  end

  for _,to_load in ipairs(options) do
    if(to_load.how == "eval") then
      invariant.source = to_load.val
      local src = compiler.compile(invariant, "*eval*")
      print(loadstring(src)())
    elseif(to_load.how == "load") then
      local f = assert(io.open(to_load.val), "File not found: " .. to_load.val)
      local lisp_source = f:read("*all")
      f:close()
      invariant.source = lisp_source
      local src = compiler.compile(invariant, to_load.val)
      loadstring(src)()
    elseif(to_load.how == "compile") then
      local f = assert(io.open(to_load.val), "File not found: " .. to_load.val)
      local lisp_source = f:read("*all")
      f:close()
      invariant.source = lisp_source
      print(compiler.compile(invariant, to_load.val))
    end
  end

  if(options.repl) then
    repl()
  end
end

return {
  run = run,
  repl = repl,
  version = version,
}
