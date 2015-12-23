local grammar = require("l2l.grammar")
local reader = require("l2l.reader3")
local itertools = require("l2l.itertools")

local SET = grammar.SET
local ALL = grammar.ALL
local ANY = grammar.ANY
local TERM = grammar.TERM
local LABEL = grammar.LABEL
local SKIP = grammar.SKIP
local OPTION = grammar.OPTION
local REPEAT = grammar.REPEAT
local Terminal = grammar.Terminal
local NonTerminal = grammar.NonTerminal
local factor_nonterminal = grammar.factor_nonterminal


-- Grammar from https://en.wikipedia.org/wiki/Left_recursion#Pitfalls
expression = NonTerminal("expression")
term = NonTerminal("term")
factor = NonTerminal("factor")
integer = NonTerminal("integer")

read_expression = factor_nonterminal(expression, function(LEFT)
    -- Give the parser a hint to avoid infinite loop on Left-recursion.
    -- The LEFT operator can only be used when either:
    --  1. the ALL clause argument
    --  2. the read_* argument standing alone, e.g. LEFT(read_y)
    -- left recursions back to this nonterminal.
    return ANY(
        LEFT(ALL(read_expression, TERM("-"), read_term)),
        LEFT(ALL(read_expression, TERM("+"), read_term)),
        read_term)
end)

read_term = factor_nonterminal(term, function(LEFT)
    return ANY(LEFT(ALL(read_term, TERM("*"), read_factor)), read_factor)
end)

read_factor = factor_nonterminal(factor, function()
    return ANY(ALL(TERM("("), read_expression, TERM(")")), read_integer)
end)

read_integer = factor_nonterminal(integer, function()
    return ANY(
        TERM("0"),
        TERM("1"),
        TERM("2"),
        TERM("3"),
        TERM("4"),
        TERM("5"),
        TERM("6"),
        TERM("7"),
        TERM("8"),
        TERM("9"))
end)


local bytes = itertools.tolist("1-(1-9*(7-3))*(4-7)*7")
local environment = reader.environ(bytes)


return read_expression(environment, bytes)

