# l2l #

In this language, Lisp and Lua are one.

## Philosophy ##

> The Tao begot one. One begot two.

**[Laozi](http://terebess.hu/english/tao/gia.html#Kap42)**

> Now I do not know whether I was then a man dreaming
> I was a butterfly, or whether I am now a butterfly, dreaming I am a man.

**[Zhuangzi](http://ctext.org/zhuangzi/adjustment-of-controversies?searchu=butterfly&searchmode=showall#result)**

> I have put duality away, I have seen that the two worlds are one;
> One I seek, One I know, One I see, One I call.

**[Jalaluddin Rumi](http://thefoggiestnotion.com/rumi.htm)**

> Now I do not know whether I was writing Lua inside of Lisp, or whether I am
> now writing Lisp, inside of Lua. I have put duality away, I have seen that
> the two languages are one. One I read. One I write. One I compile. One I run.

*[You](http://www.thoughtpursuits.com/10-faciniting-love-poems-rumi/)*

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


#### Obligatory ####

> I am the servant of the Qur'an as long as I have life.
> I am the dust on the path of Muhammad, the Chosen one.
> If anyone quotes anything except this from my sayings,
> I am quit of him and outraged by these words.

**[Jalaluddin Rumi](https://en.wikipedia.org/wiki/Rumi)**
