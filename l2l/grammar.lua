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
local map = itertools.map
local show = itertools.show
local slice = itertools.slice
local take = itertools.take
local tolist = itertools.tolist

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
      local origin = list(self.read)
      local last = origin
      for i, value in ipairs(self) do
        local repr = type(value) == "string" and value or value:representation()
        last[2] = cons(repr)
        last = last[2]
      end
      return origin
    end,
    is_valid = function(self)
      return pcall(execute, self.read, nil, tolist(tostring(self)))
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
  is_valid = function(self)
    return pcall(execute, self.read, nil, tolist(tostring(self)))
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
local OPT = "OPT"
local REPEAT = "REPEAT"

local READ, ALL, ANY

local function is(reader, flag)
  local rule = getmetatable(reader)
  if flag == nil then -- verify `reader` is a rule
    return rule == ALL or rule == ANY or rule == READ
  end
  if flag == ALL or flag == ANY or flag == READ then
    return rule == flag
  end
  assert(contains({SKIP, PEEK, OPT, REPEAT}, flag))
  if rule ~= READ then
    return false
  end
  return reader[flag]
end

READ = setmetatable({
  representation = function(self)
    return tostring(self)
  end,
  __call = function(self, environment, bytes, targets)
    return self[1](environment, bytes, targets)
  end,
  __tostring = function(self)
    local text = tostring(car(self))
    if is(self, OPT) then
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
  __call = function(READ, reader, ...)
    local self = setmetatable({reader}, READ)
    assert(reader, "missing `reader` argument.")
    for i, value in ipairs({...}) do
      self[value] = true
    end
    return self
  end,
  __tostring = function()
    return "READ"
  end
})

READ.__index = READ

local SET = setmetatable({
  __call = function(self, environment, bytes, targets)  
    -- CALL THIS WITH THE NONTERMINAL STATE? SO I CAN CHECK WHERE ITS LOOPING FROM.
    -- SOME SORT OF STACK?
    return self[1](environment, bytes, list.push(targets, self.target))
  end,
  __tostring = function(self)
    return tostring(self.target)
  end
}, {
  __call = function(SET, target, reader, factory)
    assert(target)
    local self = setmetatable({reader, target=target}, SET)
    target.read = self
    target.factory = factory
    return self
  end,
  __tostring = function()
    return "SET"
  end
})
SET.__index = SET

local function index_of_sublist(origin, sub)
  local count = 0 
  if origin == sub then
    return 0
  end
  return 1 + index_of_sublist(origin[2], sub)
end

ANY = setmetatable({
  __call = function(self, environment, bytes, targets)
    -- find the one that consumes most tokens
    for i, reader in ipairs(self) do
      if reader ~= nil then
        assert(not is(reader, OPT))
        assert(not is(reader, SKIP))
        assert(not is(reader, REPEAT))
        assert(reader)
        local ok, values, rest = pcall(execute, reader, environment, bytes,
          targets)
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
  __call = function(self, environment, bytes, targets)
    local values, rest, all, ok = nil, bytes, {}
    for i, reader in ipairs(self) do
      if reader ~= nil then
        while true do
          assert(reader)
          local prev = rest
          local prev_meta = environment._META[rest]
          if is(reader, OPT) or is(reader, REPEAT) then
            ok, values, rest = pcall(execute, reader, environment, rest,
              targets)
            if not ok then
              rest = prev -- restore to previous point.
              if getmetatable(values) == ExpectedNonTerminalException then
                break
              else
                raise(values)
              end
            end
          else
            values, rest = execute(reader, environment, rest, targets)
          end
          if not values then
            if is(reader, REPEAT) then
              break
            elseif not is(reader, OPT) then
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
            targets = list()
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

local function read_terminal(terminal)
  local value = tostring(terminal)
  local reader = SET(terminal, function(environment, bytes)
    if list.concat(take(#value, bytes)) == value then
      return list(terminal), drop(#value, bytes)
    end
    return nil, bytes
  end)
  return reader
end


--- Return the value of the first node in `parent` whose value when called on
-- `f` returns true. 
-- @param f the function that returns true to return that argument. It will
--        also be given the parent.
-- @param parent the tree to go through.
local function search(f, parent)
  assert(is(parent), parent)
  local origin = list(nil)
  local last = origin
  for i, child in ipairs(parent) do
    if type(child) == "table" then
      if f(child, parent) then
        return child
      end
      if is(child) and not is(child, SKIP) then
        search(f, child)
      end
    end
  end
  return origin[2]
end

--- Returns a list of values from `parent` that when called on `f` returns
-- true.
-- @param f the function that returns true to return that argument. It will
--        also be given the parent.
-- @param parent the tree to go through.
local function filter(f, parent)
  assert(is(parent), parent)
  local origin = list(nil)
  local last = origin
  for i, child in ipairs(parent) do
    if type(child) == "table" then
      if f(child, parent) then
        last[2] = cons(child)
        last = last[2]
      end
      if is(child) and not is(child, SKIP) then
        last[2] = filter(f, child)
        if last[2] then
          last = last[2]
        end
      end
    end
  end
  return origin[2]
end

local read_nonterminal


-- Return how many times child should be recursively called.
local function find_maximum_count(environment, bytes, head, parent, child)
  local tail = child.factory(environment, bytes, list(),
    function(head, reader)
      return reader
    end)
  local values, rest = head(environment, bytes)
  if values == nil and rest == bytes then
    return 0
  end
  local minimum_repeats = 1
  filter(function(value, rule)
    if getmetatable(rule) == ALL then
      return false
    end
    local found = false
    for i, reader in ipairs(value) do
      if type(reader) == "table" and reader.target == parent then
        found = true
        break
      end
    end
    if not found then
      if minimum_repeats > 0 and value(environment, bytes) then
        minimum_repeats = 0
      end
    end
  end, tail)

  local spans = filter(function(value)
    if getmetatable(value) ~= ALL then
      return false
    end
    local found = false
    for i, reader in ipairs(value) do
      if type(reader) == "table" and reader.target == parent then
        found = true
        break
      end
    end
    return found
  end, tail)

  -- ALL rule spans beginning with `parent`.
  local sections = map(function(section)
    local index
    for i, value in ipairs(section) do
      if value.target == parent then 
        index = i
        break
      end
    end
    local span = ALL(unpack(slice(section, index + 1)))
    return read_nonterminal(NonTerminal(tostring(span)), function()
      return span
    end, true)
  end, spans)
  local repeats = ALL(READ(ANY(list.unpack(sections)), REPEAT))
  local ok, values, _rest = pcall(repeats, environment, rest)
  if not ok then
    return 0
  end
  local count = list.__len(values)
  return count + (1-minimum_repeats)
end


read_nonterminal = function(nonterminal, factory, const)
  assert(factory, "missing `factory` argument")
  local maximum_counts, origin, ok = {}

  local state = nil
 

  local reader = SET(nonterminal, function(environment, bytes, targets)
    if not const and not state and nonterminal then
      state = {
        lefts={}
      }

      state.origin = factory(function(head, reader)
        table.insert(state.lefts, reader)
        return reader
      end)
      -- state = {}
    end
    if state then
      -- print(nonterminal, state.origin, show(state.lefts))
    end

    if not origin or not const then
      ok, origin = pcall(factory, function(head, reader)
          -- mutual recursion can't just rely on counts.
          local child = reader.target
          local count = list.count(targets, child)
          maximum_counts[bytes] = maximum_counts[bytes] or {}
          local maximum_count = maximum_counts[bytes][child]
          if not maximum_count then
            maximum_counts[bytes][child] = 1
            maximum_count = find_maximum_count(environment, bytes,
              head, nonterminal, child)
            maximum_counts[bytes][child] = maximum_count
          end
          return (count == 0 or count < maximum_count) and reader
        end)
      if not ok then
        local err = origin
        raise(GrammarException(environment, bytes, nonterminal, err))
      end
    end
    -- print("[", nonterminal, bytes)
    local ok, values, rest = pcall(execute, origin, environment, bytes,
      targets)
    -- print("]", nonterminal, rest, ok, values)
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
      raise(ExpectedNonTerminalException(environment, bytes, origin,
        show(list.concat(bytes))))
    end
    return list(nonterminal(list.unpack(values))), rest
  end, factory)
  return reader
end

local function TERM(text)
  return read_terminal(Terminal(text))
end

return {
  TERM=TERM,
  SKIP=SKIP,
  OPT=OPT,
  REPEAT=REPEAT,
  ALL=ALL,
  ANY=ANY,
  SET=SET,
  READ=READ,
  Terminal=Terminal,
  NonTerminal=NonTerminal,
  is=is,
  read_nonterminal=read_nonterminal,
  read_terminal=read_terminal,
  search=search,
  filter=filter,
  ExpectedNonTerminalException=ExpectedNonTerminalException,
  ParseException=ParseException,
  GrammarException=GrammarException
}