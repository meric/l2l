local sample05= (function() 
require('core').import('core')
local _var1
function tree(i, u, n)
local _var0
local _var1
do
local d=(1 / u)
local _var4
do
if (n>0) then
_var4=list({i,tree((i * u), u, (n - 1)),tree((i * d), u, (n - 1))})
goto _var4
end
_var4=nil
::_var4::
end
_var1=_var4
end
return _var1
end
function at(tree)
local _var0
return (tree[1])
end
function up(tree)
local _var0
local _var1
do
if (tree[2]) then
_var1=((tree[2])[1])
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
if ((tree[2])==nil) then
_var1=nil
goto _var1
end
if ((tree[2])[2]) then
_var1=(((tree[2])[2])[1])
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
_var7
=(
(
tostring(at(tree))
)
..
(
"t- "
)
..
(
draw_row(up(tree))
)
..
""
)
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
_var7
=(
(
draw_row(tree)
)
..
(
"\n"
)
..
(
draw(down(tree))
)
..
""
)
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
local u=math.exp((volatility * math.sqrt(period)))
local d=(1 / u)
local r=math.exp((0.5 * 0.1))
local dividend=1
local PV_dividend_=(dividend / r)
local price_0=70
local price_0_PV_dividend_=(price_0 - PV_dividend_)
local p0=price_0_PV_dividend_
_var20=print(draw(tree(p0, u, 3)))
_var20=print(list({1,2,3,4}))
end
return _var1
end)()
