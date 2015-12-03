local module_path = (...):gsub('compiler$', '')
local reader = require(module_path .. "reader")
local itertools = require(module_path .. "itertools")
local exception = require(module_path .. "exception")


local IllegalFunctionCallException =
  exception.exception("Illegal function call")


local FunctionArgumentException =
  exception.exception(function(_, _, ...)
    return "Argument is not a ".. (tostring(...) or "symbol")
  end)

local list, tolist = itertools.list, itertools.tolist
local slice = itertools.slice
local map, fold, zip = itertools.map, itertools.fold, itertools.zip
local foreach, each = itertools.foreach, itertools.each
local bind, pair = itertools.bind, itertools.pair
local pack = itertools.pack
local show = itertools.show
local raise = exception.raise
local stdlib

local function with_C(newC, f, ...)
  if newC == _C then
    return f(...)
  end
  local C = _C
  _G._C = setmetatable(newC, {__index = C})
  local objs, count = pack(f(...))
  _G._C = C
  return table.unpack(objs, 1, count)
end

-- Keyword table. All symbols that match those in this table will be compiled
-- down into Lua as a symbol that is valid in Lua. Uniquess probable but not
-- guaranteed. See `hash`.
local _K ={
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

local function hash(str)
  if tostring(str) == "..." then
    return "..."
  end

  local pattern

  if _K[tostring(str)] then
    pattern = "(.)"
  elseif #tostring(str) > 0 and
      tostring(str):sub(1, 1):match("[_a-zA-Z0-9]") then
    pattern = "[^_a-zA-Z0-9.%[%]]"
  else
    pattern = "[^_a-zA-Z0-9%[%]]"
  end

  str = tostring(str):gsub(pattern, function(char)
    if char == "-" then
      return "_"
    elseif char == "!" then
      return "_bang"
    end
    return "_"..char:byte()
  end)
  return str
end

-- Declare `compile` ahead of `compile_parameters`, since these two
-- functions are mutually dependent.
local compile;

-- Compile the list `data` into Lua parameters.
local function compile_parameters(block, stream, parent, data)
  local objs = {}
  if data then
    for i, datum in ipairs(data) do
      local position = _R.position(parent, i+1)
      table.insert(objs, compile(block, stream, datum, position))
    end
  end
  if tolist(objs) then
    return "("..tolist(objs):concat(", ")..")"
  end
  return "()"
end

local function macroexpand(obj, terminating)
  if not terminating then
    if getmetatable(obj) ~= list then
      return obj
    end
    local form, orig, last = obj
    repeat
      if getmetatable(form) ~= list then
        return form
      end
      orig = nil
      last = nil

      while form do
        if getmetatable(form) == list then
          local node = pair({macroexpand(form[1]), nil})
          if not orig then
            orig = node
            last = orig
          else
            last[2] = node
            last = last[2]
          end
        else
          last[2] = macroexpand(form)
          break
        end
        form = form[2]
      end

      form = macroexpand(orig, true)
    until form == orig
    return form
  else
    if getmetatable(obj) ~= list then
      return obj
    end
    if getmetatable(obj[1]) ~= symbol then
      return obj
    end
    if type(_M[hash(obj[1])]) ~= "function" then
      return obj
    end

    local env = stdlib()

    for name, f in pairs(_M) do
      env[name] = f
    end

    return unpack({setfenv(_M[hash(obj[1])], setmetatable(env, {__index=_G}))(
      select(2, list.unpack(obj, ",")))})
  end
end

-- Compile `data` into an Lua expression. Any required statements are inserted
-- into `block`.
compile = function(block, stream, form, position)
  local exprs = {}

  for _, data in ipairs({macroexpand(form)}) do
    -- Returns a lua expression that is not guranteed to be a statement.
    if stream == nil then
      stream = show(data)
    end
    if type(data) == "table" and not getmetatable(data) then
      data = tolist(data)
    end
    if data == nil then
      -- Empty list
      raise(IllegalFunctionCallException, stream, position)
    elseif getmetatable(data) == list then
      if #data == 0 then
        -- Empty list
        raise(IllegalFunctionCallException, stream, position)
      end
      local datum, rest = data[1], data[2]
      local inline = false
      if block == nil then
        -- No space for statements given, all code must be inlined.
        inline = true
        block = {}
      end
      local obj = compile(block, stream, datum)
      local code
      if getmetatable(datum) == symbol then
        if type(_C[hash(datum)]) == "function" then
          code = table.concat({
              _C[hash(datum)](block, stream, list.unpack(rest))
            }, ", ")
        else
          code = hash(datum)..compile_parameters(block, stream, data, rest)
        end
      elseif data[2] and type(data[1]) == "number" then
        raise(IllegalFunctionCallException, stream, _R.position(data, 1))
      else
        code = obj..compile_parameters(block, stream, data, rest)
      end
      if inline then
        table.insert(block, "\n")
        table.insert(exprs, "(function()\n" .. table.concat(block, "\n")
          .."return "..code.." end)()")
      else
        table.insert(exprs, code)
      end
    elseif getmetatable(data) == symbol then
      table.insert(exprs, hash(data))
    elseif type(data) == "number" then
      table.insert(exprs, data)
    elseif type(data) == "string" then
      table.insert(exprs, show(data))
    end
  end
  return table.concat(exprs, ", ")
end

local function declare(block)
  local reference = "_var" .. #block
  table.insert(block, "local " .. reference)
  return reference
end

local function assign(block, name, value)
  if value ~= nil and value ~= "" then
    table.insert(block, name.."="..tostring(value))
  end
  return name
end

--- Returns whether an argument in list representation can be variadic.
-- It returns true if the argument is a function call, since it cannot be known
-- until the call is evaluated before how many returns it has is known.
-- @param Argument in list representation to check whether can be variadic.
-- @return a boolean
local function is_variadic(param)
  if param == nil then
    return false
  end
  if type(param) == "number" or type(param) == "string" then
    return false
  end
  if getmetatable(param) == symbol and param ~= symbol("...") then
    return false
  end
  -- if getmetatable(param) == list and getmetatable(param[1]) == symbol then
  --   local is_compiler = hash(param[1])
  --   if is_compiler then
  --     return false
  --   end
  -- end
  -- symbol("...") and function calls are variadic arguments.
  return true
end

--- Quick way to define a variadic compiler function
-- prefix and suffix are placed before and after each execution for
-- each variadic argument. E.g. can be used to implement stopping evaluation
-- in an AND operator.
local function variadic(f, step, initial, prefix, suffix)
  return function(block, stream, ...)
    local last = select("#", ...) > 0 and select(-1, ...)
    if not last then
      return initial
    elseif not is_variadic(last) then
      return f(block, stream, {...})
    else
      local var = declare(block)
      local literals = slice({...}, 1, -1)
      assign(block, var,
        #literals > 0 and f(block, stream, literals)
        or initial)
      if prefix then
        table.insert(block, prefix(var))
      end
      local vararg = compile(block, stream, last)
      local i = declare(block)
      local v = declare(block)
      table.insert(block, "for "..i..", "..v.." in next, {"..vararg.."} do")
      table.insert(block, var.." = "..step(var, v))
      table.insert(block, "end")
      if suffix then
        table.insert(block, suffix(var))
      end
      return var
    end
  end
end

local function compile_comparison(operator, block, stream, ...)
  if (select('#', ...) == 0) then
    raise(TypeException, stream)
  end
  if (select('#', ...) == 1) then
    return "true"
  end
  local objs = (list(...) or {})
  return list.concat((map(function(tuple)
      return
      "("..
        compile(block, stream, tuple[1])..
      operator..
        compile(block, stream, tuple[2])..
      ")"
    end, zip(objs, objs[2])) or {}), " and ")
end

local compile_equals = bind(compile_comparison, "==")
local compile_less_than = bind(compile_comparison, "<")
local compile_less_than_equals = bind(compile_comparison, "<=")
local compile_greater_than = bind(compile_comparison, ">")
local compile_greater_than_equals = bind(compile_comparison, ">=")

local function compile_not(block, stream, obj)
  return "(not " .. compile(block, stream, obj) .. ")"
end


local compile_and = variadic(
  function(block, stream, parameters)
    return list.concat(map(bind(compile, block, stream), parameters), " and ")
  end,
  function(reference, value)
    return reference .. " and " .. value
  end, "true",
  function(var) return "if "..var.." then" end,
  function(_) return "end" end)

local compile_or = variadic(
  function(block, stream, parameters)
    return list.concat(map(bind(compile, block, stream), parameters), " or ")
  end,
  function(reference, value)
    return reference .. " or " .. value
  end, "false",
  function(var) return "if not "..var.." then" end,
  function(_) return "end" end)

local compile_multiply = variadic(
  function(block, stream, parameters)
    return list.concat(map(bind(compile, block, stream), parameters), " * ")
  end,
  function(reference, value)
    return reference .. " * " .. value
  end, "1")

local compile_concat = variadic(
  function(block, stream, parameters)
    return list.concat(map(bind(compile, block, stream), parameters), " .. ")
  end,
  function(reference, value)
    return reference .. " .. " .. value
  end, "\"\"")

local compile_add = variadic(
  function(block, stream, parameters)
    return list.concat(map(bind(compile, block, stream), parameters), " + ")
  end,
  function(reference, value)
    return reference .. " + " .. value
  end, "0")

local compile_divide = variadic(
  function(block, stream, parameters)
    return list.concat(map(bind(compile, block, stream), parameters), " / ")
  end,
  function(reference, value)
    return reference .." and "..reference.." / "..value .." or "..value
  end, "nil")

local compile_subtract = variadic(
  function(block, stream, parameters)
    return list.concat(map(bind(compile, block, stream), parameters), " - ")
  end,
  function(reference, value)
    return reference .." and "..reference.." - " ..value .." or "..value
  end, "nil")

local function compile_modulo(block, stream, value, modulo)
  return compile(block, stream, value).." % "..compile(block, stream, modulo)
end

local function compile_table_attribute(block, stream, attribute, parent, value)
  local reference = compile(block, stream, parent) .. "[" .. 
    compile(block, stream, attribute) .. "]"
  if value ~= nil then
    table.insert(block, reference .."=" .. compile(block, stream, value))
  end
  return reference
end

local function compile_table_call(block, stream, attribute, parent, ...)
  local arguments = list(...)
  local parameters = list.concat(map(function(argument)
      return compile(block, stream, argument)
    end, arguments), ",")
  return compile(block, stream, parent) .. ":" ..
    attribute .. "(" .. parameters .. ")"
end

local function compile_length(block, stream, obj)
  return "#"..compile(block, stream, obj)
end

local function compile_set(block, stream, name, value)
  if getmetatable(name) == list then
    local names = {}
    for _, n in ipairs(name) do
      table.insert(names, compile(block, stream, n))
    end
    table.insert(block, table.concat(names, ", ") .. "=" .. compile(block, stream, value))
    return table.unpack(names)
  else
    name = compile(block, stream, name)
    table.insert(block, name .. "=" .. compile(block, stream, value))
  end
  return name
end

local function compile_table_quote(block, stream, form)
  -- return "hello.."..show(form)
  if type(form) == "string" then
    return show(form)
  elseif type(form) == "number" then
    return show(form)
  elseif getmetatable(form) == symbol then
    return "symbol("..show(hash(form))..")"
  elseif getmetatable(form) == list then
    local parameters = {}
    for _, v in ipairs(form) do
      table.insert(parameters, _C[hash("table-quote")](block, stream, v))
    end
    return "({" .. table.concat(parameters, ",") .."})"
  elseif form == nil then
    return "nil"
  else
    local src = {"{"}
    for k, obj in pairs(form) do
      table.insert(src, "[".._C[hash("quote")](block, stream, k).."]="..
        _C[hash("quote")](block, stream, obj)..",")
    end
    table.insert(src, "}")
    return table.concat(src, " ")
  end
  -- error("table quote error ".. tostring(show(form)))
end

local function compile_import(block, stream, name)

  local filename
  if type(name) == "string" then
    filename = name
  else
    filename = compile(block, stream, name)
  end
  assert(type(filename) == "string",
    "import can only be called with symbols")
  local eval = require(module_path.."eval")
  eval.dofile(filename..".lisp")
  local reference = declare(block)
  assign(block, reference, "{require("..show(filename)..")}")
  return "unpack("..reference..")"
end

local function compile_quote(block, stream, form)
  if getmetatable(form) == list then
    local parameters = {}
    while form do
      if getmetatable(form) == list then
        table.insert(parameters,  _C['quote'](block, stream, form[1]))
      else
        form = _C['quote'](block, stream, form)
        break
      end
      form = form[2]
    end
    return "tolist({" .. table.concat(parameters, ",") .."}, "
      ..tostring(form)..")"
  elseif form == nil then
    return "nil"
  else
    return _C[hash("table-quote")](block, stream, form)
  end
end

local function compile_quasiquote(block, stream, form)
  local quasiquote = bind(_C["quasiquote"], block, stream)
  if getmetatable(form) ~= list then
    return _C["quote"](block, stream, form)
  end
  if getmetatable(form[1]) == symbol and 
      hash(form[1]) == hash("quasiquote-eval") then
    return compile(block, stream, form[2][1])
  end
  local parameters = {}
  while form do
    local obj = quasiquote(form[1])
    if getmetatable(form) == list then
      table.insert(parameters, obj)
    else
      form = obj
      break
    end
    form = form[2]
  end
  return "tolist({"..table.concat(parameters, ",") .. "}, "
    ..tostring(form)..")"
end


local function compile_cond(block, stream, ...)
  local count = select("#", ...)
  if count == 0 then
    return "nil"
  end
  local insert = bind(table.insert, block)
  local reference = declare(block)
  local uid = tostring(hash(reference))
  insert("do")
  foreach(
    function(parameter, index)
      local is_condition = index % 2 == 1 and index ~= count
      local expression = compile(block, stream, parameter)
      if is_condition then
        insert("if "..expression.." then")
      else
        assign(block, reference, expression)
        if index % 2 == 0 then
          -- Lua 5.1 does not have goto and ::labels::.
          if _VERSION == "Lua 5.1" then
            insert("else")
          else
            insert("goto "..uid)
            insert("end")
          end
        end
      end
    end, pack(...))
  if _VERSION == "Lua 5.1" then
    each(
      function(_, index)
        if index % 2 == 0 then
          insert("end")
        end
      end, pack(...))
  else
    insert("::"..uid.."::")
  end
  insert("end")
  return reference
end

local function compile_if(block, stream, condition, action, otherwise)
  local ref = declare(block)
  local insert = bind(table.insert, block)
  insert("if "..compile(block, stream, condition).." then")
  local body = {}
  local return_is_variadic = is_variadic(action) or is_variadic(otherwise)
  action = compile(body, stream, action)
  insert(table.concat(body, "\n"))
  if return_is_variadic then
    assign(block, ref, "{"..action.."}")
  else
    assign(block, ref, action)
  end
  if otherwise then
    insert("else")
    body = {}
    otherwise = compile(body, stream, otherwise)
    insert(table.concat(body, "\n"))
    if return_is_variadic then
      assign(block, ref, "{"..otherwise.."}")
    else
      assign(block, ref, otherwise)
    end
  end
  insert("end")
  if return_is_variadic then
    return "unpack("..ref..")"
  else
    return ref
  end
end

local function defun(block, stream, name, arguments, ...) 
  local parameters = {}
  local count = fold(function(a, _) return a + 1 end, 0, arguments)
  for i, param in ipairs(arguments or {}) do
    table.insert(parameters, hash(param))
    if hash(param) == "..." and i ~= count then
      raise(FunctionArgumentException, stream, _R.position(arguments, i))
    end
  end
  name = name and compile(block, stream, name) or ""
  arguments = table.concat(parameters, ", ")
  table.insert(block, "function "..name.."("..arguments..")")
  local body = {}
  local reference = declare(body)
  count = select("#", ...)
  for i=1, count-1 do
    assign(body, reference, compile(body, stream, select(i, ...)))
  end
  local expression = compile(body, stream, select(count, ...))
  if expression then
    table.insert(body, "return " .. expression)
  end
  table.insert(block, table.concat(body, "\n"))
  table.insert(block, "end")
  return name
end

local function compile_lambda(_, stream, arguments, ...)
  local src = {}
  defun(src, stream, nil, arguments, ...)
  return "(" .. table.concat(src, "\n") .. ")"
end

local function compile_break(block, _)
  table.insert(block, "break")
end

local function compile_do(block, stream, ...)
  local reference = declare(block)
  table.insert(block, "do")
  for _, obj in ipairs({...}) do
    assign(block, reference, compile(block, stream, obj))
  end
  table.insert(block, "end")  
  return reference
end

local function compile_for(block, stream, locals, iterator, ...)
  --[[
  Usage: 
  (for (i value) (ipairs (list 1 2 3))
    (print value)
    (break))
  
  ;; returns the last value in the last executed iteration.
  ]]--
  local reference = declare(block)
  table.insert(block, table.concat({
    "for",
    list.concat(locals, ", "),
    "in",
    compile(block, stream, iterator),
    "do"
  }, " "))
  for _, expr in ipairs({...}) do
    assign(block, reference, compile(block, stream, expr))
  end
  table.insert(block, "end")
  return reference
end

local function compile_while(block, stream, condition, ...)
  --[[
  Usage: (while true (print "broken infinite loop") (break))

  ;; returns the last value in the last executed iteration.
  ]]--
  local reference = declare(block)
  table.insert(block, "while true do")
  table.insert(block, table.concat({
    "if not (",
    compile(block, stream, condition),
    ") then break end"
  }))
  for _, obj in ipairs({...}) do
    assign(block, reference, compile(block, stream, obj))
  end
  table.insert(block, "end")
  return reference
end

local function compile_car(block, stream, form)
  return "(("..compile(block, stream, form) .. ")[1])"
end

local function compile_cdr(block, stream, form)
  return "(("..compile(block, stream, form) .. ")[2])"
end

local function compile_cadr(block, stream, form)
  return "(("..compile(block, stream, form) .. ")[2][1])"
end

local function compile_let(block, stream, vars, ...)
  local reference = declare(block)
  local return_is_variadic

  local count = select("#", ...)
  if is_variadic(select(count, ...)) then
    return_is_variadic = true
  end

  table.insert(block, "do")
  local name, value

  if vars ~= nil and type(vars) ~= "table" then
    raise(FunctionArgumentException(stream, "list"))
  end

  for i, obj in ipairs(vars or {}) do
    if i % 2 == 1 then
      name = obj
    else
      value = obj
      if getmetatable(name) == list then
        table.insert(block, "local " .. map(hash, name):concat(", ") .. "=" .. 
          compile(block, stream, value))
      elseif getmetatable(name) ~= symbol then
        raise(FunctionArgumentException(stream, "symbol"))
      else
        table.insert(block, "local " .. hash(name) .. "=" .. 
          compile(block, stream, value))  
      end
    end
  end
  for i=1, count do
    local expr = compile(block, stream, select(i, ...))
    if return_is_variadic and i == count then
      -- if it's not the last, the assignment is only going to matter as
      -- as casting expressions to statements.
      expr = "{" .. expr .. "}"
    end
    assign(block, reference, expr)
  end
  table.insert(block, "end")

  if return_is_variadic then
    return "unpack("..reference..")"
  else
    return reference
  end
end

local function compile_defun(block, stream, name, arguments, ...)
  return defun(block, stream, name, arguments, ...)
end

local eval, compiler

local function compile_defcompiler(block, stream, name, arguments, ...)
  local reference = "_C[hash(\""..show(name).."\")]"
  local src = {}
  -- Serialize the compiler into the source code.
  defun(src, stream, nil, arguments, ...)
  table.insert(block, reference.."="..table.concat(src, "\n"))
  -- Load the compiler immediately.
  _C[hash(name)] = eval(tolist({symbol("lambda"), arguments, ...}), stream, {
    hash = hash,
    declare = declare
  })
  return reference
end

stdlib = function()
  local core = {
    import = require(module_path .. "import"),
    compile = compile,
    compiler = compiler,
    hash = hash,
    read = reader.read,
    reader = reader,
    exception = exception,
    raise = exception.raise,
    eval = eval
  }

  -- Copy all itertools into the `core` table.
  for _, lib in ipairs({itertools}) do
    for index, value in pairs(lib) do
      core[index] = value
    end
  end
  return core
end

_M = {}

local function compile_defmacro(block, stream, name, parameters, ...)
  local mref = "_M["..show(hash(name)).."]"
  local src = {}
  defun(src, stream, nil, parameters, ...)
  assign(block, mref, "(" .. table.concat(src, "\n") .. ")")
  return mref
end

local function build(stream)
  local src = {
    "require(\'l2l.core\').import(\'l2l.core\')",
    "compiler.bootstrap(_G)"
  }
  local reference = declare(src)
  local ok, obj, code
  repeat
    ok, obj = pcall(reader.read, stream)
    if ok then
      if code then
        assign(src, reference, code)
      end
      code = compile(src, stream, obj)
    elseif getmetatable(obj) ~= reader.EOFException then
      error(obj)
    end
  until not ok

  if #src > 0 and code then
    src[#src+1] = "return ".. code
  end

  -- For each core method used in the code, declare it as a local variable
  -- as an optimizaiton.
  code = table.concat(src, "\n")
  for k, _ in pairs(require(module_path.."core")) do
    if code:match("%f[%a]"..k.."%f[%A]") then
      table.insert(src, 3, "local "..k.." = ".. k)
    end
  end

  return table.concat(src, "\n")
end

eval = function (obj, stream, env, G)
  G = G or _G
  -- Include the following into the `core` library. The `core` library is
  -- automatically imported into _G in all compiled programs.
  -- See `compiler.build`.
  local core = stdlib()

  local block = {}
  if stream == nil then
    stream=reader.tofile(show(obj))
  end

  local reference

  if G ~= _G then
    reference = with_C(G._C or {}, compile, block, stream, obj,
      _R.position(obj))
  else
    reference = compile(block, stream, obj, _R.position(obj))
  end
  
  local code = table.concat(block, "\n") .. "\nreturn ".. reference

  setmetatable(core, {__index=G, __newindex=G})

  if env then
    setmetatable(env, {__newindex=G, __index=core})
  end

  local f, err = load(code, code, nil, env or core)
  if f then
    local objs, count = pack(pcall(f))
    local ok = table.remove(objs, 1)
    if ok then
      return table.unpack(objs, 1, count - 1)
    else
      -- print(code)
      error(objs[1])
    end
  else
    print(code)
    error(err)
  end
end

_M = {
  
}

-- Compiler table. Operators that have special syntax in Lua is specified in 
-- this table so it can be referred to by the compiler. Can be changed
-- during read time or compiler time to modify the compiler while it is 
-- compiling. 
_C = {
  [hash("==")] = compile_equals,
  [hash("<")] = compile_less_than,
  [hash("<=")] = compile_less_than_equals,
  [hash(">")] = compile_greater_than,
  [hash(">=")] = compile_greater_than_equals,
  [hash("and")] = compile_and,
  [hash("or")] = compile_or,
  [hash("not")] = compile_not,
  [hash("..")] = compile_concat,
  [hash("*")] = compile_multiply,
  [hash("+")] = compile_add,
  [hash("-")] = compile_subtract,
  [hash("/")] = compile_divide,
  [hash("%")] = compile_modulo,
  [hash(".")] = compile_table_attribute,
  [hash(":")] = compile_table_call,
  [hash("#")] = compile_length,
  [hash("table-quote")] = compile_table_quote,
  [hash("quote")] = compile_quote,
  [hash("if")] = compile_if,
  [hash("break")] = compile_break,
  [hash("do")] = compile_do,
  [hash("for")] = compile_for,
  [hash("while")] = compile_while,
  cond = compile_cond,
  import = compile_import,
  car = compile_car,
  cadr = compile_cadr,
  cdr = compile_cdr,
  let = compile_let,
  defcompiler = compile_defcompiler,
  defmacro = compile_defmacro,
  defun = compile_defun,
  lambda = compile_lambda,
  [hash("=>")] = compile_lambda,
  set = compile_set,
  [hash("=")] = compile_set,
  quasiquote = compile_quasiquote
}

compiler = {
  eval = eval,
  compile_parameters = compile_parameters,
  compile = compile,
  build = build,
  hash = hash,
  declare = declare,
  assign = assign,
  macroexpand = macroexpand,
  FunctionArgumentException = FunctionArgumentException,
  compile_lambda = compile_lambda,
  compile_equals = compile_equals,
  compile_less_than = compile_less_than,
  compile_less_than_equals = compile_less_than_equals,
  compile_greater_than = compile_greater_than,
  compile_greater_than_equals = compile_greater_than_equals,
  compile_and = compile_and,
  compile_not = compile_not,
  compile_or = compile_or,
  compile_multiply = compile_multiply,
  compile_add = compile_add,
  compile_subtract = compile_subtract,
  compile_divide = compile_divide,
  compile_defun = compile_defun,
  compile_table_attribute = compile_table_attribute,
  compile_table_call = compile_table_call,
  compile_length = compile_length,
  compile_set = compile_set,
  compile_table_quote = compile_table_quote,
  compile_quote = compile_quote,
  compile_quasiquote = compile_quasiquote,
  compile_if = compile_if,
  compile_cond = compile_cond,
  compile_defcompiler = compile_defcompiler,
  compile_car = compile_car,
  compile_cdr = compile_cdr,
  compile_cadr = compile_cadr,
  compile_let = compile_let,
  compile_modulo = compile_modulo,
  compile_break = compile_break,
  compile_do = compile_do,
  compile_for = compile_for,
  compile_while = compile_while,
  compile_import = compile_import
}

--- Returns the minimal environment required to bootstrap l2l
local function _minimal()
  local C, M = {}, {}

  for key, value in pairs(_C) do
    C[key] = value
  end

  for key, value in pairs(_M) do
    M[key] = value
  end

  return {
    table = table,
    print = print,
    tostring = tostring,
    type = type,
    getmetatable = getmetatable,
    next = next,
    symbol = symbol,
    _C = C,
    _M = M
  }
end

local default = {}

eval(reader.read(reader.tofile([[
(do 
  (defun + (...) (+ ...))
  (defun - (...) (- ...))
  (defun * (...) (- ...))
  (defun / (...) (- ...))
  (defun and (...) (- ...))
  (defun or (...) (- ...))
  (defun not (a) (not a))
  (defun car (a) (car a))
  (defun cdr (a) (cdr a))
  (defun # (a) (# a))
  (defun .. (...) (.. ...))
  (defun % (a b) (% a b)))
]])), nil, nil, default)

--- Modifies the given environment and bootstrap default l2l functions on it.
-- @G environment table
-- @return environment table
local function bootstrap(G)
  for name, value in pairs(default) do
    G[name] = value
  end
  return G
end

--- Returns the minimal recommended environment required for l2l.
local function environment()
  return bootstrap(_minimal())
end

compiler.environment = environment
compiler.bootstrap = bootstrap
return compiler
