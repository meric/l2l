Sample source code
==================
    (defun ! (n) 
      (cond ((eq n 0) 1)
            ((eq n 1) 1)
            ('t (* n (! (- n 1))))))

    (print (! 100))

    (print (string.gsub "hello gibberish world" "gibberish " ""))

Sample output
=============
    -- header omitted --
    local function _c33_(n)
      return (function()
        if n==0 then
          return 1
        end
        if n==1 then
          return 1
        end
        if true then
          return (n*_c33_((n-1)))
        end
      end)()
    end
    print(_c33_(100))
    local hello_c45_world = "hello gibberish world"
    print(string.gsub(hello_c45_world,"gibberish ",""))
    map(print,list(1,2,3))


Sample output output
====================
    9.3326215443944e+157
    hello world 1
    1
    2
    3

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

