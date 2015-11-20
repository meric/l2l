local sample02= (function() 
require('core').import('core')
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
l then
local _var3
_var3=((l)[1])
local _var5
local _var6
for _var5, _var6 in next, {sum(((l)[2]))} do
_var3 = _var3 + _var6
end
_var1 =
_var3 else
_var1 =
0 
end
return _var1
end
return _var1
end)()
