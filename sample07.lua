local eval = require("l2l.eval")

setmetatable(_G, {__newindex=function(self, name, value)
    error(name)
end})

local env = eval.environment({
    x=3,
    setmetatable=setmetatable,
    pcall=pcall
})

local f = eval.loadstring("(set y 1) (print x 1)")

setfenv(f, env)

f()

assert(env.y == 1)
assert(y ~= 1)

-- should print "3      1"
