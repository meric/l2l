return (function() 
require('l2l.core').import('l2l.core')
compiler.bootstrap(_G)
local compiler = compiler
local import = import
local tolist = tolist
local _var2
local _var3
_var3={require("samples/sample02")}
_var2=unpack(_var3)
_var2=print(sum(tolist({1,3,5,7}, nil)))
local _var7
do
if 1 then
_var7=print(1)
goto _var7
end
_var7=print(0)
::_var7::
end
return _var7
end)()
