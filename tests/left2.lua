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


-- Grammar from https://en.wikipedia.org/wiki/Left_recursion#Pitfalls
read_expression = factor("expression", function(left)
    -- Give the parser a hint to avoid infinite loop on Left-recursion.
    -- The left operator can only be used when either:
    --  1. the all clause argument
    --  2. the read_* argument standing alone, e.g. left(read_y)
    -- left recursions back to this nonterminal.
    return any(
        left(span(read_expression, "-", read_term)),
        left(span(read_expression, "+", read_term)),
        read_term)
end)

read_term = factor("term", function(left)
    return any(left(span(read_term, "*", read_factor)), read_factor)
end)

read_factor = factor("factor", function()
    return any(span("(", read_expression, ")"), read_integer)
end)

read_integer = factor("integer", function()
    return any("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
end)

local bytes = itertools.tolist("1-(1-9*(7-3))*(4-7)*7")
local environment = reader.environ(bytes)


return read_expression(environment, bytes)

