-- This is an example to demonstrate embedding and sandboxing l2l in another
-- lua program.
-- Run using: lua sample06/embed.lua

local core = require("l2l.core")

local obj = core.read(core.reader.tofile([[
    (do
        (set myvar 4)
        (print (map add_one '(1 2 3))))
]]))

local sandbox = core.compiler.environment()

core.eval(obj, nil, {
    -- insert function into sandboxed environment
    add_one = function(x) return x + 1 end
}, 
-- the sandbox
sandbox)

-- prove it `set` did not modify _G.
assert(_G.myvar == nil)

-- peek inside sandbox
print("(set myvar 4) => sandbox.myvar => ", sandbox.myvar)
