local itertools = require("l2l.itertools")
local reader = require("l2l.reader2")
local exception = require("l2l.exception2")

local car = itertools.car
local cdr = itertools.cdr
local cons = itertools.cons
local id = itertools.id
local list = itertools.list
local tolist = itertools.tolist
-- local show = itertools.show
local slice = itertools.slice
local concat = itertools.concat
local tovector = itertools.tovector
local tolist = itertools.tolist
local empty = itertools.empty

local raise = exception.raise
local execute = reader.execute

local ExpectedNonTerminalException =
  exception.Exception("ExpectedNonTerminalException",
    "Expected %s, at %s")
local ParseException =
  exception.Exception("ParseException",
    "An exception occurred while parsing `%s`:\n  %s")
local GrammarException =
  exception.Exception("GrammarException",
    "An exception occurred while generating grammar for `%s`:\n  %s")

local NonTerminal

NonTerminal = setmetatable({
  __call = function(self, ...)
    return setmetatable({name=self.name, ...}, self)
  end,
  __tostring = function(self)
    return self.name
  end,
  representation = function(self)
    local origin = list(self.name)
    local last = origin
    for _, value in ipairs(self) do
      local repr = (type(value) ~= "table" or not value.representation)
        and tostring(value) or value:representation()
      last[2] = cons(repr)
      last = last[2]
    end
    return origin
  end
}, {
__call = function(_, name)
  local self = setmetatable({
    name = name,
    __tostring = function(self)
      local repr = {}
      for _, value in ipairs(self) do
          table.insert(repr, tostring(value))
      end
      table.insert(repr, "")
      return table.concat(repr, "")
    end,
    __eq = function(self, other)
      return getmetatable(self) == getmetatable(other) and
        tostring(self) == tostring(other)
    end,
    representation = NonTerminal.representation
  }, NonTerminal)
  self.__index = self
  return self
end,
__tostring = function()
  return "NonTerminal"
end})

-- Consists of one or more of the same type
local Terminal = setmetatable({
  representation = function(self)
    return self
  end,
  __tostring = function(self)
    return tostring(self[1])
  end,
  __eq = function(self, other)
    return getmetatable(self) == getmetatable(other) and
      tostring(self) == tostring(other)
  end
}, {__call = function(Terminal, value)
    return setmetatable({
      value,
      is_terminal=true}, Terminal)
  end, __tostring = function() return
    "Terminal"
  end})

Terminal.__index = Terminal

local mark, span, any, associate

local function ismark(obj, flag)
  return getmetatable(obj) == mark and (not flag or obj[flag])
end

local function isgrammar(obj, kind)
  local mt = getmetatable(obj)
  if kind then
    return mt == kind
  end
  return mt == mark or mt == span or mt == any or mt == associate
end

local getbyte = string.byte

local function factor_terminal(terminal)
  local value = tostring(terminal)
  local count = #value
  local cache = {}
  return associate(terminal, function(_, bytes)
    -- Reduce calls to `span` and `concat` by checking next byte.
    if bytes and getbyte(bytes[1]) ~= getbyte(value) then
      return nil, bytes
    end
    local first, rest = itertools.span(count, bytes)
    if concat("", first) == value then
      cache[bytes] = {
        values=list(terminal),
        rest=rest
      }
      return list(value), rest
    end
    if bytes then
      cache[bytes] = {
        values=nil,
        rest=bytes
      }
    end
    return nil, bytes
  end)
end

-- These are attributes that can be marked onto an expression grammar.
local skip = "skip"
local peek = "peek"
local option = "option"
local repeating = "repeating"

mark = setmetatable({
  representation = function(self)
    return tostring(self)
  end,
  __mod = function(self, apply)
    self.apply = apply
    return self
  end,
  __call = function(self, environment, bytes, stack)
    -- assert(self[1])
    local read, all, rest = self[1], {}, bytes
    local ok, values, prev
    while true do
      prev = rest
      ok, values, rest = pcall(read, environment, rest, stack)      
      if not ok then
        rest = prev -- restore to previous point.
        if (ismark(self, repeating) or ismark(self, option))
            and getmetatable(values) == ExpectedNonTerminalException then
          break
        else
          raise(values)
        end
      end
      for _, value in ipairs(values or {}) do
        table.insert(all, value)
      end
      if not values then
        if not ismark(self, repeating) then
          if not ismark(self, option) then
            return nil, bytes
          end
        end
        break
      end
      if not ismark(self, repeating) then
        break
      end
    end
    if self.apply then
      values = list(self.apply(unpack(all)))
    else
      values = tolist(all)
    end
    return values, rest
  end,
  __tostring = function(self)
    local text = tostring(car(self))
    if self[option] then
      text = "["..text.."]"
    end
    if self[repeating] then
      text = "{"..text.."}"
    end
    if self[skip] then
      text = "~"
    end
    return text
  end
}, {
  __call = function(_, read, ...)
    if type(read) == "string" then
      read = factor_terminal(Terminal(read))
    end
    local self = setmetatable({read}, mark)
    assert(read, "missing `read` argument.")
    for _, value in ipairs({...}) do
      self[value] = true
    end
    return self
  end,
  __tostring = function()
    return "mark"
  end
})

mark.__index = mark

-- associate a read function with a nonterminal.
associate = setmetatable({
  __call = function(self, environment, bytes, stack)
    return self[1](environment, bytes, list.push(stack, self.nonterminal))
  end,
  __tostring = function(self)
    return tostring(self.nonterminal)
  end
}, {
  __call = function(_, nonterminal, read, factory)
    if getmetatable(nonterminal) ~= NonTerminal
      and getmetatable(nonterminal) ~= Terminal then
      nonterminal = Terminal(
        tostring(nonterminal ~= nil and nonterminal or factory))
    end
    local self = setmetatable({read,
      nonterminal=nonterminal,
      factory=factory}, associate)
    return self
  end,  
  __tostring = function()
    return "associate"
  end
})
associate.__index = associate

any = setmetatable({
  __call = function(self, environment, bytes, stack)
    -- assert(bytes[1], self)
    for _, read in ipairs(self) do
      if read ~= nil then
        local ok, values, rest = pcall(execute, read, environment, bytes,
          stack)
        if ok and values and rest ~= bytes then
          return values, rest
        end
        if not ok and getmetatable(values) ~= ExpectedNonTerminalException then
          raise(values)
        end
      end
    end
    return nil, bytes
  end,
  __tostring = function(self)
    local repr = {"any("}
    for i, value in ipairs(self) do
        table.insert(repr, itertools.show(value))
        if i ~= #self then
          table.insert(repr, ",")
        end
    end
    table.insert(repr, ")")
    return table.concat(repr, "")
  end
}, {
  __call = function(_, ...)
    return setmetatable(tovector(itertools.map(
      function(value)
        if type(value) == "string" then
          return factor_terminal(Terminal(value))
        end
        return value
      end,
      itertools.filter(id, {...}))), any)
  end,
  __tostring = function()
    return "any"
  end
})

span = setmetatable({
  __mod = function(self, apply)
    self.apply = apply
    return self
  end,
  __call = function(self, environment, bytes, stack)
    local rest, all, values = bytes, {}
    for _, read in ipairs(self) do
      if read ~= nil then
        local prev = rest 
        local prev_meta = environment._META[rest]
        values, rest = execute(read, environment, rest, stack)
        if not values 
            and not ismark(read, option)
            and not ismark(read, repeating)
            and rest == bytes then
          return nil, bytes
        end
        if ismark(read, peek) then
          -- Restore any metadata at this point
          -- We don't want a peek operation to affect state.
          -- We didn't consume any input, it should not be recorded as we
          -- have.
          environment._META[prev] = prev_meta
          rest = prev
        elseif not ismark(read, skip) then
          stack = list()
          for _, value in ipairs(values or {}) do
            table.insert(all, value)
          end
        end
      end
    end
    if self.apply then
      values = list(self.apply(unpack(all)))
    else
      values = tolist(all)
    end
    return values, rest
  end,
  __tostring = function(self)
    local repr = {"span("}
    for i, value in ipairs(self) do
        table.insert(repr, itertools.show(value))
        if i ~= #self then
          table.insert(repr, ",")
        end
    end
    table.insert(repr, ")")
    return table.concat(repr, "")
  end
}, {
  __call = function(_, ...)
    local self = setmetatable(tovector(itertools.map(
      function(value)
        if type(value) == "string" then
          return factor_terminal(Terminal(value))
        end
        return value
      end,
      itertools.filter(id, list(...)))), span)

    return self
  end,
  __tostring = function()
    return "span"
  end
})

--- Returns a list of values from `parent` that when called on `f` returns
-- true.
-- @param f the function that returns true to return that argument. It will
--        also be given the parent.
-- @param parent the tree to go through.
local function filter(f, parent, ...)
  -- assert(isgrammar(parent), parent)
  local origin = list(nil)
  local last = origin
  for _, child in ipairs(parent) do
    if type(child) == "table" then
      if f(child, parent, ...) then
        last[2] = cons(child)
        last = last[2]
      end
      if isgrammar(child) and not ismark(child, skip) then
        last[2] = filter(f, child, parent, ...)
        if last[2] then
          last = last[2]
        end
      end
    end
  end
  return origin[2]
end

local factor

--- Return a list of all spans inside a rule wrapped in an any.
-- A span is any part of the rule that is an all or have no all ancestor.
-- that can satisfy a rule.
-- @param rule The rule to search for span's.
local function factor_spans(rule)
  while isgrammar(rule, any) and #rule == 1 do
    rule = rule[1]
  end
  if isgrammar(rule, span) or not isgrammar(rule, any) then
    return any(rule)
  end
  return any(itertools.unpack(
    filter(function(_, parent, ...) return
      not itertools.search(
        function(ancestor) return
          isgrammar(ancestor, span)
        end, {parent, ...})
      end, rule)))
end

-- Return an expanded version of `child` if `child[index]` is `nonterminal`,
-- where the corresponding `child[index]` in the expanded version is 
-- the rule of `nonterminal` instead of `nonterminal` itself.
-- Return nil otherwise.
local function expand_nonterminal_at_index(child, nonterminal, index)
  if #child > 0 and isgrammar(child[index])
      and child[index].nonterminal ~= nonterminal
      and child[index].factory then
      continue = true
    local nonterminalspan = false
    local expanded = span(child[index].factory(
      function(grandchild)
        if isgrammar(grandchild, span)
            and grandchild[index]
            and grandchild[index].nonterminal == nonterminal then

            nonterminalspan = span(unpack(grandchild))
            for i=1, #child do
              if i ~= index then
                table.insert(nonterminalspan, child[i])
              end
            end
          return
        end
      end),
      itertools.unpack(itertools.filter(
        function(_, i) return i~= index end, child)))
    if not nonterminalspan then
      return expanded
    end
    return nonterminalspan
  end
end

-- Replace all instances of `nonterminal` in `rule`, using `f`.
local function factor_replace_nonterminal(rule, nonterminal, f)
  local continue = true
  rule = factor_spans(rule)
  while continue do
    continue = false
    rule = factor_spans(any(itertools.unpack(itertools.map(
      function(child)
        if isgrammar(child) and child.factory then
          return factor_replace_nonterminal(
            child.factory(id), nonterminal, f)
        end
        if not isgrammar(child, span) then
          return child
        end
        if f(child) then
          return f(child)
        end
        return child
      end, rule))))
  end
  -- Refactor away span(any(span(any(....)))) wrapping.
  while (isgrammar(rule, any) or isgrammar(rule, span)) and #rule == 1 do
    rule = rule[1]
  end
  return rule
end

--- Given a rule, keep expanding each span's first nonterminal until it is
-- that span's first nonterminal is `nonterminal`.
-- @param rule The rule to expand.
-- @param nonterminal The nonterminal to stop expanding at.
local function factor_expand_left_nonterminal(rule, nonterminal)
  return factor_replace_nonterminal(rule, nonterminalspan, function(child)
    return expand_nonterminal_at_index(child, nonterminal, 1)
  end)
end

--- Given a rule, keep expanding each span's last nonterminal until it is
-- that span's last nonterminal is `nonterminal`.
-- @param rule The rule to expand.
-- @param nonterminal The nonterminal to stop expanding at.
local function factor_expand_right_nonterminal(rule, nonterminal)
  return factor_replace_nonterminal(rule, nonterminalspan, function(child)
    return expand_nonterminal_at_index(child, nonterminal, #child)
  end)
end

--- Given a rule, return a set of rules that return the possible
-- terminals that could occur before it recurses into `nonterminal`.
-- @param factory The factory to generate the rule to extract the possible 
--                prefix terminals rule from.
-- @param nonterminal The nonterminal to find prefix of.
local function factor_prefix_left_nonterminal(factory, nonterminal)
  local rules = {}
  table.insert(rules, factory(function(child)
    table.insert(rules,
      factor_expand_left_nonterminal(
        child.factory and child.factory(empty) or child,
        nonterminal))
  end))
  local patterns = any()
  for _, rule in ipairs(rules) do
    if not isgrammar(rule, any) then
      rule = any(rule)
    end
    for _, section in ipairs(rule) do

      local pattern = span(itertools.unpack(itertools.filter(function(child)
          if isgrammar(child, span) and child[1].nonterminal == nonterminal then
            return false
          end
          return true
        end, factor_spans(section))))

      if #pattern > 0 then
        while (isgrammar(pattern, any)
            or isgrammar(pattern, span))
            and #pattern == 1 do
          pattern = pattern[1]
        end
        table.insert(patterns, pattern)
      end
    end
  end
  return patterns
end

-- Return a rule where `nonterminal` is removed from `rule` whenever it is a 
-- node or f(node) within `rule` that forms an entire span.
-- See `factor_without_left_nonterminal`, `factor_without_right_nonterminal`.
local function factor_without_nonterminal_at(rule, nonterminal, f)
  return any(itertools.unpack(itertools.filter(function(child)
    if ismark(child, skip) then
      return false
    end
    if nonterminal and child.nonterminal == nonterminal then
      return false
    end
    if not isgrammar(child, span) then
      return true
    end
    local grandchild = f(child)
    if nonterminal and isgrammar(grandchild) and
      (grandchild.nonterminal == nonterminal
        or child.nonterminal == nonterminal) then
      return false
    end
    return true
  end, factor_spans(rule))))
end

--- Factor `rule` by removing spans involving left recursion of `nonterminal`.
-- A span is any part of the rule that is an span or have no span ancestor,
-- that is not an any.
-- @param rule The rule to remove  `nonterminal` from.
-- @param nonterminal The nonterminal to remove.
local function factor_without_left_nonterminal(rule, nonterminal)
  return factor_without_nonterminal_at(rule, nonterminal, function(child)
      return child[1]
    end)
end

--- Factor `rule` by removing spans involving right recursion of `nonterminal`.
-- A span is any part of the rule that is an span or have no span ancestor,
-- that is not an any.
-- @param rule The rule to remove  `nonterminal` from.
-- @param nonterminal The nonterminal to remove.
local function factor_without_right_nonterminal(rule, nonterminal)
  return factor_without_nonterminal_at(rule, nonterminal, function(child)
      return child[#child]
    end)
end

local function is_left_and_right_recursive(rule, nonterminal)
  return isgrammar(rule[1]) and rule[1].nonterminal == nonterminal and
         isgrammar(rule[#rule]) and rule[#rule].nonterminal == nonterminal
end

--- Factor `rule` into suffixes of spans involving left recursion of
-- `nonterminal`.
-- A span is any part of the rule that is an span or have no span ancestor,
-- that is not an any.
-- @param nonterminal The nonterminal to remove.
local function factor_left_suffix(rule, nonterminal, factory)
  local contents = tovector(itertools.map(
    function(child)
      -- Remove right recursion to keep left associativity.
      local suffix = span(unpack(tovector(slice(2, 0, child))))
      if isgrammar(suffix) and suffix.factory == factory then
        suffix = factor_without_right_nonterminal(
          factor_expand_right_nonterminal(
            factory(id), nonterminal), nonterminal)
      end
      return suffix
    end, itertools.filter(function(child)
        if ismark(child, skip) then
          return false
        end
        if not isgrammar(child, span) then
          return false
        end
        if child[1].nonterminal == nonterminal
            or child.nonterminal == nonterminal then
          return true
        end
        return false
      end, factor_spans(rule))))
  if #contents == 1 then
    return contents[1]
  end
  return any(unpack(contents))
end

-- Returns a function that takes `environment, bytes` and returns a parser
-- for the given infix recursion grammar rule. The parser is implemented using
-- the "Top-Down Operator Precedence" parsing algorithm by Vaughan Pratt.
-- See the following URL for an explanation of how the algorithm works:
-- http://eli.thegreenplace.net/2010/01/02/top-down-operator-precedence-parsing
-- @param read The infix recursion grammar rule.
-- @param infix The index of the term in `read` where operator precedence 
--              applies. It must be an `any(..)` or a nonterminal `associate`
--              wrapping an `any`.
-- @param factory The factory for the nonterminal containing the `read` rule.
local function precedent(read, infix, factory)
  local separator = span(itertools.unpack(slice(2, -1, read)))
  local prefix = span(itertools.unpack(slice(2, infix-1, read)))
  local suffix = span(itertools.unpack(slice(infix+1, -1, read)))
  local infixop = read[infix]
  local origin = factory(empty)
  local lbp = {}

  -- Expand `read[infix]` into an `any(terminal...)`, and record precedence
  -- according to the index of each `terminal`, from low to high priority:

  -- 1. Expand `read[infix]`
  local operator = read[infix]
  if isgrammar(operator) and operator.factory then
    operator = factor_expand_left_nonterminal(operator, operator.nonterminal)
  end
  -- 2. Record precedence.
  for i, value in ipairs(operator) do
    assert(getmetatable(value.nonterminal) == Terminal)
    lbp[tostring(value)] = i
  end

  -- This function returns a parser.
  return function(environment, bytes)
    local rest = bytes
    local previous, tokens, token, ok, _
    local function expression(rbp)
      if not rest then
        return nil
      end

      previous = token

      -- For example:
      -- In the following infix recurring rule:
      -- `span(exp, __, binop, __, exp)`
      --            ^          ^
      --        `prefix`    `suffix`
      -- `prefix` and `suffix` are the terms between the recurring nonterminal
      -- on each side and the infix operator in between.
      _, rest = prefix(environment, rest)

      -- Use `infixop` instead of `operator` to do the actual parsing, to use
      -- any apply method attached to `infixop`, which it may have if it is an
      -- `associate`.
      ok, tokens, rest = pcall(infixop, environment, rest)
      if not ok or not tokens or not rest then
        return origin
      end
      token = car(tokens)
      _, rest = suffix(environment, rest)
      if not rest then
        return nil
      end
      local left = span(origin)
      while rest and rbp < lbp[tostring(token)] do
        previous = token
        tokens, rest = origin(environment, rest)
        if not tokens then
          return nil
        end
        token = car(tokens)

        if #left == #read then
          left = span(left) % read.apply
        end
        table.insert(left, prefix)
        table.insert(left, span(mark(tostring(previous), peek), infixop))
        table.insert(left, suffix)
        left = left % read.apply
        table.insert(left, span(expression(lbp[tostring(previous)])))
      end
      return left
    end
    tokens, rest = origin(environment, rest)
    if not tokens then
      return nil
    end
    token = car(tokens)
    return expression(0)
  end
end

factor = function(nonterminal, factory, instantiate)
  assert(factory, "missing `factory` argument")

  local ok, origin = pcall(factory, id)

  if getmetatable(nonterminal) ~= NonTerminal then
    nonterminal = NonTerminal(
      tostring(nonterminal ~= nil and nonterminal or factory))
  end

  if ok and not isgrammar(origin) then
    return associate(nonterminal, origin)
  else
    origin = nil
  end

  local left, is_annotated, read_take_terminals = {}
  local prunes = setmetatable({}, {__mode='v'})
  local paths = setmetatable({}, {__mode='k'})
  local cache = setmetatable({}, {__mode='k'})
  local computed = setmetatable({}, {__mode='k'})
  -- local spans

  return associate(nonterminal, function(environment, bytes, stack)
    if not bytes then
      return nil, nil
    end
    cache[bytes] = cache[bytes] or {}
    local memoize = cache[bytes]
    local history = environment._META[bytes]
    -- If memoized, then perform result from cache.
    if memoize[nonterminal] then
      if memoize[nonterminal].stack == stack then
        if memoize[nonterminal].exception then
          raise(memoize[nonterminal].exception)
        end
        if memoize[nonterminal].values or memoize[nonterminal].rest then
          return memoize[nonterminal].values,
            memoize[nonterminal].rest
        end
      end
    end
    if not origin then
      -- Generate the rule, also grab any annotated left recursions 
      -- if available.
      origin = factory(
        function(read, infix)
          if infix then
            if not isgrammar(read, span) then
              raise(GrammarException(environment, bytes, nonterminal,
                "Only `span`s can have an infix operator with precedence."))
            end
            if read[1].nonterminal ~= nonterminal
              or read[#read].nonterminal ~= nonterminal then
              raise(GrammarException(environment, bytes, nonterminal,
                "The `infix` argument for the `left` function supports "..
                "only direct, one level, infix recursion.\n  The first and "..
                "terms must be the nonterminal itself.\n  In `"..
                tostring(read).."`, `"..tostring(read[1]).."` is expected to"..
                " be `"..tostring(nonterminal).."`"))
            end
            local operator = read[infix]
            if isgrammar(operator) and operator.factory then
              operator = factor_expand_left_nonterminal(
                operator, operator.nonterminal)
            end
            if not isgrammar(operator, any) then
              raise(GrammarException(environment, bytes, nonterminal,
                "The infix operator with precedence must be an `any` and is "..
                "an `nonterminal` that is defined as an `any`"))
            elseif not is_left_and_right_recursive(read, nonterminal) then
              raise(GrammarException(environment, bytes, nonterminal,
                "Only `span`s that are both left and right recursive can "..
                "have infix operator with precedence"))
            end
            infix = precedent(read, infix, factory)
          end
          local rule = factor_expand_left_nonterminal(
            read.factory and read.factory(id) or read,
            nonterminal)
          table.insert(left, {
            index = #left + 1,
            rule = rule,
            nonterminal = read.factory and read.nonterminal or nil,

            -- See `factor_left_suffix`.
            suffixes = factor_left_suffix(rule, nonterminal, factory),

            -- Paths for this child rule that doesn't left-recurse back to 
            -- `nonterminal`.
            spans = factor_without_left_nonterminal(rule, nonterminal),
            infix = infix
          })
          -- print(left[#left].infix, rule)
          return read
        end)
      -- If we could grab a rule, it means it has been annotated.
      is_annotated = #left > 0
      if is_annotated then
        -- `read_take_terminals` is a function for left recursion.
        read_take_terminals = factor_prefix_left_nonterminal(
          factory, nonterminal)

        -- Non-left recursion paths for this nonterminal.
        -- spans = factor_without_left_nonterminal(
        --   factor_expand_left_nonterminal(factory(function() end),
        --     nonterminal))

        -- We have all the Left recursions in `left`, and prefixes in
        -- `read_take_terminals`. We refactored the Left's into a flat
        -- shape, using `factor_left_suffix`. Now figure out which step which
        -- left is called on each iteration by projecting the flat grammar onto
        -- `bytes. This is done next, and saved in paths[bytes].
      -- else
        -- spans = factor_without_left_nonterminal(factory(function() end))
      end
    end

    if is_annotated then
      if history and history.values and paths[bytes]
        and not cdr(paths[bytes]) then
        -- We have executed all we want to execute and at a point where we
        -- already have a value collected, but left recursion has taken us
        -- back here. Return the collected value.
        if car(paths[bytes]) then
          return history.values, history.rest
        end
      end

      -- Check `list.count(stack, nonterminal) == 1` because we only want to
      -- calculate the recursion path once, on first recursion at each byte. 
      if list.count(stack, nonterminal) == 1 then
        -- This operation is slow. Try figure a way to optimise it.
        local prefix, rest = read_take_terminals(environment, bytes)

        -- check if left does not precede nonterminal in stack
        local from = itertools.search(function(caller)
            return itertools.search(function(info) return
                info.nonterminal == caller end, left)
          end, cdr(stack))

        if from and not computed[rest] then
          -- Called from `from`. E.g.
          -- With the following Grammar:
          --   functioncall = span(prefixexp args)
          --   prefixexp = left(functioncall) | name
          --
          -- The following call is made:
          --   functioncall(environment, bytes)
          --
          -- At this line in the code with the above scenario,
          --   `stack` is (prefixexp functioncall)
          --   `nonterminal` is `prefixexp`.
          --   `from` is `read_functioncall`, is the parent call that's
          --          executed the current `read_prefixexp`.
          -- 
          -- When deriving `prefixexp` we want to drop the last call to
          -- `functioncall`, and leave stuff for the parent `functioncall`
          -- call to parse.
          --
          -- Otherise `args` in `read_functioncall` will be missing.
          --
          -- Also see the following block later on:
          -- ```
          -- if from then
          --   paths[bytes] = cdr(paths[bytes])
          -- end
          -- ```
          -- It does the actual dropping.
          --
          -- Here we replace the `functioncall` at the end with a `prefixexp`
          -- at the beginning of the path, to provide the first `prefixexp`
          -- term in `functioncall` to `functioncall`.
          paths[bytes] = list.push(paths[bytes], nil)
        end

        -- Left recursing paths that can have no suffix, can be "independent".
        -- E.g. a = any("a", all("(", exp, ")")
        --      t = any(exp, a)
        --    Assume `exp` left recurses back to `t`.
        -- The `a` non-left-recursion choice makes `t` "independent".
        if prefix then
          local independent = itertools.search(
              function(info)
                return #info.spans > 0 and info.spans(environment, bytes)
              end, left)
          if independent then
            paths[bytes] = list.push(paths[bytes], independent.index)
          elseif not computed[rest] then -- elseif #spans > 0 and spans(environment, bytes) then
            -- Somehow the above spans check isn't needed.
            -- Consider restoring if there are problems.
            paths[bytes] = list.push(paths[bytes], nil)
          end
        end
        -- If no prefix match, and no independent match, it means this doesn't
        -- match.
        if not prefix --[[and not independent]] then
          memoize[nonterminal] = {
            values=nil,
            rest=bytes,
            stack=stack
          }
          return nil, bytes
        end

        if prefix then
          -- Check if infix operator precedent recursion grammar applies. If so
          -- use the TDOP parser and return the results instead.
          for _, info in ipairs(left) do
            if info.infix then
              local infix = info.infix(environment, bytes)
              if infix then
                local values, rest = infix(environment, bytes)
                if values or rest ~= bytes then
                  return values, rest
                end
              end
            end
          end
        end

        -- Try each suffix, while we can find a matching iteration, keep going
        -- and build a path for the recursion later. We don't return results
        -- of what we have here because we're factoring the grammar into a
        -- different shape, it would return a different tree to what the
        -- caller expected.
        --
        -- `info.suffixes` is similar to ANTLRworks technique of refactoring a
        -- left recursive grammar into a non-recursive one, but we only use the
        -- result of the refactored grammar to trace a path for our original
        -- grammar, and our technique works with mutual recursion too.
        --
        -- See https://theantlrguy.atlassian.net/wiki/display/ANTLR3/Left-Recursion+Removal
        -- 
        if not computed[rest] or paths[bytes] then
          -- `not computed[rest]` => if the path was computed in a previous
          -- byte, then don't do it again.
          local matching, values = prefix
          while matching and rest do
            matching = nil
            for _, info in ipairs(left) do
              local from = rest
              ok, values, rest = pcall(info.suffixes, environment, rest)
              if ok and values ~= nil and rest ~= bytes then
                computed[from] = true
                matching = true
                paths[bytes] = list.push(paths[bytes], info.index)
                break
              end
            end
          end
          if from then
            paths[bytes] = cdr(paths[bytes])
          end
        end
      end
      local index, path = 0
      local ordering = paths[bytes]
      path, paths[bytes] = unpack(ordering or {})

      -- Cache in `prune`, rather than calling factory again for same index.
      local prune = tostring(path)
      if prunes[prune] then
        origin = prunes[prune]
      else
        ok, origin = pcall(factory, function(read)
          -- Whether to show `read` on this iteration.
          index = index + 1
          if index == path then
            return read
          end
        end)
        if not ok then
          local err = origin
          raise(GrammarException(environment, bytes, nonterminal, err))
        end
        prunes[prune] = origin
      end
    end
    local values, rest
    local original = origin
    ok, values, rest = pcall(execute, origin, environment, bytes, stack)

    if not ok then
      local err = values
      if getmetatable(values) == ExpectedNonTerminalException then
        raise(err)
      elseif getmetatable(values) == ParseException then
        raise(err)
      else
        if type(values) == "table" and values.bytes then
          bytes = cdr(values.bytes)
        end
        raise(ParseException(environment, bytes, nonterminal, err))
      end
    end

    values = {list.unpack(values)}

    if #values == 0 then
      -- Memoize
      memoize[nonterminal] = {
        exception = ExpectedNonTerminalException(environment, bytes, origin,
          bytes),
        stack=stack
      }
      raise(memoize[nonterminal].exception)
    end

    if instantiate then
      values = list(instantiate(nonterminal, unpack(values)))
    else
      values = list(nonterminal(unpack(values)))
    end

    -- Memoize
    memoize[nonterminal] = {
      values=values,
      rest=rest,
      stack=stack
    }
    return memoize[nonterminal].values, rest
  end, factory)
end

return {
  skip=skip,
  option=option,
  repeating=repeating,
  span=span,
  any=any,
  associate=associate,
  mark=mark,
  Terminal=Terminal,
  NonTerminal=NonTerminal,
  ismark=ismark,
  isgrammar=isgrammar,
  factor=factor,
  factor_terminal=factor_terminal,
  filter=filter,
  ExpectedNonTerminalException=ExpectedNonTerminalException,
  ParseException=ParseException,
  GrammarException=GrammarException
}