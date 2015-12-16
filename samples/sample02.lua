return (function() 
require('l2l.core').import('l2l.core')
compiler.bootstrap(_G)
local import = import
local compiler = compiler
local tolist = tolist
local _var2
_M["if1"]=(function (condition, action, otherwise)
local _var0
return tolist({symbol("cond"),condition,action,otherwise}, nil)
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
return sum
end)()
