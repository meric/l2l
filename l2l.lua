local input, output = arg[1] or "test.lsp", arg[2] or "out.lua"
setmt, tostr, getmt = setmetatable, tostring, getmetatable
function id(a)return a end 
function map(f, t) local m={} for i,v in ipairs(t) do m[i]=f(v) end return m end
list_mt = {__tostring=function(self)return "list("..sep(self,quote)..")" end
          ,__eq=function(s,o) return s[1]==o[1] and s[2]==o[2] end
          ,__ipairs=function(s) return function() 
            if s then local i=s[1] s=s[2] return i or s,i end end end}
function list(v,...)return setmt({v,next({...})and list(...) or nil},list_mt)end
function unlist(l,f)f=f or id if l then return f(l[1]), unlist(l[2], f) end end
function sep(l, f) return table.concat(map(tostr, {unlist(l, f)}), ",") end
sym_mt = {__tostring = function(self) return self.n end}
function sym(n) return setmt({n=n}, sym_mt) end
function hash(v) return tostr(v):gsub("%W",function(a) 
  if a ~= "." then return "_c"..a:byte().."_" else return "." end end) end
op_mt = {__call = function(self,...) return self.f(...)end}
function op(f) return setmt({f=f}, op_mt) end
function trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
function substitute(src, s, rp) 
  local rest = list(parse(src:sub(#s+1):match("%s*(.*)"))) 
  return list(sym(rp), rest[1]), unlist(rest[2])
end
function prefixed(src, pr) return src:sub(1, #pr) == pr end
function parse(src) -- parse into tree
  src = trim(src) 
  local open, close = src:find("%b()")
  if open == 1 then 
    return list(parse(src:sub(2, close-1))), parse(src:sub(close+1))
  elseif prefixed(src, ";") then
    local r = src:sub(2):match("%s*.-\n(.*)") if r then return parse(r) end
  elseif prefixed(src, "'") then return substitute(src, "'", "quote")
  elseif prefixed(src, "`") then return substitute(src, "`", "quasiquote")
  elseif prefixed(src, ",") then return substitute(src, ",", "quasiquote-eval")
  elseif prefixed(src, "\"") then
    local esc, i = false, 2
    while esc == true or src:sub(i, i)~="\"" do
      if esc then esc = false end
      if src:sub(i, i) == "\\" then esc = true end i = i + 1 
    end 
    return src:sub(2, i-1), parse(src:sub(i+1))
  elseif #src > 0 then
    local first, rest = src:match("(%S+)"), src:match("%S+%s+(.*)")
    return tonumber(first) or sym(first), parse(rest or "") end
end
function escape(str) return '"'..str:gsub('"','\\"')..'"' end
function lua(l) -- l is parse tree, convert to lua
  if type(l) == "string" then return escape(l)
  elseif type(l) == "number" then return tostring(l)
  elseif getmt(l) == sym_mt then return hash(l)
  elseif getmt(l) == list_mt then
    local fst = l[1]; if not fst then return nil end
    if getmt(fst) == sym_mt and getmt(_G[hash(tostring(fst))]) == op_mt then
      return _G[hash(fst)](unlist(l[2], id))
    elseif getmt(fst) == sym_mt then
      return hash(fst).."("..sep(l[2],lua)..")"
    end
    return lua(fst).."("..sep(l[2],lua)..")" end
end
function compile(ret, s, ...) -- convert multiple trees into lua
  local c = "\n"..lua(s)
  if ... then return c .. compile(ret, ...) end
  if ret then return "\nreturn ".. c:sub(2) else return c end
end
function indent(src) return src:gsub("\n", "\n  ") end -- primitives
_G[hash("*")] = op(function(a, b) return "("..lua(a).."*"..lua(b)..")" end)
_G[hash("/")] = op(function(a, b) return "("..lua(a).."/"..lua(b)..")" end)
_G[hash("+")] = op(function(a, b) return "("..lua(a).."+"..lua(b)..")" end)
_G[hash("-")] = op(function(a, b) return "("..lua(a).."-"..lua(b)..")" end)
cons = op(function(a, b)return"setmt({"..sep(list(a,b),lua).."},list_mt)"end)
atom = op(function(a) return "(getmt("..lua(a)..")~=list_mt)" end)
car = op(function(a) return lua(a).."[1]" end)
cdr = op(function(a) return lua(a).."[2]" end)
eq = op(function(a, b) return lua(a) .. "==" .. lua(b) end)
set = op(function(s, v) return "local ".. hash(s) .." = "..lua(v) end)
defun = op(function(n,a,...) return "local function "..hash(n).."("..(a[1] and 
  sep(a, hash) or "")..")"..indent(compile(true, ...)).."\nend" end)
lambda = op(function(a, ...) return "function("..(a[1] and sep(a, hash) or "")..
  ")"..indent(compile(true, ...)).."\nend" end)
cond = op(function(...)
  local def = map(function(v) return "if "..lua(v[1]).." then"..
    indent(compile(true, unlist(v[2]))).."\nend" end, {...})
  return "(function()"..indent("\n"..table.concat(def, "\n")).."\nend)()" end)
quote = op(function(l)
  if type(l) == "string" then return escape(l)
  elseif type(l) == "number" then return tostring(l)
  elseif getmt(l) == sym_mt then return  "sym(\""..tostring(l).."\")"
  elseif getmt(l) == list_mt and l[1] == nil and l[2] == nil then return "nil"
  elseif getmt(l) == list_mt then return "list("..sep(l, quote)..")" end
end)
quasiquote = op(function(l)
  if getmt(l) ~= list_mt then return quote(l) end
  if getmt(l[1]) == sym_mt and tostr(l[1])=="quasiquote-eval" then 
    return lua(l[2][1])
  elseif l[1] == nil and l[2] == nil then return "nil" end
  return "list("..sep(l, quasiquote)..")" end)
if not input or not output then return end
inf=io.open(input, "r") src = inf:read("*all") inf:close() -- write lua
of=io.open(output, "w") lf=io.open("l2l.lua", "r")
  for i=1,95 do of:write(lf:read("*line").."\n") end lf:close()
of:write(compile(false, parse(src)).."\n") of:close()
