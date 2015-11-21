local sample02= (function() 
require('l2l.core').import('l2l.core')
local _var1
_C[hash("if1")]=function (block, stream, condition, action, otherwise)
local _var0
local _var1
do
local fn=eval(list({symbol("lambda"),list({symbol("condition"),symbol("action"),symbol("otherwise")}),list({symbol("quasiquote"),list({symbol("cond"),condition,action,otherwise})})}))
_var1=compile(block, stream, fn(condition, action, otherwise))
end
return _var1
end
_var1=_C[hash("if1")]
function sum(l)
local _var0
local _var1
if
l
then
_var1
=
((l[1]) + sum((l[2])))
else
_var1
=
0
end
return _var1
end
return _var1
end)()
local sample03= (function() 
require('l2l.core').import('l2l.core')
local _var1
_var1=print(sum(list({1,3,5,7})))
local _var3
do
if 1 then
_var3=print(1)
goto _var3
end
_var3=print(0)
::_var3::
end
return _var1
end)()
