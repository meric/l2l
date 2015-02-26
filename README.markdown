Lisp to Lua Compiler
====================

A Lisp to Lua compiler, compatible with LuaJIT or Lua5.3.

Features
-----------
* Reader Macros
* Macros
* Lua functions
* Compiler modification on-the-fly.
* Compiler partially implemented by itself. See https://github.com/meric/l2l/blob/master/compiler.lua#L596


How To
------

* `./l2l` to launch REPL.

        ;; Welcome to Lua-To-Lisp REPL!
        ;; Type '(print "hello world!") to start.
        >->o (print "Hello world!")
        Hello world!
        =   nil
        >->o 

* `./l2l sample01.lsp` to compile `sample01.lsp` and output Lua to stdout.
* `./l2l sample01.lsp | lua` to compile and run `sample01.lsp` immediately.
