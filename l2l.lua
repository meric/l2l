local input, output = arg[1] or "test.lsp", arg[2] or "out.lua"
setmt, tostr, getmt = setmetatable, tostring, getmetatable
function id(a)return a end 

-- list
list_mt = {__tostring=function(self)return "list("..sep(self,quote)..")" end
          ,__eq=function(s,o) return s[1]==o[1] and s[2]==o[2] end}
function list(v,...)return setmt({v,...~=nil and list(...) or nil},list_mt) end
function unlist(l,f)f=f or id if l then return f(l[1]), unlist(l[2], f) end end
function sep(l, f) return table.concat({unlist(l, f)}, ",") end

-- symbol & operator
sym_mt = {__tostring = function(self) return self.n end}
function sym(n) return setmt({n=n}, sym_mt) end
function hash(v)return v:gsub("%W",function(a) 
  if a ~= "." then return "_c"..a:byte().."_" else return "." end end) end
op_mt = {__call = function(self,...) return self.f(...)end}
function op(f) return setmt({f=f}, op_mt) end

-- parser & compiler
function tolua(l)
  if type(l) == "string" then return "[["..l.."]]"
  elseif type(l) == "number" then return tostring(l)
  elseif getmt(l) == sym_mt then return hash(tostring(l))
  elseif getmt(l) == list_mt then
    local fst = l[1]; if not fst then return nil end
    if getmt(fst) == sym_mt and getmt(_G[hash(tostring(fst))]) == op_mt then
      return _G[hash(tostring(fst))](unlist(l[2], id))
    elseif getmt(fst) == sym_mt then
      return hash(tostring(fst)) .."("..sep(l[2],tolua)..")"
    end
    return tolua(fst).."("..sep(l[2],tolua)..")" 
  end
end
function trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
function parse(src)
  src = trim(src)
  local open, close = src:find("%b()")
  if open == 1 then 
    return list(parse(src:sub(2, close-1))), parse(src:sub(close+1))
  elseif src:sub(1, 1) == ";" then
    local rest = src:sub(2):match("%s*.-\n(.*)")
    if rest then return parse(rest) end
  elseif src:sub(1, 1) == "'" then
    local rest = src:sub(2):match("%s*(.*)")
    local r = list(parse(rest))
    return list(sym("quote"), r[1]), unlist(r[2])
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
function compile(ret, s,...) 
  local c = tolua(s)..(ret and " " or "\n") 
  if ... then return c .. compile(ret, ...) end
  if ret then return "return ".. c else return c end
end

-- primitives
_G[hash("*")] = op(function(a, b) return "("..tolua(a).."*"..tolua(b)..")" end)
_G[hash("/")] = op(function(a, b) return "("..tolua(a).."/"..tolua(b)..")" end)
_G[hash("+")] = op(function(a, b) return "("..tolua(a).."+"..tolua(b)..")" end)
_G[hash("-")] = op(function(a, b) return "("..tolua(a).."-"..tolua(b)..")" end)
cons = op(function(a, b)return"setmt({"..sep(list(a,b),tolua).."},list_mt)"end)
atom = op(function(a) return "(getmt("..tolua(a)..")~=list_mt)" end)
car = op(function(a) return tolua(a).."[1]" end)
cdr = op(function(a) return tolua(a).."[2]" end)
eq = op(function(a, b) return tolua(a) .. "==" .. tolua(b) end)
defun = op(function(n,a,...) return hash(tostr(n)).."="..lambda(a, ...)end)
lambda = op(function(a, ...) 
  local def, r = "function("..(a[1] and sep(a, tostr) or "")..") ", "return "
  for i,v in ipairs({...}) do def=def..(i==#{...}and r or"")..tolua(v).." " end
  return def.."end" end)
cond = op(function(...)
  local def, r = "(function()", "return "
  for i,v in ipairs({...}) do def=def.."\n  if "..tolua(v[1]).. " then ".. compile(true, unlist(v[2])) .. "end" end
  return def.."\n  end)()" end)
quote = op(function(l)
  if type(l) == "string" then return "[["..l.."]]"
  elseif type(l) == "number" then return tostring(l)
  elseif getmt(l) == sym_mt then return "sym(\""..tostring(l).."\")"
  elseif getmt(l) == list_mt and l[1] == nil and l[2] == nil then return "nil"
  elseif getmt(l) == list_mt then return "list("..sep(l, quote)..")" end
end)

-- write lua
if not input or not output then return end
inf=io.open(input, "r") src = inf:read("*all") inf:close()
of=io.open(output, "w") lf=io.open("l2l.lua", "r")
  for i=1,94 do of:write(lf:read("*line").."\n") end lf:close()
of:write(compile(false, parse(src)).."\n") of:close()
