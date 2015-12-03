return (function() 
require('l2l.core').import('l2l.core')
compiler.bootstrap(_G)
local import = import
local tolist = tolist
local compiler = compiler
local _var2
function tree(i, u, n)
local _var0
local _var1
do
local d=1 / u
local _var4
do
if (n>0) then
_var4=tolist({i,tree(i * u, u, n - 1),tree(i * d, u, n - 1)}, nil)
goto _var4
end
_var4=nil
::_var4::
end
_var1={_var4}
end
return unpack(_var1)
end
_var2=tree
function at(tree)
local _var0
return ((tree)[1])
end
_var2=at
function up(tree)
local _var0
local _var1
do
if ((tree)[2]) then
_var1=((((tree)[2]))[1])
goto _var1
end
_var1=nil
::_var1::
end
return _var1
end
_var2=up
function down(tree)
local _var0
local _var1
do
if (((tree)[2])==nil) then
_var1=nil
goto _var1
end
if ((((tree)[2]))[2]) then
_var1=((((((tree)[2]))[2]))[1])
goto _var1
end
_var1=nil
::_var1::
end
return _var1
end
_var2=down
function draw_row(tree)
local _var0
local _var1
do
if (tree==nil) then
_var1=""
goto _var1
end
local _var7
_var7=tostring(at(tree)) .. "t- "
local _var9
local _var10
for _var9, _var10 in next, {draw_row(up(tree))} do
_var7 = _var7 .. _var10
end
_var1=_var7
::_var1::
end
return _var1
end
_var2=draw_row
function draw(tree, indent)
local _var0
local _var1
do
if (tree==nil) then
_var1=""
goto _var1
end
local _var7
_var7=draw_row(tree) .. "\n"
local _var9
local _var10
for _var9, _var10 in next, {draw(down(tree))} do
_var7 = _var7 .. _var10
end
_var1=_var7
::_var1::
end
return _var1
end
_var2=draw
local _var27
do
local period=0.5
local count_period=2
local volatility=0.32
local _var32
_var32=volatility
local _var34
local _var35
for _var34, _var35 in next, {math.sqrt(period)} do
_var32 = _var32 * _var35
end
local u=math.exp(_var32)
local d=1 / u
local r=math.exp(0.5 * 0.1)
local dividend=1
local PV_dividend_=dividend / r
local price_0=70
local price_0_PV_dividend_=price_0 - PV_dividend_
local p0=price_0_PV_dividend_
_var27=print(draw(tree(p0, u, 3)))
_var27={print(tolist({1,2,3,4}, nil))}
end
return unpack(_var27)
end)()
