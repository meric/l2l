Lisp to Lua Compiler
====================

[![Join the chat at https://gitter.im/meric/l2l](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/meric/l2l?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

A Lisp to Lua compiler, compatible with LuaJIT (built with -DLUAJIT_ENABLE_LUA52COMPAT) or Lua5.3.

Features
-----------
* Reader Macros
* Macros
* Lua functions
* Compiler modification on-the-fly during compile-time..
* Compiler partially implemented by itself. See https://github.com/meric/l2l/blob/master/compiler.lua#L596


Contribute
----------
Play around. Make issues. Submit pull requests. :)


How To
------

* `./l2l` to launch REPL.

        ;; Welcome to Lua-To-Lisp REPL!
        ;; Type '(print "hello world!") to start.
        >> (print "Hello world!")
        Hello world!
        =   nil
        >> 

* `./l2l sample01.lsp` to compile `sample01.lsp` and output Lua to stdout.
* `./l2l sample01.lsp | lua` to compile and run `sample01.lsp` immediately.
* `./l2l sample02.lsp sample03.lsp` to compile two lisp files where one 
    requires the other.
* `make -C sample04` to run the makefile in the sample04 directory. It
   demonstrates how to use l2l from another directory.

* Change prompt string by setting the `_P` global variable.

        >> (set _P ">->o ")
        =   >> 
        >->o (print "Hello World")
        Hello World
        =   nil
        >->o 

* The read macro table is `_R`. `_R.META` stores locations of all read symbols.

        >> (set _R.META {}) ;; _R.META is too big.
        =   table: 0x7fcf90c54c90
        >> (show _R)
        =   {"}" function: 0x7fcf90c1a930 "META" {(show _R) {1 6 2 9 0 6}} ";" function: 0x7fcf90c1a8c0 "position" function: 0x7fcf90c1b1a0 ")" function: 0x7fcf90c1a8e0 "(" function: 0x7fcf90c1ac10 "'" function: 0x7fcf90c1ad30 "," function: 0x7fcf90c1adb0 "[" function: 0x7fcf90c1aab0 "#" function: 0x7fcf90c1adf0 "\"" function: 0x7fcf90c1a9d0 "]" function: 0x7fcf90c1a980 "`" function: 0x7fcf90c1ad70 "{" function: 0x7fcf90c1ab80}
        >> 

* The dispatch read macro table is `_D`.

        >> (show _D)
        =   {"." function: 0x7fcf90c27360 " " function: 0x7fcf90c1a890 "'" function: 0x7fcf90c1acf0}

* The compiler table is `_C`.

        >> (show _C)
        =   {"_60_61" function: 0x7fac1bc1e4d0 "_105_102" function: 0x7fac1bc948f0 "_" function: 0x7fac1bc26280 "defcompiler" function: 0x7fac1bc266a0 "defun" function: 0x7fac1bc26820 "_111_114" function: 0x7fac1bc261c0 "quasiquote" function: 0x7fac1bc26460 "_119_104_105_108_101" function: 0x7fac1bc3b300 "cadr" function: 0x7fac1bc26780 "_35" function: 0x7fac1bc26370 "_100_111" function: 0x7fac1bc64040 "car" function: 0x7fac1bc26720 "_58" function: 0x7fac1bc26330 "_62" function: 0x7fac1bc1e570 "cond" function: 0x7fac1bc264b0 "_47" function: 0x7fac1bc262c0 "chunk" function: 0x7fac1bc4a340 "_46_46" function: 0x7fac1bc0be00 "_43" function: 0x7fac1bc26240 "_110_111_116" function: 0x7fac1bc26190 "_46" function: 0x7fac1bc26300 "_62_61" function: 0x7fac1bc26090 "quote" function: 0x7fac1bc26420 "_98_114_101_97_107" function: 0x7fac1bc6bc30 "set" function: 0x7fac1bc263a0 "table_quote" function: 0x7fac1bc263e0 "_61_61" function: 0x7fac1bc1e3d0 "defmacro" function: 0x7fac1bc717b0 "let" function: 0x7fac1bc267b0 "_42" function: 0x7fac1bc26200 "lambda" function: 0x7fac1bc26650 "_60" function: 0x7fac1bc1e450 "_97_110_100" function: 0x7fac1bc26130 "cdr" function: 0x7fac1bc26750}
        >> 

* The format of a compiler is a function with at least two arguments.
    For example: 

        local function compile_subtract(block, stream, ...)
          return "("..map(bind(compile, block, stream), {...}):concat(" - ")..")"
        end

    This implements compiling `(- 1 2 3)` to `(1 - 2 - 3)`.

    A compiler function inserts any non-expression Lua statements into `block`,
    and returns a single Lua expression which should either be the value
    or reference to the value that will be returned in its parent lisp block
    (which is likely to be a lisp function).

    The arguments of a function are raw lisp values, uncompiled and 
    unprocessed. They must be compiled before being inserted into generated 
    Lua code.

* Use the `defcompiler` helper to define compilers in lisp. 
    For example:

        (defcompiler -- (block stream str)
            (table.insert block (.. "\n--" (tostring str))))

    This implements comments that will be printed directly into the Lua output.

    `defcompiler` will put your compiler into `_C` table as well as activate
    the compiler immediately for use. Right after the above compiler 
    declaration you can have:

        `(-- "This is a comment")`

    and the code will be output directly as "-- This is a comment" into the
    Lua source code.
    
    The following information about `defcompiler` is relevant for compilers
    taking variable arguments, i.e. `...`, like the add operator.
    `(+ 1 2 3...)`:

    Caveat: `...` in a compiler arguments as cannot be expanded in a 
    compilation context, because the code isn't compiled yet, the data cannot
    be accessed.

    Currently the work around is to write a function with the same name,
    and in the `defcompiler`, if `...` is in the arguments, call that function
    to recursively unroll `...` and call it into the compiler function.


    For example, the add operator, here is the compiler definition.

        local function compile_add(block, stream, ...)
          if last({...}) == symbol("...") then
            local literals = slice({...}, 1, -1)
            local first = ""
            if #literals > 0 then
               first = map(bind(compile, block, stream), literals):concat(" + ")..","
            end
            return ("("..hash("+").."("..first.."...))")
          end
          return "("..map(bind(compile, block, stream), false, ...):concat(" + ")..")"
        end

    When "..." is an argument, it will output code representing a call to the
    `+` function.

        (defun + (a ...)
            (if (> (select "#" ...) 0) (let (op +) (+ a (op ...))) a))

    This will unroll `...` into individual values and call the compiler with
    the variable arguments expanded.

* `defmacro` is currently implemented like so:


        (defcompiler defmacro (block stream name parameters ...)
          (let 
            (params (list.push (list.push parameters 'stream) 'block)
             code `(defcompiler ,name ,params
                     (let (fn (eval `(lambda ,parameters ,...)))
                       (compile block stream (fn ,(list.unpack parameters))))))
            (eval code)
            (compile block stream code)))


TODO
----

* The `_R.META` does not record locations accurately enough during the compiler 
stage.

