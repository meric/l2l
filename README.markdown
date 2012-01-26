Sample source code
==================
(label a 5)
(print a)
(print (* a 5))

(label double (lambda (x) (* x 2)))
(print (double a))

(print (eval (quote (double (+ 1 2)))))

Sample output
=============
-- header omitted --
a=5
print(a)
print(a*5)
double=function(x) return x*2 end
print(double(a))
print(eval(list(sym("double"),list(sym("+"),1,2))))

Quickstart:
cd into l2l directory
lua l2l.lua test.lsp out.lua
lua out.lua

Description
===========
A lisp to lua compiler (with parser) in 100 lines.

Motivated by
============
http://blog.fogus.me/2012/01/25/lisp-in-40-lines-of-ruby/

