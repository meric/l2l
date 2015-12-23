local grammar = require("l2l.grammar")
local reader = require("l2l.reader3")
local itertools = require("l2l.itertools")

local associate = grammar.associate
local span = grammar.span
local any = grammar.any
local mark = grammar.mark
local skip = grammar.skip
local option = grammar.option
local repeating = grammar.repeating
local Terminal = grammar.Terminal
local NonTerminal = grammar.NonTerminal
local factor = grammar.factor

one = NonTerminal("one")
two = NonTerminal("two")
two_ = NonTerminal("two_")
number = NonTerminal("number")

read_one = factor(one,
    function() return
        any(
            span(read_number, "1"),
            "1")
    end)

read_two = factor(two,
    function() return
        any(
            span(read_number, "2"),
            "2")
    end)

read_two_ = factor(two_,
    function()
        return span(read_two)
    end)

read_number = factor(number,
    function(LEFT) return
        any(
            LEFT(read_one),
            LEFT(read_two_),
            span(
                "(",
                read_number,
                ")",
                mark(read_number, repeating)))
    end)

local bytes = itertools.tolist("((1)2)112(2)112211")
local environment = reader.environ(bytes)

return read_number(environment, bytes)
