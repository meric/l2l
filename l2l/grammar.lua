local itertools = require("l2l.itertools")
local reader = require("l2l.reader3")
local exception = require("l2l.exception2")

local car = itertools.car
local cdr = itertools.cdr
local cons = itertools.cons
local contains = itertools.contains
local drop = itertools.drop
local id = itertools.id
local list = itertools.list
local show = itertools.show
local slice = itertools.slice
local take = itertools.take
local tolist = itertools.tolist
local vector = itertools.vector
local take_while = itertools.take_while

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


local function NonTerminal(name)
  -- Consists of one or more of the same type
  local non_terminal = setmetatable({
    representation = function(self)
      local origin = list(name)
      local last = origin
      for i, value in ipairs(self) do
        local repr = type(value) == "string" and value or value:representation()
        last[2] = cons(repr)
        last = last[2]
      end
      return origin
    end,
    __tostring = function(self)
      local repr = {}
      for i, value in ipairs(self) do
          table.insert(repr, tostring(value))
      end
      table.insert(repr, "")
      return table.concat(repr, "")
    end,
    __eq = function(self, other)
      return getmetatable(self) == getmetatable(other) and
        tostring(self) == tostring(other)
    end
  }, {__call = function(non_terminal, ...)
      return setmetatable({
        name=name,
        is_terminal=false,
        ...}, non_terminal)
    end,
    __tostring = function(self)
      return name
    end})

  non_terminal.__index = non_terminal
  return non_terminal
end

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

local SKIP = "SKIP"
local PEEK = "PEEK"
local OPTION = "OPTION"
local REPEAT = "REPEAT"

local LABEL, ALL, ANY, SET

local function is(reader, flag)
  local rule = getmetatable(reader)
  if flag == nil then -- verify `reader` is a rule
    return rule == ALL or rule == ANY or rule == LABEL or rule == SET
  end
  if flag == ALL or flag == ANY or flag == LABEL or flag == SET then
    return rule == flag
  end
  if rule ~= LABEL then
    return false
  end
  return reader[flag]
end

LABEL = setmetatable({
  representation = function(self)
    return tostring(self)
  end,
  __call = function(self, environment, bytes, stack)
    return self[1](environment, bytes, stack)
  end,
  __tostring = function(self)
    local text = tostring(car(self))
    if is(self, OPTION) then
      text = "["..text.."]"
    end
    if is(self, REPEAT) then
      text = "{"..text.."}"
    end
    if is(self, SKIP) then
      text = "~"
    end
    return text
  end
}, {
  __call = function(LABEL, reader, ...)
    local self = setmetatable({reader}, LABEL)
    assert(reader, "missing `reader` argument.")
    for i, value in ipairs({...}) do
      self[value] = true
    end
    return self
  end,
  __tostring = function()
    return "LABEL"
  end
})

LABEL.__index = LABEL

SET = setmetatable({
  __call = function(self, environment, bytes, stack)
    return self[1](environment, bytes, list.push(stack, self.nonterminal))
  end,
  __tostring = function(self)
    return tostring(self.nonterminal)
  end
}, {
  __call = function(SET, nonterminal, reader, factory)
    assert(nonterminal)
    local self = setmetatable({reader,
      nonterminal=nonterminal,
      factory=factory}, SET)
    return self
  end,
  __tostring = function()
    return "SET"
  end
})
SET.__index = SET

ANY = setmetatable({
  __call = function(self, environment, bytes, stack)
    -- find the one that consumes most tokens
    for i, reader in ipairs(self) do
      if reader ~= nil then
        assert(not is(reader, OPTION))
        assert(not is(reader, SKIP))
        assert(not is(reader, REPEAT))
        assert(reader)
        local ok, values, rest = pcall(execute, reader, environment, bytes,
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
    local repr = {"ANY("}
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
  __call = function(ANY, ...)
    return setmetatable({list.unpack(itertools.filter(id, list(...)))}, ANY)
  end,
  __tostring = function()
    return "ANY"
  end
})

ALL = setmetatable({
  __call = function(self, environment, bytes, stack)
    local values, rest, all, ok = nil, bytes, {}
    for i, reader in ipairs(self) do
      if reader ~= nil then
        while true do
          assert(reader)
          local prev = rest
          local prev_meta = environment._META[rest]
          if is(reader, OPTION) or is(reader, REPEAT) then
            ok, values, rest = pcall(execute, reader, environment, rest,
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
            values, rest = execute(reader, environment, rest, stack)
          end
          if not values then
            if is(reader, REPEAT) then
              break
            elseif not is(reader, OPTION) then
              return nil, bytes
            end
          end
          if is(reader, PEEK) then
            -- Restore any metadata at this point
            -- We don't want a PEEK operation to affect state.
            -- We didn't consume any input, it should not be recorded as we
            -- have.
            environment._META[prev] = prev_meta
            rest = prev
          elseif not is(reader, SKIP) then
            stack = list()
            for j, value in ipairs(values or {}) do
              table.insert(all, value)
            end
          end

          if not is(reader, REPEAT) then
            break
          end
        end
      end
    end
    return tolist(all), rest
  end,
  __tostring = function(self)
    local repr = {"ALL("}
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
  __call = function(ALL, ...)
    return setmetatable({list.unpack(itertools.filter(id, list(...)))}, ALL)
  end,
  __tostring = function()
    return "ALL"
  end
})

local function factor_terminal(terminal)
  local value = tostring(terminal)
  local reader = SET(terminal, function(environment, bytes)
    if list.concat(take(#value, bytes)) == value then
      return list(terminal), drop(#value, bytes)
    end
    return nil, bytes
  end)
  return reader
end

local function TERM(text)
  return factor_terminal(Terminal(text))
end

--- Returns a list of values from `parent` that when called on `f` returns
-- true.
-- @param f the function that returns true to return that argument. It will
--        also be given the parent.
-- @param parent the tree to go through.
local function filter(f, parent, ...)
  assert(is(parent), parent)
  local origin = list(nil)
  local last = origin
  for i, child in ipairs(parent) do
    if type(child) == "table" then
      if f(child, parent, ...) then
        last[2] = cons(child)
        last = last[2]
      end
      if is(child) and not is(child, SKIP) then
        last[2] = filter(f, child, parent, ...)
        if last[2] then
          last = last[2]
        end
      end
    end
  end
  return origin[2]
end

local factor_nonterminal

--- Return a list of all spans inside a rule wrapped in an ANY.
-- A span is any part of the rule that is an ALL or have no ALL ancestor.
-- that can satisfy a rule.
-- @param rule The rule to search for ALL's.
local function factor_spans(rule, ...)
  while not ... and is(rule, ANY) and #rule == 1 do
    rule = rule[1]
  end
  if not ... and (is(rule, ALL) or not is(rule, ANY)) then
    return ANY(rule)
  end
  local parents = {...}
  return ANY(list.unpack(filter(function(value, parent, ...)
    return not itertools.search(function(parent)
      return is(parent, ALL)
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
    rule = factor_spans(ANY(list.unpack(itertools.map(
      function(child)
        if not is(child, ALL) then
          return child
        end
        if #child > 0 and child[1].nonterminal ~= nonterminal
            and child[1].factory then
            continue = true
          return ALL(child[1].factory(function() end), unpack(slice(child, 2)))
        end
        return child
      end, rule))))
  end

  -- Refactor away ALL(ANY(ALL(ANY(....)))) wrapping.
  while (is(rule, ANY) or is(rule, ALL)) and #rule == 1 do
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
  local patterns = ANY()
  for i, rule in ipairs(rules) do
    local pattern = ALL(list.unpack(itertools.filter(function(span)
        if is(span, ALL) and span[1].nonterminal == nonterminal then
          return false
        end
        return true
      end, factor_spans(rule))))
    if #pattern > 0 then
      table.insert(patterns, pattern)
    end
  end
  return patterns
end

--- Factor `rule` by removing spans involving left recursion of `nonterminal`.
-- A span is any part of the rule that is an ALL or have no ALL ancestor,
-- that is not an ANY.
-- @param rule The rule to remove  `nonterminal` from.
-- @param nonterminal The nonterminal to remove.
local function factor_without_left_nonterminal(rule, nonterminal)
  return ANY(list.unpack(itertools.filter(function(child)
    if is(child, SKIP) then
      return false
    end
    if child.nonterminal == nonterminal then
      return false
    end
    if not is(child, ALL) then
      return true
    end
    if child[1].nonterminal == nonterminal or child.nonterminal == nonterminal then
      return false
    end
    return true
  end, factor_spans(rule))))
end

--- Factor `rule` into suffixes of spans involving left recursion of
-- `nonterminal`.
-- A span is any part of the rule that is an ALL or have no ALL ancestor,
-- that is not an ANY.
-- @param nonterminal The nonterminal to remove.
local function factor_left_suffix(rule, nonterminal)
  return ANY(list.unpack(itertools.map(
    function(child)
      return ALL(unpack(slice(child, 2)))
    end, itertools.filter(function(child)
        if is(child, SKIP) then
          return false
        end
        if not is(child, ALL) then
          return false
        end
        if child[1].nonterminal == nonterminal
            or child.nonterminal == nonterminal then
          return true
        end
        return false
      end, factor_spans(rule)))))
end

factor_nonterminal = function(nonterminal, factory)
  assert(factory, "missing `factory` argument")
  local ok, origin = pcall(factory, id)

  if ok and not is(origin) then
    return SET(nonterminal, origin)
  else
    origin = nil
  end

  local left, is_annotated, read_take_terminals = {}
  local paths = setmetatable({}, {__mode='k'})
  local cache = setmetatable({}, {__mode='k'})
  local spans

  return SET(nonterminal, function(environment, bytes, stack)
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
        -- We have all the Left recursions in `left`, and prefixes in `prefix`.
        -- We need to refactor the Left's into a flat shape and project it onto 
        -- `bytes`. Then figure out which step which left is called on each 
        -- iteration. This is done next, and saved in paths[bytes].
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
        local from = itertools.search(function(nonterminal)
            return itertools.search(function(info) return
                info.nonterminal == nonterminal end, left)
          end, cdr(stack))
        if from then
          -- Called from `from`. E.g.
          -- With the following Grammar:
          --   read_functioncall = ALL(read_prefixexp args)
          --   read_prefixexp = LEFT(read_functioncall) | name
          --
          -- The following call is made:
          --   read_functioncall(environment, bytes)
          --
          -- At this line in the code with the above scenario,
          --   `stack` is (prefixexp functioncall)
          --   `nonterminal` is `prefixexp`.
          --   `from` is `read_functioncall`, is the parent call that's
          --          executed the current `read_prefixexp`.
          -- 
          -- When deriving `prefixexp` we want to drop the last call to
          -- `read_functioncall`, and leave stuff for the parent 
          -- `read_functioncall` call to parse.
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
        -- E.g. read_a = ANY(TERM("a"), ALL(TERM("("), read_exp, TERM(")"))
        --      read_t = ANY(read_exp, read_a)
        --    Assume `read_exp` left recurses back to `read_t`.
        -- The `read_a` non-left-recursion choice makes `read_t` "independent".
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
        local matching, values = prefix
        while matching and rest do
          matching = nil
          for i, info in ipairs(left) do
            values, rest = info.suffixes(environment, rest)
            if values ~= nil and rest ~= bytes then
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
      ok, origin = pcall(factory, function(reader)
        -- Whether to show `reader` on this iteration.
        index = index + 1
        if index == path then
          return reader
        end
      end)
      if not ok then
        local err = origin
        raise(GrammarException(environment, bytes, nonterminal, err))
      end
    end
    local ok, values, rest = pcall(execute, origin, environment, bytes, stack)
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
  TERM=TERM,
  SKIP=SKIP,
  OPTION=OPTION,
  REPEAT=REPEAT,
  ALL=ALL,
  ANY=ANY,
  SET=SET,
  LABEL=LABEL,
  Terminal=Terminal,
  NonTerminal=NonTerminal,
  is=is,
  factor_nonterminal=factor_nonterminal,
  factor_terminal=factor_terminal,
  search=search,
  filter=filter,
  ExpectedNonTerminalException=ExpectedNonTerminalException,
  ParseException=ParseException,
  GrammarException=GrammarException
}