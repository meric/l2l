local function profile(method)
  local hook = debug.gethook()
  assert(debug.sethook)
  local calls, total, this, lines = {}, {}, {}, {}
  debug.sethook(function(event, line)
    local i = debug.getinfo(2, "Sn")
    if i.what ~= 'Lua' then return end
    local func = ((i.name or i.source)..':'..i.linedefined)
    if event == 'call' or event == 'tail call' then
      this[func] = os.clock()
    elseif event == "return" then
      if not this[func] then
      this[func] = os.clock()
      end
      local time = os.clock() - this[func]
      total[func] = (total[func] or 0) + time
      calls[func] = (calls[func] or 0) + 1
    elseif event == "line" then
      lines[func] = line
    end
  end, "lcr");

  local returns={method()}

  debug.sethook(hook)

  local output = {}
  for f, time in pairs(total) do
    table.insert(output, {
      f,
      lines[f],
      ("%.3f seconds"):format(time),
      ("%d calls"):format(calls[f])})
  end
  table.sort(output, function(a, b) return a[3] < b[3] end)

  print("function", "line", "total time", "number of calls")
  for _, value in ipairs(output) do
    print(unpack(value))
  end
  return unpack(returns)
end

return {
  profile = profile
}
