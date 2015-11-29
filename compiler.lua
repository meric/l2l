local module_path = (...):gsub('compiler$', '')
local import = require(module_path .. "import")
local reader = require(module_path .. "reader")
local itertools = require(module_path .. "itertools")
local exception = require(module_path .. "exception")


local IllegalFunctionCallException =
  exception.exception("Illegal function call")


local FunctionArgumentException =
  exception.exception(function(self, stream, ...)
    return "Argument is not a ".. (tostring(...) or "symbol")
  end)

local list, tolist, pair = itertools.list, itertools.tolist, itertools.pair
local slice = itertools.slice
local map, fold, zip = itertools.map, itertools.fold, itertools.zip
local foreach = itertools.foreach
local bind = itertools.bind
local pack = itertools.pack
local show = itertools.show
local raise = exception.raise

local function with_C(newC, f, ...)
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

-- Compile `data` into an Lua expression. Any required statements are inserted
-- into `block`.
compile = function(block, stream, data, position)
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
        code = _C[hash(datum)](block, stream, list.unpack(rest))
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
      return "(function()\n" .. table.concat(block, "\n")
        .."return "..code.." end)()"
    else
      return code
    end
  elseif getmetatable(data) == symbol then
    return hash(data)
  elseif type(data) == "number" then
    return data
  elseif type(data) == "string" then
    return show(data)
  end
  return ""
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
-- @argument Argument in list representation to check whether can be variadic.
-- @return a boolean
local function is_variadic(argument)
  if type(argument) == "number" or type(argument) == "string" then
    return false
  end
  if getmetatable(argument) == symbol and argument ~= symbol("...") then
    return false
  end
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

local macro = {}

local function macroexpand(obj)
  if getmetatable(obj) ~= list then
    return obj
  end
  if getmetatable(obj[1]) ~= symbol then
    return obj
  end
  if getmetatable(resolve(hash(obj[1]))) ~= macro then
    return obj
  end
  local orig, form
  repeat
    orig = tolist({
      macroexpand(obj[1]),
      map(macroexpand, obj[2])})
    form = macroexpand(orig)
  until orig  == form
  return orig
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
  function(var) return "end" end)

local compile_or = variadic(
  function(block, stream, parameters)
    return list.concat(map(bind(compile, block, stream), parameters), " or ")
  end,
  function(reference, value)
    return reference .. " or " .. value
  end, "false")

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
  function(block, stream, parameters, is_unary)
    return list.concat(map(bind(compile, block, stream), parameters), " - ")
  end,
  function(reference, value)
    return reference .." and "..reference.." - " ..value .." or "..value
  end, "nil")

local function compile_table_attribute(block, stream, attribute, parent, value)
  local reference = compile(block, stream, parent) .. "[" .. 
    compile(block, stream, attribute) .. "]"
  if value ~= nil then
    table.insert(block, reference .."=" .. compile(block, stream, parent))
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
    for i, n in ipairs(name) do
      table.insert(names, compile(block, stream, n))
      table.insert(block, table.concat(names, ", ") .. "=" .. compile(block, stream, value))
    end
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
    for i, v in ipairs(form) do
      table.insert(parameters, _C[hash("table-quote")](block, stream, v))
    end
    return "({" .. table.concat(parameters, ",") .."})"
  elseif form == nil then
    return "nil"
  end
  error("table quote error ".. tostring(form))
end

local function compile_quote(block, stream, form)
  if getmetatable(form) == list then
    local parameters = {}
    for i, v in ipairs(form) do
      table.insert(parameters, _C['quote'](block, stream, v))
    end
    return "tolist({" .. table.concat(parameters, ",") .."})"
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
  return "tolist({"..list.concat(map(quasiquote, form), ",") .. "})"
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
    map(
      function(parameter, index)
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
  local reference ="_var" .. hash(#block)
  table.insert(block, "local "..reference)
  table.insert(block, "if " .. compile(block, stream, condition) .." then")
  local inner1 = {}
  action = compile(inner1, stream, action)
  table.insert(block, table.concat(inner1, "\n"))
  table.insert(block, reference .. " = ".. action)
  if otherwise then
    table.insert(block, "else")
    local inner2 = {}
    otherwise = compile(inner2, stream, otherwise)
    table.insert(block, table.concat(inner2, "\n"))
    table.insert(block, reference .. " = ".. otherwise)
  end
  table.insert(block, "end")
  return reference
end

local function defun(block, stream, name, arguments, ...) 
  local parameters = {}
  local vararg = nil
  local count = fold(function(a, b) return a + 1 end, 0, arguments)
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

local function compile_lambda(block, stream, arguments, ...)
  local src = {}
  defun(src, stream, nil, arguments, ...)
  return "(" .. table.concat(src, "\n") .. ")"
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
  for i=1, select("#", ...) do
    assign(block, reference, compile(block, stream, select(i, ...)))
  end
  table.insert(block, "end")
  return reference
end

local function compile_defun(block, stream, name, arguments, ...)
  return defun(block, stream, name, arguments, ...)
end

local eval

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

local function build(stream)
  local src = {
    "require(" .. module_path .. "\'core\').import(\'core\')"
  }
  local reference = declare(src)
  local ok, obj
  repeat
    ok, obj = pcall(reader.read, stream)
    if ok then
      local code = compile(src, stream, obj)
      if hash(code) ~= code then
        assign(src, reference, code)
      end
    elseif getmetatable(obj) ~= reader.EOFException then
      error(obj)
    end
  until not ok
  if #src > 0 then
    src[#src+1] = "return " .. reference
  end

  -- For each core method used in the code, declare it as a local variable
  -- as an optimizaiton.
  local code = table.concat(src, "\n")
  for k, _ in pairs(require(module_path.."core")) do
    if code:match("%f[%a]"..k.."%f[%A]") then
      table.insert(src, 2, "local "..k.." = ".. k)
    end
  end

  return table.concat(src, "\n")
end

local compiler

eval = function (obj, stream, env, G)
  G = G or _G
  -- Include the following into the `core` library. The `core` library is
  -- automatically imported into _G in all compiled programs.
  -- See `compiler.build`.
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
  for i, lib in ipairs({itertools}) do
    for index, value in pairs(lib) do
      core[index] = value
    end
  end

  local block = {}
  if stream == nil then
    stream=reader.tofile(show(obj))
  end

  local reference

  if G ~= _G then
    reference = with_C(G._C or {}, compile, block, stream, obj, _R.position(obj))
  else
    reference = compile(block, stream, obj, _R.position(obj))
  end
  
  local code = table.concat(block, "\n") .. "\nreturn ".. reference

  local f, err = load(code, code, nil, setmetatable(env or {},
      {__newindex=G, __index = setmetatable(core, {__index=G})}))
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
  [hash(".")] = compile_table_attribute,
  [hash(":")] = compile_table_call,
  [hash("#")] = compile_length,
  [hash("table-quote")] = compile_table_quote,
  [hash("quote")] = compile_quote,
  [hash("if")] = compile_if,
  cond = compile_cond,
  car = compile_car,
  cadr = compile_cadr,
  cdr = compile_cdr,
  let = compile_let,
  defcompiler = compile_defcompiler,
  defun = compile_defun,
  lambda = compile_lambda,
  set = compile_set,
  quasiquote = compile_quasiquote,
}

function reader.read_execute(stream, byte)
  local obj = reader.read(stream)
  eval(obj, stream)
end

_D['.'] = reader.read_execute


local src = [[
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

  (defcompiler chunk (block stream _block vars ...)
    ; A small DSL for defining compilers.
    (let (
      @block (declare block)
      @vars (map hash vars)
      insert (bind (.insert table) block)
      add (lambda (...)
        (insert
          (.. "table.insert(" @block ", "
              ((.concat table) (pack ...) " ") ")")))
      append (lambda (obj)
        (insert
          (.. @block
            "[#" @block "]=" @block "[#" @block "]..\" \"..tostring(" obj ")"
            ))))
      (insert (.. @block "=" (compile block stream _block)))
      (map
        (lambda (@var) (insert (.. "local " @var " = declare(" @block ")")))
        @vars)
      (map
        (lambda (obj)
          (cond 
            (== (type obj) "string") (append (show obj))
            (== (getmetatable obj) list)
              (insert (.. "local " (hash (car obj)) "="
                (compile block stream (cadr obj))))
            (if (== (getmetatable obj) symbol)
              (add (hash obj)))))
        (pack ...))
        (or (and @vars (car @vars)) nil)))

  (defcompiler while (block stream condition ...)
    (chunk block (return)
      "\nwhile true do\n"
      (@condition (compile block stream condition))
      "if not (" @condition ") then break end"
      (@placeholder (map (lambda (obj)
        (chunk block ()
          (@action (compile block stream obj))
          return "=" @action
        )) (pack ...)))
      "\nend"))

  (defcompiler break (block stream)
    (chunk block (return)
      "\nbreak"))

  (defcompiler do (block stream ...)
    (chunk block (return)
      "\ndo"
      (@action (map (lambda (obj)
        (chunk block ()
          (@ (compile block stream obj))
          return "=" @)) (pack ...)))
      "\nend"))

  (defcompiler if (block stream condition action otherwise)
    (chunk block (return)
      (@condition (compile block stream condition))
      "\nif" @condition "then"
      (@action (cond action (compile block stream action) @condition))
      return "=" @action
      (@placeholder (cond otherwise
        (chunk block ()
          "else"
              (@otherwise (compile block stream otherwise))
            return "=" @otherwise)))
      "\nend"))

  (defcompiler defmacro (block stream name parameters ...)
    (let 
      (params (list.push (list.push parameters 'stream) 'block)
       code `(defcompiler ,name ,params
        (let (fn (eval `(lambda ,parameters ,...)))
          (compile block stream (fn ,(list.unpack parameters))))))
      (eval code)
      (compile block stream code)))

  (defcompiler for (block stream fn iterable)
    (chunk block (return var1 var2 var3)
      (@iterable (compile block stream iterable))
      (@fn (compile block stream fn))
      "\nlocal" return "= {}"
      "\nfor" var1 "," var2 "," var3 "in" @iterable "do\n"
          "local" var1 "=" @fn "(" var1 ")"
          "table.insert(" return "," var1 ")"
      "\nend"))
]]

compiler = {
  eval = eval,
  compile_parameters = compile_parameters,
  compile = compile,
  build = build,
  hash = hash,
  declare = declare,
  assign = assign,
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
}

--- Returns the minimal environment required to bootstrap l2l
local function _minimal()
  return {
    table = table,
    print = print,
    tostring = tostring,
    type = type,
    getmetatable = getmetatable,
    next = next,
    symbol = symbol,
    _C = setmetatable({}, {__index=_C})
  }
end

--- Modifies the given environment and bootstrap l2l on it.
-- The given `G` argument must have all elements returned by a table returned
-- by `_minimal()`. For example, bootstrap(_minimal()).
-- @G environment table
-- @return environment table
local function bootstrap(G)
  -- l2l errors when an undefined global variable is accessed.
  setmetatable(G, {__index=function(self, key)
    error("undefined '"..key.."'")
  end})
  local stream = reader.tofile(src)
  local ok, form
  repeat
    ok, form = pcall(reader.read, stream)
    if ok then
      eval(form, stream, {
        assign = assign,
        declare = declare,
        _C = _C,
      }, G)
    end
  until not ok
  if getmetatable(form) ~= reader.EOFException then
    error(form)
  end
  return G
end

--- Returns the minimal environment required to bootstrap l2l, and bootstrap.
local function environment()
  return bootstrap(_minimal())
end

compiler.environment = environment
compiler.bootstrap = bootstrap
return compiler
