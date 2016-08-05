Notice
======
This branch is deprecated.

When the [rewrite](https://github.com/meric/l2l/tree/rewrite) branch is ready, this master branch will be tagged and replaced with it.

Lisp to Lua Compiler
====================

[![Join the chat at https://gitter.im/meric/l2l](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/meric/l2l?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

A Lisp to Lua compiler, compatible with LuaJIT or Lua5.1+. Lua 5.2+ or 
LuaJIT (built with -DLUAJIT_ENABLE_LUA52COMPAT) recommended for higher
performance.

Status
------
This project is currently very unstable. Every commit is more likely than not to break compatibility with its previous commit. If you find a commit that works for you, stick to it. Right now I'm working on rewriting large parts of it to improve parsing performance, as well as adding a parser generator that will be used to parse Lua inside Lisp code, and adding meta information to compiled expressions so it'll be possible to intercept Lua runtime errors and translate them back into a Lisp traceback.


Features
-----------
* Reader Macros
* Macros
* Lua functions
* Compiler modification on-the-fly during compile-time.

Potential uses
--------------
* Lisp in web server. [[Nginx](https://github.com/openresty)] [[Apache](https://httpd.apache.org/docs/trunk/mod/mod_lua.html)]
* Lisp in Redis. [[Redis](http://redis.io/commands/EVAL)]
* Lisp with Lua web framework. [[Lapis](https://github.com/leafo/lapis)]
* Lisp with Lua game engine. [[LÖVE](https://love2d.org)]
* Lisp in Lua scripted game. [[Wesnoth](http://wiki.wesnoth.org/Luawml#Lua_files)]
* Cross-platform mobile app development with Lisp. [[Corona](https://coronalabs.com)] [[MOAI](http://getmoai.com)]
* Lisp whenever there's only ANSI C to build Lua with.
* Where there's Lua, there can be Lisp also.

Contribute
----------
Play around. Make issues. Submit pull requests. :)


How To
------

* `./bin/l2l --enable read_execute` to launch REPL.

```lisp
;; Welcome to Lisp-To-Lua REPL!
;; Type '(print "hello world!") to start.
>> (print "Hello world!")
Hello world!
=   nil
>> 
```

* `./bin/l2l --enable read_execute sample01.lisp` to compile `sample01.lisp` and output Lua to stdout.
* `./bin/l2l --enable read_execute sample01.lisp | lua` to compile and run `sample01.lisp` immediately.
* `./bin/l2l sample02.lisp sample03.lisp` to compile two lisp files where one 
    requires the other.
* `make -C sample04` to run the makefile in the sample04 directory. It
   demonstrates how to use l2l from another directory.
* `make samples` to build all samples. Requires bash.
* `make test` to run unit tests.
* `make repl` to launch the repl.

```lisp
bin/l2l
;; Welcome to Lisp-To-Lua REPL!
;; Type '(print "hello world!") to start.
>> (import sample02) ;; sample02.lisp defines the if1 macro.
=	true
>> (if1 false 1 2)
=	2
```

Use in Lua
----------

```lua
lua
Lua 5.2.4  Copyright (C) 1994-2015 Lua.org, PUC-Rio
> require("l2l.eval").loadstring("(print 1) (print 2)")()
1
2
> 
```


Differences from other lisps
----------------------------

While l2l is not a Scheme or Common Lisp implementation, it shares
many features of these languages.

It is a [Lisp-1](https://hornbeck.wordpress.com/2009/07/05/lisp-1-vs-lisp-2/)
like Scheme, which means that functions are treated like other values
rather than being stored in a separate namespace. However, the macro
system uses a much simpler `defmacro` like CL and Clojure instead of
Scheme's hygenic macros.

The `let` macro for binding locals works more like Clojure--it does
not require each name/value pair to be wrapped in its own parens:

```lisp
(let (x 12
      y 30)
  (+ x (* y 22)))
```

The syntax for [varargs](https://en.wikipedia.org/wiki/Variadic_function)
is taken from Lua rather than any existing lisp dialect; it uses three dots:

```lisp
(defun myfun (...) (cdr (pack ...)))
```

Functions can also return multiple values.

```lisp
(defun x () (id 1 2 3))
(print (x))
(set y (vector (x))) ;; wrap it in a table.
;; prints "1    2    3"
```

The `-` and `/` operators do not have a unary mode.

```lisp
(- 4)
```
and 

```lisp
(/ 4)
```
both return 4. 

Implementing unary mode would prevent implementing these two operators directly
 in the form of `(a - b - c - d...)` and `(a / b / c / d)`.

There are complications that can arise because of Lua's vararg mechanics.

Should `(- (somefunction x))` be a unary call or a non-unary call?

`somefunction` can return 1 or more values, and it is impossible to know which,
in the compiling stage, before the particular call is evaluated.

Internals
---------

* Change prompt string by setting the `_P` global variable.

```lisp
>> (set _P ">->o ")
=   >> 
>->o (print "Hello World")
Hello World
=   nil
>->o 
```

* The read macro table is `_R`. `_R.META` stores locations of all read symbols.

```lisp
>> (set _R.META {}) ;; _R.META is too big.
=   table: 0x7fcf90c54c90
>> (show _R)
=   {"}" function: 0x7fcf90c1a930 "META" {(show _R) {1 6 2 9 0 6}} ";" function: 0x7fcf90c1a8c0 "position" function: 0x7fcf90c1b1a0 ")" function: 0x7fcf90c1a8e0 "(" function: 0x7fcf90c1ac10 "'" function: 0x7fcf90c1ad30 "," function: 0x7fcf90c1adb0 "[" function: 0x7fcf90c1aab0 "#" function: 0x7fcf90c1adf0 "\"" function: 0x7fcf90c1a9d0 "]" function: 0x7fcf90c1a980 "`" function: 0x7fcf90c1ad70 "{" function: 0x7fcf90c1ab80}
>> 
```

* The dispatch read macro table is `_D`.

```lisp
>> (show _D)
=   {"." function: 0x7fcf90c27360 " " function: 0x7fcf90c1a890 "'" function: 0x7fcf90c1acf0}
```

* The macro table is `_M`.

```lisp
>> (defmacro GAMMA () '(+ 1 2))
=   function: 0x7f8fe3e52e00
>> (show _M)
=   {"GAMMA" function: 0x7f8fe3e52e00}
```

* The compiler table is `_C`.


```lisp
>> (show _C)
=   {"quote" function: 0x7f8fe3e0f790 "lambda" function: 0x7f8fe3e16930 "_119_104_105_108_101" function: 0x7f8fe3f3a470 "defun" function: 0x7f8fe3e16a90 "_97_110_100" function: 0x7f8fe3e21ae0 "_58" function: 0x7f8fe3e22300 "_110_111_116" function: 0x7f8fe3e0ecf0 "_62_61" function: 0x7f8fe3e1acf0 "_" function: 0x7f8fe3e22160 "_37" function: 0x7f8fe3e222a0 "defmacro" function: 0x7f8fe3e19f10 "let" function: 0x7f8fe3e16a20 "car" function: 0x7f8fe3e16990 "chunk" function: 0x7f8fe3f5ce00 "_61_62" function: 0x7f8fe3e16930 "_60" function: 0x7f8fe3e20ce0 "_35" function: 0x7f8fe3e22340 "cond" function: 0x7f8fe3e0f820 "defcompiler" function: 0x7f8fe3e16ac0 "_102_111_114" function: 0x7f8fe3f58650 "_100_111" function: 0x7f8fe3f1b1c0 "_98_114_101_97_107" function: 0x7f8fe3f40e10 "quasiquote" function: 0x7f8fe3e0f7d0 "_42" function: 0x7f8fe3e1f030 "_47" function: 0x7f8fe3e1db00 "_62" function: 0x7f8fe3e1abe0 "_43" function: 0x7f8fe3e0d7c0 "_46_46" function: 0x7f8fe3e10a90 "_61" function: 0x7f8fe3e22370 "_61_61" function: 0x7f8fe3e1a5f0 "set" function: 0x7f8fe3e22370 "cdr" function: 0x7f8fe3e169c0 "cadr" function: 0x7f8fe3e169f0 "table_quote" function: 0x7f8fe3e0f750 "_60_61" function: 0x7f8fe3e14e60 "_105_102" function: 0x7f8fe3e0f8c0 "_111_114" function: 0x7f8fe3e159c0 "_46" function: 0x7f8fe3e222d0}
```

* A "compiler" can be used to implement [special forms](http://stackoverflow.com/a/2877854).

* The format of a compiler is a function with at least two arguments.
For example: 

```lua
local function compile_car(block, stream, form)
  return "(("..compile(block, stream, form) .. ")[1])"
end
```
This implements compiling `(car x)` to `(x[1])`.

A compiler function inserts any non-expression Lua statements into `block`,
and returns a single Lua expression which should either be the value
or reference to the value that will be returned in its parent lisp block
(which is likely to be a lisp function).

The arguments of a function are raw lisp values, uncompiled and 
unprocessed. They must be compiled before being inserted into generated 
Lua code.

There are caveats involved when implementing special forms involving
variadic arguments, since the compiler function would see `...` rather
than the expanded values. Checkout the math operators in "compilers.lua".

* Use the `defcompiler` helper to define compilers in lisp. 
    For example:

```lisp
(defcompiler -- (block stream str)
    (table.insert block (.. "\n--" (tostring str))))
```

This implements comments that will be printed directly into the Lua output.

`defcompiler` will put your compiler into `_C` table as well as activate
the compiler immediately for use. Right after the above compiler 
declaration you can have:

```lisp
(-- "This is a comment")
```

and the code will be output directly as "-- This is a comment" into the
Lua source code.


TODO
----

* Make sure `_R.META` is recording locations accurately enough during the compiler 
stage.
* ~~Implement a method to automate unwrapping of `...` arguments to operators.~~
* ~~`compiler.lua` self-bootstrapping generates ugly code and poses problem when sandboxing.~~ 
* Replace the io interface `reader.lua` uses with one that has nothing to do with files.

License
=======

Copyright © 2012-2015, Eric Man and contributors
Released under the 2-clause BSD license, see LICENSE

