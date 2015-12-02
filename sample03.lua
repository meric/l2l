local sample02= (function() 
require('l2l.core').import('l2l.core')
compiler.bootstrap(_G)
local tolist = tolist
local import = import
local compiler = compiler
local _var2
_M["if1"]=(function (condition, action, otherwise)
local _var0
return tolist({symbol("cond"),condition,action,otherwise})
end)
_var2=_M["if1"]
function sum(l)
local _var0
local _var1
if l then
local _var0
_var0=((l)[1])
local _var2
local _var3
for _var2, _var3 in next, {sum(((l)[2]))} do
_var0 = _var0 + _var3
end
_var1={_var0}
else

_var1={0}
end
return unpack(_var1)
end
return _var2
end)()
local sample03= (function() 
require('l2l.core').import('l2l.core')
compiler.bootstrap(_G)
local tolist = tolist
local import = import
local compiler = compiler
local _var2
_var2=print(sum(tolist({1,3,5,7}, nil)))
_var2=if1(1, print(1), print(0))
return _var2
end)()
