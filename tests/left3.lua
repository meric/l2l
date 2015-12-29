local grammar = require("l2l.grammar")
local reader = require("l2l.reader2")
local itertools = require("l2l.itertools")

local span = grammar.span
local any = grammar.any
local factor = grammar.factor


-- This example demonstrates mutual recursion.
-- The grammar is taken from:
-- https://theantlrguy.atlassian.net/wiki/display/ANTLR3/Left-Recursion+Removal
b = factor("b", function(left)
    return any(left(span(a, integer)), integer)
end)


a = factor("a", function(left)
    return any(left(span(b, integer)), integer)
end)

integer = factor("integer", function()
    return any("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
end)


local bytes = itertools.tolist("12345")
local environment = reader.environ(bytes)

return a(environment, bytes)
