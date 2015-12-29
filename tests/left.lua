local grammar = require("l2l.grammar")
local reader = require("l2l.reader2")
local itertools = require("l2l.itertools")

local span = grammar.span
local any = grammar.any
local mark = grammar.mark
local repeating = grammar.repeating
local factor = grammar.factor

read_one = factor("one", function() return
        any(span(read_number, "1"), "1")
    end)

read_two = factor("two", function() return
        any(span(read_number, "2"), "2")
    end)

read_two_ = factor("two_", function() return
        span(read_two)
    end)

read_number = factor("number", function(left) return
        any(left(read_one), left(read_two_),
            span("(", read_number, ")", mark(read_number, repeating)))
    end)

local bytes = itertools.tolist("((1)2)112(2)112211")
local environment = reader.environ(bytes)

return read_number(environment, bytes)
