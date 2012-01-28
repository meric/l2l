Sample source code
==================
    (defun ! (n) 
      (cond ((eq n 0) 1)
            ((eq n 1) 1)
            ('t (* n (! (- n 1))))))

    (print (! 100))

Sample output
=============
    -- header omitted --
    _c33_=function(n) return (function()
      if n==0 then return 1 end
      if n==1 then return 1 end
      if sym("t") then return (n*_c33_((n-1))) end
      end)() end
    print(_c33_(100))

Sample output output
====================
    9.3326215443944e+157

Quickstart
==========
    cd into l2l directory
    lua l2l.lua test.lsp out.lua
    lua out.lua

Description
===========
A lisp to lua compiler (with parser) in 100 lines.

Motivated by
============
http://blog.fogus.me/2012/01/25/lisp-in-40-lines-of-ruby/

