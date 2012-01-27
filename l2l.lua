local input, output = arg[1] or "test.lsp", arg[2] or "out.lua"
setmt, tostr, getmt = setmetatable, tostring, getmetatable
list_mt = {__tostring=function(self)return "list("..sep(self, quote)..")" end,
           __eq=function(self,other)
            if car(self) ~= car(other) then return false end
            if cdr(self) == nil and cdr(other) == nil then return true end
            if cdr(self) == nil or cdr(other) == nil then return false end
            return cdr(self) == cdr(other)
           end}
function list(v, ...) return setmt({v, ... and list(...) or nil}, list_mt) end
function unlist(l, f) if l then return f(car(l)), unlist(cdr(l), f) end end
function sep(l, f) return table.concat({unlist(l, f)}, ",") end
sym_mt = {__tostring = function(self) return self.n end}
kw_mt = {__call = function(self,...) return self.f(...)end,
         __tostring = sym_mt.__tostring}
fun_mt = {__tostring = sym_mt.__tostring, __call = kw_mt.__call}
function kw(n,f) return setmt({n=n,f=f}, kw_mt) end
function sym(n) return setmt({n=n}, sym_mt) end
function fun(n,f) return setmt({n=n,f=f}, fun_mt) end
eq = kw("eq", function(a, b) return tolua(a).."=="..tolua(b) end)
atom = fun("atom", function(a) return getmetatable(a)~=list_mt end)
car = fun("car", function(l) return l[1] end)
cdr = fun("cdr", function(l) return l[2] end)
cons = fun("cons", function(a, b) return setmt({a, b}, list_mt) end)
cond = kw("cond", function (...)
  local c, n = "(function() if true then ", #{...}
  for i, v in ipairs({...}) do
    if n~=i then 
      c = c.."elseif "..tolua(car(v)).." then return "..tolua(car(cdr(v))).." "
    else c = c .. "else return "..tolua(v).." end end)()" end
  end
  return c
end)
defun = kw("defun",function(n, a, ...)
  return "_G[\""..tostring(n).."\"]="..lambda(a, ...) end)
print = fun("print", print)
quote = kw("quote", function(l)
  if type(l) == "string" then return "[["..l.."]]"
  elseif type(l) == "number" then return tostring(l)
  elseif getmt(l) == sym_mt then return "sym(\""..tostring(l).."\")"
  elseif getmt(l) == fun_mt then return "sym(\""..tostring(l).."\")"
  elseif getmt(l) == kw_mt then return "sym(\""..tostring(l).."\")"
  elseif getmt(l) == list_mt then return "list("..sep(l, quote)..")" end
end)
tolua = fun("tolua", function(l)
  if type(l) == "string" then return "[["..l.."]]"
  elseif type(l) == "number" then return tostring(l)
  elseif getmt(l) == sym_mt or getmt(l) == fun_mt then 
    return "_G[\""..tostring(l) .. "\"]"
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
lambda = kw("lambda", function(args, ...) 
  local def, r = "function("..sep(args, tostring)..") ", "return "
  for i,v in ipairs({...}) do def=def..(i==#{...}and r or"")..tolua(v).." " end
  return def.."end" end)
function compile(s,...) return tolua(s).."\n"..(... and compile(...) or "") end
function run(src)
  local b=1 return load(function() if b then b=nil return src end end)()
end
eval = fun("eval", function(l) return run("return "..tolua(l)) end)
trim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
parse = function(src)
  src = trim(src)
  local open, close = src:find("%b()")
  if open == 1 then 
    return list(parse(src:sub(2, close-1))), parse(src:sub(close+1))
  elseif src:sub(1, 1) == ";" then
    local rest = src:sub(2):match("%s*.-\n(.*)")
    if rest then return parse(rest) end
  elseif src:sub(1, 1) == "'" then
    local rest = src:sub(2):match("%s*(.*)")
    return list(quote, parse(rest))
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
of=io.open(output, "w") lf=io.open("l2l.lua", "r")
  for i=1,93 do of:write(lf:read("*line").."\n") end lf:close()
of:write(compile(parse(src)).."\n") of:close()
