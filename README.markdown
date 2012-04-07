Lisp to Lua Compiler
====================

Description
-----------
A tail-call-optimized, object-oriented, unicode-enabled lisp that compiles to and runs as fast as lua. Equipped with macroes and compile-time compiler manipulation. Comes with all built-in lua functions. 

Requires Lua 5.2!

Example 
-------

See test.lsp and out.lua (Scroll to line 700) for example inputs and outputs respectively.

TODO
----

Proper error messages, with line number tracking

Quickstart
----------
    # cd into l2l directory
    # Use Lua 5.2!
    lua l2l.lua test.lsp out.lua
    lua out.lua

