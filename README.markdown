Lisp to Lua Compiler
====================

Description
-----------
A tail-call-optimized, object-oriented, unicode-enabled lisp that compiles to and runs as fast as Lua. Equipped with macros and compile-time compiler manipulation. Comes with all built-in Lua functions. 

Requires Lua 5.2!

Example 
-------

See test.lsp for example input source code.

Example Output
--------------
    -- header omitted --
    print("\n--- Example 1 ---\n");

    function __c33__(n)
      return (function()  
        if (0 == n) then
          return 1
        end
        if (1 == n) then
          return 1
        end
        if true then
          return (n * __c33__((n - 1)))
        end
      end)()
    end;

    print(__c33__(100));

    print("\n--- Example 2 ---\n");

    function __c206____c163__()
      return print("ΣΣΣ")
    end;

    __c206____c163__();

    print("\n--- Example 3 ---\n");

    hello__c45__world = "hello gibberish world";

    print(string["gsub"](hello__c45__world,"gibberish ",""));

    print("\n--- Example 4 ---\n");

    map(print,List(1,2,3,map((function(x)
      return (x * 5)
    end),List(1,2,3))));

    print("\n--- Example 5 ---\n");

    (function()
      local a = (1 + 2)
      local b = (3 + 4)
      print(a);
      return print(b)
    end)();

    print("\n--- Example 6 ---\n");

    ({["write"] = (function(self,x)
      return print(x)
    end)}):write("hello-world");

    print("\n--- Example 7 ---\n");

    print((function(x,y)
      return (x + y)
    end)(10,20));

    print("\n--- Example 8 ---\n");

    (function()
      local a = (7 * 8)
      return map(print,({1,2,a,4}))
    end)();

    print("\n--- Example 9 ---\n");

    (function()
      local dict = ({["a"] = "b",[1] = 2,["3"] = 4})
      print(dict["a"],"b");
      print(dict["a"],"b");
      print(dict[1],2);
      return print(dict["3"],4)
    end)();

    print("\n--- Example 10 ---\n");

    ;

    -- This is a comment;

    ;

    ;

    ;

    print("\n--- Example 11 ---\n");

    print("\n--- Did you see what was printed while compiling? ---\n");

    (function()
      print(1);
      return print(2)
    end)();

    ;

    print("\n--- Example 12 ---\n");

    ;

    (function()
      local a = 2
      return (function()  
        if ("1" == a) then
          return print("a == 1")
        end
        if true then
          return (function()  
            if (2 == a) then
              return print("a == 2")
            end
            if true then
              return print("a != 2")
            end
          end)()
        end
      end)()
    end)();

    ;

    ;

    ;

    ;

    ;


TODO
----

Proper error messages, with line number tracking

Quickstart
----------
    # cd into l2l directory
    # Use Lua 5.2!
    lua l2l.lua test.lsp out.lua
    lua out.lua

