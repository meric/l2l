# Sample09 #

This is a prototype of a time travelling debugger for Lua, inspired by [Elm's](http://debug.elm-lang.org/edit/Mario.elm).

## Quickstart. ##

Download Love2d from http://love2d.org. Version 0.9.x.
Run with `path_to_love2d/love .`

## Contents ##

* [debugger.lua](../../l2l/ext/debugger.lua) implements the time travelling debugger.
* [mario.lua](main.lua) contains the actual game code.
* [main.lua](main.lua) contains the debugger gray panel UI code.

## How it looks ##

  1. Move with Left, Right, jump with Up.
  2. Press "P" to toggle Pause and Resume.
  3. Once paused, press the slider to move the program backwards and forwards.


* As we move, a line tracks mario's historical positions.
![1-track-mario-movement-with-line](screenshots/1-track-mario-movement-with-line.png?raw=true "track mario movement with line")

* We can pause the program and scrub back and forth.
![2-pause-and-rewind](screenshots/2-pause-and-rewind.png?raw=true "pause and rewind")

* Change the velocity when jumping from 6.

![3-a-jump-velocity-change-from-6](screenshots/3-a-jump-velocity-change-from-6.png?raw=true "jump velocity change from 6")

* Change the velocity when jumping to 12, and save the file.

![3-b-jump-velocity-change-to-12](screenshots/3-b-jump-velocity-change-to-12.png?raw=true "jump velocity change to 12")

* The code is hotswapped into the program, and all changes applied
retroactively, as is the case with the Elm's mario example.
![4-hotswap-and-apply-change-retroactively](screenshots/4-hotswap-and-apply-change-retroactively.png?raw=true "hotswap and apply change retroactively")

* The program now runs with new jump velocity code.
![5-continue-running-with-new-code](screenshots/5-continue-running-with-new-code.png?raw=true "continue running with new code")

## Pitfalls ##

* It's likely performance will not scale since every function call is
recorded, and every function call is now dozens of function calls instead. 
Will likely slow as the program runs and/or more logic is added.

* Does not currently handle bugs in code well.

## About ##

Saw it from http://debug.elm-lang.org/edit/Mario.elm

Elm's functional programming and pure functions are tools to assist building
a time travelling debugger.

Lua's functions, on surface, are mutable and can have side effects,
and would greatly impede the implementation of a time travelling debugger like
Elm's. 

However, if we switch our perspective, really, every Lua functions are pure
functions. A Lua function takes the global state, the upvalues state, the input parameters, and returns some values, as well as a set of modifications to the
global state, and the upvalues state. As long as we use the same global table,
the same set of upvalues, and the same arguments, a Lua function will almost
always return the same values, and do exactly the same thing. This prototype
is implemented based on this fact.

There are functions that use information or perform actions that affect the
world outside of the global state or upvalues, for example, io.read and 
io.write. All we have to do is tell the debugger that these are impure
functions whose returns must be recorded, so they can be played back without
being run, while the debugger is performing the "time-travel". This is done
through the `record` function. 

```love.keyboard.isDown = record(love.keyboard.isDown)```

See usage in `main.lua`.

# Other Programs #

This debugger can work with any Lua program, not just with Love2d.





