Lisp to Lua Compiler
====================

Description
-----------
A Dangerous Lisp to Lua Compiler.

Requires Lua 5.2!

Example 
-------

Here is an example lisp file, output messages when compiling the example, the output lua code from compiling the example as well as the output of the final program when run.

Example Lisp File
-----------------

    ; Example 1: Function declaration
    (print "\n--- Example 1 ---\n")
    (defun ! (n) 
      (cond ((== n 0) 1)
            ((== n 1) 1)
            (true (* n (! (- n 1))))))

    (print (! 100))

    ; Example 2: Acccessing functions from Lua environment
    (print "\n--- Example 2 ---\n")
    (set hello-world "hello gibberish world")
    (print (string.gsub hello-world "gibberish " ""))

    ; Example 3: Quasiquote and unquote
    (print "\n--- Example 3 ---\n")
    (map print `(1 2 3 ,(map (lambda (x) (* x 5)) '(1 2 3))))
    ; Note: prints all numbers only for lua 5.2. only 5.2 supports __ipairs override

    ; Example 4: Let
    (print "\n--- Example 4 ---\n")
    (let (a (+ 1 2) 
          b (+ 3 4))
      (print a)
      (print b))

    ; Example 5: Accessor method
    (print "\n--- Example 5 ---\n")
    (.print {print (lambda (self x) (print x))} "hello-world")

    ; Example 6: Anonymous function
    (print "\n--- Example 6 ---\n")
    (print ((lambda (x y) (+ x y)) 10 20))

    ; Example 7: Directive (The '#' prefix)
    (print "\n--- Example 7 ---\n")
    ; The following line will run as soon as it is parsed, no code will be generated
    ; It will add a new "--" operator that will be effective immediately
    #(set -- (Operator (lambda (str) (.. "-- " (tostring str))))) 

    ; Adds a lua comment to lua executable, using operator we defined.
    (-- "This is a comment") ; Will appear in `out.lua`

    ; Example 8: Define a do block
    #(print "\n--- Example 8 ---\n")
    ; E.g. (do (print 1) (print 2)) will execute (print 1) and (print 2) in sequence
    #(set do (Operator (lambda (...) 
          (.. "(function()\n" 
                (indent (compile [...])) 
              "\nend)()"))))
    (print "\n--- Example 8 ---\n")
    (print "\n--- Did you what was printed while compiling? ---\n")
    (do
      (print 1)
      (print 2))

    ; We can now make this program be interpreted by wrapping code in "#(do ...)"!

    #(do
      (print "I am running this line in the compilation step!")
      (print "This too!")
      (print (.. "1 + 1 = " (+ 1 1) "!"))
      (print "Okay that's enough."))

    ; We've had enough, so let's delete our do Operator
    #(set do nil)

    ; Uncommenting the following will result in an error when compiling
    ; #(do (print 1))

    ; Example 9: Vector
    (print "\n--- Example 9 ---\n")
    (let (a (* 7 8))
      (map print [1 2 a 4]))

    ; Example 10: Dictionary
    (print "\n--- Example 10 ---\n")
    (let (dict {"a" "b" 1 2 "3" 4})
      (print dict["a"] "b")
      (print dict.a "b")
      (print dict[1] 2)
      (print dict.3 4))

Printed out while compiling example
-----------------------------------

    --- Example 8 ---

    I am running this line in the compilation step!
    This too!
    1 + 1 = 2!
    Okay that's enough.

Compiled Output
---------------
    -- header omitted --
    print("\n--- Example 1 ---\n");

    function _c33_(n)
      return (function()  
        if (0 == n) then
          return 1
        end
        if (1 == n) then
          return 1
        end
        if true then
          return (n * _c33_((n - 1)))
        end
      end)()
    end;

    print(_c33_(100));

    print("\n--- Example 2 ---\n");

    hello_c45_world = "hello gibberish world";

    print(string["gsub"](hello_c45_world,"gibberish ",""));

    print("\n--- Example 3 ---\n");

    map(print,List(1,2,3,map((function(x)
      return (x * 5)
    end),List(1,2,3))));

    print("\n--- Example 4 ---\n");

    (function()
      local a = (1 + 2)
      local b = (3 + 4)
      print(a);
      return print(b)
    end)();

    print("\n--- Example 5 ---\n");

    ({["print"] = (function(self,x)
      return print(x)
    end)}):print("hello-world");

    print("\n--- Example 6 ---\n");

    print((function(x,y)
      return (x + y)
    end)(10,20));

    print("\n--- Example 7 ---\n");

    ;

    -- This is a comment;

    ;

    ;

    print("\n--- Example 8 ---\n");

    print("\n--- Did you what was printed while compiling? ---\n");

    (function()
      print(1);
      return print(2)
    end)();

    ;

    ;

    print("\n--- Example 9 ---\n");

    (function()
      local a = (7 * 8)
      return map(print,({1,2,a,4}))
    end)();

    print("\n--- Example 10 ---\n");

    return (function()
      local dict = ({["a"] = "b",[1] = 2,["3"] = 4})
      print(dict["a"],"b");
      print(dict["a"],"b");
      print(dict[1],2);
      return print(dict["3"],4)
    end)()



Output from running compiled lua
--------------------------------
    --- Example 1 ---

    9.3326215443944e+157

    --- Example 2 ---

    hello world 1

    --- Example 3 ---

    1
    2
    3
    (5 10 15)

    --- Example 4 ---

    3
    7

    --- Example 5 ---

    hello-world

    --- Example 6 ---

    30

    --- Example 7 ---


    --- Example 8 ---


    --- Did you what was printed while compiling? ---

    1
    2

    --- Example 9 ---

    1
    2
    56
    4

    --- Example 10 ---

    b   b
    b   b
    2   2
    4   4

Quickstart
----------
    # cd into l2l directory
    # Use Lua 5.2!
    lua l2l.lua test.lsp out.lua
    lua out.lua

