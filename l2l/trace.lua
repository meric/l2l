local unpack = _G["unpack"] or table.unpack
local pack = table.pack or function(...) return {n=select("#", ...), ...} end
local len = require("l2l.len")

local level = setmetatable({
  __tostring = function(self)
    local text = {}
    if self.message then
      table.insert(text, "ERROR: "..tostring(self.message))
    end
    if self.previous then
      table.insert(text, tostring(self.previous))
    end
    table.insert(text, self.location)
    return table.concat(text, "\n")
  end,
  __len = function(self)
    if not self.previous then
      return 1
    end
    return 1 + len(self.previous)
  end}, {
  __call = function(level, location, previous)
    local message
    if getmetatable(previous) == level then
      message = nil
      if len(previous) > 10 then
        -- Maximum 10 levels displayed.
        previous = nil
      end
    else
      message = tostring(previous):match(":[0-9]+:%s*([^\n]+)")
      previous = nil
    end
    return setmetatable({
      message = message,
      location = location,
      previous = previous
    }, level)
  end
})

return function (exception, f, ...)
  local returns = pack(pcall(f, ...))
  local ok = returns[1]
  if ok then
    return unpack(returns, 2, returns.n)
  end
  error(level(exception, returns[2]))
end
