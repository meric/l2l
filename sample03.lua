local sample03= (function() 
require('l2l.core').import('l2l.core')
compiler.bootstrap(_G)
local compiler = compiler
local tolist = tolist
local import = import
local _var2
local _var3
_var3=require("sample02")
_var2=print(sum(tolist({1,3,5,7}, nil)))
local _var6
do
if 1 then
_var6=print(1)
goto _var6
end
_var6=print(0)
::_var6::
end
return _var2
end)()
