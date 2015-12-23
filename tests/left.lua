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

one = NonTerminal("one")
number = NonTerminal("number")

read_one = factor_nonterminal(one,
    function() return
        ANY(
            ALL(read_number, TERM("1")),
            TERM("1"))
    end)

read_two = factor_nonterminal(one,
    function() return
        ANY(
            ALL(read_number, TERM("2")),
            TERM("2"))
    end)


read_number = factor_nonterminal(number,
    function(LEFT) return
        ANY(
            LEFT(read_one),
            LEFT(read_two),
            ALL(
                TERM("("),
                read_number,
                TERM(")"),
                LABEL(read_number, REPEAT)))
    end)

local bytes = itertools.tolist("((1)2)112(2)112211")
local environment = reader.environ(bytes)

return read_number(environment, bytes)
