-- input -> lisp file to be compiled
-- output -> where compiled lua code is saved
local input, output = arg[1] or "test.lsp", arg[2] or "out.lua"
setmt, tostr, getmt = setmetatable, tostring, getmetatable
-- list type
list_mt = {__tostring=function(self)return "list("..sep(self, quote)..")" end}
-- list constructor
function list(v, ...) return setmt({v, ... and list(...) or nil}, list_mt) end
-- desolve list into n-tuple
function unlist(l, f) if l then return f(car(l)), unlist(cdr(l), f) end end
-- stringify list into form "{a},{b},{c},..."
function sep(l, f) return table.concat({unlist(l, f)}, ",") end
-- symbol type (runtime symbol)
sym_mt = {__tostring = function(self) return self.n end}
-- operator type (modifys parse tree at compile time)
kw_mt = {__call = function(self,...) return self.f(...)end,
         __tostring = sym_mt.__tostring}
-- function type (built-in functions)
fun_mt = {__tostring = sym_mt.__tostring, __call = kw_mt.__call}
-- operator constructor
function kw(n,f) return setmt({n=n,f=f}, kw_mt) end
-- symbol constructor
function sym(n) return setmt({n=n}, sym_mt) end
-- built-in function constructor
function fun(n,f) return setmt({n=n,f=f}, fun_mt) end
-- primitives
_G["="] = kw("=", function(a, b) return tolua(a).."=="..tolua(b) end)
_G["+"] = kw("+", function(a, b) return tolua(a).."+"..tolua(b) end)
_G["-"] = kw("-", function(a, b) return tolua(a).."-"..tolua(b) end)
_G["*"] = kw("*", function(a, b) return tolua(a).."*"..tolua(b) end)
_G["/"] = kw("/", function(a, b) return tolua(a).."/"..tolua(b) end)
car = fun("car", function(l) return l[1] end)
cdr = fun("cdr", function(l) return l[2] end)
cons = fun("cons", function(a, b) return setmt({a, b}, list_mt) end)
label = kw("label", function (k, v) return tostring(k).."="..tolua(v) end)
print = fun("print", print)
-- quote operator
quote = kw("quote", function(l)
  if type(l) == "string" then return "[["..l.."]]"
  elseif type(l) == "number" then return tostring(l)
  elseif getmt(l) == sym_mt then return "sym(\""..tostring(l).."\")"
  elseif getmt(l) == fun_mt then return "sym(\""..tostring(l).."\")"
  elseif getmt(l) == kw_mt then return "sym(\""..tostring(l).."\")"
  elseif getmt(l) == list_mt then return "list("..sep(l, quote)..")" end
end)
-- convert parse tree to lua code
tolua = fun("tolua", function(l)
  if type(l) == "string" then return "[["..l.."]]"
  elseif type(l) == "number" then return tostring(l)
  elseif getmt(l) == sym_mt or getmt(l) == fun_mt then return tostring(l)
  elseif getmt(l) == list_mt then 
    if not car(l) then return nil end
    if getmt(car(l)) == sym_mt and getmt(_G[tostring(car(l))]) == kw_mt then
      return _G[tostring(car(l))](unlist(cdr(l), function(a) return a end))
    elseif getmt(car(l)) == kw_mt then
      return car(l)(unlist(cdr(l), function(a) return a end))
    end
    return tolua(car(l)) .."("..sep(cdr(l),tolua)..")" end
  return ""
end)
-- lambda operator
lambda = kw("lambda", function(args, ...) 
  local def, r = "function("..sep(args, tostring)..") ", "return "
  for i,v in ipairs({...}) do def=def..(i==#{...}and r or"")..tolua(v).." " end
  return def.."end" end)
-- compile parse tree(s)
function compile(s,...) return tolua(s).."\n"..(... and compile(...) or "") end
function run(src)
  local b=1 return load(function() if b then b=nil return src end end)()
end
-- lisp eval primitive
eval = fun("eval", function(l) return run("return "..tolua(l)) end)
trim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
-- parser
parse = function(src)
  src = trim(src)
  local open, close = src:find("%b()")
  if open == 1 then 
    return list(parse(src:sub(2, close-1))), parse(src:sub(close+1))
  elseif src:sub(1, 1) == "\"" then
    local esc, i = false, 2
    while esc == true or src:sub(i, i)~="\"" do
      if esc then esc = false end
      if src:sub(i, i) == "\\" then esc = true end i = i + 1 
    end 
    return src:sub(2, i-1), parse(src:sub(i+1))
  elseif #src > 0 then
    local first = src:match("(%S+)")
    local rest = src:match("%S+%s+(.*)")
    return tonumber(first) or sym(first), parse(rest or "")
  end
end
if not input or not output then return end
inf=io.open(input, "r") src = inf:read("*all") inf:close()
of=io.open(output, "w")
lf=io.open("l2l.lua", "r")
  for i=1,92 do of:write(lf:read("*line").."\n") end 
lf:close()
of:write(compile(parse(src)).."\n")
of:close()
