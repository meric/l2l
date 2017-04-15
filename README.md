# l2l #

This language is a superset of Lisp and Lua.

## Example ##

[boolean.lisp](/l2l/ext/boolean.lisp), implements `and`, `or` special forms:

```lua
@import quasiquote
@import quote
@import fn
@import local
@import do
@import let
@import cond

(fn circuit_and (invariant cdr output truth)
  (cond cdr
    (let (
      car (:car cdr)
      ref (lua_name:unique "_and_value"))
      `\
        local \,ref = \,\(expize(invariant, car, output))
        if \,ref then
          \,(cond (:cdr cdr)
              (circuit_and invariant (:cdr cdr) output truth)
              `\\,truth = \,ref)
        else
          \,truth = false
        end)))

(fn expize_and (invariant cdr output)
  (let (ref (lua_name:unique "_and_bool"))
    (table.insert output `\local \,ref = true)
    (table.insert output (circuit_and invariant cdr output ref))
    ref))

(fn statize_and (invariant cdr output)
  (to_stat (expize_and invariant cdr output)))

(fn circuit_or (invariant cdr output truth)
  (cond cdr
    (let (
      car (:car cdr)
      ref (lua_name:unique "_or_value"))
      `\
        if not \,truth then
          local \,ref = \,\(expize(invariant, car, output))
          if \,ref then
            \,truth = \,ref
          end
        end
        \,(cond (:cdr cdr)
            (circuit_or invariant (:cdr cdr) output truth)))))

(fn expize_or (invariant cdr output)
  (let (ref (lua_name:unique "_or_bool"))
    (table.insert output `\local \,ref = false)
    (table.insert output (circuit_or invariant cdr output ref))
    ref))

(fn statize_or (invariant cdr output)
  (to_stat (expize_or invariant cdr output)))

{
  lua = {
    ["and"] = {expize=expize_and, statize=statize_and},
    ["or"] = {expize=expize_or, statize=statize_or}
  }
}
```

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

## Syntax Highlighting ##

There is a [l2l syntax highlighting package for Atom](http://github.com/meric/language-l2l) that is a work-in-progress.
It is not registered to Atom.io yet, so you will have to copy it to your packages directory manually:

```bash
cd ~/.atom/packages
git clone git@github.com:meric/language-l2l.git
```

It will take effect when you restart Atom and apply to all files with a .lisp extension.

![l2l-syntax-highlighting](/l2l-syntax-highlight.png?raw=true "")

## Naming ##

Lisp names are mangled into Lua by replacing non lua compliant characters
with lua compliant characters. (See the mangle function in l2l/reader.lua).

Lisp names can contain dashes, dots, alphabets, numbers, underscores, and many
more characters, but they must not consist of two dots consecutively unless
the name is `..` (lua string concat) or `...` (lua vararg).

This is so the compiler can mangle lua field accessor names
`my_table.my_subtable-with-dashes.some_key` properly.

## Features ##

* Mix Lisp and Lua in source code with backslash.

  ```lua
  \print(\(+ 1 2 3 4))
  ```

* Quasiquoting Lua expressions.

  ```lua
  (table.insert output `\local \,ref = false)
  ```

* Macro and special form aliasing.
* Macro as modules.

  ```lisp
  @import (let x); (x.let (y 1) (print y))
  ```

* Custom special forms as modules.

  For example, [boolean.lisp](/l2l/ext/boolean.lisp).

* Zero-cost `map`, `filter`, `reduce` abstractions.
* Implement special forms that can inline anonymous functions as macros.
* Special forms in Lua.

  ```lua
  @import iterator
  \
  map(function(x) return x + 2 end,
    filter(function(x) return x % 2 == 0 end,
      map(function(x) return x + 1 end, {1, 2, 3, 4})))
  ```

  Compiles into (nested loops collapsed into a single pass):

  ```lua
  local ipairs = require("l2l.iterator")
  local vector = require("l2l.vector")
  local next38,invariant37,i39 = ipairs({1,2,3,4});
  local values41 = vector();
  while i39 do
    local v40;i39,v40=next38(invariant37,i39);
    if i39 then
      v40=v40 + 1;
      if v40 % 2 == 0 then
        v40=v40 + 2;
        (values41):insert(v40)
      end
    end
  end
  return values41
  ```

## Philosophy ##

> The Tao begot one. One begot two.<br>
> &mdash; *[Laozi](http://terebess.hu/english/tao/gia.html#Kap42)*

> Now I do not know whether I was then a man dreaming
> I was a butterfly,<br>
> Or whether I am now a butterfly, dreaming I am a man.<br>
> &mdash; *[Zhuangzi](http://ctext.org/zhuangzi/adjustment-of-controversies?searchu=butterfly&searchmode=showall#result)*

> I have put duality away, I have seen that the two worlds are one;<br>
> One I seek, One I know, One I see, One I call.<br>
> &mdash; *[Jalaluddin Rumi](http://thefoggiestnotion.com/rumi.htm)*

> Now I do not know whether I was writing Lua inside of Lisp,<br>
> Or whether I am now writing Lisp, inside of Lua.<br>
> I have put duality away, I have seen that the two worlds are one;<br>
> One I read. One I write. One I compile. One I run.<br>
> &mdash; *[You](http://www.thoughtpursuits.com/10-faciniting-love-poems-rumi/)*


#### Obligatory ####

> I am the servant of the Qur'an as long as I have life.<br>
> I am the dust on the path of Muhammad, the Chosen one.<br>
> If anyone quotes anything except this from my sayings,<br>
> I am quit of him and outraged by these words.<br>
> &mdash; *[Jalaluddin Rumi](https://en.wikipedia.org/wiki/Rumi)*
