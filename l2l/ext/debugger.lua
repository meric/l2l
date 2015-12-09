--[[
Copyright © 2012-2015, Eric Man and contributors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

Redistributions in binary form must reproduce the above copyright notice, this
list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]--

-- See samples/sample09. 

local _require = require
local _mtime = {}
local _modules = {}
local _preload
local _postload

local function append(t, ...)
  local n = {}
  for i, v in ipairs(t) do
    table.insert(n, v)
  end
  for i, v in ipairs({...}) do
    table.insert(n, v)
  end
  return n
end

local function mtime(path)
  if _mtime[path] and os.time() - _mtime[path][2] <= 1 then
    return _mtime[path][1]
  end
  local f = io.popen("stat -f '%Sm' "..path)
  local time = f:read('*line')
  f:close()
  _mtime[path] = {time, os.time()}
  return time
end

local function location(path)
  for match in package.path:gmatch("[^;]+") do
    local filepath = match:gsub("?", path)
    local file = io.open(filepath, 'r')
    if file then
      file:close()
      return filepath
    end
  end
end

local function context(path)
  return _modules[path].func
end

local function rewind(path, steps)
  local present = _modules[path].func
  return present:rewind(steps)
end

local function reload(path)
  local present = _modules[path].func
  local time = _modules[path].time
  if os.time() - time > 1 then
    local filepath = location(path)
    local modified = mtime(filepath)
    if modified ~= _modules[path].modified or time == 0 then
      print("require(\"" .. path .. "\")")
      local future, err = loadfile(filepath)
      _modules[path].time = os.time()
      _modules[path].modified = modified
      if future then
        if _preload then
          _preload()
        end
        present:push(future)
        if _postload then
          _postload()
        end
      else
        if not present:present() then
          error(err)
        end
        print("Fix the following error to continue.")
        print(err)
      end
    end
  end
  return present
end

local MutableFunction

MutableFunction = setmetatable({
  present = function(self)
    return self[#self]
  end,
  mock = function(self, returns)
    table.insert(self.history, returns)
  end,
  __tostring = function(self)
    return table.concat(self.index, ".")
  end,
  __call = function(self, ...)
    if #self.history > 0 then
      return unpack(table.remove(self.history, 1))
    end
    local present = self:present()
    local returns = {present(...)}
    if _context then
      table.insert(_context.mutables, {
        mutable=self,
        returns=returns
      })
    end
    return unpack(returns)
  end
}, {__call=function(MutableFunction, f, index)
  return setmetatable({f, index=index, history={}}, MutableFunction)
end})


MutableFunction.__index = MutableFunction

local Function

function require(path)
  local filepath = location(path)
  if not filepath then
    _require(path)
    error(path.." library could not be loaded.")
  end
  _modules[path] = {
    func=Function(path, path, nil),
    time=0,
    modified=mtime(filepath)}
  return reload(path)()
end

Function = setmetatable({
  __tostring = function(self)
    return self.name
  end,
  watch = function(self, func)
    self.watched[func] = {}
    return self.watched[func]
  end,
  lift = function(self, value, event, index)
    if type(value) == "function" then
      local child = Function(
        self.name.."."..table.concat(index, "."),
        self.path,
        self)
      child:push(value)
      table.insert(event, {index=index, func=child})
      return child
    end
    if type(value) == "table" then
      for k, v in pairs(value) do
        if value ~= v then
          value[k] = self:lift(v, event, append(index, k))
        end
      end
      return value
    end
    return value
  end,
  to = function(self, present, future, index)
    if type(future) == "function" then
      local type_is_matching = getmetatable(present) == Function
      if type_is_matching then
        present:push(future)
        return present
      else
        return Function(self.name.."."..table.concat(index, "."),
          self.path,
          self)
      end
    elseif type(future) == "table" then
      local type_is_matching = type(present) == "table" 
        and getmetatable(present) ~= Function
      for k, value in pairs(future) do
        if type_is_matching then
          future[k] = self:to(present[k], future[k], append(index, k))
        end
      end
      return future      
    else
      return future
    end
  end,
  reticulate=function(self)
    for i, event in ipairs(self.history) do
      if event.func then
        local parameters = event.arguments.parameters
        local func = event.func
        local present = func:present()
        self:mock(event)
        local returns = {present(unpack(parameters))}
        self:to(event.returns, returns, append(event.index or {}, i))
      end
    end
    for i, event in ipairs(self.history) do
      if event.func then
        event.func:reticulate()
      end
    end
  end,
  mock = function(self, event)
    local times = 0
    for i, instance in ipairs(event.mutables) do
      times = times + 1
      instance.mutable:mock(instance.returns)
      mutable = instance.mutable
    end
  end,
  rewind = function(self, steps)
    -- self.history[steps] = nil
    if self.module_invocation then
      self:mock(self.module_invocation)
      local returns = {loadfile(location(self.path))()}
      self:to(self.module_invocation.returns, returns, {})
      for i, event in ipairs(self.history) do
        if i > steps then
          break
        end
        if event.func then
          local parameters = event.arguments.parameters
          local func = event.func
          local present = func:present()
          func:mock(event)
          self:to(event.returns, {present(unpack(parameters))}, {})
        end
      end
      for i, event in ipairs(self.history) do
        if i > steps then
          break
        end
        if event.func then
          event.func:reticulate()
        end
      end
    end
    return self
  end,
  push = function(self, future)
    self[1] = future
    if self.module_invocation then
      self:mock(self.module_invocation)
      local returns = {future()}
      self:to(self.module_invocation.returns, returns, {})
      for i, event in ipairs(self.history) do
        if event.func then
          local parameters = event.arguments.parameters
          local func = event.func
          local present = func:present()
          func:mock(event)
          self:to(event.returns, {present(unpack(parameters))}, {})
        end
      end
      for i, event in ipairs(self.history) do
        if event.func then
          event.func:reticulate()
        end
      end
    end
  end,
  present = function(self)
    return self[#self]
  end,
  invoke = function(self, ...)
    reload(self.path)

    local present = self:present()

    local arguments = {
      parameters={...},
      _G=_G}

    local event = {func=self, arguments=arguments, index={}, mutables={}}

    if self.parent then
      table.insert(self.parent.history, event)
      for func, events in pairs(self.parent.watched) do
        if self == func then
          table.insert(events, #self.parent.history)
        end
      end
    else
      self.module_invocation = event
    end

    _context = event

    event.returns = {present(...)}

    for i, value in ipairs(event.returns) do
      event.returns[i] = self:lift(value, event, {i})
    end

    return unpack(event.returns)
  end,
  __call = function(self, ...)
    return self:invoke(...)
  end
}, {__call=function(Function, name, path, parent)
  local self = setmetatable({
    name=name,
    path=path,
    parent=parent,
    history={},
    watched={}
  }, Function)
  return self
end})

Function.__index = Function

local function record(t, index, cache)
  cache = cache or {}
  index = index or {}
  if t == table then
    return t
  end
  cache[t] = true
  if type(t) == "table" then
    for k, v in pairs(t) do
      if not cache[v] then
        t[k] = record(v, append(index, k), cache)
      end
    end
    return t
  elseif type(t) == "function" then
    return MutableFunction(t, index)
  else
    return t
  end
end

local function prereload(f)
  _preload = f
end

local function postreload(f)
  _postload = f
end

return {
  record = record,
  prereload = prereload,
  postreload = postreload,
  reload=reload,
  rewind=rewind,
  context=context
}
