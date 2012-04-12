Lisp to Lua Compiler
====================

Description
-----------
A tail-call-optimized, object-oriented, unicode-enabled lisp that compiles to and runs as fast as Lua. Equipped with macros and compile-time compiler manipulation. Comes with all built-in Lua functions. 

Requires Lua 5.2!

Example 
-------

See test.lsp for example input source code.
See out.lua for example output source code.

TODO
----

Proper error messages, with line number tracking

Quickstart
----------
    # cd into l2l directory
    # Use Lua 5.2!
    lua l2l.lua test.lsp out.lua
    lua out.lua

