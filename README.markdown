-- Statistical Node Language Processor
-- Change Symbol Subsitution so Unicode is allowed

Lisp to Lua Compiler
====================

Description
-----------
A tail-call-optimized, object-oriented, unicode-enabled lisp that compiles to and runs as fast as lua. Equipped with macroes and compile-time compiler manipulation.

Requires Lua 5.2!

Example 
-------

See test.lsp

TODO
----

Proper error messages, with line number tracking

Quickstart
----------
    # cd into l2l directory
    # Use Lua 5.2!
    lua l2l.lua test.lsp out.lua
    lua out.lua

