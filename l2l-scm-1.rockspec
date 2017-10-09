package = "l2l"
version = "scm-1"

source = {
  url = "git://github.com/meric/l2l.git"
}

description = {
  summary = "A programming language that is a superset of Lisp and Lua.",
  detailed = [[
    ## Quick Start ##

    ```bash
    # Requires https://github.com/meric/leftry cloned as a sibling to this repo.
    git clone git@github.com:meric/leftry.git
    git clone git@github.com:meric/l2l.git
    cd l2l
    make clean
    make test
    make repl
    ```

    Run the following commands:

    ```
    > (print "hello world")
    hello world
    > \print("hello world")
    hello world
    > (let (a 1) (print `\print(\,a)))
    print(1)
    > (let (a 1) (print (getmetatable `\print(\,a))))
    lua_block
    ```
  ]],
  license = "BSD-2",
  homepage = "http://github.com/meric/l2l",
  maintainer = "meric.au@gmail.com"
}


dependencies = {
  "leftry",
  "luacheck"
}


build = {
  type = "builtin",
  install = {
    bin = {"bin/l2l"}
  },
  modules = {
    ["l2l.lib.apply"] = "l2l/lib/apply.lua",
    ["l2l.lib.destructure"] = "l2l/lib/destructure.lua",
    ["l2l.lib.operators"] = "l2l/lib/operators.lua",
    ["l2l.ext.locals"] = "l2l/ext/locals.lua",
    ["l2l.ext.quote"] = "l2l/ext/quote.lua",
    ["l2l.ext.lua_quote"] = "l2l/ext/lua_quote.lua",
    ["l2l.ext.set"] = "l2l/ext/set.lua",
    ["l2l.ext.let"] = "l2l/ext/let.lua",
    ["l2l.ext.fn"] = "l2l/ext/fn.lua",
    ["l2l.ext.while"] = "l2l/ext/while.lua",
    ["l2l.ext.seti"] = "l2l/ext/seti.lua",
    ["l2l.ext.iterator"] = "l2l/ext/iterator.lua",
    ["l2l.ext.quasiquote"] = "l2l/ext/quasiquote.lua",
    ["l2l.ext.if"] = "l2l/ext/if.lua",
    ["l2l.ext.local"] = "l2l/ext/local.lua",
    ["l2l.ext.do"] = "l2l/ext/do.lua",
    ["l2l.ext.cond"] = "l2l/ext/cond.lua",
    ["l2l.ext.boolean"] = "l2l/ext/boolean.lua",
    ["l2l.ext.operators"] = "l2l/ext/operators.lua",
    ["l2l.main"] = "l2l/main.lua",
    ["l2l.iterator"] = "l2l/iterator.lua",
    ["l2l.compiler"] = "l2l/compiler.lua",
    ["l2l.vector"] = "l2l/vector.lua",
    ["l2l.trace"] = "l2l/trace.lua",
    ["l2l.list"] = "l2l/list.lua",
    ["l2l.test"] = "l2l/test.lua",
    ["l2l.reader"] = "l2l/reader.lua",
    ["l2l.len"] = "l2l/len.lua",
    ["l2l.exception"] = "l2l/exception.lua",
    ["l2l.lua"] = "l2l/lua.lua"
  }
}
