local unpack = _G["unpack"] or table.unpack

return function (exception, f, ...)
  local returns = table.pack(pcall(f, ...))
  local ok = returns[1]
  if ok then
    return unpack(returns, 2, returns.n)
  end
  error("ERROR: "..returns[2]:match(":[0-9]+:%s*([^\n]+)").."\n"..exception)
end
