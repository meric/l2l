local itertools = require("l2l.itertools")
local reader = require("l2l.reader2")
local exception = require("l2l.exception2")

local car = itertools.car
local cdr = itertools.cdr
local cons = itertools.cons
local id = itertools.id
local list = itertools.list
local show = itertools.show
local slice = itertools.slice
local concat = itertools.concat
local tolist = itertools.tolist
local tovector = itertools.tovector

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
    "An exception occurred while generating `%s`:\n  %s")

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
      local repr = type(value) == "string" and value or value:representation()
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
  end})

Terminal.__index = Terminal

local mark, span, any, associate

local function ismark(obj, flag)
  return getmetatable(obj) and (not flag or obj[flag])
end

local function isgrammar(obj, kind)
  local mt = getmetatable(obj)
  if kind then
    return mt == kind
  end
  return mt == mark or mt == span or mt == any or mt == associate
end

local function factor_terminal(terminal)
  local value = tostring(terminal)
  local count = #value
  local cache = {}
  return associate(terminal, function(_, bytes)
    local first, rest = itertools.span(count, bytes)
    if concat("", first) == value then
      cache[bytes] = {
        values=list(terminal),
        rest=rest
      }
      return list(terminal), rest
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
  __call = function(self, environment, bytes, stack)
    return self[1](environment, bytes, stack)
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
    if getmetatable(nonterminal) ~= NonTerminal then
      nonterminal = NonTerminal(
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
    assert(bytes[1], self)
    -- find the one that consumes most tokens
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
  __call = function(self, environment, bytes, stack)
    local rest, all, ok, values = bytes, {}
    for _, read in ipairs(self) do
      if read ~= nil then
        while true do
          assert(read)
          local prev = rest
          local prev_meta = environment._META[rest]
          if ismark(read, option) or ismark(read, repeating) then
            ok, values, rest = pcall(execute, read, environment, rest,
              stack)
            if not ok then
              rest = prev -- restore to previous point.
              if getmetatable(values) == ExpectedNonTerminalException then
                break
              else
                raise(values)
              end
            end
          else
            values, rest = execute(read, environment, rest, stack)
          end
          if not values then
            if ismark(read, repeating) then
              break
            elseif not ismark(read, option) then
              return nil, bytes
            end
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

          if not ismark(read, repeating) then
            break
          end
        end
      end
    end
    return tolist(all), rest
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
    return setmetatable(tovector(itertools.map(
      function(value)
        if type(value) == "string" then
          return factor_terminal(Terminal(value))
        end
        return value
      end,
      itertools.filter(id, list(...)))), span)
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

--- Given a rule, keep expanding each span's first nonterminal until it is
-- that span's first nonterminal is `nonterminal`.
-- @param rule The rule to expand.
-- @param nonterminal The nonterminal to stop expanding at.
local function factor_expand_left_nonterminal(rule, nonterminal)
  local continue = true
  rule = factor_spans(rule)
  while continue do
    continue = false
    rule = factor_spans(any(itertools.unpack(itertools.map(
      function(child)
        if not isgrammar(child, span) then
          return child
        end
        if #child > 0 and child[1].nonterminal ~= nonterminal
            and child[1].factory then
            continue = true
          local nonterminalspan = false
          local expanded = span(child[1].factory(function(grandchild)
              if isgrammar(grandchild, span)
                  and grandchild[1]
                  and grandchild[1].nonterminal == nonterminal then

                  nonterminalspan = span(unpack(grandchild))
                  for i=2, #child do
                    table.insert(nonterminalspan, child[i])
                  end
                return
              end
            end),
            itertools.unpack(slice(2, 0, child)))
          if not nonterminalspan then
            return expanded
          end
          return nonterminalspan
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
        child.factory and child.factory(function() end) or child,
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

--- Factor `rule` by removing spans involving left recursion of `nonterminal`.
-- A span is any part of the rule that is an span or have no span ancestor,
-- that is not an any.
-- @param rule The rule to remove  `nonterminal` from.
-- @param nonterminal The nonterminal to remove.
local function factor_without_left_nonterminal(rule, nonterminal)
  return any(itertools.unpack(itertools.filter(function(child)
    if ismark(child, skip) then
      return false
    end
    if child.nonterminal == nonterminal then
      return false
    end
    if not isgrammar(child, span) then
      return true
    end
    if child[1].nonterminal == nonterminal
        or child.nonterminal == nonterminal then
      return false
    end
    return true
  end, factor_spans(rule))))
end

--- Factor `rule` into suffixes of spans involving left recursion of
-- `nonterminal`.
-- A span is any part of the rule that is an span or have no span ancestor,
-- that is not an any.
-- @param nonterminal The nonterminal to remove.
local function factor_left_suffix(rule, nonterminal)
  local contents = tovector(itertools.map(
    function(child)
      return span(unpack(tovector(slice(2, 0, child))))
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

factor = function(nonterminal, factory)
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
  local paths = setmetatable({}, {__mode='k'})
  local cache = setmetatable({}, {__mode='k'})
  local spans

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
        function(read)
          local rule = factor_expand_left_nonterminal(
            read.factory and read.factory(id) or read,
            nonterminal)
          table.insert(left, {
            index = #left + 1,
            rule = rule,
            nonterminal = read.factory and read.nonterminal or nil,

            -- See `factor_left_suffix`.
            suffixes = factor_left_suffix(rule, nonterminal),

            -- Paths for this child rule that doesn't left-recurse back to 
            -- `nonterminal`.
            spans = factor_without_left_nonterminal(rule, nonterminal)
          })
          return read
        end)
      -- If we could grab a rule, it means it has been annotated.
      is_annotated = #left > 0
      if is_annotated then
        -- `read_take_terminals` is a function for left recursion.
        read_take_terminals = factor_prefix_left_nonterminal(
          factory, nonterminal)

        -- Non-left recursion paths for this nonterminal.
        spans = factor_without_left_nonterminal(
          factor_expand_left_nonterminal(factory(function() end),
            nonterminal))
        -- We have all the Left recursions in `left`, and prefixes in
        -- `read_take_terminals`. We need to refactor the Left's into a flat
        -- shape and project it onto `bytes`. Then figure out which step which
        -- left is called on each iteration. This is done next, and saved in 
        -- paths[bytes].
      else
        spans = factor_without_left_nonterminal(factory(function() end))
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
        -- check if left does not precede nonterminal in stack
        local from = itertools.search(function(caller)
            return itertools.search(function(info) return
                info.nonterminal == caller end, left)
          end, cdr(stack))
        if from then
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
        local independent = itertools.search(
            function(info)
              return #info.spans > 0 and info.spans(environment, bytes)
            end, left)
        if independent then
          paths[bytes] = list.push(paths[bytes], independent.index)
        elseif #spans > 0 and spans(environment, bytes) then
          paths[bytes] = list.push(paths[bytes], nil)
        end
        local prefix, rest = read_take_terminals(environment, bytes)
        -- If no prefix match, and no independent match, it means this doesn't
        -- match.
        if not prefix and not independent then
          memoize[nonterminal] = {
            values=nil,
            rest=bytes,
            stack=stack
          }
          return nil, bytes
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
        local matching, values = prefix
        while matching and rest do
          matching = nil
          for _, info in ipairs(left) do
            ok, values, rest = pcall(info.suffixes, environment, rest)
            if ok and values ~= nil and rest ~= bytes then
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
      local index, path = 0
      local ordering = paths[bytes]
      path, paths[bytes] = unpack(ordering or {})
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
    end
    local values, rest
    ok, values, rest = pcall(execute, origin, environment, bytes, stack)
    if not ok then
      local err = values
      if getmetatable(values) == ExpectedNonTerminalException then
        raise(err)
      elseif getmetatable(values) == ParseException then
        raise(err)
      else
        raise(ParseException(environment, bytes, nonterminal, err))
      end
    end
    if #({list.unpack(values)}) == 0 then
      -- Memoize
      memoize[nonterminal] = {
        exception = ExpectedNonTerminalException(environment, bytes, origin,
          show(list.concat(bytes))),
        stack=stack
      }
      raise(memoize[nonterminal].exception)
    end
    -- Memoize
    memoize[nonterminal] = {
      values=list(nonterminal(list.unpack(values))),
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