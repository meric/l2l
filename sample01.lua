
--- Example 11 ---

-- I am running this line in the compilation step!
-- This too!
-- 1 + 1 = 2!
-- Okay that's enough.

--- Example 12 ---

local sample01= (function() 
require('l2l.core').import('l2l.core')
compiler.bootstrap(_G)
local pack = pack
local compiler = compiler
local tolist = tolist
local map = map
local hash = hash
local dict = dict
local vector = vector
local import = import
local _var2
_var2=print("\n--- Example 1 ---\n")
function _bang(n)
local _var0
local _var1
do
if (n==0) then
_var1=1
goto _var1
end
if (n==1) then
_var1=1
goto _var1
end
local _var11
_var11=n
local _var13
local _var14
for _var13, _var14 in next, {_bang(n - 1)} do
_var11 = _var11 * _var14
end
_var1=_var11
::_var1::
end
return _var1
end
_var2=print(_bang(100))
_var2=print("\n--- Example 2 ---\n")
function _206_163()
local _var0
return print("ΣΣΣ")
end
_var2=_206_163()
_var2=print("\n--- Example 3 ---\n")
hello_world="hello gibberish world"
_var2=print(table.concat(pack(string.gsub(hello_world, "gibberish ", "")), " "))
_var2=print("\n--- Example 4 ---\n")
_var2=map(print, tolist({1,2,3,map((function (x)
local _var0
return x * 5
end), tolist({1,2,3}, nil))}))
_var2=print("\n--- Example 5 ---\n")
local _var19
do
local a=1 + 2
local b=3 + 4
_var19={print(a)}
_var19={print(b)}
end
_var2=unpack(_var19)
_var2=print("\n--- Example 6 ---\n")
_var2=dict("write", (function (self, x)
local _var0
return print(x)
end)):write("hello-world")
dict("write", (function (self, x)
local _var0
return print(x)
end))["write"]="hello-world"
_var2=print(dict("write", (function (self, x)
local _var0
return print(x)
end))["write"])
_var2=print("\n--- Example 7 ---\n")
_var2=print((function (x, y)
local _var0
return x + y
end)(10, 20))
_var2=print("\n--- Example 8 ---\n")
local _var34
do
local a=7 * 8
_var34={map(print, vector(1, 2, a, 4))}
end
_var2=unpack(_var34)
_var2=print("\n--- Example 9 ---\n")
local _var41
do
local d=dict("a", "b", 1, 2, "3", 4)
_var41={print(d["a"], "b")}
_var41={print(d.a, "b")}
_var41={print(d[1], 2)}
_var41={print(d["3"], 4)}
end
_var2=unpack(_var41)
_var2=print("\n--- Example 10 ---\n")
_C[hash("--")]=function (block, stream, str)
local _var0
local _var1
_var1="\n--"
local _var3
local _var4
for _var3, _var4 in next, {tostring(str)} do
_var1 = _var1 .. _var4
end
return table.insert(block, _var1)
end
_var2=_C[hash("--")]

--This is a comment
_var2=print("\n--- Example 11 ---\n")
_var2=print("\n--- Did you see what was printed while compiling? ---\n")
local _var56
do
_var56=print(1)
_var56=print(2)
end
_var2=print("\n--- Example 12 ---\n")
local _var62
do
local a=2
local _var65
do
if (a=="1") then
_var65=print("a == 1")
goto _var65
end
local _var71
do
if (a==2) then
_var71=print("a == 2")
goto _var71
end
_var71=print("a != 2")
::_var71::
end
_var65=_var71
::_var65::
end
_var62={_var65}
end
_var2=unpack(_var62)
_var2=print(tostring(1 + 2) .. "4")
return _var2
end)()
