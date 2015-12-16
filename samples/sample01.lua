return (function() 
require('l2l.core').import('l2l.core')
compiler.bootstrap(_G)
local import = import
local dict = dict
local compiler = compiler
local _var2
_var2=(dict("write", (function (self, x)
local _var0
return print(x)
end))):write("hello-world")
_var2=("hello-world"):byte()
_var2=(1):byte()
dict("write", (function (self, x)
local _var0
return print(x)
end))["write"]="hello-world"
return print(dict("write", (function (self, x)
local _var0
return print(x)
end))["write"])
end)()
