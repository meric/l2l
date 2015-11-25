local sample05= (function() 
require('l2l.core').import('l2l.core')
local _var1
function tree(i, u, n)
local _var0
local _var1
do
local _var3
_var3=(1 / (1))
local _var5
local _var6
for _var5, _var6 in next, {u} do
_var3 = _var3 / _var6
end
local d=_var3
local _var11
do
if (n>0) then
local _var14
_var14=i
local _var16
local _var17
for _var16, _var17 in next, {u} do
_var14 = _var14 * _var17
end
local _var21
_var21=i
local _var23
local _var24
for _var23, _var24 in next, {d} do
_var21 = _var21 * _var24
end
_var11=list({i,tree(_var14, u, n - 1),tree(_var21, u, n - 1)})
goto _var11
end
_var11=nil
::_var11::
end
_var1=_var11
end
return _var1
end
function at(tree)
local _var0
return ((tree)[1])
end
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
local _var20
do
local period=0.5
local count_period=2
local volatility=0.32
local _var25
_var25=volatility
local _var27
local _var28
for _var27, _var28 in next, {math.sqrt(period)} do
_var25 = _var25 * _var28
end
local u=math.exp(_var25)
local _var33
_var33=(1 / (1))
local _var35
local _var36
for _var35, _var36 in next, {u} do
_var33 = _var33 / _var36
end
local d=_var33
local r=math.exp(0.5 * 0.1)
local dividend=1
local _var43
_var43=(1 / (dividend))
local _var45
local _var46
for _var45, _var46 in next, {r} do
_var43 = _var43 / _var46
end
local PV_dividend_=_var43
local price_0=70
local _var52
_var52=(-price_0)
local _var54
local _var55
for _var54, _var55 in next, {PV_dividend_} do
_var52 = _var52 - _var55
end
local price_0_PV_dividend_=_var52
local p0=price_0_PV_dividend_
_var20=print(draw(tree(p0, u, 3)))
_var20=print(list({1,2,3,4}))
end
return _var1
end)()
