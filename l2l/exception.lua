local function lineat(src, index)
  if index > #src or index < 0 then
    print(debug.traceback())
    error('index out of bounds: '.. index)
  end
  local cursor = index
  local start = cursor
  local char = src:sub(cursor, cursor)
  local line = ""
  while cursor > 0 and char ~= "\n" do
    line = char..line
    cursor = cursor - 1
    char = src:sub(cursor, cursor)
  end
  cursor = math.max(cursor, 0)
  start = cursor
  cursor = index + 1
  char = src:sub(cursor, cursor)
  while cursor <= #src and char ~= "\n" do
    line = line..char
    cursor = cursor + 1
    char = src:sub(cursor, cursor)
  end
  cursor = math.min(cursor, #src + 1)
  local check = src:sub(start + 1, cursor - 1)
  if check ~= line then
    error('lineat error: \n"'..line ..'"\n does not match \n"'..check..'"')
  end
  return line, start + 1, cursor-1
end

local function pointat(src, index)
  local line, start, finish = lineat(src, index)
  local display = ""
  for i=start, finish, 1 do
    if i == index then
      display = display.."^"
    else
      display = display.."~"
    end
  end
  return display
end

local function numberat(src, index)
  local count = 1
  for i=1, #src:sub(0, index) do
    if src:sub(i, i) == "\n" then
      count = count + 1
    end
  end
  return count
end

local function formatsource(src, message, index)
  local messages = {}
  local linenumber = numberat(src, index)
  local line, start, finish = lineat(src, index)
  local columnnumber = index - start + 1

  table.insert(messages, tostring(message).." at line "..linenumber..
    ", column "..columnnumber..":")
  local stack, content = {}
  for i=1, 3 do
    if start >= 2 then
      content, start = lineat(src, start-2)
      table.insert(stack, content)
    end
  end
  for i=0, #stack-1 do
    table.insert(messages, linenumber-(#stack-i).."\t|"..stack[(#stack-i)])
  end
  table.insert(messages, linenumber.."\t|".. line)
  table.insert(messages, "\t|".. pointat(src, index))
  for i=1, 3 do
    if finish + 1 <= #src then
      content, start, finish = lineat(src, finish+1)
      table.insert(messages, (linenumber + i).."\t|"..content)
    end
  end
  return messages
end

local function raise(except, stream, position)
  if type(except) == "string" then
    error("expected non-string exception." .. except)
    local index = stream:seek("cur")
    stream:seek("set", 0)
    local src = stream:read("*all")
    stream:seek("set", index)
    error(table.concat(formatsource(src, except, index), "\n"))
  else
    if stream then
      if position then
        stream:seek("set", position)
      end
      except = except(stream)
    end
    error(except)
  end
end

local Exception;
Exception = {
  __tostring = function(self)
    return self.message or ""
  end,
  __call = function(self, stream, ...)
    if not stream then
      print(debug.traceback())
      error("stream argument expected")
    end
    local message = ""
    local index = stream:seek("cur")
    stream:seek("set", 0)
    local src = stream:read("*all")
    stream:seek("set", index)
    if type(self.message) == "function" then
      if not ... and self.parameters then
        message = self:message(stream, unpack(Exception.parameters))
      elseif ... then
        message = self:message(stream, ...)
      else
        message = self:message(stream)
      end
    else
      message = self.message
    end
    local messages = formatsource(src, message, index)
    local instance = setmetatable({
      stream=stream, 
      parameters={...},
      message=table.concat(messages, "\n")}, self)
    return instance
  end
}


local function exception(message)
  local class = setmetatable({message=message,
    __tostring = function(self) 
      return tostring(self.message) or ""
    end}, Exception)
  class.__index = class
  return class
end

return setmetatable({
    exception = exception,
    Exception = Exception,
    raise = raise,
    formatsource = formatsource,
    lineat = lineat,
    pointat = pointat,
    numberat = numberat
}, {__call = function(self, ...) return exception(...) end})
