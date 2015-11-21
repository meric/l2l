-- This is an example to demonstrate embedding l2l in another lua program.
-- Run using: lua sample06/embed.lua

local core = require("core")


local obj = core.read(core.reader.tofile([[
    (do
        (set myvar 4)
        (print (map add_one '(1 2 3))))
]]))

local G = core.compiler.environment()

core.eval(obj, nil, {
    add_one = function(x) return x + 1 end
}, G)

assert(_G.myvar == nil)
